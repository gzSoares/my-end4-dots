#!/usr/bin/env python3
"""Microphone level for the Chat tab's test: peak and RMS in dBFS, 20 times a second.

Reads the source through parec (PipeWire's PulseAudio layer), the same one the
Discord app records from. stdout, one JSON object per line:
  {"peak": -12.3, "rms": -22.1}            levels, 0 is full scale
  {"error": "..."}                          what stopped it
usage: mic_meter.py [source]   (empty or "default" = the default microphone)
"""
import json
import math
import struct
import subprocess
import sys

RATE = 16000
CHUNK = RATE // 20          # 50 ms


def db(x):
    return -90.0 if x <= 0 else max(-90.0, 20 * math.log10(x))


def pick_source(want):
    if not want or want == "default":
        return "@DEFAULT_SOURCE@"
    try:
        out = subprocess.run(["pactl", "list", "short", "sources"], capture_output=True, text=True, timeout=5).stdout
        names = [line.split("\t")[1] for line in out.splitlines() if "\t" in line]
        if want in names:
            return want
    except Exception:
        pass
    return "@DEFAULT_SOURCE@"


def main():
    source = pick_source(sys.argv[1] if len(sys.argv) > 1 else "")
    try:
        proc = subprocess.Popen(
            ["parec", "--raw", "--format=s16le", f"--rate={RATE}", "--channels=1",
             "--latency-msec=40", f"--device={source}"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except FileNotFoundError:
        print(json.dumps({"error": "parec not found (install libpulse / pipewire-pulse)"}), flush=True)
        return
    nbytes = CHUNK * 2
    while True:
        data = proc.stdout.read(nbytes)
        if len(data) < nbytes:
            err = proc.stderr.read().decode(errors="replace").strip()
            print(json.dumps({"error": err or "the microphone stream ended"}), flush=True)
            return
        samples = struct.unpack(f"<{CHUNK}h", data)
        peak = max(abs(s) for s in samples) / 32768.0
        rms = math.sqrt(sum(s * s for s in samples) / CHUNK) / 32768.0
        print(json.dumps({"peak": round(db(peak), 1), "rms": round(db(rms), 1)}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
