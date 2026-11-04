#!/usr/bin/env python3
"""Controls a Tuya smart bulb over the local network (used by the Spotlight `luz` command).

    lamp.py on | off | toggle
    lamp.py brightness 40          (percent)
    lamp.py temp warm|neutral|cool|0-100
    lamp.py color red|green|blue|...|#rrggbb
    lamp.py state                  (prints {"on": bool, "brightness": percent} as JSON; the Spotlight card reads it)
    lamp.py info                   (prints what the bulb reports, for troubleshooting)

The bulb's address and local key come from the `devices.json` that
`python -m tinytuya wizard` writes. They are looked for, in order, in
$LAMP_DEVICES, ~/.config/ii-lamp/devices.json and ./devices.json. The local key
never leaves that file. $LAMP_DEVICE_ID picks one bulb when the file lists several.
"""
import colorsys
import json
import os
import subprocess
import sys

COLORS = {
    "red": (255, 0, 0), "vermelha": (255, 0, 0), "vermelho": (255, 0, 0),
    "green": (0, 255, 0), "verde": (0, 255, 0),
    "blue": (0, 0, 255), "azul": (0, 0, 255),
    "yellow": (255, 200, 0), "amarela": (255, 200, 0), "amarelo": (255, 200, 0),
    "orange": (255, 100, 0), "laranja": (255, 100, 0),
    "purple": (140, 0, 255), "roxa": (140, 0, 255), "roxo": (140, 0, 255),
    "pink": (255, 0, 140), "rosa": (255, 0, 140),
    "cyan": (0, 255, 255), "ciano": (0, 255, 255),
}
TEMPS = {
    "warm": 0, "quente": 0,
    "neutral": 50, "neutra": 50, "neutro": 50,
    "cool": 100, "fria": 100, "frio": 100,
}


def notify(message, quiet):
    print(message)
    if quiet:
        return
    try:
        subprocess.run(["notify-send", "-t", "1500", "-a", "Luz", "Luz", message], check=False)
    except FileNotFoundError:
        pass


def load_device():
    candidates = [
        os.environ.get("LAMP_DEVICES", ""),
        os.path.expanduser("~/.config/ii-lamp/devices.json"),
        "devices.json",
    ]
    path = next((p for p in candidates if p and os.path.isfile(p)), None)
    if path is None:
        raise SystemExit("devices.json not found. Copy the file made by `python -m tinytuya wizard` "
                         "to ~/.config/ii-lamp/devices.json")
    with open(path, encoding="utf-8") as f:
        devices = json.load(f)
    if isinstance(devices, dict):
        devices = devices.get("devices", [])
    devices = [d for d in devices if d.get("id") and d.get("key")]
    wanted = os.environ.get("LAMP_DEVICE_ID")
    if wanted:
        devices = [d for d in devices if d["id"] == wanted]
    if not devices:
        raise SystemExit("No device with a local key in " + path)
    return devices[0]


def open_bulb(info):
    import tinytuya  # imported late so `--help`-style failures stay readable

    address = info.get("ip") or "Auto"
    bulb = tinytuya.BulbDevice(info["id"], address, info["key"])
    try:
        bulb.set_version(float(info.get("version") or 3.3))
    except (TypeError, ValueError):
        bulb.set_version(3.3)
    bulb.set_socketPersistent(False)
    bulb.set_socketTimeout(4)
    return bulb


def is_on(bulb):
    dps = (bulb.status() or {}).get("dps") or {}
    for key in ("20", "1"):  # v2 bulbs use 20, v1 use 1
        if key in dps:
            return bool(dps[key])
    raise SystemExit("The bulb did not report its on/off state: " + json.dumps(dps))


def read_state(bulb):
    """On/off and brightness percent, whichever of the two Tuya bulb layouts it speaks."""
    dps = (bulb.status() or {}).get("dps") or {}
    if "20" in dps:  # v2: switch 20, brightness 22 (10..1000)
        on, raw, lo, hi = dps["20"], dps.get("22"), 10, 1000
    elif "1" in dps:  # v1: switch 1, brightness 3 (25..255)
        on, raw, lo, hi = dps["1"], dps.get("3"), 25, 255
    else:
        raise SystemExit("The bulb did not report its state: " + json.dumps(dps))
    pct = 100 if raw is None else round((float(raw) - lo) * 100 / (hi - lo))
    return {"on": bool(on), "brightness": max(0, min(100, pct))}


def check(result):
    if isinstance(result, dict) and result.get("Error"):
        raise SystemExit("Bulb error: " + str(result.get("Error")))
    return result


def parse_color(text):
    text = text.strip().lower()
    if text in COLORS:
        return COLORS[text]
    if text.startswith("#") and len(text) == 7:
        try:
            return tuple(int(text[i:i + 2], 16) for i in (1, 3, 5))
        except ValueError:
            pass
    raise SystemExit("Unknown color: " + text)


def main(argv):
    quiet = "--quiet" in argv
    args = [a for a in argv if a != "--quiet"]
    if not args:
        raise SystemExit(__doc__)
    cmd, rest = args[0], args[1:]
    bulb = open_bulb(load_device())

    if cmd == "state":
        print(json.dumps(read_state(bulb)))
    elif cmd == "info":
        print(json.dumps(bulb.status(), indent=2))
    elif cmd == "on":
        check(bulb.turn_on())
        notify("Luz acesa", quiet)
    elif cmd == "off":
        check(bulb.turn_off())
        notify("Luz apagada", quiet)
    elif cmd == "toggle":
        if is_on(bulb):
            check(bulb.turn_off())
            notify("Luz apagada", quiet)
        else:
            check(bulb.turn_on())
            notify("Luz acesa", quiet)
    elif cmd == "brightness" and rest:
        pct = max(1, min(100, int(rest[0])))
        check(bulb.turn_on())
        check(bulb.set_brightness_percentage(pct))
        notify("Brilho em %d%%" % pct, quiet)
    elif cmd == "temp" and rest:
        word = rest[0].lower()
        pct = TEMPS[word] if word in TEMPS else max(0, min(100, int(word)))
        check(bulb.turn_on())
        check(bulb.set_colourtemp_percentage(pct))
        notify("Luz branca, temperatura %d%%" % pct, quiet)
    elif cmd == "color" and rest:
        r, g, b = parse_color(rest[0])
        check(bulb.turn_on())
        check(bulb.set_colour(r, g, b))
        notify("Luz colorida", quiet)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except SystemExit as e:
        if e.code not in (0, None):
            msg = str(e.code)
            print(msg, file=sys.stderr)
            if "--quiet" not in sys.argv:
                try:
                    subprocess.run(["notify-send", "-u", "critical", "-a", "Luz", "Luz", msg[:200]], check=False)
                except FileNotFoundError:
                    pass
            sys.exit(1)
    except Exception as e:  # network timeouts and the like
        msg = "%s: %s" % (type(e).__name__, e)
        print(msg, file=sys.stderr)
        if "--quiet" not in sys.argv:
            try:
                subprocess.run(["notify-send", "-u", "critical", "-a", "Luz", "Luz", msg[:200]], check=False)
            except FileNotFoundError:
                pass
        sys.exit(1)
