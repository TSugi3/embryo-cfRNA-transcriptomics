#!/usr/bin/env python3
"""Build final Extended Data Figure 4 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure4_editable.pptx",
        "Extended Data Figure 4",
        FIG_DIR,
        7.5,
        [
            ("FigureS2C_GO_BP_EWEvsESM_EWEvsAWE_dotplot.png", 0.207, 0.515, 3.542, 4.132),
            ("FigureS2D_KEGG_EWEvsESM_EWEvsAWE_dotplot.png", 3.743, 0.515, 3.542, 4.132),
            ("FigureS2E_RepresentativeGene_Boxplot.png", 0.203, 4.760, 7.083, 2.361),
        ],
        [
            ("A", 0.208, 0.296),
            ("B", 3.736, 0.296),
            ("C", 0.208, 4.652),
        ],
    )


if __name__ == "__main__":
    main()
