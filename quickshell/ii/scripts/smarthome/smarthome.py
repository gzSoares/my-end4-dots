#!/usr/bin/env python3
"""
smarthome.py — backend for the ii Smart Home app (Quickshell). Local Tuya control via tinytuya.

Config: ~/.config/illogical-impulse/smarthome.json
  {"syncWallpaper": false,
   "devices": [{"name": "Luz do quarto", "id": "...", "key": "...", "ip": "192.168.0.50", "version": 3.3}]}
If it doesn't exist, devices are imported from tinytuya's wizard output (devices.json).

Interactive mode (used by the app): JSON commands on stdin, JSON lines on stdout
  {"cmd":"refresh"} {"cmd":"reload"}
  {"cmd":"power","id":ID,"on":true}
  {"cmd":"brightness","id":ID,"value":0-100}
  {"cmd":"white","id":ID,"brightness":0-100,"temp":0-100}
  {"cmd":"color","id":ID,"hex":"#rrggbb","brightness":0-100}
  {"cmd":"setting","key":"syncWallpaper","value":true}

One-shot mode (keybinds / Spotlight / wallpaper sync):
  smarthome.py --oneshot toggle|on|off
  smarthome.py --oneshot scene relax|read|focus|night|cinema
  smarthome.py --wallpaper-sync "#rrggbb"     (only acts if syncWallpaper is on)
"""
import colorsys
import json
import os
import sys
import threading
import time

CONF_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "illogical-impulse")
CONF = os.path.join(CONF_DIR, "smarthome.json")
WIZARD_PATHS = [
    os.path.expanduser("~/.config/tinytuya/devices.json"),
    os.path.expanduser("~/tinytuya/devices.json"),
    os.path.expanduser("~/devices.json"),
    os.path.join(os.getcwd(), "devices.json"),
]
SNAPSHOT_PATHS = [p.replace("devices.json", "snapshot.json") for p in WIZARD_PATHS]

SCENES = {
    "relax": {"mode": "white", "brightness": 45, "temp": 10},
    "read": {"mode": "white", "brightness": 85, "temp": 45},
    "focus": {"mode": "white", "brightness": 100, "temp": 90},
    "night": {"mode": "white", "brightness": 5, "temp": 0},
    "cinema": {"mode": "color", "hex": "#3d2a7a", "brightness": 18},
    "sunset": {"mode": "color", "hex": "#ff7a3d", "brightness": 55},
}

try:
    import tinytuya
    TINYTUYA_ERR = ""
except Exception as e:  # noqa: BLE001
    tinytuya = None
    TINYTUYA_ERR = f"tinytuya is not installed for this Python ({e}). Run: pip install --user tinytuya"

_out_lock = threading.Lock()


def emit(obj):
    with _out_lock:
        try:
            sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, ValueError):
            os._exit(0)


# ───────────────────────── config ─────────────────────────

def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def import_from_wizard():
    devices, used = [], ""
    for p in WIZARD_PATHS:
        data = read_json(p)
        if isinstance(data, list) and data:
            used = p
            snap = {}
            for sp in SNAPSHOT_PATHS:
                s = read_json(sp)
                if isinstance(s, dict):
                    for d in s.get("devices", []):
                        snap[d.get("id")] = d
            for d in data:
                if not d.get("key"):
                    continue  # gateways/sub-devices without a local key
                cat = d.get("category", "")
                if cat and cat not in ("dj", "dd", "fwd", "tgq", "xdd", "dc", "tgkg", "fsd"):
                    continue  # keep lights only
                s = snap.get(d.get("id"), {})
                devices.append({
                    "name": d.get("name") or d.get("product_name") or "Light",
                    "id": d["id"],
                    "key": d["key"],
                    "ip": s.get("ip") or d.get("ip") or "Auto",
                    "version": float(s.get("ver") or d.get("version") or 3.3),
                })
            break
    return devices, used


def load_config():
    conf = read_json(CONF)
    if isinstance(conf, dict) and conf.get("devices"):
        return conf
    devices, used = import_from_wizard()
    conf = conf if isinstance(conf, dict) else {}
    conf.setdefault("syncWallpaper", False)
    conf["devices"] = devices
    if devices:
        conf["importedFrom"] = used
        save_config(conf)
    return conf


def save_config(conf):
    os.makedirs(CONF_DIR, exist_ok=True)
    tmp = CONF + ".tmp"
    with open(tmp, "w") as f:
        json.dump(conf, f, indent=2, ensure_ascii=False)
    os.replace(tmp, CONF)


# ───────────────────────── devices ─────────────────────────

