#!/usr/bin/env python3
"""
containers.py — backend for the ii Containers app (Quickshell).

Podman (or Docker) containers with live stats, images, and Ollama models.
Prints JSON lines; reads commands on stdin, one per line:

  refresh
  interval <ms>
  start|stop|restart|pause|unpause|remove <id>
  logs <id>                       → last 300 log lines
  images
  ollama_unload <model>
  ollama_delete <model>
"""
import json
import os
import re
import select
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

ENGINE = os.environ.get("II_CONTAINER_ENGINE") or ("podman" if shutil.which("podman") else
                                                   "docker" if shutil.which("docker") else "")
OLLAMA = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
if not OLLAMA.startswith("http"):
    OLLAMA = "http://" + OLLAMA

state = {"interval": 3.0}
_lock = threading.Lock()
_stats = {}  # id prefix → {"cpu":..., "mem":..., "memLimit":..., "memPerc":..., "pids":...}


def emit(obj):
    with _lock:
        try:
            sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, ValueError):
            os._exit(0)


def run(args, timeout=20):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr.strip()
    except (OSError, subprocess.SubprocessError) as e:
        return 1, "", str(e)


# ───────────────────────── parsing helpers ─────────────────────────

UNITS = {"b": 1, "kb": 1e3, "mb": 1e6, "gb": 1e9, "tb": 1e12,
         "kib": 1024, "mib": 1024 ** 2, "gib": 1024 ** 3, "tib": 1024 ** 4, "kB": 1e3}


def parse_size(s):
    if isinstance(s, (int, float)):
        return float(s)
    m = re.match(r"\s*([\d.]+)\s*([a-zA-Z]*)", str(s or ""))
    if not m:
        return 0.0
    return float(m.group(1)) * UNITS.get(m.group(2).lower(), 1)


def parse_pct(s):
    if isinstance(s, (int, float)):
        return float(s)
    try:
        return float(str(s).strip().rstrip("%") or 0)
    except ValueError:
        return 0.0


def ci(d, *names, default=None):
    """case-insensitive dict lookup over several candidate keys"""
    low = {k.lower(): v for k, v in d.items()}
    for n in names:
        if n.lower() in low:
            return low[n.lower()]
    return default


def parse_json_any(text):
    text = text.strip()
    if not text:
        return []
    if text.startswith("["):
        return json.loads(text)
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def labels_of(c):
    lab = ci(c, "Labels", default={}) or {}
    if isinstance(lab, str):  # docker: "a=b,c=d"
        lab = dict(kv.split("=", 1) for kv in lab.split(",") if "=" in kv)
    return lab


def ports_of(c):
    p = ci(c, "Ports", default=[]) or []
    out = []
    if isinstance(p, str):  # docker: "0.0.0.0:8080->80/tcp, ..."
        for part in p.split(","):
            m = re.search(r":(\d+)->(\d+)/(\w+)", part)
            if m:
                out.append(f"{m.group(1)}→{m.group(2)}/{m.group(3)}")
        return sorted(set(out))
    for e in p:
        hp, cp = e.get("host_port") or e.get("hostPort"), e.get("container_port") or e.get("containerPort")
        proto = e.get("protocol", "tcp")
        if hp:
            out.append(f"{hp}→{cp}/{proto}")
    return sorted(set(out))


# ───────────────────────── containers ─────────────────────────

