"""Local test for the exploration script: no network needed."""

from datetime import datetime, timedelta
from urllib.parse import parse_qs, urlparse

import explore_find_a_tender as explore


def test_first_page_url_asks_for_the_last_n_hours() -> None:
    query = parse_qs(urlparse(explore.first_page_url(hours=3)).query)

    updated_from = datetime.fromisoformat(query["updatedFrom"][0])
    updated_to = datetime.fromisoformat(query["updatedTo"][0])
    assert updated_to - updated_from == timedelta(hours=3)
    assert query["limit"] == ["100"]
