#!/usr/bin/env python3
"""
sysmon.py — backend for the ii System Monitor (Quickshell).

Pure Python, no dependencies. Reads /proc and /sys and prints one JSON
object per line on stdout. Accepts commands on stdin, one per line:

    interval <ms>          refresh interval (250..10000)
    sort <key> <asc|desc>  key: cpu mem pid name user threads time
    filter <text>          filter processes by name / user / pid / cmdline
    percore <0|1>          process CPU% relative to one core (top-style)
    limit <n>              max processes sent
    kill <pid> <signal>    send a signal to a process
    refresh                re-send the process list now (re-sorted)
"""
import glob
import json
import os
import platform
import pwd
import re
import select
import signal
import socket
import subprocess
import sys
import time

CLK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
NCPU = os.cpu_count() or 1

state = {
    "interval": 1.0,
    "sort": "cpu",
    "desc": True,
    "filter": "",
    "percore": False,
    "limit": 250,
}

SORT_KEYS = {"cpu", "mem", "pid", "name", "user", "threads", "time"}
REAL_FS = {"ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "vfat", "exfat",
           "ntfs", "ntfs3", "fuseblk", "zfs", "bcachefs", "jfs", "reiserfs"}
WHOLE_DISK = re.compile(r"nvme\d+n\d+|mmcblk\d+|(?:sd|vd|hd|xvd)[a-z]+")


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def emit(obj):
    try:
        sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
        sys.stdout.flush()
    except (BrokenPipeError, ValueError):
        sys.exit(0)


# ───────────────────────── static info ─────────────────────────

def cpu_model():
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            name = line.split(":", 1)[1]
            for junk in ("(R)", "(TM)", "(tm)", " CPU", " Processor"):
                name = name.replace(junk, "")
            name = name.split("@")[0]
            return " ".join(name.split())
    return platform.processor() or "CPU"


def find_temp_sensor():
    """Return (path_to_package_temp_input or None)."""
    preferred = ("coretemp", "k10temp", "zenpower", "cpu_thermal", "acpitz")
    found = {}
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read(os.path.join(hw, "name")).strip()
        if name in preferred:
            found.setdefault(name, hw)
    for name in preferred:
        hw = found.get(name)
        if not hw:
            continue
        inputs = sorted(glob.glob(os.path.join(hw, "temp*_input")))
        # prefer the "Package id 0" / "Tctl" / "Tdie" label
        for inp in inputs:
            label = read(inp.replace("_input", "_label")).strip()
            if label.startswith(("Package", "Tctl", "Tdie")):
                return inp
        if inputs:
            return inputs[0]
    # fallback: thermal zones
    for tz in glob.glob("/sys/class/thermal/thermal_zone*"):
        if read(os.path.join(tz, "type")).strip() in ("x86_pkg_temp", "cpu-thermal"):
            return os.path.join(tz, "temp")
    return None


TEMP_PATH = find_temp_sensor()


def find_nvidia():
    for dev in glob.glob("/sys/bus/pci/devices/*"):
        if read(os.path.join(dev, "vendor")).strip() == "0x10de" and \
                read(os.path.join(dev, "class")).strip().startswith("0x03"):
            return dev
    return None


NVIDIA_DEV = find_nvidia()
HAS_NVSMI = any(os.access(os.path.join(p, "nvidia-smi"), os.X_OK)
                for p in os.environ.get("PATH", "").split(":") if p)


# ───────────────────────── CPU ─────────────────────────

_prev_cpu = None


def cpu_usage():
    """Returns (per-line usage list [total, cpu0, cpu1...], aggregate jiffies delta)."""
    global _prev_cpu
    cur = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        p = line.split()
        vals = [int(x) for x in p[1:9]]  # user nice system idle iowait irq softirq steal
        cur.append((sum(vals), vals[3] + vals[4]))
    usage, dtotal = [0.0] * len(cur), 0
    if _prev_cpu and len(_prev_cpu) == len(cur):
        dtotal = cur[0][0] - _prev_cpu[0][0]
        for i, ((t, idle), (pt, pidle)) in enumerate(zip(cur, _prev_cpu)):
            dt, di = t - pt, idle - pidle
            usage[i] = max(0.0, min(1.0, (dt - di) / dt)) if dt > 0 else 0.0
    _prev_cpu = cur
    return usage, dtotal


