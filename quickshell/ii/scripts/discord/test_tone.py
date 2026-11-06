#!/usr/bin/env python3
"""A short two-note chime on the default output, to check the speakers or headphones."""
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 44100


def tone(freq, seconds, volume=0.35):
    n = int(RATE * seconds)
    fade = int(RATE * 0.03)
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - i) / fade)
        out.append(int(32767 * volume * env * math.sin(2 * math.pi * freq * i / RATE)))
    return out


def main():
    samples = tone(660, 0.35) + [0] * int(RATE * 0.05) + tone(880, 0.45)
    path = os.path.join(tempfile.gettempdir(), "ii-discord-test-tone.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    for player in (["pw-play"], ["paplay"], ["aplay", "-q"]):
        if shutil.which(player[0]):
            sys.exit(subprocess.call(player + [path]))
    print("no player found (pw-play, paplay or aplay)", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
