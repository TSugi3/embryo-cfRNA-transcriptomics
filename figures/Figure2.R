# Figure2.R
# Generate Figure 2 panels B-E and panel-level source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(forcats)
  library(ggpubr)
  library(cowplot)
  library(GSVA)
  library(AnnotationDbi)
  library(org.Hs.eg.db)
  library(SummarizedExperiment)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure2.R"
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

source_files <- character()
output_files <- character()

# ============================================================
# Figure 2A - non-DEG / CV filtering workflow source data
# ============================================================
nondeg_files <- list(
  "EWE vs. ESM" = file.path(paths$human_analysis_dir, "nonDEG", "nonDEGfile_CV", "nonDEG_EWEvsESM_CV_lt_1.0.csv"),
  "EWE vs. AWE" = file.path(paths$human_analysis_dir, "nonDEG", "nonDEGfile_CV", "nonDEG_EWEvsAWE_CV_lt_1.0.csv"),
  "AWE vs. ASM" = file.path(paths$human_analysis_dir, "nonDEG", "nonDEGfile_CV", "nonDEG_AWEvsASM_CV_lt_1.0.csv"),
  "ESM vs. ASM" = file.path(paths$human_analysis_dir, "nonDEG", "nonDEGfile_CV", "nonDEG_ESMvsASM_CV_lt_1.0.csv")
)
nondeg_lists <- lapply(nondeg_files, function(file) {
  read_csv(file, show_col_types = FALSE) %>% pull(gene_id) %>% unique()
})
all_nondeg <- Reduce(union, nondeg_lists)
stable_nondeg <- nondeg_lists[["EWE vs. ESM"]]
workflow_df <- tibble(
  step = c(
    "Input: all genes in normalized count data",
    "Exclude DEGs",
    "Filter genes by coefficient of variation",
    "Output: stable non-DEG gene set"
  ),
  criterion = c(
    "Genes quantified in the TCC-normalized expression matrix",
    "q-value >= 0.05 in the indicated comparison",
    "CV < 1.0 in both EWE and ESM",
    "Genes retained after DEG exclusion and CV filtering"
  ),
  value = c(NA_character_, "q-value < 0.05 excluded", "CV < 1.0", as.character(length(stable_nondeg)))
)
source_files <- c(source_files, write_panel_source_data(
  workflow_df, "Figure 2", "A",
  "Workflow criteria used to define the stable non-DEG gene set.",
  panel_data_dir, "Figure2A_nonDEG_CV_workflow"
))

# ============================================================
# Figure 2B - GO BP enrichment of stable non-DEGs
# ============================================================
go_bp_file <- file.path(paths$human_analysis_dir, "nonDEG", "enrichment_output", "CV", "GO_BP", "GO_BP_EWEvsESM_1.0.csv")
go_bp_all <- read_csv(go_bp_file, show_col_types = FALSE) %>%
  mutate(qvalue = as.numeric(qvalue))

go_bp_plot <- go_bp_all %>%
  filter(!is.na(qvalue), qvalue < 0.05) %>%
  arrange(qvalue) %>%
  slice_head(n = 20) %>%
  mutate(
    GeneRatio_numeric = purrr::map_dbl(GeneRatio, ~ {
      parts <- str_split(.x, "/", simplify = TRUE)
      as.numeric(parts[1]) / as.numeric(parts[2])
    }),
    minus_log10_qvalue = -log10(qvalue),
    Description = fct_reorder(Description, minus_log10_qvalue)
  )

pB <- ggplot(go_bp_plot, aes(x = minus_log10_qvalue, y = Description)) +
  geom_point(aes(size = Count, color = GeneRatio_numeric), alpha = 0.95) +
  scale_color_viridis_c(name = "Gene Ratio", option = "D", direction = 1, end = 0.95) +
  scale_size_continuous(name = "Gene Count", range = c(1.2, 4.2)) +
  scale_x_continuous(limits = c(3, 8), expand = expansion(mult = c(0.02, 0.06))) +
  labs(x = expression(-log[10]~"(q-value)"), y = NULL) +
  theme_publication() +
  theme(
    legend.position = "right",
    legend.title = element_text(size = 6),
    legend.text = element_text(size = 6),
    axis.text.y = element_text(size = 5.8),
    plot.margin = margin(3, 3, 3, 3)
  )

output_files <- c(output_files, save_panel(pB, "Figure2B_GO_BP_EWEvsESM_dotplot", 110, 65))
source_files <- c(source_files, write_panel_source_data(
  go_bp_plot %>% arrange(qvalue),
  "Figure 2", "B",
  "GO biological process enrichment terms plotted for stable non-DEGs in EWE versus ESM.",
  panel_data_dir, "Figure2B_GO_BP_EWEvsESM_terms"
))

