#!/usr/bin/env python3

import csv
import json
import os
import subprocess
from datetime import date, timedelta
from pathlib import Path


data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
oauth_file = data_home / "gcalcli/oauth"
cache_file = cache_home / "quickshell-control-center/calendar.json"


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False))


if not oauth_file.exists():
    emit({"authenticated": False, "events": []})
    raise SystemExit(0)

start = date.today().isoformat()
end = (date.today() + timedelta(days=31)).isoformat()
command = [
    "gcalcli",
    "--nocolor",
    "agenda",
    "--tsv",
    "--military",
    "--nostarted",
    "--nodeclined",
    "--details",
    "calendar",
    "--details",
    "url",
    start,
    end,
]

try:
    result = subprocess.run(
        command,
        check=True,
        capture_output=True,
        text=True,
        timeout=25,
    )
    rows = csv.DictReader(result.stdout.splitlines(), dialect="excel-tab")
    events = []
    for row in rows:
        events.append(
            {
                "startDate": row.get("start_date", ""),
                "endDate": row.get("end_date", ""),
                "time": row.get("start_time", "") or "All day",
                "title": row.get("title", "(No title)"),
                "calendar": row.get("calendar", ""),
                "url": row.get("html_link", "") or row.get("hangout_link", ""),
            }
        )
    payload = {"authenticated": True, "events": events, "error": ""}
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(json.dumps(payload, ensure_ascii=False))
    emit(payload)
except (subprocess.SubprocessError, OSError) as error:
    if cache_file.exists():
        print(cache_file.read_text())
    else:
        emit({"authenticated": True, "events": [], "error": str(error)})
