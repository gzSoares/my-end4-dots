#!/usr/bin/env python3
"""
nosuspend.py — keep chosen PipeWire outputs from auto-suspending.

Fixes outputs (like HDMI / USB-C monitor speakers) that go silent after a pause
because WirePlumber suspends the idle sink. Manages one WirePlumber drop-in:
~/.config/wireplumber/wireplumber.conf.d/51-ii-no-suspend.conf

  nosuspend.py list                 → JSON list of node names
  nosuspend.py add <node.name>      → add + restart wireplumber
  nosuspend.py remove <node.name>   → remove + restart wireplumber
"""
import json
import os
import subprocess
import sys

CONF_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                        "wireplumber", "wireplumber.conf.d")
CONF = os.path.join(CONF_DIR, "51-ii-no-suspend.conf")
MARK = "# ii-no-suspend: "


def load():
    try:
        with open(CONF) as f:
            for line in f:
                if line.startswith(MARK):
                    return json.loads(line[len(MARK):])
    except (OSError, ValueError):
        pass
    return []


def save(names):
    if not names:
        try:
            os.remove(CONF)
        except FileNotFoundError:
            pass
        return
    os.makedirs(CONF_DIR, exist_ok=True)
    matches = "\n".join(f'      {{ node.name = "{n}" }}' for n in names)
    rule = f"""  {{
    matches = [
{matches}
    ]
    actions = {{
      update-props = {{
        session.suspend-timeout-seconds = 0
      }}
    }}
  }}"""
    with open(CONF, "w") as f:
        f.write(f"{MARK}{json.dumps(names)}\n")
        f.write("# Managed by the ii Audio Mixer — outputs listed here never auto-suspend.\n\n")
        f.write(f"monitor.alsa.rules = [\n{rule}\n]\n\n")
        f.write(f"monitor.bluez.rules = [\n{rule}\n]\n")


def restart():
    subprocess.run(["systemctl", "--user", "restart", "wireplumber"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        print(json.dumps(load()))
        return
    cmd, name = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
    names = load()
    if cmd == "add" and name and name not in names:
        names.append(name)
    elif cmd == "remove" and name in names:
        names.remove(name)
    else:
        print(json.dumps(names))
        return
    save(names)
    restart()
    print(json.dumps(names))


if __name__ == "__main__":
    main()