# ============================================================
# Figure 2C - UpSet plot of stable non-DEGs across comparisons
# ============================================================
all_genes <- unique(unlist(nondeg_lists))
gene_matrix <- tibble(gene_id = all_genes)
for (comp in names(nondeg_lists)) {
  gene_matrix[[comp]] <- gene_matrix$gene_id %in% nondeg_lists[[comp]]
}

intersection_summary <- gene_matrix %>%
  mutate(pattern = pmap_chr(across(all_of(names(nondeg_lists))), ~ {
    vals <- as.logical(c(...))
    paste(names(nondeg_lists)[vals], collapse = " & ")
  })) %>%
  mutate(pattern = if_else(pattern == "", "None", pattern)) %>%
  dplyr::count(pattern, name = "intersection_size") %>%
  arrange(desc(intersection_size)) %>%
  filter(pattern != "None") %>%
  mutate(intersection_id = row_number())

membership_for_plot <- intersection_summary %>%
  separate_rows(pattern, sep = " & ", convert = FALSE) %>%
  dplyr::rename(comparison = pattern) %>%
  mutate(
    comparison = factor(comparison, levels = rev(names(nondeg_lists))),
    y_matrix = -as.numeric(comparison)
  )

matrix_for_plot <- tidyr::expand_grid(
  intersection_id = intersection_summary$intersection_id,
  comparison = factor(rev(names(nondeg_lists)), levels = rev(names(nondeg_lists)))
) %>%
  left_join(
    membership_for_plot %>%
      mutate(present = TRUE) %>%
      dplyr::select(intersection_id, comparison, present),
    by = c("intersection_id", "comparison")
  ) %>%
  mutate(present = if_else(is.na(present), FALSE, present))

segment_for_plot <- membership_for_plot %>%
  group_by(intersection_id) %>%
  summarise(ymin = min(as.numeric(comparison)), ymax = max(as.numeric(comparison)), .groups = "drop") %>%
  filter(ymin != ymax)

pC_bar <- ggplot(intersection_summary, aes(x = intersection_id, y = intersection_size)) +
  geom_col(
    width = 0.68, fill = "grey25"
  ) +
  geom_text(
    aes(label = intersection_size),
    vjust = -0.25, size = 1.9
  ) +
  scale_x_continuous(limits = c(0.5, max(intersection_summary$intersection_id) + 0.5),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.16))) +
  labs(x = NULL, y = "Intersection size") +
  theme_publication() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.y = element_text(size = 6.5),
    axis.text.y = element_text(size = 5.8),
    plot.margin = margin(2, 2, 0, 7)
  )

pC_matrix <- ggplot(matrix_for_plot, aes(x = intersection_id, y = comparison)) +
  geom_segment(
    data = segment_for_plot,
    aes(x = intersection_id, xend = intersection_id, y = ymin, yend = ymax),
    inherit.aes = FALSE,
    linewidth = 0.35, color = "gray35"
  ) +
  geom_point(aes(fill = present), shape = 21, size = 2.1, color = "black", stroke = 0.2) +
  scale_fill_manual(values = c("TRUE" = "black", "FALSE" = "white"), guide = "none") +
  scale_x_continuous(limits = c(0.5, max(intersection_summary$intersection_id) + 0.5),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_discrete(drop = FALSE) +
  labs(x = NULL, y = NULL) +
  theme_publication() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 6),
    axis.line.x = element_blank(),
    axis.line.y = element_blank(),
    axis.ticks.y = element_blank(),
    plot.margin = margin(0, 2, 2, 7)
  )

pC <- cowplot::plot_grid(pC_bar, pC_matrix, ncol = 1, align = "v",
                         rel_heights = c(0.70, 0.30))

output_files <- c(output_files, save_panel(pC, "Figure2C_UpSetPlot_nonDEG", 70, 65))
source_files <- c(
  source_files,
  write_panel_source_data(gene_matrix, "Figure 2", "C_values",
                          "Gene-level membership matrix for stable non-DEG sets used in the UpSet plot.",
                          panel_data_dir, "Figure2C_nonDEG_membership_matrix"),
  write_panel_source_data(intersection_summary, "Figure 2", "C_intersections",
                          "Intersection sizes for stable non-DEG sets across comparisons.",
                          panel_data_dir, "Figure2C_nonDEG_intersections")
)

# ============================================================
# Figure 2D/E - ssGSEA heatmap and pathway score comparison
# ============================================================
expr_mat <- read_csv(file.path(paths$human_analysis_dir, "2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv"),
                     show_col_types = FALSE)
expr <- as.data.frame(expr_mat)
rownames(expr) <- expr[[1]]
expr <- expr[, -1]

selected_samples <- colnames(expr) %>% str_subset("^(EWE|ESM|AWE)")
expr_selected <- expr[, selected_samples]

go_terms <- c(
  "Macroautophagy" = "GO:0016236",
  "Vesicle transport" = "GO:0099024",
  "Small GTPase signaling" = "GO:1902531",
  "Endosomal transport" = "GO:0016197"
)

