#!/usr/bin/env python3
"""Disk access for text-editor.qml: one JSON request per line in, one reply out.

Everything that can lose someone's file lives here. A save goes to a temporary
file beside the target, is flushed, and only then replaces it, so a crash leaves
the old file whole. A file that changed since it was read is not overwritten
unless the request says so. Text that the file's encoding cannot hold is an
error, not a silent loss of characters.
"""
import codecs
import fnmatch
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile

STATE = os.environ.get("EDITOR_STATE_DIR") or os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "quickshell/user/text-editor")
DRAFTS = os.path.join(STATE, "drafts")
STATE_FILE = os.path.join(STATE, "state.json")
MAX_SIZE = 64 * 1024 * 1024
BOMS = [(codecs.BOM_UTF8, "utf-8"), (codecs.BOM_UTF32_LE, "utf-32-le"), (codecs.BOM_UTF32_BE, "utf-32-be"),
        (codecs.BOM_UTF16_LE, "utf-16-le"), (codecs.BOM_UTF16_BE, "utf-16-be")]


def mtime_of(path):
    return os.stat(path).st_mtime_ns


def detect(data):
    for bom, name in BOMS:
        if data.startswith(bom):
            return name, True, data[len(bom):]
    try:
        data.decode("utf-8")
        return "utf-8", False, data
    except UnicodeDecodeError:
        pass
    # Not UTF-8. Legacy files here are almost always Western; cp1252 is a
    # superset of what Latin-1 text actually contains and rejects few bytes.
    try:
        data.decode("cp1252")
        return "cp1252", False, data
    except UnicodeDecodeError:
        return "latin-1", False, data


def line_ending(text):
    crlf = text.count("\r\n")
    cr = text.count("\r") - crlf
    lf = text.count("\n") - crlf
    best = max(crlf, cr, lf)
    if best == 0 or best == lf:
        return "lf", (crlf + cr) > 0
    return ("crlf", lf + cr > 0) if best == crlf else ("cr", lf + crlf > 0)


def modeline(text):
    """vim: set ts=4 sw=4 et:  in the first or last lines of the file."""
    lines = text.split("\n")
    found = {}
    for line in lines[:5] + lines[-5:]:
        match = re.search(r"(?:^|\s)(?:vim?|ex):\s*(?:set?\s+)?(.*?)(?::\s*$|$)", line)
        if not match:
            continue
        for item in re.split(r"[\s:]+", match.group(1)):
            key, _, value = item.partition("=")
            if key in ("ts", "tabstop") and value.isdigit():
                found["tabWidth"] = int(value)
            elif key in ("sw", "shiftwidth") and value.isdigit():
                found["indentWidth"] = int(value)
            elif key in ("et", "expandtab"):
                found["useSpaces"] = True
            elif key in ("noet", "noexpandtab"):
                found["useSpaces"] = False
    return found


def editorconfig(path):
    """The nearest .editorconfig files, the closest one winning, up to root=true."""
    chain = []
    folder = os.path.dirname(os.path.abspath(path))
    while True:
        candidate = os.path.join(folder, ".editorconfig")
        if os.path.isfile(candidate):
            chain.append(candidate)
            with open(candidate, encoding="utf-8", errors="replace") as handle:
                if re.search(r"^\s*root\s*=\s*true\s*$", handle.read(), re.M | re.I):
                    break
        parent = os.path.dirname(folder)
        if parent == folder:
            break
        folder = parent
    values = {}
    name = os.path.basename(path)
    for config in reversed(chain):
        section = None
        with open(config, encoding="utf-8", errors="replace") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line[0] in "#;":
                    continue
                if line.startswith("[") and line.endswith("]"):
                    section = line[1:-1]
                    continue
                if section is None or "=" not in line:
                    continue
                options = re.fullmatch(r"(.*)\{(.*)\}", section)
                patterns = [options.group(1) + part for part in options.group(2).split(",")] if options else [section]
                if any(fnmatch.fnmatch(name, pattern.lstrip("/").replace("**", "*")) for pattern in patterns):
                    key, _, value = line.partition("=")
                    values[key.strip().lower()] = value.strip().lower()
    found = {}
    if values.get("indent_style") in ("space", "tab"):
        found["useSpaces"] = values["indent_style"] == "space"
    if values.get("indent_size", "").isdigit():
        found["indentWidth"] = int(values["indent_size"])
    if values.get("tab_width", "").isdigit():
        found["tabWidth"] = int(values["tab_width"])
    return found


def themes(_):
    """Colors of the highlighting themes, which QML is not given. Cached: it runs
    the highlighter once per theme."""
    cache = os.path.join(STATE, "themes.json")
    try:
        with open(cache, encoding="utf-8") as handle:
            return {"ok": True, "themes": json.load(handle)}
    except (OSError, ValueError):
        pass
    found = []
    try:
        names = subprocess.run(["ksyntaxhighlighter6", "--list-themes"], capture_output=True, text=True,
                               timeout=20).stdout.split("\n")
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as sample:
            sample.write("x\n")
        for name in filter(None, names):
            html = subprocess.run(["ksyntaxhighlighter6", "-t", name, "-f", "html", sample.name],
                                  capture_output=True, text=True, timeout=20).stdout
            tag = re.search(r"<(?:body|pre)[^>]*style=['\"]([^'\"]*)", html)
            style = tag.group(1) if tag else ""
            back = re.search(r"background-color:\s*(#[0-9a-fA-F]{6})", style)
            front = re.search(r"(?<!-)color:\s*(#[0-9a-fA-F]{6})", style)
            if not back or not front:
                continue
            background = back.group(1)
            red, green, blue = (int(background[i:i + 2], 16) for i in (1, 3, 5))
            found.append({"name": name, "background": background, "text": front.group(1),
                          "dark": red * 0.299 + green * 0.587 + blue * 0.114 < 128})
        os.unlink(sample.name)
    except (OSError, subprocess.SubprocessError) as error:
        return {"ok": False, "error": "themes", "detail": str(error)}
    if found:
        atomic_json(cache, found)
    return {"ok": True, "themes": found}


