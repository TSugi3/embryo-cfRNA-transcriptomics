#!/usr/bin/env python3
"""Build final Extended Data Figure 3 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure3_editable.pptx",
        "Extended Data Figure 3",
        FIG_DIR,
        6.8,
        [
            ("FigureS2A_KEGG_EWEvsESM_dotplot.png", 0.207, 0.468, 7.083, 2.944),
            ("FigureS2B_UpSetPlot_GO_BP_Terms.png", 0.207, 3.413, 7.083, 2.944),
        ],
        [
            ("A", 0.208, 0.296),
            ("B", 0.208, 3.293),
        ],
    )


if __name__ == "__main__":
    main()
