#!/bin/sh
set -eu

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
glance=$(dirname "$scripts_dir")/config/glance/glance.yml

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

python - "$glance" <<'PY' || fail 'Briefing configuration contract failed'
import hashlib
import sys

import yaml


with open(sys.argv[1], "rb") as source:
    raw = source.read()

briefing_marker = b"\n  - name: Briefing\n"
assert raw.count(briefing_marker) == 1
home_raw, briefing_raw = raw.split(briefing_marker, 1)
assert hashlib.sha256(home_raw).hexdigest() == "a84870cb1c5b6e2945ee4a1bb25c75d9c618c4017ab673bdb432c7eb7d845eeb"
assert hashlib.sha256(briefing_marker + briefing_raw).hexdigest() == "c5a5de5de8cc8fc021074eaf2dfa698545ac4d326e6ee4c0bd28cc3f91220c8d"

data = yaml.safe_load(raw)
assert [page["name"] for page in data["pages"]] == ["Home", "Briefing"]
home = data["pages"][0]
home_widgets = [widget for column in home["columns"] for widget in column["widgets"]]
assert all(widget["type"] != "rss" for widget in home_widgets)
assert all(widget.get("title") != "News" for widget in home_widgets)

briefing = data["pages"][1]
assert [column["size"] for column in briefing["columns"]] == ["full", "small"]

main, utility = (column["widgets"] for column in briefing["columns"])
assert [widget["type"] for widget in main] == ["hacker-news", "rss", "rss", "rss"]
assert [widget.get("title") for widget in main] == [None, "AI & Tech", "España", "Mundo"]

hacker_news = main[0]
assert hacker_news == {
    "type": "hacker-news",
    "sort-by": "top",
    "limit": 8,
    "collapse-after": 5,
    "cache": "30m",
}

expected_rss = {
    "AI & Tech": {
        "style": "horizontal-cards",
        "cache": "6h",
        "limit": 9,
        "collapse-after": 6,
        "feeds": {
            "MIT Technology Review AI": "https://www.technologyreview.com/topic/artificial-intelligence/feed/",
            "TechCrunch AI": "https://techcrunch.com/category/artificial-intelligence/feed/",
            "TLDR AI": "https://tldr.tech/api/rss/ai",
        },
        "per-feed-limit": 3,
    },
    "España": {
        "style": "detailed-list",
        "cache": "3h",
        "limit": 9,
        "collapse-after": 6,
        "feeds": {
            "El País": "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada",
            "elDiario.es": "https://www.eldiario.es/rss/",
            "Xataka": "https://www.xataka.com/index.xml",
        },
        "per-feed-limit": 3,
    },
    "Mundo": {
        "style": "vertical-list",
        "cache": "3h",
        "limit": 8,
        "collapse-after": 5,
        "feeds": {
            "BBC World": "https://feeds.bbci.co.uk/news/world/rss.xml",
            "The Guardian World": "https://www.theguardian.com/world/rss",
        },
        "per-feed-limit": 4,
    },
}

feed_urls = []
for widget in main[1:]:
    expected = expected_rss[widget["title"]]
    assert widget["style"] == expected["style"]
    assert widget["cache"] == expected["cache"]
    assert widget["limit"] == expected["limit"]
    assert widget["collapse-after"] == expected["collapse-after"]
    assert {feed["title"]: feed["url"] for feed in widget["feeds"]} == expected["feeds"]
    assert all(feed["limit"] == expected["per-feed-limit"] for feed in widget["feeds"])
    feed_urls.extend(feed["url"] for feed in widget["feeds"])

tldr = next(feed for feed in main[1]["feeds"] if feed["title"] == "TLDR AI")
assert tldr["headers"] == {
    "Accept": "application/rss+xml, application/xml;q=0.9, */*;q=0.8",
    "User-Agent": "Glance RSS reader",
}

assert [widget["type"] for widget in utility] == ["bookmarks", "releases", "monitor"]
bookmarks, releases, monitor = utility
assert bookmarks["title"] == "Quick Reads"
assert len(bookmarks["groups"]) == 1
assert {link["title"]: link["url"] for link in bookmarks["groups"][0]["links"]} == {
    "daily.dev": "https://app.daily.dev/",
    "AlphaSignal Archive": "https://alphasignal.ai/archive",
    "TLDR AI Archive": "https://tldr.tech/ai/archives",
}

assert releases["cache"] == "1d"
assert releases["limit"] == 9
assert releases["collapse-after"] == 5
assert releases["repositories"] == [
    "home-assistant/core",
    "immich-app/immich",
    "traefik/traefik",
    "authelia/authelia",
    "TwiN/gatus",
    "esphome/esphome",
    "node-red/node-red",
    "open-webui/open-webui",
    "amir20/dozzle",
]

assert monitor["title"] == "External Status"
assert monitor["cache"] == "10m"
assert {site["title"]: site["url"] for site in monitor["sites"]} == {
    "GitHub Status": "https://www.githubstatus.com/",
    "OpenAI Status": "https://status.openai.com/",
    "Cloudflare Status": "https://www.cloudflarestatus.com/",
}

destinations = feed_urls
destinations.extend(link["url"] for link in bookmarks["groups"][0]["links"])
destinations.extend(site["url"] for site in monitor["sites"])
assert len(destinations) == len(set(destinations))
assert len(releases["repositories"]) == len(set(releases["repositories"]))

briefing_text = raw.split(briefing_marker, 1)[1].lower()
for forbidden in (b"reddit", b"localllama", b"alphasignal.com/rss", b"type: videos", b"custom-css"):
    assert forbidden not in briefing_text
PY

printf '%s\n' 'glance_briefing_status=PASS'