def cpu_freq():
    freqs = []
    for i in range(NCPU):
        v = read(f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_cur_freq").strip()
        if v.isdigit():
            freqs.append(int(v) / 1000.0)
    if not freqs:
        for line in read("/proc/cpuinfo").splitlines():
            if line.startswith("cpu MHz"):
                try:
                    freqs.append(float(line.split(":")[1]))
                except ValueError:
                    pass
    return (sum(freqs) / len(freqs)) if freqs else 0.0, max(freqs) if freqs else 0.0


def cpu_temp():
    if not TEMP_PATH:
        return -1
    v = read(TEMP_PATH).strip()
    try:
        return int(v) / 1000.0
    except ValueError:
        return -1


# ───────────────────────── memory ─────────────────────────

def memory():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        parts = v.split()
        if parts:
            info[k] = int(parts[0]) * 1024
    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", info.get("MemFree", 0))
    cached = info.get("Cached", 0) + info.get("SReclaimable", 0) + info.get("Buffers", 0)
    st, sf = info.get("SwapTotal", 0), info.get("SwapFree", 0)
    return {
        "total": total,
        "used": total - avail,
        "available": avail,
        "cached": cached,
        "free": info.get("MemFree", 0),
        "swapTotal": st,
        "swapUsed": st - sf,
    }


# ───────────────────────── disks ─────────────────────────

def disks():
    seen, out = set(), []
    for line in read("/proc/mounts").splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        dev, mnt, fs = parts[0], parts[1].replace("\\040", " "), parts[2]
        if fs not in REAL_FS or dev in seen:
            continue
        try:
            st = os.statvfs(mnt)
        except OSError:
            continue
        total = st.f_blocks * st.f_frsize
        if total == 0:
            continue
        seen.add(dev)
        free = st.f_bavail * st.f_frsize
        used = total - st.f_bfree * st.f_frsize
        out.append({"mount": mnt, "dev": os.path.basename(dev), "fs": fs,
                    "total": total, "used": used, "free": free})
    out.sort(key=lambda d: (d["mount"] != "/", d["mount"]))
    return out[:6]


def disk_io_bytes():
    r = w = 0
    for line in read("/proc/diskstats").splitlines():
        p = line.split()
        if len(p) < 10:
            continue
        # whole disks only: nvme0n1 (not nvme0n1p1), sda (not sda1), mmcblk0 (not mmcblk0p1)
        if not WHOLE_DISK.fullmatch(p[2]):
            continue
        r += int(p[5]) * 512
        w += int(p[9]) * 512
    return r, w


# ───────────────────────── network ─────────────────────────

def default_iface():
    for line in read("/proc/net/route").splitlines()[1:]:
        p = line.split()
        if len(p) > 1 and p[1] == "00000000":
            return p[0]
    return ""


VIRTUAL_IF = ("lo", "veth", "docker", "br-", "virbr", "podman", "cni", "flannel", "vnet")


def net_bytes():
    iface = default_iface()
    rx = tx = 0
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, data = line.partition(":")
        name = name.strip()
        p = data.split()
        if len(p) < 9:
            continue
        if iface:
            if name != iface:
                continue
        elif name.startswith(VIRTUAL_IF):
            continue
        rx += int(p[0])
        tx += int(p[8])
    return iface, rx, tx


# ───────────────────────── battery / gpu ─────────────────────────

def battery():
    bats = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    if not bats:
        return None
    b = bats[0]
    cap = read(os.path.join(b, "capacity")).strip()
    status = read(os.path.join(b, "status")).strip()
    power = 0.0
    pn = read(os.path.join(b, "power_now")).strip()
    if pn.isdigit():
        power = int(pn) / 1e6
    else:
        cn, vn = read(os.path.join(b, "current_now")).strip(), read(os.path.join(b, "voltage_now")).strip()
        if cn.isdigit() and vn.isdigit():
            power = int(cn) * int(vn) / 1e12
    return {"percent": int(cap) if cap.isdigit() else 0, "status": status or "Unknown",
            "watts": round(power, 1)}


_gpu_cache = {"t": 0.0, "data": None}


def gpu():
    """NVIDIA only. Never wakes a sleeping dGPU (Optimus laptops)."""
    if not NVIDIA_DEV:
        return None
    now = time.monotonic()
    if now - _gpu_cache["t"] < 3.0:
        return _gpu_cache["data"]
    _gpu_cache["t"] = now
    runtime = read(os.path.join(NVIDIA_DEV, "power", "runtime_status")).strip()
    data = {"name": "NVIDIA GPU", "sleeping": False, "util": 0, "memUsed": 0,
            "memTotal": 0, "temp": -1}
    prev = _gpu_cache["data"]
    if prev:
        data["name"] = prev["name"]
    if runtime == "suspended" or not HAS_NVSMI:
        data["sleeping"] = runtime == "suspended"
        data["available"] = HAS_NVSMI
        _gpu_cache["data"] = data
        return data
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2).stdout.strip().splitlines()
        if out:
            name, util, mu, mt, temp = [x.strip() for x in out[0].split(",")]
            data.update({"name": name.replace("NVIDIA GeForce ", "").replace("NVIDIA ", ""),
                         "util": int(float(util)), "memUsed": int(float(mu)) * 1048576,
                         "memTotal": int(float(mt)) * 1048576, "temp": int(float(temp))})
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    data["available"] = True
    _gpu_cache["data"] = data
    return data