class Lamp:
    def __init__(self, cfg):
        self.cfg = cfg
        self.id = cfg["id"]
        self.name = cfg.get("name", "Light")
        self.dev = None
        self.state = {"online": False, "on": False, "mode": "white", "brightness": 0, "temp": 0,
                      "color": "#ffffff", "error": ""}

    def device(self):
        if self.dev is None:
            ip = self.cfg.get("ip") or "Auto"
            self.dev = tinytuya.BulbDevice(dev_id=self.id, address=ip, local_key=self.cfg["key"],
                                           version=float(self.cfg.get("version", 3.3)),
                                           connection_timeout=3, connection_retry_limit=1,
                                           connection_retry_delay=1)
            self.dev.set_socketPersistent(False)
            if ip == "Auto" and getattr(self.dev, "address", None) not in (None, "Auto"):
                self.cfg["ip"] = self.dev.address  # remember discovered IP
                self.cfg["_dirty"] = True
        return self.dev

    def refresh(self):
        try:
            d = self.device()
            st = d.state()
            if not isinstance(st, dict) or "Error" in st:
                raise RuntimeError((st or {}).get("Error", "no response"))
            mode = st.get("mode") or "white"
            color = "#ffffff"
            try:
                r, g, b = d.colour_rgb(state=st)
                color = "#%02x%02x%02x" % (int(r), int(g), int(b))
            except Exception:  # noqa: BLE001
                pass
            bright = d.get_brightness_percentage(state=st) if mode == "white" else self._color_value(d, st)
            try:
                temp = d.get_colourtemp_percentage(state=st)
            except Exception:  # noqa: BLE001
                temp = self.state["temp"]
            self.state.update(online=True, on=bool(st.get("is_on")), mode="color" if mode == "colour" else mode,
                              brightness=int(round(bright or 0)), temp=int(round(temp or 0)), color=color, error="")
        except Exception as e:  # noqa: BLE001
            self.dev = None
            msg = str(e)
            if "not configured" in msg or "timed out" in msg.lower() or "Network Error" in msg:
                msg = "Unreachable — check that the lamp is powered and the IP / local key are right"
            self.state.update(online=False, error=msg[:160])
        return self.snapshot()

    @staticmethod
    def _color_value(d, st):
        try:
            h, s, v = d.colour_hsv(state=st)
            return v * 100
        except Exception:  # noqa: BLE001
            return 0

    def snapshot(self):
        return dict(self.state, id=self.id, name=self.name, ip=self.cfg.get("ip", ""))

    def run(self, c):
        d = self.device()
        cmd = c["cmd"]
        if cmd == "power":
            (d.turn_on if c.get("on") else d.turn_off)()
        elif cmd == "toggle":
            (d.turn_off if self.state.get("on") else d.turn_on)()
        elif cmd == "brightness":
            v = max(1, min(100, int(c["value"])))
            if self.state.get("mode") == "color":
                h, s, _ = colorsys.rgb_to_hsv(*hex_rgb(self.state.get("color", "#ffffff")))
                d.set_hsv(h, s, v / 100)
            else:
                d.set_brightness_percentage(v)
        elif cmd == "white":
            d.set_white_percentage(max(1, min(100, int(c.get("brightness", self.state["brightness"] or 80)))),
                                   max(0, min(100, int(c.get("temp", self.state["temp"])))))
        elif cmd == "temp":
            d.set_colourtemp_percentage(max(0, min(100, int(c["value"]))))
        elif cmd == "color":
            r, g, b = hex_rgb(c["hex"])
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            if "brightness" in c and c["brightness"] is not None:
                v = max(1, min(100, int(c["brightness"]))) / 100
            d.set_hsv(h, s, max(0.01, v))
        elif cmd == "scene":
            sc = SCENES.get(c.get("name", ""))
            if not sc:
                raise ValueError("unknown scene")
            if not self.state.get("on"):
                d.turn_on()
            if sc["mode"] == "white":
                d.set_white_percentage(sc["brightness"], sc["temp"])
            else:
                r, g, b = hex_rgb(sc["hex"])
                h, s, _ = colorsys.rgb_to_hsv(r, g, b)
                d.set_hsv(h, s, sc["brightness"] / 100)
        time.sleep(0.15)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


# ───────────────────────── interactive service ─────────────────────────