def read(req):
    path = req["path"]
    if not os.path.exists(path):
        return {"ok": False, "error": "notfound"}
    if os.path.isdir(path):
        return {"ok": False, "error": "directory"}
    size = os.path.getsize(path)
    if size > MAX_SIZE:
        return {"ok": False, "error": "toolarge", "size": size}
    with open(path, "rb") as handle:
        data = handle.read()
    encoding, bom, body = detect(data)
    if b"\0" in body and not encoding.startswith("utf-") or (encoding == "utf-8" and b"\0" in body):
        if not req.get("force"):
            return {"ok": False, "error": "binary"}
    text = body.decode(encoding, errors="replace")
    eol, mixed = line_ending(text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    settings = editorconfig(path)
    settings.update(modeline(text))
    return {"ok": True, "text": text, "encoding": encoding, "bom": bom, "eol": eol, "mixedEol": mixed,
            "mtime": str(mtime_of(path)), "writable": os.access(path, os.W_OK), "settings": settings}


def write(req):
    path = os.path.realpath(req["path"])  # through a symlink, not over it
    text = req["text"]
    encoding = req.get("encoding", "utf-8")
    newline = {"crlf": "\r\n", "cr": "\r"}.get(req.get("eol", "lf"))
    if newline:
        text = text.replace("\n", newline)
    try:
        data = text.encode(encoding)
    except (UnicodeEncodeError, LookupError) as error:
        return {"ok": False, "error": "encoding", "detail": str(error)}
    if req.get("bom"):
        data = next((bom for bom, name in BOMS if name == encoding), b"") + data

    exists = os.path.exists(path)
    expected = req.get("expectedMtime")
    if exists and expected and not req.get("force") and str(mtime_of(path)) != expected:
        return {"ok": False, "error": "changed"}

    folder = os.path.dirname(path) or "."
    mode = stat.S_IMODE(os.stat(path).st_mode) if exists else 0o666 & ~current_umask()
    try:
        handle, temporary = tempfile.mkstemp(dir=folder, prefix=".editor-", suffix=".tmp")
    except OSError as error:
        return {"ok": False, "error": "permission", "detail": error.strerror}
    try:
        with os.fdopen(handle, "wb") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(temporary, mode)
        if exists:
            info = os.stat(path)
            try:
                os.chown(temporary, info.st_uid, info.st_gid)
            except PermissionError:
                pass
            shutil.copystat(path, temporary, follow_symlinks=True)
            os.chmod(temporary, mode)
        os.replace(temporary, path)
    except OSError as error:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        return {"ok": False, "error": "permission", "detail": error.strerror}
    return {"ok": True, "mtime": str(mtime_of(path)), "path": path}


def current_umask():
    mask = os.umask(0)
    os.umask(mask)
    return mask


def stat_files(req):
    out = {}
    for path in req["paths"]:
        try:
            out[path] = str(mtime_of(path))
        except OSError:
            out[path] = ""
    return {"ok": True, "mtimes": out}


def atomic_json(path, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as out:
        json.dump(value, out, ensure_ascii=False)
        out.flush()
        os.fsync(out.fileno())
    os.replace(temporary, path)


def load_state(_):
    state = {}
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            state = json.load(handle)
    except (OSError, ValueError):
        pass
    drafts = []
    if os.path.isdir(DRAFTS):
        for name in sorted(os.listdir(DRAFTS)):
            if not name.endswith(".json"):
                continue
            try:
                with open(os.path.join(DRAFTS, name), encoding="utf-8") as handle:
                    drafts.append(json.load(handle))
            except (OSError, ValueError):
                pass
    return {"ok": True, "state": state, "drafts": drafts}


def save_state(req):
    atomic_json(STATE_FILE, req["state"])
    return {"ok": True}


def save_draft(req):
    atomic_json(os.path.join(DRAFTS, req["draft"]["id"] + ".json"), req["draft"])
    return {"ok": True}


def delete_draft(req):
    try:
        os.unlink(os.path.join(DRAFTS, req["id"] + ".json"))
    except OSError:
        pass
    return {"ok": True}


OPS = {"read": read, "write": write, "stat": stat_files, "loadState": load_state, "saveState": save_state,
       "saveDraft": save_draft, "deleteDraft": delete_draft, "themes": themes}


def main():
    for line in sys.stdin:
        try:
            request = json.loads(line)
            reply = OPS[request["op"]](request)
        except Exception as error:  # a bad request must not take the helper down
            request = locals().get("request", {})
            reply = {"ok": False, "error": "internal", "detail": str(error)}
        reply["id"] = request.get("id") if isinstance(request, dict) else None
        sys.stdout.write(json.dumps(reply, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
