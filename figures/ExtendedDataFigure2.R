# ExtendedDataFigure2.R
# Generate Extended Data Figure 3 and 4 panels with source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(forcats)
  library(ggpubr)
  library(patchwork)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "ExtendedDataFigure2.R"
script_dir <- dirname(normalizePath(this_file, mustWork = FALSE))
script_root <- normalizePath(file.path(script_dir, ".."), mustWork = FALSE)

source(file.path(script_root, "R", "load_config.R"))
source(file.path(script_root, "R", "source_data_helpers.R"))
source(file.path(script_root, "R", "figure_theme.R"))

fig_dir <- paths$figure_dir
panel_data_dir <- paths$source_data_dir
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(panel_data_dir, recursive = TRUE, showWarnings = FALSE)

save_panel <- function(plot, name, width_mm, height_mm, dpi = 600) {
  pdf_file <- file.path(fig_dir, paste0(name, ".pdf"))
  png_file <- file.path(fig_dir, paste0(name, ".png"))
  tiff_file <- file.path(fig_dir, paste0(name, ".tiff"))
  ggplot2::ggsave(pdf_file, plot = plot, width = width_mm, height = height_mm,
                  units = "mm", device = cairo_pdf, bg = "white")
  ggplot2::ggsave(png_file, plot = plot, width = width_mm, height = height_mm,
                  units = "mm", dpi = dpi, bg = "white")
  ggplot2::ggsave(tiff_file, plot = plot, width = width_mm, height = height_mm,
                  units = "mm", dpi = dpi, compression = "lzw", bg = "white")
  c(pdf = pdf_file, png = png_file, tiff = tiff_file)
}

parse_gene_ratio <- function(x) {
  parts <- stringr::str_split(x, "/", simplify = TRUE)
  as.numeric(parts[, 1]) / as.numeric(parts[, 2])
}

enrich_dotplot <- function(file, title, n_terms = 12, wrap_width = 42,
                           axis_text_size = 7.5) {
  df <- readr::read_csv(file, show_col_types = FALSE) %>%
    mutate(qvalue = as.numeric(qvalue)) %>%
    filter(!is.na(qvalue), qvalue < 0.05) %>%
    arrange(qvalue) %>%
    slice_head(n = n_terms) %>%
    mutate(
      GeneRatio_numeric = parse_gene_ratio(GeneRatio),
      log10q = -log10(qvalue),
      Description_wrapped = stringr::str_wrap(Description, width = wrap_width),
      Description_wrapped = fct_reorder(Description_wrapped, log10q)
    )
  p <- ggplot(df, aes(x = log10q, y = Description_wrapped)) +
    geom_point(aes(size = Count, color = GeneRatio_numeric), alpha = 0.95) +
    scale_color_viridis_c(name = "Gene ratio", option = "D", direction = 1, end = 0.95) +
    scale_size_continuous(name = "Gene count", range = c(1.0, 3.6)) +
    labs(title = title, x = expression(-log[10]~"(q-value)"), y = NULL) +
    theme_publication() +
    theme(
      plot.title = element_text(size = 7.5, face = "bold", hjust = 0.5),
      axis.text.y = element_text(size = axis_text_size, lineheight = 0.86),
      axis.text.x = element_text(size = 7.5),
      axis.title.x = element_text(size = 7.5),
      legend.title = element_text(size = 7.5),
      legend.text = element_text(size = 7.5),
      legend.key.size = unit(0.18, "cm"),
      plot.margin = margin(2, 2, 2, 2)
    )
  list(plot = p, data = df)
}

output_files <- character()
source_files <- character()

