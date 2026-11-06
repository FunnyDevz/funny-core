#!/usr/bin/env python3
"""Locate crater's vendor layout from ``crater.settings.json``.

crater 0.7.5 describes the vendor realms in ``vendor``: either a single folder
with ``client`` / ``server`` inside, or an object that gives each realm its own
path and alias (``vendor.client.path`` = ``src/vendor/import``). The build
scripts must not hardcode ``include``, so this module is the single place that
reads the layout; renaming folders in ``crater.settings.json`` is enough.

``load(root)`` returns a dictionary:

  ``vendor``       the ``vendor`` setting as written
  ``vendor_path``  the folder that holds every realm (``root / vendor``)
  ``vendor_name``  the folder name of ``vendor_path`` (``vendor``)
  ``realms``       ``{realm: {"path", "alias", "folder"}}`` for client/server
  ``aliases``      ``{alias: target relative to src/}`` used by darklua and CI
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

DEFAULT_VENDOR = "_vendor"
REALMS = ("client", "server")


def _folder(raw: Any, fallback: str) -> tuple[str, str]:
    """Normalize a crater folder setting to ``(path, alias)``."""

    if isinstance(raw, str):
        path = raw or fallback
        return path, Path(path).name or fallback

    if isinstance(raw, dict):
        path = raw.get("path") or fallback
        alias = raw.get("alias") or Path(path).name or fallback
        return path, alias

    return fallback, fallback


def _path_of(raw: Any) -> str:
    if isinstance(raw, str):
        return raw
    if isinstance(raw, dict):
        return raw.get("path") or ""
    return ""


def _inside(path: str, base: str) -> bool:
    if not path or not base:
        return False
    path, base = Path(path).as_posix().rstrip("/"), Path(base).as_posix().rstrip("/")
    return path == base or path.startswith(f"{base}/")


def _realm(raw_vendor: Any, top: Any, realm: str) -> tuple[str, str]:
    """Resolve one vendor realm to ``(path, alias)``."""

    if isinstance(raw_vendor, dict):
        raw = raw_vendor.get(realm)
        if _path_of(raw):
            return _folder(raw, realm)

    vendor = raw_vendor if isinstance(raw_vendor, str) and raw_vendor else DEFAULT_VENDOR

    # Older (string) form: the import folder doubles as the realm when it sits
    # inside the vendor folder.
    if _inside(_path_of(top), vendor):
        return _folder(top, realm)

    return f"{vendor}/{realm}", realm


def _common_parent(paths: list[str]) -> str:
    values = [Path(path).as_posix() for path in paths if path]
    if not values:
        return DEFAULT_VENDOR
    parent = Path(os.path.commonpath(values))
    return parent.as_posix() if parent.as_posix() != "." else DEFAULT_VENDOR


def load(root: Path) -> dict[str, Any]:
    settings = root / "crater.settings.json"
    data: dict[str, Any] = {}

    if settings.is_file():
        try:
            data = json.loads(settings.read_text("utf-8"))
        except json.JSONDecodeError:
            data = {}

    raw_vendor = data.get("vendor")
    src = root / "src"

    realms: dict[str, dict[str, str]] = {}

    for realm in REALMS:
        path, alias = _realm(raw_vendor, data.get(realm), realm)
        folder = Path(path).name or realm
        realms[realm] = {"path": path, "alias": alias, "folder": folder}

    vendor_root = _common_parent([realms[realm]["path"] for realm in REALMS])
    vendor_name = Path(vendor_root).name or DEFAULT_VENDOR

    aliases: dict[str, str] = {}
    for realm in REALMS:
        path, alias = realms[realm]["path"], realms[realm]["alias"]

        # The alias target is relative to src/, which is the same in the repo,
        # in the dev package, in core/ and in build/package, so one value fits
        # every built tree.
        target = os.path.relpath(root / path, src).replace(os.sep, "/")
        aliases[alias] = target

    return {
        "vendor": raw_vendor if raw_vendor is not None else DEFAULT_VENDOR,
        "vendor_path": root / vendor_root,
        "vendor_name": vendor_name,
        "realms": realms,
        "aliases": aliases,
    }
