#!/usr/bin/env python3
# eds-events.py — dump upcoming calendar events from evolution-data-server as
# JSON for the sidebar calendar.

import json
import sys
from datetime import datetime, timedelta, date


def main():
    try:
        import gi
        gi.require_version("ECal", "2.0")
        gi.require_version("EDataServer", "1.2")
        gi.require_version("ICalGLib", "4.0")
        from gi.repository import ECal, EDataServer, ICalGLib  # noqa: F401
    except Exception:
        print("[]")
        return 0

    args = sys.argv[1:]
    do_sync = False

    if args and args[0] == "--sync":
        do_sync = True
        args = args[1:]

    def _int(value, default):
        try:
            return int(value)
        except Exception:
            return default

    days_back = _int(args[0], 45) if len(args) > 0 else 45
    days_forward = _int(args[1], 120) if len(args) > 1 else 120

    now = datetime.now()
    t0 = int((now - timedelta(days=days_back)).timestamp())
    t1 = int((now + timedelta(days=days_forward)).timestamp())

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
    except Exception:
        print("[]")
        return 0

    events = []

    def add_instance(summary, ical_start, ical_end, cal_name, cal_color):
        try:
            all_day = bool(ical_start.is_date())

            if all_day:
                first = date(
                    ical_start.get_year(),
                    ical_start.get_month(),
                    ical_start.get_day()
                )

                if ical_end:
                    end_excl = date(
                        ical_end.get_year(),
                        ical_end.get_month(),
                        ical_end.get_day()
                    )

                    # DTEND de evento all-day é exclusivo
                    last_day = max(
                        first,
                        end_excl - timedelta(days=1)
                    )
                else:
                    last_day = first

                start_label = None
                end_label = None

            else:
                start_dt = datetime.fromtimestamp(
                    ical_start.as_timet()
                )

                end_dt = datetime.fromtimestamp(
                    ical_end.as_timet()
                    if ical_end
                    else ical_start.as_timet()
                )

                first = start_dt.date()
                last_day = end_dt.date()

                start_label = start_dt.strftime("%H:%M")
                end_label = end_dt.strftime("%H:%M")

            day = first

            while day <= last_day:
                events.append({
                    "date": day.isoformat(),
                    "title": summary or "(untitled)",
                    "allDay": all_day,
                    "start": start_label,
                    "end": end_label,
                    "calendar": cal_name,
                    "color": cal_color,
                })

                day += timedelta(days=1)

        except Exception:
            pass

    for source in registry.list_enabled(
        EDataServer.SOURCE_EXTENSION_CALENDAR
    ):
        try:
            ext = source.get_extension(
                EDataServer.SOURCE_EXTENSION_CALENDAR
            )

            cal_color = ext.get_color() if ext else None
            cal_name = source.get_display_name()

            client = ECal.Client.connect_sync(
                source,
                ECal.ClientSourceType.EVENTS,
                3,
                None
            )

            if client is None:
                continue

            if do_sync:
                try:
                    if client.check_refresh_supported():
                        client.refresh_sync(None)
                except Exception:
                    pass

            def cb(
                comp,
                start,
                end,
                *_args,
                _n=cal_name,
                _c=cal_color
            ):
                summary = None

                try:
                    if hasattr(comp, "get_summary"):
                        s = comp.get_summary()
                        summary = (
                            s.get_value()
                            if hasattr(s, "get_value")
                            else s
                        )

                    if (
                        summary is None
                        and hasattr(comp, "get_icalcomponent")
                    ):
                        summary = (
                            comp
                            .get_icalcomponent()
                            .get_summary()
                        )

                except Exception:
                    pass

                add_instance(
                    summary,
                    start,
                    end,
                    _n,
                    _c
                )

                return True

            client.generate_instances_sync(
                t0,
                t1,
                None,
                cb
            )

        except Exception:
            continue

    print(json.dumps(events))
    return 0


sys.exit(main())