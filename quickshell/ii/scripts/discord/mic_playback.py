#!/usr/bin/env python3
"""Records a few seconds from the microphone and plays them back on the output.

No live loop, so no feedback whatever the speakers: the microphone is closed by the
time the sound plays. stdout, one JSON object per line:
  {"state": "recording"} {"state": "playing"} {"state": "done"} {"error": "..."}
usage: mic_playback.py [source] [seconds]
"""
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mic_meter import pick_source  # noqa: E402

RATE = 48000


def say(**kw):
    print(json.dumps(kw), flush=True)


def main():
    source = pick_source(sys.argv[1] if len(sys.argv) > 1 else "")
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 4.0
    want = int(RATE * seconds) * 2
    try:
        proc = subprocess.Popen(
            ["parec", "--raw", "--format=s16le", f"--rate={RATE}", "--channels=1",
             "--latency-msec=40", f"--device={source}"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except FileNotFoundError:
        return say(error="parec not found (install libpulse / pipewire-pulse)")
    say(state="recording")
    data = b""
    while len(data) < want:
        chunk = proc.stdout.read(min(4096, want - len(data)))
        if not chunk:
            break
        data += chunk
    proc.terminate()
    if len(data) < want // 2:
        err = proc.stderr.read().decode(errors="replace").strip()
        return say(error=err or "nothing was recorded")
    data = data[: len(data) // 2 * 2]
    path = os.path.join(tempfile.gettempdir(), "ii-discord-mic-test.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    for player in (["pw-play"], ["paplay"], ["aplay", "-q"]):
        if shutil.which(player[0]):
            say(state="playing")
            subprocess.call(player + [path])
            return say(state="done")
    say(error="no player found (pw-play, paplay or aplay)")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
