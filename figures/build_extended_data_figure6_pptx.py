#!/usr/bin/env python3
"""Build final Extended Data Figure 6 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure6_editable.pptx",
        "Extended Data Figure 6",
        FIG_DIR,
        8.2,
        [
            ("FigureS3C_Reactome_DownregulatedOnly.png", 0.775, 0.560, 5.950, 7.200),
        ],
        [],
    )


if __name__ == "__main__":
    main()
