#!/usr/bin/env python3
# eds-add-event.py — cria um evento em um calendário do evolution-data-server.
#
# Uso: eds-add-event.py TITULO AAAA-MM-DD [HH:MM|-] [DURACAO_MIN]
#   sem HH:MM o evento é de dia inteiro.
# Imprime o nome do calendário em caso de sucesso; erros vão para stderr.

import sys
import uuid
from datetime import datetime, timedelta, timezone

# Nome (ou parte do nome / conta / uid) do calendário onde gravar.
# Vazio = calendário padrão do EDS.
TARGET = "soares.geazi@hotmail.com"


def ical_escape(s):
    return (s.replace("\\", "\\\\").replace(";", "\\;")
             .replace(",", "\\,").replace("\r", "").replace("\n", "\\n"))


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        print("uso: eds-add-event.py TITULO AAAA-MM-DD [HH:MM|-] [DURACAO_MIN]", file=sys.stderr)
        return 2

    title, date_s = args[0], args[1]
    time_s = args[2] if len(args) > 2 and args[2] not in ("", "-") else None
    try:
        duration = int(args[3]) if len(args) > 3 else 60
    except ValueError:
        duration = 60

    try:
        import gi
        gi.require_version("ECal", "2.0")
        gi.require_version("EDataServer", "1.2")
        gi.require_version("ICalGLib", "4.0")
        from gi.repository import ECal, EDataServer, ICalGLib
    except Exception as e:
        print(f"EDS/gi indisponível: {e}", file=sys.stderr)
        return 1

    try:
        day = datetime.strptime(date_s, "%Y-%m-%d")
        uid = str(uuid.uuid4())
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        lines = ["BEGIN:VEVENT", f"UID:{uid}", f"DTSTAMP:{stamp}"]
        if time_s:
            hh, mm = (int(x) for x in time_s.split(":"))
            # hora local -> UTC, para todo mundo mostrar o horário certo
            start = datetime(day.year, day.month, day.day, hh, mm).astimezone().astimezone(timezone.utc)
            end = start + timedelta(minutes=duration)
            lines += [f"DTSTART:{start:%Y%m%dT%H%M%SZ}", f"DTEND:{end:%Y%m%dT%H%M%SZ}"]
        else:
            nxt = day + timedelta(days=1)
            lines += [f"DTSTART;VALUE=DATE:{day:%Y%m%d}", f"DTEND;VALUE=DATE:{nxt:%Y%m%d}"]
        lines += [f"SUMMARY:{ical_escape(title)}", "END:VEVENT"]
        ical = "\r\n".join(lines) + "\r\n"
    except Exception as e:
        print(f"argumentos inválidos: {e}", file=sys.stderr)
        return 2

    def create(client, icomp):
        flags = getattr(ECal, "OperationFlags", None)
        if flags is not None:
            try:
                return client.create_object_sync(icomp, flags.NONE, None)
            except TypeError:
                pass
        return client.create_object_sync(icomp, None)

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
    except Exception as e:
        print(f"registry EDS indisponível: {e}", file=sys.stderr)
        return 1

    def matches(s):
        t = TARGET.lower()
        names = [s.get_display_name() or "", s.get_uid() or ""]
        try:
            parent = registry.ref_source(s.get_parent()) if s.get_parent() else None
            if parent:
                names.append(parent.get_display_name() or "")
        except Exception:
            pass
        return any(t in n.lower() for n in names)

    sources = []
    if TARGET:
        sources = [s for s in registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR) if matches(s)]
        if not sources:
            print(f"calendário '{TARGET}' não encontrado", file=sys.stderr)
            return 1
    else:
        try:
            default = registry.ref_default_calendar()
            if default:
                sources.append(default)
        except Exception:
            pass
        for s in registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR):
            if all(s.get_uid() != d.get_uid() for d in sources):
                sources.append(s)

    last_err = "nenhum calendário disponível"
    for source in sources:
        try:
            client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 10, None)
            if client is None or client.is_readonly():
                continue
            create(client, ICalGLib.Component.new_from_string(ical))
            print(source.get_display_name())
            return 0
        except Exception as e:
            last_err = str(e)

    print(f"não foi possível adicionar o evento: {last_err}", file=sys.stderr)
    return 1


sys.exit(main())