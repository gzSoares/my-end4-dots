#!/usr/bin/env python3
"""
agenda.py — backend for the ii Agenda app (Quickshell).

Talks to Evolution Data Server (the same store GNOME Calendar, the shell's
calendar widget and GNOME Online Accounts use). Google calendars added in
GNOME Online Accounts show up here and sync automatically.

Reads one JSON command per line on stdin, prints JSON lines on stdout:
  {"cmd":"sources"}
  {"cmd":"range","start":<ts>,"end":<ts>}
  {"cmd":"tasks"}
  {"cmd":"create_event", "source":uid, "summary":..., "start":ts, "end":ts, "allDay":bool, "location":..., "description":...}
  {"cmd":"update_event", "source":uid, "uid":..., ...same fields}
  {"cmd":"delete_event", "source":uid, "uid":...}
  {"cmd":"create_task",  "source":uid, "summary":..., "due":ts|null, "dueAllDay":bool, "description":...}
  {"cmd":"update_task",  "source":uid, "uid":..., "summary":..., "due":..., "dueAllDay":..., "description":...}
  {"cmd":"toggle_task",  "source":uid, "uid":..., "done":bool}
  {"cmd":"delete_task",  "source":uid, "uid":...}
"""
import json
import sys
import time
import uuid
from datetime import date, datetime, timedelta

import gi



def require_any(namespace, versions):
    """Use the first available version (Arch moved libical-glib from 3.0 to 4.0)."""
    for v in versions:
        try:
            gi.require_version(namespace, v)
            return v
        except ValueError:
            continue
    return None  # let gi pick whatever is installed


require_any("ECal", ["2.0", "3.0"])
require_any("EDataServer", ["1.2", "2.0"])
require_any("ICalGLib", ["4.0", "3.0"])
from gi.repository import ECal, EDataServer, ICalGLib  # noqa: E402

UTC = ICalGLib.Timezone.get_utc_timezone()


def emit(obj):
    try:
        sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        sys.exit(0)


def error(text):
    emit({"type": "msg", "ok": False, "text": text})


# ───────────────────────── sources / clients ─────────────────────────

registry = EDataServer.SourceRegistry.new_sync(None)
_clients = {}


def account_name(src):
    pid = src.get_parent()
    parent = registry.ref_source(pid) if pid else None
    return parent.get_display_name() if parent else ""


def source_info(src, ext_name, default_uid):
    ext = src.get_extension(ext_name)
    color = ext.get_color() if hasattr(ext, "get_color") else None
    return {
        "uid": src.get_uid(),
        "name": src.get_display_name(),
        "color": color or "",
        "writable": src.get_writable() or src.get_remote_creatable() or True,
        "default": src.get_uid() == default_uid,
        "account": account_name(src),
    }


def list_sources(ext_name):
    out = []
    for src in registry.list_enabled(ext_name):
        out.append(src)
    return out


def get_client(uid, kind):
    key = (uid, kind)
    if key in _clients:
        return _clients[key]
    src = registry.ref_source(uid)
    if src is None:
        raise ValueError(f"unknown source {uid}")
    # short wait: cached data appears instantly, remote (Google) sources refresh in background
    client = ECal.Client.connect_sync(src, kind, 2, None)
    _clients[key] = client
    return client


def send_sources():
    dcal = registry.ref_default_calendar()
    dtask = registry.ref_default_task_list()
    cals = [source_info(s, EDataServer.SOURCE_EXTENSION_CALENDAR, dcal.get_uid() if dcal else "")
            for s in list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)]
    tls = [source_info(s, EDataServer.SOURCE_EXTENSION_TASK_LIST, dtask.get_uid() if dtask else "")
           for s in list_sources(EDataServer.SOURCE_EXTENSION_TASK_LIST)]
    # mark read-only clients properly (needs a connection)
    for lst, kind in ((cals, ECal.ClientSourceType.EVENTS), (tls, ECal.ClientSourceType.TASKS)):
        for s in lst:
            try:
                s["writable"] = not get_client(s["uid"], kind).is_readonly()
            except Exception:  # noqa: BLE001
                s["writable"] = False
    emit({"type": "sources", "calendars": cals, "taskLists": tls})


# ───────────────────────── time helpers ─────────────────────────

def ical_to_ts(t):
    """ICalTime → (unix ts, is_date)."""
    if t is None or t.is_null_time():
        return None, False
    if t.is_date():
        d = datetime(t.get_year(), t.get_month(), t.get_day())
        return int(d.timestamp()), True
    z = t.get_timezone()
    if z is None:  # floating time → local
        d = datetime(t.get_year(), t.get_month(), t.get_day(), t.get_hour(), t.get_minute(), t.get_second())
        return int(d.timestamp()), False
    return int(t.as_timet_with_zone(z)), False


