#!/usr/bin/env python3
"""
remote.py — backend for the ii Remote Desktop app (Quickshell).

Remmina-style RDP connection manager on top of FreeRDP 3.
  • connections:  ~/.config/illogical-impulse/remote.json   (no passwords in it)
  • passwords:    system keyring via `secret-tool` (libsecret / GNOME Keyring / KWallet)
  • sessions:     xfreerdp3 / sdl-freerdp3 launched with /from-stdin — the password
                  never shows up in `ps` or in the command line

JSON commands on stdin, one per line; JSON lines on stdout:
  {"cmd":"save", "conn":{...}, "password":"..."|null}   password null = keep, "" = forget
  {"cmd":"delete", "id":...}
  {"cmd":"duplicate", "id":...}
  {"cmd":"connect", "id":..., "password":"..."|null, "remember":bool}
  {"cmd":"quick", "host":"...", "user":"...", "password":"..."}
  {"cmd":"disconnect", "id":...}
  {"cmd":"open_or_focus", "id":...}                     connect, or focus its window if already open
  {"cmd":"import_remmina"}
  {"cmd":"set_client", "client":"xfreerdp3"}
  {"cmd":"check"}                                       reachability now
  {"cmd":"set_pref", "key":"view|sort|desc", "value":...}  window preferences
"""
import configparser
import glob
import json
import os
import select
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import uuid

CONF_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "illogical-impulse")
CONF = os.path.join(CONF_DIR, "remote.json")
REMMINA_DIRS = [os.path.expanduser("~/.local/share/remmina"), os.path.expanduser("~/.remmina"),
                os.path.expanduser("~/.var/app/org.remmina.Remmina/data/remmina")]
CLIENTS = ["xfreerdp3", "sdl-freerdp3", "xfreerdp", "sdl-freerdp", "wlfreerdp3", "wlfreerdp"]
HAS_SECRET = shutil.which("secret-tool") is not None

DEFAULTS = {
    "name": "", "host": "", "port": 3389, "user": "", "domain": "", "group": "",
    "display": "fit",          # fit | fullscreen | custom
    "width": 1920, "height": 1080,
    "multimon": False, "scale": 100,
    "sound": True, "microphone": False, "clipboard": True,
    "shareFolder": "",          # local folder shared as a drive
    "network": "auto",          # auto | lan | broadband | modem
    "ignoreCert": False,
    "gateway": "", "gatewayUser": "",
    "extraArgs": "",
    "lastConnected": 0,
    "source": "",               # "remmina:<file>" when imported
}

_out = threading.Lock()


def emit(obj):
    with _out:
        try:
            sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, ValueError):
            os._exit(0)


def msg(text, ok=True):
    emit({"type": "msg", "ok": ok, "text": text})


# ───────────────────────── storage ─────────────────────────

def load():
    try:
        with open(CONF) as f:
            data = json.load(f)
    except (OSError, ValueError):
        data = {}
    data.setdefault("connections", [])
    data.setdefault("client", "")
    data.setdefault("prefs", {"view": "grid", "sort": "name", "desc": False})
    data["connections"] = [dict(DEFAULTS, **c) for c in data["connections"]]
    return data


def save(data):
    os.makedirs(CONF_DIR, exist_ok=True)
    tmp = CONF + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CONF)


# ───────────────────────── keyring ─────────────────────────

def secret_get(cid):
    if not HAS_SECRET:
        return None
    try:
        p = subprocess.run(["secret-tool", "lookup", "app", "ii-remote", "id", cid],
                           capture_output=True, text=True, timeout=10)
        return p.stdout.rstrip("\n") if p.returncode == 0 and p.stdout else None
    except (OSError, subprocess.SubprocessError):
        return None


def secret_set(cid, label, password):
    if not HAS_SECRET:
        return False
    try:
        p = subprocess.run(["secret-tool", "store", "--label", f"ii Remote Desktop: {label}",
                            "app", "ii-remote", "id", cid],
                           input=password, capture_output=True, text=True, timeout=15)
        return p.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def secret_clear(cid):
    if HAS_SECRET:
        subprocess.run(["secret-tool", "clear", "app", "ii-remote", "id", cid],
                       capture_output=True, timeout=10)


# ───────────────────────── FreeRDP ─────────────────────────

def available_clients():
    return [c for c in CLIENTS if shutil.which(c)]


def pick_client(data):
    avail = available_clients()
    if data.get("client") in avail:
        return data["client"]
    return avail[0] if avail else ""


