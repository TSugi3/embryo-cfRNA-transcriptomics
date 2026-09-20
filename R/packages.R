# R package list used by the figure-generation workflow.
# Install from CRAN/Bioconductor as appropriate for your R version.

cran_packages <- c(
  "tidyverse", "readxl", "ggplot2", "ggpubr", "ggrepel",
  "patchwork", "cowplot", "viridis", "hexbin", "entropy",
  "circlize", "pheatmap", "ggsci", "scales", "RColorBrewer"
)

bioc_packages <- c(
  "ComplexHeatmap", "clusterProfiler", "ReactomePA", "GSVA",
  "org.Hs.eg.db", "org.Mm.eg.db", "enrichplot"
)

message("Install CRAN packages with install.packages(cran_packages)")
message("Install Bioconductor packages with BiocManager::install(bioc_packages)")
