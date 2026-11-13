# -*- coding: utf-8 -*-
# EN: Unit tests: ansible-test units --venv (from the collection root), or plain pytest.
# FR : Tests unitaires : ansible-test units --venv (depuis la racine de la collection), ou pytest.
from __future__ import annotations

import pytest

from ansible.errors import AnsibleFilterError
from ansible_collections.inspiredevgen.platform.plugins.filter.releases import release_previous, release_sort


@pytest.mark.parametrize(
    "given, expected",
    [
        (["v1.10", "v1.9", "v1.2"], ["v1.2", "v1.9", "v1.10"]),
        (["v2", "v2-rc1", "v1"], ["v1", "v2-rc1", "v2"]),
        (["v2-rc10", "v2-rc2"], ["v2-rc2", "v2-rc10"]),
        (["2.0.3", "v2.0.10", "V2.0.4"], ["2.0.3", "V2.0.4", "v2.0.10"]),
        ([], []),
    ],
)
def test_release_sort(given, expected):
    assert release_sort(given) == expected


def test_release_sort_reverse():
    assert release_sort(["v1", "v3", "v2"], reverse=True) == ["v3", "v2", "v1"]


@pytest.mark.parametrize(
    "current, expected",
    [("v10", "v2"), ("v2", "v1"), ("v1", None), ("v99", None)],
)
def test_release_previous(current, expected):
    assert release_previous(["v10", "v1", "v2"], current) == expected


@pytest.mark.parametrize("bad", [["latest"], [3], "v1,v2"])
def test_release_sort_rejects_bad_input(bad):
    with pytest.raises(AnsibleFilterError):
        release_sort(bad)
