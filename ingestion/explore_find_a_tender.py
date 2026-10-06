"""Fetch Find a Tender releases for the last N hours and save each page to data/samples/.

Usage: python3 ingestion/explore_find_a_tender.py [hours]
"""

import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

API_URL = "https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S"  # the API expects no time zone
OUTPUT_DIR = Path("data/samples")


def first_page_url(hours):
    """URL for releases updated in the last `hours` hours."""
    updated_to = datetime.now(timezone.utc)
    updated_from = updated_to - timedelta(hours=hours)
    params = {
        "updatedFrom": updated_from.strftime(DATE_FORMAT),
        "updatedTo": updated_to.strftime(DATE_FORMAT),
        "limit": 100,
    }
    return f"{API_URL}?{urllib.parse.urlencode(params)}"


def get_json(url):
    with urllib.request.urlopen(url) as response:
        return json.load(response)


def save_page(page, page_number):
    path = OUTPUT_DIR / f"page_{page_number:03}.json"
    path.write_text(json.dumps(page, indent=2))
    return path


def main():
    hours = float(sys.argv[1]) if len(sys.argv) > 1 else 3
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    url = first_page_url(hours)
    page_number = 0
    while url:
        page = get_json(url)
        path = save_page(page, page_number)
        print(f"{path}: {len(page['releases'])} releases")

        url = page.get("links", {}).get("next")  # missing on the last page
        page_number += 1


if __name__ == "__main__":
    main()