def build_args(client, c):
    host = c["host"].strip()
    port = int(c.get("port") or 3389)
    a = [client, f"/v:{host}:{port}" if port != 3389 else f"/v:{host}"]
    if c.get("user"):
        a.append(f"/u:{c['user']}")
    if c.get("domain"):
        a.append(f"/d:{c['domain']}")
    a.append("/from-stdin:force")
    title = c.get("name") or host
    a.append(f"/title:{title}")
    if client.startswith("xfreerdp"):
        a.append("/wm-class:ii-remote")

    disp = c.get("display", "fit")
    if disp == "fullscreen":
        a.append("/f")
        if c.get("multimon"):
            a.append("/multimon")
    elif disp == "custom":
        a.append(f"/size:{int(c.get('width') or 1920)}x{int(c.get('height') or 1080)}")
    else:  # fit: resize the remote desktop with the window
        a += [f"/size:{int(c.get('width') or 1920)}x{int(c.get('height') or 1080)}", "/dynamic-resolution"]
    scale = int(c.get("scale") or 100)
    if scale != 100:
        a.append(f"/scale-desktop:{scale}")

    a.append("/sound" if c.get("sound") else "/audio-mode:2")
    if c.get("microphone"):
        a.append("/microphone")
    a.append("+clipboard" if c.get("clipboard") else "-clipboard")
    folder = os.path.expanduser(c.get("shareFolder") or "")
    if folder and os.path.isdir(folder):
        a.append(f"/drive:{os.path.basename(folder.rstrip('/')) or 'share'},{folder}")
    a.append(f"/network:{c.get('network') or 'auto'}")
    a.append("/cert:ignore" if c.get("ignoreCert") else "/cert:tofu")
    if c.get("gateway"):
        a.append(f"/g:{c['gateway']}")
        if c.get("gatewayUser"):
            a.append(f"/gu:{c['gatewayUser']}")
    a += ["+auto-reconnect", "/auto-reconnect-max-retries:5"]
    if c.get("extraArgs"):
        try:
            a += shlex.split(c["extraArgs"])
        except ValueError:
            pass
    return a


# ───────────────────────── Hyprland focus ─────────────────────────

def _hypr(*args):
    try:
        p = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=3)
        return (p.stdout or "") + (p.stderr or "")
    except (OSError, subprocess.SubprocessError):
        return "error"


def window_for_pid(pid):
    try:
        clients = json.loads(_hypr("clients", "-j") or "[]")
    except ValueError:
        return None
    return next((c for c in clients if c.get("pid") == pid), None)


def focus_window(addr):
    """Bring a window to front (switches workspace if needed). Tries the Lua
    dispatcher API first, then the classic one; verifies with activewindow."""
    sel = f"address:{addr}"
    attempts = [
        ("dispatch", f'hl.dsp.focus({{window = "{sel}"}})'),
        ("dispatch", f'hl.dsp.window.focus({{window = "{sel}"}})'),
        ("dispatch", f'hl.dsp.focus_window({{window = "{sel}"}})'),
        ("dispatch", "focuswindow", sel),
    ]
    for args in attempts:
        out = _hypr(*args)
        if "error" in out.lower():
            continue
        time.sleep(0.15)
        try:
            if json.loads(_hypr("activewindow", "-j") or "{}").get("address") == addr:
                return True
        except ValueError:
            pass
    return False


# ───────────────────────── service ─────────────────────────

