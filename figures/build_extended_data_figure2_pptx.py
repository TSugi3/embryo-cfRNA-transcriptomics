#!/usr/bin/env python3
"""Build final Extended Data Figure 2 as an editable PowerPoint slide."""

from __future__ import annotations

from path_config import FIG_DIR
from pptx_helpers import build_single_slide


def main() -> None:
    build_single_slide(
        FIG_DIR / "ExtendedDataFigure2_editable.pptx",
        "Extended Data Figure 2",
        FIG_DIR,
        7.5,
        [
            ("FigureS1G_MAplot_Facet.png", 0.208, 0.420, 3.542, 3.542),
            ("FigureS1H_DensityPlot_Facet.png", 3.750, 0.420, 3.542, 3.542),
            ("FigureS1I_UpSetPlot_DEG.png", 0.208, 4.050, 7.083, 3.139),
        ],
        [
            ("A", 0.208, 0.296),
            ("B", 3.750, 0.296),
            ("C", 0.208, 3.930),
        ],
    )


if __name__ == "__main__":
    main()
