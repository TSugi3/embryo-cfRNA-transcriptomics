#!/usr/bin/env python3
"""Build final Extended Data Figure 8 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure8_editable.pptx",
        "Extended Data Figure 8",
        FIG_DIR,
        8.2,
        [
            ("FigureS4A_KEGG_dotplot.png", 0.208, 0.260, 7.083),
            ("FigureS4B_heatmap_vesicle.png", 0.208, 3.455, 7.083),
        ],
        [
            ("A", 0.208, 0.118),
            ("B", 0.208, 3.315),
        ],
    )


if __name__ == "__main__":
    main()
