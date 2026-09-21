#!/usr/bin/env python3
"""Build final Extended Data Figure 1 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure1_editable.pptx",
        "Extended Data Figure 1",
        FIG_DIR,
        7.8,
        [
            ("FigureS1A_Barplot_ReadCounts.png", 0.208, 0.426, 7.083),
            ("FigureS1B_ViolinPlot_RawReads.png", 0.207, 2.417, 2.347),
            ("FigureS1C_MappingRate_PerGroup.png", 2.550, 2.417, 2.347),
            ("FigureS1D_GiniCoefficient_withPval.png", 5.002, 2.417, 2.145),
            ("FigureS1E_Subsampling_Gene_Count_ALL_log10.png", 0.204, 4.600, 3.400),
            ("FigureS1F_Subsampling_Gene_Count_ProteinCoding_log10.png", 3.892, 4.600, 3.400),
        ],
        [
            ("A", 0.208, 0.296),
            ("B", 0.208, 2.383),
            ("C", 2.556, 2.383),
            ("D", 4.899, 2.383),
            ("E", 0.192, 4.550),
            ("F", 3.870, 4.550),
        ],
    )


if __name__ == "__main__":
    main()