# A. KEGG EWE vs ESM non-DEG enrichment
resA <- enrich_dotplot(
  file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "CV", "KEGG", "KEGG_EWEvsESM_1.0.csv"),
  "KEGG enrichment of stable non-DEGs",
  n_terms = 18, wrap_width = 64, axis_text_size = 7.5
)
output_files <- c(output_files, save_panel(resA$plot, "FigureS2A_KEGG_EWEvsESM_dotplot", 180, 75))
source_files <- c(source_files, write_panel_source_data(resA$data, "Extended Data Figure 2", "A",
                                                        "KEGG enrichment terms for EWE vs. ESM stable non-DEGs.",
                                                        panel_data_dir, "FigureS2A_KEGG_EWEvsESM_terms"))

# B. GO:BP term intersection, stable UpSet-like plot
files_b <- c(
  "EWE vs. ESM" = file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "CV", "GO_BP", "GO_BP_EWEvsESM_1.0.csv"),
  "EWE vs. AWE" = file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "CV", "GO_BP", "GO_BP_EWEvsAWE_1.0.csv"),
  "AWE vs. ASM" = file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "CV", "GO_BP", "GO_BP_AWEvsASM_1.0.csv"),
  "ESM vs. ASM" = file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "CV", "GO_BP", "GO_BP_ESMvsASM_1.0.csv")
)
term_lists <- lapply(files_b, function(file) {
  readr::read_csv(file, show_col_types = FALSE) %>%
    filter(qvalue < 0.05) %>%
    pull(Description) %>%
    unique()
})
term_matrix <- tibble(Description = unique(unlist(term_lists)))
for (nm in names(term_lists)) {
  term_matrix[[nm]] <- term_matrix$Description %in% term_lists[[nm]]
}
set_cols <- names(term_matrix)[-1]
intersection_b <- term_matrix %>%
  unite("pattern", all_of(set_cols), remove = FALSE, sep = "|") %>%
  count(pattern, across(all_of(set_cols)), name = "intersection_size") %>%
  arrange(desc(intersection_size)) %>%
  slice_head(n = 12) %>%
  mutate(pattern = factor(pattern, levels = pattern))
matrix_b <- intersection_b %>%
  select(pattern, all_of(set_cols)) %>%
  pivot_longer(-pattern, names_to = "Comparison", values_to = "present") %>%
  mutate(Comparison = factor(Comparison, levels = rev(set_cols)))
pB <- (ggplot(intersection_b, aes(x = pattern, y = intersection_size)) +
         geom_col(width = 0.6, fill = "gray25") +
         geom_text(aes(label = intersection_size), vjust = -0.25, size = 2.8) +
         scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
         labs(y = "Intersection size", x = NULL) +
         theme_publication() +
         theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
               axis.text.y = element_text(size = 7.5), axis.title.y = element_text(size = 7.5),
               plot.margin = margin(1, 1, 0, 1))) /
      (ggplot(matrix_b, aes(x = pattern, y = Comparison)) +
         geom_line(aes(group = pattern), color = "gray35", linewidth = 0.25) +
         geom_point(aes(fill = present), shape = 21, size = 1.8, color = "black", stroke = 0.2) +
         scale_fill_manual(values = c("TRUE" = "black", "FALSE" = "white"), guide = "none") +
         labs(x = NULL, y = NULL) +
         theme_publication() +
         theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
               axis.text.y = element_text(size = 7.5),
               plot.margin = margin(0, 1, 1, 1))) +
  plot_layout(heights = c(2.1, 1))
output_files <- c(output_files, save_panel(pB, "FigureS2B_UpSetPlot_GO_BP_Terms", 180, 75))
source_files <- c(source_files,
                  write_panel_source_data(term_matrix, "Extended Data Figure 2", "B_membership",
                                          "GO:BP term membership across comparisons.",
                                          panel_data_dir, "FigureS2B_GO_BP_term_membership"),
                  write_panel_source_data(intersection_b, "Extended Data Figure 2", "B_intersections",
                                          "Top GO:BP term intersections plotted in panel B.",
                                          panel_data_dir, "FigureS2B_GO_BP_term_intersections"))

