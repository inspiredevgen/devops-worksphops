# -*- coding: utf-8 -*-
# EN: Filters for release names such as v1, v1.10, 2.0.3, v2-rc1. A plain "sort" puts v1.10 BEFORE v1.9.
# FR : Filtres pour des noms de versions comme v1, v1.10, 2.0.3, v2-rc1. Un simple « sort » place v1.10 AVANT v1.9.
from __future__ import annotations

import re

from ansible.errors import AnsibleFilterError

_PART = re.compile(r"(\d+)|([A-Za-z]+)")


def _key(release):
    """Natural sort key: numbers compare as numbers; a pre-release (v2-rc1) sorts before its release (v2)."""
    if not isinstance(release, str):
        raise AnsibleFilterError(f"release names must be strings, got {type(release).__name__}: {release!r}")
    text = release.strip()
    if text[:1] in ("v", "V"):
        text = text[1:]
    main, _, pre = text.partition("-")
    numbers = tuple(int(n) for n in re.findall(r"\d+", main))
    if not numbers:
        raise AnsibleFilterError(f"{release!r} does not look like a release name (expected v1, 1.2.3, v2-rc1…)")
    pre_key = tuple((0, int(n)) if n else (1, w.lower()) for n, w in _PART.findall(pre))
    # (numbers, is_final, pre-release parts): 2.0-rc1 < 2.0
    return numbers, 0 if pre else 1, pre_key


def release_sort(releases, reverse=False):
    """Sort release names from oldest to newest (or newest first with reverse=true)."""
    if not isinstance(releases, (list, tuple)):
        raise AnsibleFilterError("release_sort expects a list of release names")
    return sorted(releases, key=_key, reverse=reverse)


def release_previous(releases, current):
    """The release just before `current` in the sorted list, or None if `current` is the oldest or unknown."""
    ordered = release_sort(releases)
    if current not in ordered:
        return None
    index = ordered.index(current)
    return ordered[index - 1] if index > 0 else None


class FilterModule:
    def filters(self):
        return {
            "release_sort": release_sort,
            "release_previous": release_previous,
        }