def list_containers():
    if not ENGINE:
        return None, "Neither podman nor docker found"
    fmt = ["--format", "json"] if ENGINE == "podman" else ["--format", "{{json .}}"]
    code, out, err = run([ENGINE, "ps", "-a", "--no-trunc"] + fmt)
    if code != 0:
        return None, err or "ps failed"
    try:
        raw = parse_json_any(out)
    except ValueError:
        return None, "could not parse container list"
    res = []
    for c in raw:
        cid = ci(c, "Id", "ID", default="")
        names = ci(c, "Names", default="")
        name = names[0] if isinstance(names, list) and names else str(names)
        lab = labels_of(c)
        image = ci(c, "Image", default="")
        st = (ci(c, "State", default="") or "").lower()
        status = ci(c, "Status", default="") or st
        if ENGINE == "docker" and not st:
            st = "running" if str(status).startswith("Up") else "exited"
        kind = "distrobox" if lab.get("manager") == "distrobox" else \
               "toolbox" if "com.github.containers.toolbox" in lab else \
               "ollama" if "ollama" in image.lower() else \
               "pod" if ci(c, "Pod", default="") else "container"
        s = None
        for k, v in _stats.items():
            if cid.startswith(k) or k.startswith(cid[:12]) or v.get("name") == name:
                s = v
                break
        created = ci(c, "Created", default=0)
        res.append({
            "id": cid[:12],
            "name": name,
            "image": image,
            "state": st,              # running / exited / paused / created
            "status": status,         # "Up 3 hours"
            "ports": ports_of(c),
            "kind": kind,
            "created": created if isinstance(created, (int, float)) else 0,
            "cpu": s["cpu"] if s and st == "running" else 0.0,
            "mem": s["mem"] if s and st == "running" else 0.0,
            "memLimit": s["memLimit"] if s else 0.0,
            "pids": s["pids"] if s and st == "running" else 0,
        })
    order = {"running": 0, "paused": 1, "created": 2}
    res.sort(key=lambda x: (order.get(x["state"], 3), x["name"].lower()))
    return res, None


def stats_worker():
    """`podman stats` samples for ~1s, so it runs in its own thread."""
    while True:
        if ENGINE:
            fmt = ["--format", "json"] if ENGINE == "podman" else ["--format", "{{json .}}"]
            code, out, _ = run([ENGINE, "stats", "--no-stream"] + fmt, timeout=15)
            if code == 0:
                try:
                    new = {}
                    for s in parse_json_any(out):
                        cid = str(ci(s, "id", "ContainerID", "ID", default=""))[:12]
                        usage = str(ci(s, "mem_usage", "MemUsage", default="0 / 0"))
                        used, _, limit = usage.partition("/")
                        new[cid] = {
                            "name": ci(s, "name", "Name", default=""),
                            "cpu": parse_pct(ci(s, "cpu_percent", "CPUPerc", "CPU", default=0)),
                            "mem": parse_size(used),
                            "memLimit": parse_size(limit),
                            "pids": int(parse_pct(ci(s, "pids", "PIDs", default=0))),
                        }
                    _stats.clear()
                    _stats.update(new)
                except (ValueError, TypeError):
                    pass
        time.sleep(max(2.0, state["interval"]))


def list_images():
    fmt = ["--format", "json"] if ENGINE == "podman" else ["--format", "{{json .}}"]
    code, out, err = run([ENGINE, "images"] + fmt)
    if code != 0:
        emit({"type": "msg", "ok": False, "text": err or "images failed"})
        return
    imgs = []
    for i in parse_json_any(out):
        names = ci(i, "Names", default=None)
        if isinstance(names, list) and names:
            name = names[0]
        else:
            repo, tag = ci(i, "Repository", default="<none>"), ci(i, "Tag", default="")
            name = f"{repo}:{tag}" if tag else repo
        imgs.append({
            "id": str(ci(i, "Id", "ID", default=""))[:12],
            "name": name or "<none>",
            "size": parse_size(ci(i, "Size", default=0)),
            "created": ci(i, "Created", default=0) if isinstance(ci(i, "Created", default=0), (int, float)) else 0,
        })
    imgs.sort(key=lambda x: -x["size"])
    emit({"type": "images", "images": imgs})


# ───────────────────────── ollama ─────────────────────────

