# Figure scripts

This directory provides final-numbered entry points for the main figures:

- `Figure1.R` through `Figure8.R` correspond to the final main figures.
- `ExtendedDataFigure1.R` through `ExtendedDataFigure4.R` generate the shared panel outputs used for the final Extended Data figures.
- `Figure5_panels.R` and `Figure6_7_panels.R` are shared panel generators used by final-numbered wrapper scripts.

Figures 3/4 and 6/7 reuse upstream panel-generation code. The final-numbered wrapper scripts are included so that the public file list follows the final manuscript numbering, while shared panel generators preserve compatibility with the final Source Data mapping.

Run `Rscript run_all_figures.R` from the repository root to generate the main panel outputs and panel-level Source Data tables.

After assembling the editable PowerPoint files, run `audit_figure_pptx.py` to check that each figure is single-page, fits the configured 180 x 200 mm output boundary and contains no non-proportionally scaled raster panels.
