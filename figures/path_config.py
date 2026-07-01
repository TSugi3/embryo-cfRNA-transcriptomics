#!/usr/bin/env python3
"""Path configuration helpers for figure assembly scripts.

Set NCB_REVISED_ROOT to the revised manuscript directory when running outside
the original project layout. If it is unset, the scripts assume this file lives
in Script/figures/ and infer the revised manuscript root from that location.
"""

from __future__ import annotations

import os
from pathlib import Path


def revised_root() -> Path:
    env_root = os.environ.get("NCB_REVISED_ROOT")
    if env_root:
        return Path(env_root).expanduser().resolve()
    return Path(__file__).resolve().parents[2]


BASE_DIR = revised_root()
FIG_DIR = BASE_DIR / "Figure_revision"