# ───────────────────────── processes ─────────────────────────

_prev_proc = {}
_users = {}
_last_procs = []
_proc_summary = {"total": 0, "running": 0, "threads": 0}


def user_of(uid):
    if uid not in _users:
        try:
            _users[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            _users[uid] = str(uid)
    return _users[uid]


def cmdline(pid):
    raw = read(f"/proc/{pid}/cmdline")
    # collapse NUL separators, newlines and tabs into single spaces (one-line display)
    return " ".join(raw.replace("\0", " ").split())[:300]


def scan_processes(dtotal, mem_total):
    global _prev_proc, _last_procs, _proc_summary
    procs, newprev = [], {}
    running = threads = 0
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        pid = int(name)
        try:
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
            uid = os.stat(f"/proc/{pid}").st_uid
        except OSError:
            continue
        l, r = stat.find("("), stat.rfind(")")
        comm = stat[l + 1:r]
        f = stat[r + 2:].split()
        try:
            st = f[0]
            ppid = int(f[1])
            ticks = int(f[11]) + int(f[12])
            nth = int(f[17])
            start = int(f[19])
            rss = int(f[21]) * PAGE
        except (IndexError, ValueError):
            continue
        prev = _prev_proc.get(pid)
        cpu = 0.0
        if prev and prev[1] == start and dtotal > 0:
            cpu = (ticks - prev[0]) / dtotal * 100.0
        newprev[pid] = (ticks, start)
        if st == "R":
            running += 1
        threads += nth
        procs.append({
            "pid": pid, "ppid": ppid, "name": comm, "user": user_of(uid),
            "state": st, "threads": nth, "cpuRaw": cpu,
            "rss": rss, "mem": (rss / mem_total * 100.0) if mem_total else 0.0,
            "time": ticks / CLK, "cmd": None,
        })
    _prev_proc = newprev
    _last_procs = procs
    _proc_summary = {"total": len(procs), "running": running, "threads": threads}


def visible_processes():
    mult = NCPU if state["percore"] else 1
    flt = state["filter"].lower()
    out = []
    for p in _last_procs:
        if flt:
            hit = flt in p["name"].lower() or flt in p["user"].lower() or flt == str(p["pid"])
            if not hit:
                if p["cmd"] is None:
                    p["cmd"] = cmdline(p["pid"])
                hit = flt in p["cmd"].lower()
            if not hit:
                continue
        out.append(p)
    key = state["sort"]
    keyfn = {
        "cpu": lambda p: p["cpuRaw"],
        "mem": lambda p: p["rss"],
        "pid": lambda p: p["pid"],
        "name": lambda p: p["name"].lower(),
        "user": lambda p: p["user"].lower(),
        "threads": lambda p: p["threads"],
        "time": lambda p: p["time"],
    }[key]
    out.sort(key=keyfn, reverse=state["desc"])
    out = out[:state["limit"]]
    result = []
    for p in out:
        if p["cmd"] is None:
            p["cmd"] = cmdline(p["pid"])
        result.append({
            "pid": p["pid"], "ppid": p["ppid"], "name": p["name"], "user": p["user"],
            "state": p["state"], "threads": p["threads"],
            "cpu": round(min(p["cpuRaw"] * mult, 100.0 * mult), 1),
            "mem": round(p["mem"], 1), "rss": p["rss"], "time": round(p["time"], 1),
            "cmd": p["cmd"] or f"[{p['name']}]",
        })
    return result


# ───────────────────────── loop ─────────────────────────

_last = {"t": None, "io": None, "net": None}


def tick():
    now = time.monotonic()
    usage, dtotal = cpu_usage()
    mem = memory()
    scan_processes(dtotal, mem["total"])

    io = disk_io_bytes()
    iface, rx, tx = net_bytes()
    dt = (now - _last["t"]) if _last["t"] else 0
    io_r = io_w = net_rx = net_tx = 0.0
    if dt > 0 and _last["io"] and _last["net"]:
        io_r = max(0, io[0] - _last["io"][0]) / dt
        io_w = max(0, io[1] - _last["io"][1]) / dt
        if _last["net"][0] == iface:
            net_rx = max(0, rx - _last["net"][1]) / dt
            net_tx = max(0, tx - _last["net"][2]) / dt
    _last.update(t=now, io=io, net=(iface, rx, tx))

    freq, freq_max = cpu_freq()
    load = os.getloadavg()
    emit({
        "type": "stats",
        "cpu": {
            "total": round(usage[0] * 100, 1) if usage else 0,
            "cores": [round(u * 100, 1) for u in usage[1:]],
            "freq": round(freq), "freqMax": round(freq_max),
            "temp": round(cpu_temp(), 1),
            "load": [round(x, 2) for x in load],
        },
        "mem": mem,
        "disks": disks(),
        "io": {"read": io_r, "write": io_w},
        "net": {"iface": iface, "rx": net_rx, "tx": net_tx, "rxTotal": rx, "txTotal": tx},
        "battery": battery(),
        "gpu": gpu(),
        "uptime": float(read("/proc/uptime", "0").split()[0] or 0),
        "summary": _proc_summary,
        "procs": visible_processes(),
    })


def handle(line):
    if not line:
        return
    cmd, _, arg = line.partition(" ")
    arg = arg.strip()
    try:
        if cmd == "interval":
            state["interval"] = max(0.25, min(10.0, int(arg) / 1000.0))
        elif cmd == "sort":
            parts = arg.split()
            if parts and parts[0] in SORT_KEYS:
                state["sort"] = parts[0]
                state["desc"] = (parts[1] if len(parts) > 1 else "desc") != "asc"
            emit({"type": "procs", "procs": visible_processes()})
        elif cmd == "filter":
            state["filter"] = arg
            emit({"type": "procs", "procs": visible_processes()})
        elif cmd == "percore":
            state["percore"] = arg in ("1", "true", "yes")
            emit({"type": "procs", "procs": visible_processes()})
        elif cmd == "limit":
            state["limit"] = max(10, min(2000, int(arg)))
        elif cmd == "refresh":
            emit({"type": "procs", "procs": visible_processes()})
        elif cmd == "kill":
            pid_s, _, sig_s = arg.partition(" ")
            pid, sig = int(pid_s), int(sig_s or signal.SIGTERM)
            if pid <= 1:
                raise PermissionError
            try:
                name = read(f"/proc/{pid}/comm").strip() or str(pid)
                os.kill(pid, sig)
                label = {15: "Terminated", 9: "Killed", 19: "Paused", 18: "Resumed",
                         1: "Sent SIGHUP to", 2: "Interrupted"}.get(sig, f"Signal {sig} sent to")
                emit({"type": "msg", "ok": True, "text": f"{label} {name} ({pid})"})
            except ProcessLookupError:
                emit({"type": "msg", "ok": False, "text": f"Process {pid} no longer exists"})
    except PermissionError:
        emit({"type": "msg", "ok": False, "text": "Permission denied — process belongs to another user"})
    except ValueError:
        emit({"type": "msg", "ok": False, "text": f"Invalid command: {line}"})


def main():
    for i, a in enumerate(sys.argv):
        if a == "--interval" and i + 1 < len(sys.argv):
            handle("interval " + sys.argv[i + 1])
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    emit({
        "type": "info",
        "hostname": socket.gethostname(),
        "kernel": platform.release(),
        "cpuModel": cpu_model(),
        "cpuCount": NCPU,
        "hasTemp": TEMP_PATH is not None,
        "hasGpu": NVIDIA_DEV is not None,
    })
    # prime the deltas, then start ticking shortly after
    cpu_usage()
    scan_processes(0, 1)
    _last.update(t=time.monotonic(), io=disk_io_bytes(), net=net_bytes())
    next_t = time.monotonic() + 0.35

    fd = sys.stdin.fileno()
    buf = ""
    while True:
        now = time.monotonic()
        if now >= next_t:
            tick()
            next_t = now + state["interval"]
        timeout = max(0.0, next_t - time.monotonic())
        try:
            ready, _, _ = select.select([fd], [], [], timeout)
        except (OSError, ValueError):
            time.sleep(timeout)
            continue
        if ready:
            data = os.read(fd, 4096)
            if not data:  # stdin closed → Quickshell is gone
                sys.exit(0)
            buf += data.decode(errors="ignore")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                handle(line.strip())


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