# C/D. Shared non-DEG enrichment terms
resC <- enrich_dotplot(
  file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "intersection_terms", "CV", "terms_GO_BP_EWEvsESM_EWEvsAWE_1.0.csv"),
  "GO:BP enrichment of shared non-DEGs",
  n_terms = 20, wrap_width = 42, axis_text_size = 7.5
)
resD <- enrich_dotplot(
  file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "intersection_terms", "CV", "terms_KEGG_EWEvsESM_EWEvsAWE_1.0.csv"),
  "KEGG enrichment of shared non-DEGs",
  n_terms = 20, wrap_width = 42, axis_text_size = 7.5
)
output_files <- c(output_files, save_panel(resC$plot, "FigureS2C_GO_BP_EWEvsESM_EWEvsAWE_dotplot", 90, 105))
output_files <- c(output_files, save_panel(resD$plot, "FigureS2D_KEGG_EWEvsESM_EWEvsAWE_dotplot", 90, 105))
source_files <- c(source_files,
                  write_panel_source_data(resC$data, "Extended Data Figure 2", "C",
                                          "GO:BP enrichment terms shared by EWE vs. ESM and EWE vs. AWE stable non-DEGs.",
                                          panel_data_dir, "FigureS2C_GO_BP_shared_terms"),
                  write_panel_source_data(resD$data, "Extended Data Figure 2", "D",
                                          "KEGG enrichment terms shared by EWE vs. ESM and EWE vs. AWE stable non-DEGs.",
                                          panel_data_dir, "FigureS2D_KEGG_shared_terms"))

# E. Representative genes
expr_data <- readr::read_csv(file.path(paths$human_analysis_dir, "2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv"),
                             show_col_types = FALSE) %>%
  column_to_rownames(colnames(.)[1])
sample_info <- tibble(Sample = colnames(expr_data)) %>%
  mutate(Group = case_when(
    str_detect(Sample, "^EWE") ~ "EWE",
    str_detect(Sample, "^ESM") ~ "ESM",
    str_detect(Sample, "^AWE") ~ "AWE",
    str_detect(Sample, "^ASM") ~ "ASM",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(Group))
selected_genes <- c("MTOR", "ATG7", "RAB7A", "VAMP3", "RHOB", "RAC1")
plot_data <- expr_data %>%
  as.data.frame() %>%
  rownames_to_column("Gene") %>%
  filter(Gene %in% selected_genes) %>%
  pivot_longer(-Gene, names_to = "Sample", values_to = "Expression") %>%
  left_join(sample_info, by = "Sample") %>%
  mutate(Group = factor(Group, levels = c("EWE", "ESM", "AWE", "ASM")),
         Gene = factor(Gene, levels = selected_genes))
gene_lab <- setNames(paste0("italic('", selected_genes, "')"), selected_genes)
pE <- ggplot(plot_data, aes(x = Group, y = Expression, fill = Group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, linewidth = 0.3) +
  geom_jitter(shape = 21, fill = "black", color = "black", stroke = 0.2, width = 0.18, size = 0.9) +
  facet_wrap(~Gene, scales = "free_y", ncol = 3,
             labeller = labeller(Gene = as_labeller(gene_lab, label_parsed))) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.12))) +
  scale_fill_manual(values = color_group) +
  labs(x = NULL, y = "Normalized expression") +
  theme_publication() +
  theme(legend.position = "none",
        strip.text = element_text(size = 7.5, face = "italic"),
        strip.background = element_blank(),
        axis.text = element_text(size = 7.5),
        axis.title.y = element_text(size = 7.5),
        plot.margin = margin(2, 2, 2, 2))
output_files <- c(output_files, save_panel(pE, "FigureS2E_RepresentativeGene_Boxplot", 180, 60))
source_files <- c(source_files, write_panel_source_data(plot_data, "Extended Data Figure 2", "E",
                                                        "Representative gene expression values.",
                                                        panel_data_dir, "FigureS2E_representative_gene_values"))

write_run_manifest("ExtendedDataFigure2", output_files, source_files, paths$log_dir)
message("Extended Data Figure 2 panels and source data completed.")
