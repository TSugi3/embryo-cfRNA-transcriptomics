#!/usr/bin/env python3
"""Path configuration helpers for figure assembly scripts.

Set CFRNA_PROJECT_ROOT to the project directory when outputs should be written
outside this repository. If it is unset, the scripts infer the repository root
from this file's location.
"""

from __future__ import annotations

import os
from pathlib import Path


def project_root() -> Path:
    env_root = os.environ.get("CFRNA_PROJECT_ROOT")
    if env_root:
        return Path(env_root).expanduser().resolve()
    return Path(__file__).resolve().parents[1]


BASE_DIR = project_root()
FIG_DIR = BASE_DIR / "figure_outputs"
