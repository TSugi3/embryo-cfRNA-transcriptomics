# Embryo cfRNA release analysis code

This repository contains revision-stage analysis scripts used to generate figures and source-data tables for the manuscript:

**Regulated release of embryo-derived cell-free RNA reflects chromosomal integrity and developmental potential**

The scripts are intended to document and reproduce the figure-generation workflow from processed input tables. Raw sequencing files and private submission materials are not included in this repository.

## Repository contents

- `R/config_template.R`: path configuration template based on environment variables.
- `R/load_config.R`: configuration loader. It uses private `R/config.local.R` if present, otherwise it reads environment variables through `config_template.R`.
- `R/theme_ncb_revision.R`: shared plotting theme for revised figures.
- `R/source_data_helpers.R`: helper functions for panel-level source-data tables.
- `figures/*_revision.R`: scripts that generate revised figure panels and panel-level source-data CSV files.
- `figures/build_*_pptx.py`: scripts that assemble editable PowerPoint figures from generated panels.
- `figures/render_figure_previews.py`: preview rendering helper.
- `figures/export_submission_figures.py`: submission image/PDF export helper.
- `build_source_data_workbook.py`: combines panel-level CSV files into `SourceData.xlsx`.
- `inventory/figure_revision_inventory.csv`: panel-level figure checklist.

## Data availability and inputs

This code expects processed input files generated from the RNA-seq analysis workflow. Raw sequencing data are available from the public repositories described in the manuscript Data availability section. Processed count matrices and figure source data are provided with the paper as Supplementary Tables and Source Data files.

Expected local inputs include:

- Human RNA-seq processed analysis directory, including normalized expression matrices, differential-expression outputs, enrichment results and QC tables.
- Original human figure script/data directory containing `theme_figure.R` and processed figure inputs.
- Mouse perturbation processed analysis directory, including normalized count matrices, treatment groupings, ranked lists and GO:BP GSEA outputs.
- A writable output directory for revised figures, panel-level source-data CSV files and logs.

Local paths are intentionally not stored in the repository.

## Configuration

Either create a private local config:

```r
file.copy("R/config_template.R", "R/config.local.R")
```

and edit `R/config.local.R`, or set these environment variables:

```bash
export NCB_HUMAN_ANALYSIS_DIR=/path/to/Analysis_RNAseq
export NCB_HUMAN_FIGURE_SCRIPT_DIR=/path/to/Analysis_RNAseq/Figure_revision
export NCB_MOUSE_ANALYSIS_DIR=/path/to/Analysis_RNAseq_mouse
export NCB_REVISED_ROOT=/path/to/revision_workspace
export NCB_REVISED_FIGURE_DIR=/path/to/revision_workspace/Figure_revision
export NCB_SOURCE_DATA_DIR=/path/to/revision_workspace/Figure_revision/source_data/panel_tables
export NCB_SOURCE_DATA_WORKBOOK=/path/to/revision_workspace/SourceData.xlsx
export NCB_LOG_DIR=/path/to/revision_workspace/Figure_revision/logs
```

`R/config.local.R` is ignored by git and should not be published.

## Basic usage

Generate individual figure panels:

```bash
Rscript figures/Figure1_revision.R
Rscript figures/Figure2_revision.R
Rscript figures/Figure3_revision.R
Rscript figures/Figure4_revision.R
Rscript figures/Figure5_revision.R
Rscript figures/Figure6_revision.R
Rscript figures/ExtendedDataFigure1_revision.R
Rscript figures/ExtendedDataFigure2_revision.R
Rscript figures/ExtendedDataFigure3_revision.R
Rscript figures/ExtendedDataFigure4_revision.R
```

Build the combined Source Data workbook:

```bash
python3 build_source_data_workbook.py \
  --panel-dir "$NCB_SOURCE_DATA_DIR" \
  --output "$NCB_SOURCE_DATA_WORKBOOK"
```

Assemble editable figures and export submission images:

```bash
python3 figures/build_figure1_pptx.py
python3 figures/build_figure2_pptx.py
python3 figures/build_figure3_pptx.py
python3 figures/build_figure4_pptx.py
python3 figures/build_figure5_pptx.py
python3 figures/build_figure6_pptx.py
python3 figures/build_extended_data_figure1_pptx.py
python3 figures/build_extended_data_figure2_pptx.py
python3 figures/build_extended_data_figure3_pptx.py
python3 figures/build_extended_data_figure4_pptx.py
python3 figures/export_submission_figures.py --figure-dir "$NCB_REVISED_FIGURE_DIR" --out-dir /path/to/submission_figures --width-mm 180 --dpi 600
```

## Privacy and reproducibility notes

- Do not commit raw FASTQ/BAM files, SRA submission metadata containing local file paths, private reviewer correspondence, manuscript drafts, credentials or `config.local.R`.
- Generated figures, PowerPoint files, PDFs, images, logs and Excel workbooks are ignored by default.
- Some paths in the scripts refer to expected processed input filenames. If input filenames differ, update the local processed-data directory or add a small local adapter script outside the public repository.

## Software

The workflow uses R and Python. Main R packages include `tidyverse`, `readxl`, `ggplot2`, `ggpubr`, `ComplexHeatmap`, `clusterProfiler`, `ReactomePA`, `GSVA`, `circlize`, `openxlsx`, `patchwork`, `cowplot`, `viridis`, `ggrepel`, `ggupset` and related plotting/data packages. Python helpers use `openpyxl`, `python-pptx` and `Pillow`.

## License

No license has been selected yet. Add a `LICENSE` file before public reuse if you want to permit redistribution or reuse beyond viewing the code.