def ts_to_ical(ts, all_day):
    if all_day:
        d = date.fromtimestamp(ts)
        t = ICalGLib.Time.new_null_time()
        t.set_date(d.year, d.month, d.day)
        t.set_is_date(True)
        return t
    return ICalGLib.Time.new_from_timet_with_zone(int(ts), 0, UTC)


def dt_prop(ts, all_day):
    t = ts_to_ical(ts, all_day)
    return ECal.ComponentDateTime.new(t, None if all_day else "UTC")


def text(s):
    return ECal.ComponentText.new(s or "", None)


def comp_text(getter):
    try:
        v = getter()
    except Exception:  # noqa: BLE001
        return ""
    if v is None:
        return ""
    if isinstance(v, list):
        v = v[0] if v else None
        if v is None:
            return ""
    return v.get_value() if hasattr(v, "get_value") else str(v)


# ───────────────────────── events ─────────────────────────

def send_range(start, end):
    events = []
    for src in list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR):
        uid = src.get_uid()
        ext = src.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
        try:
            client = get_client(uid, ECal.ClientSourceType.EVENTS)
        except Exception as e:  # noqa: BLE001
            error(f"{src.get_display_name()}: {e}")
            continue
        readonly = client.is_readonly()

        def cb(icomp, istart, iend, *rest):
            comp = ECal.Component.new_from_icalcomponent(icomp.clone())
            s_ts, all_day = ical_to_ts(istart)
            e_ts, _ = ical_to_ts(iend)
            if e_ts is None or e_ts <= s_ts:
                e_ts = s_ts + (86400 if all_day else 3600)
            rid = comp.get_recurid_as_string() or ""
            events.append({
                "uid": comp.get_uid(),
                "rid": rid,
                "source": uid,
                "sourceName": src.get_display_name(),
                "color": ext.get_color() or "",
                "summary": comp_text(comp.get_summary) or "(no title)",
                "location": comp.get_location() or "",
                "description": comp_text(comp.get_descriptions),
                "start": s_ts,
                "end": e_ts,
                "allDay": all_day,
                "recurring": comp.has_recurrences() or bool(rid),
                "readonly": readonly,
            })
            return True

        try:
            client.generate_instances_sync(int(start), int(end), None, cb)
        except Exception as e:  # noqa: BLE001
            error(f"{src.get_display_name()}: {e}")
    events.sort(key=lambda e: (e["start"], not e["allDay"]))
    emit({"type": "events", "start": start, "end": end, "events": events})


def fill_event(comp, c):
    comp.set_summary(text(c.get("summary", "").strip() or "Untitled"))
    all_day = bool(c.get("allDay"))
    start = int(c["start"])
    end = int(c.get("end") or (start + (86400 if all_day else 3600)))
    if all_day and end <= start:
        end = start + 86400
    comp.set_dtstart(dt_prop(start, all_day))
    comp.set_dtend(dt_prop(end, all_day))
    comp.set_location(c.get("location") or None)
    desc = c.get("description") or ""
    comp.set_descriptions([text(desc)] if desc else [])


def create_event(c):
    client = get_client(c["source"], ECal.ClientSourceType.EVENTS)
    comp = ECal.Component.new()
    comp.set_new_vtype(ECal.ComponentVType.EVENT)
    comp.set_uid(str(uuid.uuid4()))
    fill_event(comp, c)
    comp.set_created(ICalGLib.Time.new_current_with_zone(UTC))
    comp.commit_sequence()
    client.create_object_sync(comp.get_icalcomponent(), ECal.OperationFlags.NONE, None)
    emit({"type": "msg", "ok": True, "text": "Event created"})


