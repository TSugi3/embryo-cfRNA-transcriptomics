#!/usr/bin/env python3
"""Build final Extended Data Figure 5 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure5_editable.pptx",
        "Extended Data Figure 5",
        FIG_DIR,
        7.8,
        [
            ("FigureS3A_Distribution_KS_Density.png", 0.208, 0.360, 7.083),
            ("FigureS3B_Reactome_UpregulatedOnly.png", 0.208, 2.020, 7.083),
        ],
        [
            ("A", 0.208, 0.218),
            ("B", 0.208, 1.880),
        ],
    )


if __name__ == "__main__":
    main()