class Service:
    def __init__(self):
        self.data = load()
        self.sessions = {}   # id → {"proc", "started", "log"}
        self.reach = {}      # id → True/False
        self.lock = threading.Lock()
        self.wake = threading.Event()

    def conn(self, cid):
        for c in self.data["connections"]:
            if c["id"] == cid:
                return c
        return None

    def state(self):
        conns = []
        for c in self.data["connections"]:
            d = dict(c)
            d["hasPassword"] = False  # filled lazily below (keyring lookups are slow-ish)
            conns.append(d)
        with self.lock:
            sessions = {k: {"started": v["started"]} for k, v in self.sessions.items()}
        emit({"type": "state", "connections": conns, "sessions": sessions, "reach": self.reach,
              "client": pick_client(self.data), "clients": available_clients(),
              "keyring": HAS_SECRET, "prefs": self.data.get("prefs", {})})

    def passwords_state(self):
        saved = {c["id"]: secret_get(c["id"]) is not None for c in self.data["connections"]}
        emit({"type": "saved", "saved": saved})

    # ── commands ──
    def save_conn(self, cmd):
        c = dict(DEFAULTS, **(cmd.get("conn") or {}))
        if not c.get("host"):
            return msg("Host is required", False)
        c["name"] = c.get("name") or c["host"]
        if not c.get("id"):
            c["id"] = uuid.uuid4().hex[:12]
            self.data["connections"].append(c)
        else:
            for i, old in enumerate(self.data["connections"]):
                if old["id"] == c["id"]:
                    c["lastConnected"] = old.get("lastConnected", 0)
                    self.data["connections"][i] = c
                    break
            else:
                self.data["connections"].append(c)
        save(self.data)
        pw = cmd.get("password")
        if pw is not None:
            if pw == "":
                secret_clear(c["id"])
            elif not secret_set(c["id"], c["name"], pw):
                msg("Saved, but the password could not be stored (install libsecret / a keyring)", False)
        msg(f"Saved {c['name']}")
        self.state()
        self.passwords_state()
        threading.Thread(target=self.check_one, args=(c,), daemon=True).start()

    def delete(self, cid):
        c = self.conn(cid)
        if not c:
            return
        self.data["connections"] = [x for x in self.data["connections"] if x["id"] != cid]
        save(self.data)
        secret_clear(cid)
        msg(f"Deleted {c['name']}")
        self.state()

    def duplicate(self, cid):
        c = self.conn(cid)
        if not c:
            return
        n = dict(c, id=uuid.uuid4().hex[:12], name=c["name"] + " (copy)", lastConnected=0)
        self.data["connections"].append(n)
        save(self.data)
        self.state()

    def connect(self, c, password=None, remember=False, persist=True):
        with self.lock:
            if c["id"] in self.sessions:
                return msg(f"{c['name']} is already connected")
        client = pick_client(self.data)
        if not client:
            return msg("FreeRDP not found — install it: sudo pacman -S freerdp", False)
        if password is None:
            password = secret_get(c["id"])
        if password is None:
            emit({"type": "need_password", "id": c["id"], "name": c["name"], "user": c.get("user", "")})
            return
        if remember and persist and password:
            secret_set(c["id"], c["name"], password)
        args = build_args(client, c)
        try:
            proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, start_new_session=True)
        except OSError as e:
            return msg(f"Could not start {client}: {e}", False)
        try:
            proc.stdin.write(password + "\n")
            proc.stdin.flush()
            proc.stdin.close()
        except (BrokenPipeError, OSError):
            pass
        sess = {"proc": proc, "pid": proc.pid, "started": time.time(), "log": [], "name": c["name"]}
        with self.lock:
            self.sessions[c["id"]] = sess
        if persist:
            c["lastConnected"] = int(time.time())
            save(self.data)
        msg(f"Connecting to {c['name']}…")
        self.state()
        threading.Thread(target=self.pump, args=(c["id"], sess), daemon=True).start()

    def pump(self, cid, sess):
        """Collect FreeRDP output; when it exits, report why."""
        proc = sess["proc"]
        for line in proc.stdout:
            line = line.rstrip()
            if line:
                sess["log"] = (sess["log"] + [line])[-40:]
        code = proc.wait()
        with self.lock:
            self.sessions.pop(cid, None)
        if code not in (0, 1, 2, 12) and not sess.get("killed"):  # 0/1/2/12 = normal disconnect / logoff
            reason = friendly_error(sess["log"], code)
            msg(f"{sess['name']}: {reason}", False)
            emit({"type": "log", "id": cid, "text": "\n".join(sess["log"][-25:])})
        else:
            msg(f"Disconnected from {sess['name']}")
        self.state()

    def disconnect(self, cid):
        with self.lock:
            sess = self.sessions.get(cid)
        if sess:
            sess["killed"] = True
            try:
                os.killpg(sess["pid"], signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass

    def import_remmina(self):
        files = []
        for d in REMMINA_DIRS:
            files += glob.glob(os.path.join(d, "*.remmina"))
        known = {c.get("source") for c in self.data["connections"]}
        added = 0
        for f in sorted(files):
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
            except (configparser.Error, UnicodeDecodeError):
                continue
            if "remmina" not in cp:
                continue
            r = cp["remmina"]
            if r.get("protocol", "").upper() != "RDP" or f"remmina:{f}" in known:
                continue
            server = r.get("server", "")
            host, _, port = server.rpartition(":") if server.count(":") == 1 else (server, "", "")
            host = host or server
            mode = r.get("resolution_mode", "")
            c = dict(DEFAULTS)
            c.update({
                "id": uuid.uuid4().hex[:12],
                "name": r.get("name") or host,
                "host": host,
                "port": int(port) if port.isdigit() else 3389,
                "user": r.get("username", ""),
                "domain": r.get("domain", ""),
                "group": r.get("group", ""),
                "display": "custom" if mode == "1" else "fit",
                "width": int(r.get("resolution_width") or 1920),
                "height": int(r.get("resolution_height") or 1080),
                "shareFolder": r.get("sharefolder", ""),
                "gateway": r.get("gateway_server", "") if r.get("gateway_usage") == "1" else "",
                "gatewayUser": r.get("gateway_username", ""),
                "ignoreCert": r.get("ignore-tls-errors", "0") == "1",
                "microphone": r.get("microphone", "0") not in ("0", ""),
                "source": f"remmina:{f}",
            })
            self.data["connections"].append(c)
            added += 1
        if added:
            save(self.data)
        msg(f"Imported {added} RDP connection(s) from Remmina" if added else
            ("No new RDP profiles found in Remmina" if files else "No Remmina profiles found"), bool(added) or True)
        self.state()
        if added:
            threading.Thread(target=self.check_all, daemon=True).start()

    # ── reachability ──
    def check_one(self, c):
        ok = False
        try:
            with socket.create_connection((c["host"], int(c.get("port") or 3389)), timeout=1.5):
                ok = True
        except (OSError, ValueError):
            ok = False
        if self.reach.get(c["id"]) != ok:
            self.reach[c["id"]] = ok
            return True
        return False

    def check_all(self):
        changed = False
        threads = []
        results = []
        for c in list(self.data["connections"]):
            t = threading.Thread(target=lambda c=c: results.append(self.check_one(c)), daemon=True)
            t.start()
            threads.append(t)
        for t in threads:
            t.join(3)
        changed = any(results)
        if changed:
            self.state()

    def adopt_running(self):
        """Sessions keep running after the window closes — find them again on reopen."""
        for pid_s in os.listdir("/proc"):
            if not pid_s.isdigit():
                continue
            try:
                with open(f"/proc/{pid_s}/cmdline", "rb") as f:
                    argv = [x.decode(errors="ignore") for x in f.read().split(b"\0") if x]
            except OSError:
                continue
            if not argv or os.path.basename(argv[0]) not in CLIENTS or "/from-stdin:force" not in argv:
                continue
            target = next((x[3:] for x in argv if x.startswith("/v:")), "")
            for c in self.data["connections"]:
                port = int(c.get("port") or 3389)
                if target in (c["host"], f"{c['host']}:{port}"):
                    try:
                        started = os.stat(f"/proc/{pid_s}").st_mtime
                    except OSError:
                        started = time.time()
                    sess = {"proc": None, "pid": int(pid_s), "started": started, "log": [], "name": c["name"]}
                    with self.lock:
                        self.sessions[c["id"]] = sess
                    threading.Thread(target=self.watch_pid, args=(c["id"], sess), daemon=True).start()
                    break

    def watch_pid(self, cid, sess):
        while True:
            try:
                os.kill(sess["pid"], 0)
            except ProcessLookupError:
                break
            except PermissionError:
                pass
            time.sleep(2)
        with self.lock:
            self.sessions.pop(cid, None)
        msg(f"Disconnected from {sess['name']}")
        self.state()

    def hypr_events(self):
        """Wake the window tracker immediately on focus/workspace/window events
        (Hyprland's event socket), instead of waiting for the next poll."""
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not sig:
            return
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        paths = [os.path.join(runtime, "hypr", sig, ".socket2.sock"), f"/tmp/hypr/{sig}/.socket2.sock"]
        interesting = ("activewindow", "workspace", "focusedmon", "movewindow", "openwindow",
                       "closewindow", "fullscreen", "changefloatingmode", "activespecial", "monitor")
        while True:
            for path in paths:
                if not os.path.exists(path):
                    continue
                try:
                    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                        sock.connect(path)
                        buf = b""
                        while True:
                            data = sock.recv(4096)
                            if not data:
                                break
                            buf += data
                            *lines, buf = buf.split(b"\n")
                            if any(l.decode(errors="ignore").startswith(interesting) for l in lines):
                                self.wake.set()
                except OSError:
                    pass
            time.sleep(2)

    def window_tracker(self):
        """Report where the FOCUSED session window is, so the floating switcher
        sits in its top-right corner. Background sessions get no bubble."""
        last = None
        while True:
            with self.lock:
                pids = {v["pid"]: k for k, v in self.sessions.items()}
            wins = []
            if pids and os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
                try:
                    active = json.loads(_hypr("activewindow", "-j") or "{}")
                except ValueError:
                    active = {}
                cid = pids.get(active.get("pid"))
                if cid and active.get("mapped", True) and not active.get("hidden"):
                    try:
                        monitors = json.loads(_hypr("monitors", "-j") or "[]")
                    except ValueError:
                        monitors = []
                    m = next((m for m in monitors if m.get("id") == active.get("monitor")), None)
                    if m:
                        (x, y), (w, h) = active.get("at", [0, 0]), active.get("size", [0, 0])
                        wins.append({"id": cid, "address": active.get("address"), "monitor": m.get("name"),
                                     "x": x - m.get("x", 0), "y": y - m.get("y", 0), "w": w, "h": h})
            if wins != last:
                last = wins
                emit({"type": "windows", "windows": wins})
            # events wake us instantly; the short timeout keeps following a window being dragged
            self.wake.wait(0.35 if pids else 2)
            self.wake.clear()

    def checker(self):
        while True:
            self.check_all()
            time.sleep(20)

    def handle(self, cmd):
        k = cmd.get("cmd")
        if k == "save":
            self.save_conn(cmd)
        elif k == "delete":
            self.delete(cmd["id"])
        elif k == "duplicate":
            self.duplicate(cmd["id"])
        elif k == "connect":
            c = self.conn(cmd["id"])
            if c:
                self.connect(c, cmd.get("password"), bool(cmd.get("remember")))
        elif k == "quick":
            host = (cmd.get("host") or "").strip()
            if not host:
                return
            h, _, p = host.rpartition(":") if host.count(":") == 1 else (host, "", "")
            c = dict(DEFAULTS, id="quick-" + (h or host), name=h or host, host=h or host,
                     port=int(p) if p.isdigit() else 3389, user=cmd.get("user", ""))
            self.connect(c, cmd.get("password") or "", persist=False)
        elif k == "disconnect":
            self.disconnect(cmd["id"])
        elif k == "focus_app":
            # bring the Remote Desktop window itself to front (it may be on another workspace)
            try:
                clients = json.loads(_hypr("clients", "-j") or "[]")
            except ValueError:
                clients = []
            w = next((c for c in clients if c.get("class") == "org.quickshell" and c.get("title") == "Remote Desktop"), None)
            if w:
                focus_window(w["address"])
        elif k == "open_or_focus":
            c = self.conn(cmd["id"])
            if not c:
                return
            with self.lock:
                sess = self.sessions.get(c["id"])
            if not sess:
                return self.connect(c)
            win = window_for_pid(sess["pid"])
            if not win:
                return msg(f"{c['name']} is still connecting…")
            if not focus_window(win["address"]):
                msg(f"Could not bring {c['name']} to front", False)
        elif k == "import_remmina":
            self.import_remmina()
        elif k == "set_client":
            self.data["client"] = cmd.get("client", "")
            save(self.data)
            self.state()
        elif k == "set_pref":
            self.data.setdefault("prefs", {})[cmd.get("key", "")] = cmd.get("value")
            save(self.data)
            self.state()
        elif k == "check":
            threading.Thread(target=self.check_all, daemon=True).start()
        elif k == "refresh":
            self.state()
            threading.Thread(target=self.passwords_state, daemon=True).start()


def friendly_error(log, code):
    text = "\n".join(log).lower()
    if "logon_failure" in text or "authentication failure" in text or "auth" in text and "fail" in text:
        return "wrong username or password"
    if "dns" in text or "getaddrinfo" in text or "unable to resolve" in text:
        return "host name not found"
    if "connect_transport_failed" in text or "connection refused" in text or "no route" in text or "timed out" in text:
        return "could not reach the computer (is it on and is RDP enabled?)"
    if "certificate" in text:
        return "certificate problem — try “Ignore certificate” in the connection settings"
    if "account_restriction" in text or "password_expired" in text:
        return "account restriction or expired password"
    last = next((l for l in reversed(log) if "error" in l.lower()), log[-1] if log else "")
    return (last[-140:] or f"exited with code {code}")


def main():
    svc = Service()
    svc.adopt_running()
    svc.state()
    threading.Thread(target=svc.passwords_state, daemon=True).start()
    threading.Thread(target=svc.checker, daemon=True).start()
    threading.Thread(target=svc.window_tracker, daemon=True).start()
    threading.Thread(target=svc.hypr_events, daemon=True).start()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
        except ValueError:
            continue
        try:
            svc.handle(cmd)
        except Exception as e:  # noqa: BLE001
            msg(f"{cmd.get('cmd')}: {e}", False)
    # stdin closed (window closed) — sessions keep running on their own


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