def update_event(c):
    client = get_client(c["source"], ECal.ClientSourceType.EVENTS)
    _, icomp = client.get_object_sync(c["uid"], None, None)
    comp = ECal.Component.new_from_icalcomponent(icomp)
    fill_event(comp, c)
    comp.set_last_modified(ICalGLib.Time.new_current_with_zone(UTC))
    comp.commit_sequence()
    client.modify_object_sync(comp.get_icalcomponent(), ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
    emit({"type": "msg", "ok": True, "text": "Event updated"})


def delete_event(c):
    client = get_client(c["source"], ECal.ClientSourceType.EVENTS)
    client.remove_object_sync(c["uid"], None, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
    emit({"type": "msg", "ok": True, "text": "Event deleted"})


# ───────────────────────── tasks ─────────────────────────

def send_tasks():
    tasks = []
    for src in list_sources(EDataServer.SOURCE_EXTENSION_TASK_LIST):
        uid = src.get_uid()
        ext = src.get_extension(EDataServer.SOURCE_EXTENSION_TASK_LIST)
        try:
            client = get_client(uid, ECal.ClientSourceType.TASKS)
            _, comps = client.get_object_list_as_comps_sync("#t", None)
        except Exception as e:  # noqa: BLE001
            error(f"{src.get_display_name()}: {e}")
            continue
        for comp in comps:
            due = comp.get_due()
            due_ts, due_all_day = ical_to_ts(due.get_value()) if due else (None, False)
            status = comp.get_status()
            done = status == ICalGLib.PropertyStatus.COMPLETED or comp.get_completed() is not None
            tasks.append({
                "uid": comp.get_uid(),
                "source": uid,
                "sourceName": src.get_display_name(),
                "color": ext.get_color() or "",
                "summary": comp_text(comp.get_summary) or "(no title)",
                "description": comp_text(comp.get_descriptions),
                "due": due_ts if due_ts is not None else -1,
                "dueAllDay": due_all_day,
                "done": bool(done),
                "readonly": client.is_readonly(),
            })
    tasks.sort(key=lambda t: (t["done"], t["due"] < 0, t["due"], t["summary"].lower()))
    emit({"type": "tasks", "tasks": tasks})


def fill_task(comp, c):
    comp.set_summary(text(c.get("summary", "").strip() or "Untitled"))
    due = c.get("due")
    if due is not None and int(due) >= 0:
        comp.set_due(dt_prop(int(due), bool(c.get("dueAllDay"))))
    else:
        comp.set_due(None)
    desc = c.get("description") or ""
    comp.set_descriptions([text(desc)] if desc else [])


def create_task(c):
    client = get_client(c["source"], ECal.ClientSourceType.TASKS)
    comp = ECal.Component.new()
    comp.set_new_vtype(ECal.ComponentVType.TODO)
    comp.set_uid(str(uuid.uuid4()))
    fill_task(comp, c)
    comp.set_status(ICalGLib.PropertyStatus.NEEDSACTION)
    comp.set_created(ICalGLib.Time.new_current_with_zone(UTC))
    comp.commit_sequence()
    client.create_object_sync(comp.get_icalcomponent(), ECal.OperationFlags.NONE, None)
    emit({"type": "msg", "ok": True, "text": "Task added"})


def modify_task(c, mutate, msg):
    client = get_client(c["source"], ECal.ClientSourceType.TASKS)
    _, icomp = client.get_object_sync(c["uid"], None, None)
    comp = ECal.Component.new_from_icalcomponent(icomp)
    mutate(comp)
    comp.set_last_modified(ICalGLib.Time.new_current_with_zone(UTC))
    comp.commit_sequence()
    client.modify_object_sync(comp.get_icalcomponent(), ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
    if msg:
        emit({"type": "msg", "ok": True, "text": msg})


def toggle_task(c):
    def mutate(comp):
        if c.get("done"):
            comp.set_status(ICalGLib.PropertyStatus.COMPLETED)
            comp.set_percent_complete(100)
            comp.set_completed(ICalGLib.Time.new_current_with_zone(UTC))
        else:
            comp.set_status(ICalGLib.PropertyStatus.NEEDSACTION)
            comp.set_percent_complete(0)
            comp.set_completed(None)
    modify_task(c, mutate, None)


def update_task(c):
    modify_task(c, lambda comp: fill_task(comp, c), "Task updated")


def delete_task(c):
    client = get_client(c["source"], ECal.ClientSourceType.TASKS)
    client.remove_object_sync(c["uid"], None, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
    emit({"type": "msg", "ok": True, "text": "Task deleted"})


HANDLERS = {
    "sources": lambda c: send_sources(),
    "range": lambda c: send_range(c["start"], c["end"]),
    "tasks": lambda c: send_tasks(),
    "create_event": create_event,
    "update_event": update_event,
    "delete_event": delete_event,
    "create_task": create_task,
    "update_task": update_task,
    "toggle_task": toggle_task,
    "delete_task": delete_task,
}


def main():
    send_sources()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            c = json.loads(line)
            HANDLERS[c["cmd"]](c)
            if c["cmd"].endswith("_task"):
                send_tasks()
            if c["cmd"].endswith("_event"):
                emit({"type": "changed"})
        except KeyError as e:
            error(f"bad command: {e}")
        except Exception as e:  # noqa: BLE001
            msg = getattr(e, "message", None) or str(e)
            error(msg)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