def http(method, path, body=None, timeout=1.5):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(OLLAMA + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        txt = r.read().decode() or "{}"
    try:
        return json.loads(txt)
    except ValueError:
        return {}


def ollama_status():
    try:
        tags = http("GET", "/api/tags")
    except (urllib.error.URLError, OSError, TimeoutError):
        return {"online": False, "url": OLLAMA, "models": []}
    try:
        ps = http("GET", "/api/ps").get("models", [])
    except (urllib.error.URLError, OSError, TimeoutError):
        ps = []
    loaded = {m.get("name") or m.get("model"): m for m in ps}
    models = []
    for m in tags.get("models", []):
        name = m.get("name") or m.get("model")
        det = m.get("details", {}) or {}
        lm = loaded.get(name)
        models.append({
            "name": name,
            "size": m.get("size", 0),
            "family": det.get("family", ""),
            "params": det.get("parameter_size", ""),
            "quant": det.get("quantization_level", ""),
            "modified": m.get("modified_at", ""),
            "loaded": lm is not None,
            "vram": (lm or {}).get("size_vram", 0),
            "ram": (lm or {}).get("size", 0),
            "expires": (lm or {}).get("expires_at", ""),
        })
    models.sort(key=lambda x: (not x["loaded"], x["name"]))
    return {"online": True, "url": OLLAMA, "models": models}


# ───────────────────────── commands ─────────────────────────

ACTION_LABEL = {"start": "Started", "stop": "Stopped", "restart": "Restarted",
                "pause": "Paused", "unpause": "Resumed", "remove": "Removed"}


def do_action(action, cid):
    args = [ENGINE, "rm", "-f", cid] if action == "remove" else [ENGINE, action, cid]
    code, _, err = run(args, timeout=90)
    emit({"type": "msg", "ok": code == 0,
          "text": f"{ACTION_LABEL.get(action, action)} {cid}" if code == 0 else (err or f"{action} failed")})
    tick()


def do_logs(cid):
    # container stdout and stderr both matter — merge them
    try:
        p = subprocess.run([ENGINE, "logs", "--tail", "300", cid], capture_output=True, text=True, timeout=10)
        text = (p.stdout + p.stderr) or "(no output)"
    except (OSError, subprocess.SubprocessError) as e:
        text = str(e)
    emit({"type": "logs", "id": cid, "text": text[-60000:]})


def ollama_cmd(cmd, model):
    try:
        if cmd == "ollama_unload":
            http("POST", "/api/generate", {"model": model, "keep_alive": 0}, timeout=15)
            emit({"type": "msg", "ok": True, "text": f"Unloaded {model}"})
        elif cmd == "ollama_delete":
            http("DELETE", "/api/delete", {"model": model, "name": model}, timeout=15)
            emit({"type": "msg", "ok": True, "text": f"Deleted {model}"})
    except Exception as e:  # noqa: BLE001
        emit({"type": "msg", "ok": False, "text": f"Ollama: {e}"})
    tick()


def tick():
    cs, err = list_containers()
    emit({"type": "state", "engine": ENGINE, "error": err or "",
          "containers": cs or [], "ollama": ollama_status()})


def handle(line):
    cmd, _, arg = line.partition(" ")
    arg = arg.strip()
    if cmd == "refresh":
        threading.Thread(target=tick, daemon=True).start()
    elif cmd == "interval":
        try:
            state["interval"] = max(1.0, min(30.0, int(arg) / 1000))
        except ValueError:
            pass
    elif cmd in ACTION_LABEL and arg:
        threading.Thread(target=do_action, args=(cmd, arg), daemon=True).start()
    elif cmd == "logs" and arg:
        threading.Thread(target=do_logs, args=(arg,), daemon=True).start()
    elif cmd == "images":
        threading.Thread(target=list_images, daemon=True).start()
    elif cmd in ("ollama_unload", "ollama_delete") and arg:
        threading.Thread(target=ollama_cmd, args=(cmd, arg), daemon=True).start()


def main():
    emit({"type": "info", "engine": ENGINE, "ollamaUrl": OLLAMA})
    threading.Thread(target=stats_worker, daemon=True).start()
    fd = sys.stdin.fileno()
    buf = ""
    next_t = time.monotonic()
    while True:
        now = time.monotonic()
        if now >= next_t:
            tick()
            next_t = now + state["interval"]
        ready, _, _ = select.select([fd], [], [], max(0.0, next_t - time.monotonic()))
        if ready:
            data = os.read(fd, 4096)
            if not data:
                os._exit(0)
            buf += data.decode(errors="ignore")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                if line.strip():
                    handle(line.strip())


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
