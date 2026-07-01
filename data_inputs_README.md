# Expected processed inputs

The public repository does not include raw sequencing data or private local analysis folders. The figure scripts expect processed inputs prepared by the RNA-seq analysis pipeline.

## Human processed analysis directory

Set as `CFRNA_HUMAN_ANALYSIS_DIR`. Expected subdirectories/files include, among others:

- `InsertLength/InsertLengthWESM.xlsx`
- `biotype/biotype_all.xlsx`
- normalized count matrix, e.g. `2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv`
- differential-expression outputs used by figure scripts
- GO/KEGG/Reactome enrichment and GSEA outputs
- ssGSEA/GSVA outputs

## Human figure script directory

Set as `CFRNA_HUMAN_FIGURE_SCRIPT_DIR`. Expected to include:

- `theme_figure.R`
- original processed figure inputs where required

## Mouse processed analysis directory

Set as `CFRNA_MOUSE_ANALYSIS_DIR`. Expected files include:

- `CQ_tmm_edger_3_0.1_0.05_TCC_Normalized.csv`
- `CB_tmm_edger_3_0.1_0.05_TCC_Normalized.csv`
- treatment group/sample metadata tables
- ranked gene lists for treatment-versus-control comparisons
- GO:BP GSEA result files for CQ and CB comparisons

## Outputs

Set these output locations:

- `CFRNA_FIGURE_DIR`
- `CFRNA_SOURCE_DATA_DIR`
- `CFRNA_SOURCE_DATA_WORKBOOK`
- `CFRNA_LOG_DIR`