class Service:
    def __init__(self):
        self.cv = threading.Condition()
        self.pending = {}       # (cmd,id) → command   (coalesces slider spam)
        self.order = []
        self.reload()

    def reload(self):
        self.conf = load_config()
        self.lamps = {d["id"]: Lamp(d) for d in self.conf.get("devices", [])}

    def setup_info(self):
        return {"type": "setup", "configPath": CONF, "searched": WIZARD_PATHS, "error": TINYTUYA_ERR,
                "hasDevices": bool(self.lamps), "syncWallpaper": bool(self.conf.get("syncWallpaper")),
                "scenes": list(SCENES.keys())}

    def emit_devices(self):
        emit({"type": "devices", "devices": [l.snapshot() for l in self.lamps.values()]})

    def persist_if_dirty(self):
        dirty = False
        for d in self.conf.get("devices", []):
            if d.pop("_dirty", False):
                dirty = True
        if dirty:
            save_config(self.conf)

    def push(self, c):
        with self.cv:
            key = (c.get("cmd"), c.get("id"))
            if key not in self.pending:
                self.order.append(key)
            self.pending[key] = c
            self.cv.notify()

    def worker(self):
        last_poll = 0
        while True:
            with self.cv:
                if not self.order:
                    self.cv.wait(timeout=max(0.5, 10 - (time.monotonic() - last_poll)))
                c = None
                if self.order:
                    key = self.order.pop(0)
                    c = self.pending.pop(key)
            if c is None:
                if time.monotonic() - last_poll >= 10 and tinytuya:
                    for l in self.lamps.values():
                        l.refresh()
                    self.persist_if_dirty()
                    self.emit_devices()
                    last_poll = time.monotonic()
                continue
            self.execute(c)
            if not self.order:
                last_poll = 0  # refresh right after a burst of commands

    def execute(self, c):
        cmd = c.get("cmd")
        try:
            if cmd == "refresh":
                for l in self.lamps.values():
                    l.refresh()
                self.emit_devices()
            elif cmd == "reload":
                self.reload()
                emit(self.setup_info())
                for l in self.lamps.values():
                    l.refresh()
                self.emit_devices()
            elif cmd == "setting":
                self.conf[c["key"]] = c["value"]
                save_config(self.conf)
                emit(self.setup_info())
            elif cmd in ("all_on", "all_off"):
                for l in self.lamps.values():
                    l.run({"cmd": "power", "on": cmd == "all_on"})
                    l.refresh()
                self.emit_devices()
            else:
                lamp = self.lamps.get(c.get("id"))
                if not lamp:
                    raise ValueError("unknown device")
                lamp.run(c)
                lamp.refresh()
                self.emit_devices()
        except Exception as e:  # noqa: BLE001
            emit({"type": "msg", "ok": False, "text": f"{cmd}: {e}"[:200]})


def interactive():
    svc = Service()
    emit(svc.setup_info())
    if not tinytuya:
        svc.emit_devices()
    else:
        threading.Thread(target=svc.worker, daemon=True).start()
        svc.push({"cmd": "refresh"})
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            c = json.loads(line)
        except ValueError:
            continue
        if not tinytuya:
            emit({"type": "msg", "ok": False, "text": TINYTUYA_ERR})
            continue
        svc.push(c)


def oneshot(args):
    if not tinytuya:
        print(TINYTUYA_ERR, file=sys.stderr)
        sys.exit(1)
    conf = load_config()
    lamps = [Lamp(d) for d in conf.get("devices", [])]
    if not lamps:
        print("No devices configured", file=sys.stderr)
        sys.exit(1)
    what = args[0] if args else "toggle"
    for l in lamps:
        try:
            if what == "toggle":
                l.refresh()
                l.run({"cmd": "toggle"})
            elif what in ("on", "off"):
                l.run({"cmd": "power", "on": what == "on"})
            elif what == "scene" and len(args) > 1:
                l.refresh()
                l.run({"cmd": "scene", "name": args[1]})
            elif what == "color" and len(args) > 1:
                l.run({"cmd": "color", "hex": args[1]})
        except Exception as e:  # noqa: BLE001
            print(f"{l.name}: {e}", file=sys.stderr)


def wallpaper_sync(hexcolor):
    conf = load_config()
    if not conf.get("syncWallpaper") or not tinytuya:
        return
    for d in conf.get("devices", []):
        l = Lamp(d)
        try:
            st = l.refresh()
            if st["on"]:
                l.run({"cmd": "color", "hex": hexcolor, "brightness": max(20, st["brightness"])})
        except Exception as e:  # noqa: BLE001
            print(f"{l.name}: {e}", file=sys.stderr)


if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "--oneshot":
            oneshot(sys.argv[2:])
        elif len(sys.argv) > 2 and sys.argv[1] == "--wallpaper-sync":
            wallpaper_sync(sys.argv[2])
        else:
            interactive()
    except KeyboardInterrupt:
        pass
