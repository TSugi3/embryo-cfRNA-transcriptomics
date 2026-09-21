#!/usr/bin/env python3
"""Build final Extended Data Figure 7 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure7_editable.pptx",
        "Extended Data Figure 7",
        FIG_DIR,
        8.15,
        [
            ("FigureS3D_GSEA_Reactome_dotplot.png", 0.208, 0.420, 7.083, 3.229),
            ("FigureS3E_GSEAplot_EWEvsAWE_Reactome.png", 0.208, 3.850, 7.083),
        ],
        [
            ("A", 0.208, 0.278),
            ("B", 0.208, 3.720),
        ],
    )


if __name__ == "__main__":
    main()