gene_sets_list <- lapply(go_terms, function(go_id) {
  genes <- suppressMessages(
    AnnotationDbi::select(org.Hs.eg.db, keys = go_id, keytype = "GOALL", columns = "SYMBOL")
  )$SYMBOL
  unique(genes[!is.na(genes) & genes %in% rownames(expr_selected)])
})

se <- SummarizedExperiment(assays = list(counts = as.matrix(expr_selected)))
ssgsea_scores <- assay(gsva(ssgseaParam(se, gene_sets_list)))

ssgsea_long <- as.data.frame(ssgsea_scores) %>%
  rownames_to_column("Pathway") %>%
  pivot_longer(-Pathway, names_to = "Sample", values_to = "ssGSEA_Score") %>%
  mutate(
    SampleType = case_when(
      str_detect(Sample, "^EWE") ~ "EWE",
      str_detect(Sample, "^ESM") ~ "ESM",
      str_detect(Sample, "^AWE") ~ "AWE",
      TRUE ~ "Other"
    ),
    SampleType = factor(SampleType, levels = c("EWE", "ESM", "AWE")),
    Pathway = factor(Pathway, levels = names(go_terms))
  )

score_scaled <- ssgsea_long %>%
  group_by(Pathway) %>%
  mutate(z_score = as.numeric(scale(ssGSEA_Score))) %>%
  ungroup()

pD <- ggplot(score_scaled, aes(x = Sample, y = Pathway, fill = z_score)) +
  geom_tile(color = "white", linewidth = 0.15) +
  scale_fill_gradient2(low = "navy", mid = "white", high = "firebrick3",
                       midpoint = 0, name = "z-score") +
  labs(x = NULL, y = NULL) +
  theme_publication() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 6.2),
    legend.position = "right",
    legend.title = element_text(size = 6),
    legend.text = element_text(size = 6),
    plot.margin = margin(2, 2, 2, 2)
  )

output_files <- c(output_files, save_panel(pD, "Figure2D_ssGSEA_heatmap", 178, 40))
source_files <- c(source_files, write_panel_source_data(
  score_scaled, "Figure 2", "D",
  "Sample-level ssGSEA scores and row-wise z-scores used in the heatmap.",
  panel_data_dir, "Figure2D_ssGSEA_scores"
))

comparisons <- list(c("EWE", "ESM"), c("EWE", "AWE"), c("ESM", "AWE"))
ssgsea_stats <- ssgsea_long %>%
  group_by(Pathway) %>%
  group_modify(~ {
    map_dfr(comparisons, function(comp) {
      df_use <- .x %>% filter(SampleType %in% comp)
      wt <- wilcox.test(ssGSEA_Score ~ SampleType, data = df_use)
      tibble(group1 = comp[1], group2 = comp[2],
             test = "Wilcoxon rank-sum test",
             p_value = wt$p.value,
             statistic = unname(wt$statistic),
             n_group1 = sum(df_use$SampleType == comp[1]),
             n_group2 = sum(df_use$SampleType == comp[2]))
    })
  }) %>%
  ungroup()

pE <- ggplot(ssgsea_long, aes(x = SampleType, y = ssGSEA_Score, fill = SampleType)) +
  geom_boxplot(color = "black", outlier.shape = NA, width = 0.58, alpha = 0.9) +
  geom_jitter(width = 0.22, size = 0.65, alpha = 0.75) +
  stat_compare_means(
    comparisons = comparisons,
    method = "wilcox.test",
    label = "p.format",
    size = 2.2,
    tip.length = 0.01
  ) +
  facet_wrap(~Pathway, scales = "free_y", nrow = 1) +
  scale_fill_manual(values = color_group) +
  scale_y_continuous(expand = expansion(mult = c(0.04, 0.20))) +
  labs(x = NULL, y = "ssGSEA Score") +
  theme_publication() +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(size = 6.2, face = "bold"),
    axis.text.x = element_text(size = 5.8),
    axis.text.y = element_text(size = 5.8),
    legend.position = "none",
    plot.margin = margin(3, 3, 3, 3)
  )

output_files <- c(output_files, save_panel(pE, "Figure2E_ssGSEA_score_comparison", 180, 50))
source_files <- c(
  source_files,
  write_panel_source_data(ssgsea_long, "Figure 2", "E_values",
                          "Sample-level ssGSEA scores plotted by sample group.",
                          panel_data_dir, "Figure2E_ssGSEA_values"),
  write_panel_source_data(ssgsea_stats, "Figure 2", "E_statistics",
                          "Wilcoxon rank-sum tests comparing ssGSEA scores between sample groups.",
                          panel_data_dir, "Figure2E_ssGSEA_statistics")
)

write_run_manifest("Figure2", output_files, source_files, paths$log_dir)
message("Figure2 panels B-E and source data completed.")
