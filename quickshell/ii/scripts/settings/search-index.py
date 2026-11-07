#!/usr/bin/env python3
"""Prints the search index of the Settings app as JSON.

Read from the page sources each time Settings opens, so a new option is found
without a list to keep up to date. Only labels written as literals are picked
up; one built at runtime is not indexed, and its page is still found by name.
"""
import json
import re
import sys
from pathlib import Path

TAGS = {
    "ContentSection": "title", "CardSection": "title", "ContentSubsection": "title",
    "ConfigSwitch": "text", "ConfigSlider": "text", "ConfigSpinBox": "text",
    "ConfigTextField": "text", "IpAddressField": "label",
}
OPEN = re.compile(r"^(\s*)(" + "|".join(TAGS) + r")\s*\{")
LABEL = r'\s*:\s*(?:Translation\.tr\()?"((?:[^"\\]|\\.)+)"\s*\)?\s*;?\s*(?://.*)?$'
COMPONENT = re.compile(r"^\s*([A-Z]\w+)\s*\{")


def entries(path, page, seen):
    section = ""
    # Code switched off in a block comment is not an option the page shows.
    text = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.S)
    lines = text.splitlines()
    for i, line in enumerate(lines):
        match = OPEN.match(line)
        if not match:
            continue
        indent, tag = len(match.group(1)), match.group(2)
        prop = re.compile(r"^\s{%d}%s%s" % (indent + 4, TAGS[tag], LABEL))
        for follow in lines[i + 1:i + 16]:
            if follow.strip() and len(follow) - len(follow.lstrip()) <= indent:
                break
            found = prop.match(follow)
            if not found:
                continue
            label = found.group(1).replace('\\"', '"')
            if tag in ("ContentSection", "CardSection"):
                section = label
            if (page, label) not in seen:
                seen.add((page, label))
                yield {"page": page, "label": label, "section": section}
            break


def main():
    root = Path(sys.argv[1])
    shared = {p.stem: p for p in root.glob("*/*.qml")}
    out, seen = [], set()
    for path in sorted(root.glob("*.qml")):
        out.extend(entries(path, path.name, seen))
        used = {m.group(1) for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
                if (m := COMPONENT.match(line))}
        for name in sorted(used & shared.keys()):
            out.extend(entries(shared[name], path.name, seen))
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
