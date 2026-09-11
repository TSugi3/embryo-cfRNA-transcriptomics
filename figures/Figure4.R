# Figure4.R
# Generate final Figure 5 panels and panel-level source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(forcats)
  library(ggpubr)
  library(GSVA)
  library(AnnotationDbi)
  library(org.Hs.eg.db)
  library(SummarizedExperiment)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure4.R"
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

wilcox_by_feature <- function(df, feature_col, value_col, group_col = "Group",
                              group_a = "ESM", group_b = "ASM") {
  df %>%
    group_by(.data[[feature_col]]) %>%
    group_modify(~ {
      wt <- wilcox.test(.x[[value_col]] ~ .x[[group_col]])
      tibble(
        test = "Wilcoxon rank-sum test",
        comparison = paste(group_a, "vs", group_b),
        p_value = wt$p.value,
        statistic = unname(wt$statistic),
        n_group_1 = sum(.x[[group_col]] == group_a),
        n_group_2 = sum(.x[[group_col]] == group_b)
      )
    }) %>%
    ungroup()
}

output_files <- character()
source_files <- character()

# ============================================================
# Figure 4A - GO:BP GSEA of ESM vs. ASM
# ============================================================
gsea <- readr::read_csv(file.path(paths$human_analysis_dir, "DEG", "GSEA", "ESMvsASM", "GSEA_GO_BP.csv"),
                        show_col_types = FALSE)
gsea_filt <- gsea %>% filter(qvalue < 0.25)
gsea_pos <- gsea_filt %>%
  filter(NES > 0) %>%
  arrange(desc(NES)) %>%
  slice_head(n = 15) %>%
  mutate(set = "Upregulated in ESM")
gsea_neg <- gsea_filt %>%
  filter(NES < 0) %>%
  arrange(NES) %>%
  slice_head(n = 15) %>%
  mutate(set = "Upregulated in ASM")

gsea_top <- bind_rows(gsea_pos, gsea_neg) %>%
  mutate(
    set = factor(set, levels = c("Upregulated in ESM", "Upregulated in ASM")),
    Description_wrapped = stringr::str_wrap(Description, width = 100),
    Description_wrapped = forcats::fct_reorder(Description_wrapped, NES),
    minus_log10_qvalue = -log10(qvalue)
  )

pA <- ggplot(gsea_top, aes(x = NES, y = Description_wrapped, color = set, size = minus_log10_qvalue)) +
  geom_point(alpha = 0.95) +
  scale_size_continuous(name = expression(-log[10]~"q-value"), range = c(1, 4)) +
  scale_color_manual(values = c("Upregulated in ESM" = "#1b9e77", "Upregulated in ASM" = "#d95f02")) +
  facet_wrap(~set, scales = "free_y", ncol = 1) +
  labs(title = "GO:BP GSEA of ESM vs. ASM", x = "Normalized Enrichment Score (NES)", y = NULL, color = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(size = 8, hjust = 0.5),
    strip.text = element_text(size = 8),
    axis.text.y = element_text(size = 8, lineheight = 0.5),
    axis.text.x = element_text(size = 8),
    legend.title = element_text(size = 8),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.3, "cm"),
    panel.spacing.y = unit(4, "mm")
  ) +
  guides(color = "none")

output_files <- c(output_files, save_panel(pA, "Figure4A_GSEA_GO_BP_ESMvsASM_dotplot", 180, 100))
source_files <- c(source_files, write_panel_source_data(
  gsea_top %>% arrange(set, desc(abs(NES))),
  "Figure 4", "A",
  "GO biological process GSEA terms for ESM versus ASM. Point size encodes -log10(q-value).",
  panel_data_dir, "Figure4A_GSEA_GO_BP_ESMvsASM_terms"
))

# ============================================================
# Shared expression table for Figure 4B/C
# ============================================================
expr <- readr::read_csv(file.path(paths$human_analysis_dir, "2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv"),
                        show_col_types = FALSE)

# ============================================================
# Figure 4B - Representative gene expression
# ============================================================
gene_set <- list(
  "RNA Splicing" = c("SRSF1", "SF3B1"),
  "Vesicle Transport" = c("RAB5C", "VAMP3"),
  "Oxidative Phosphorylation" = c("COX5B", "NDUFA9")
)
target_genes_b <- unlist(gene_set, use.names = FALSE)

expr_b <- expr %>%
  filter(gene_id %in% target_genes_b) %>%
  pivot_longer(-gene_id, names_to = "Sample", values_to = "Expression") %>%
  mutate(
    Group = factor(case_when(
      str_detect(Sample, "^ESM") ~ "ESM",
      str_detect(Sample, "^ASM") ~ "ASM",
      TRUE ~ NA_character_
    ), levels = c("ESM", "ASM")),
    Category = case_when(
      gene_id %in% gene_set[["RNA Splicing"]] ~ "RNA splicing",
      gene_id %in% gene_set[["Vesicle Transport"]] ~ "Vesicle transport",
      gene_id %in% gene_set[["Oxidative Phosphorylation"]] ~ "Oxidative phosphorylation"
    ),
    Log2_expression = log2(Expression + 1),
    gene_id = factor(gene_id, levels = target_genes_b)
  ) %>%
  filter(!is.na(Group))

stats_b <- wilcox_by_feature(expr_b, "gene_id", "Log2_expression")
gene_lab_b <- setNames(paste0("italic('", target_genes_b, "')"), target_genes_b)

pB <- ggplot(expr_b, aes(x = Group, y = Log2_expression, fill = Group)) +
  geom_boxplot(outlier.shape = NA, width = 0.6, alpha = 0.8) +
  geom_jitter(width = 0.2, size = 0.85, alpha = 0.8) +
  stat_compare_means(method = "wilcox.test", comparisons = list(c("ESM", "ASM")),
                     label = "p.format", size = 2.0) +
  facet_wrap(~gene_id, scales = "free_y", ncol = 6,
             labeller = labeller(gene_id = as_labeller(gene_lab_b, label_parsed))) +
  scale_fill_manual(values = color_group[c("ESM", "ASM")]) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.16))) +
  labs(title = "Representative genes associated with RNA transport and metabolism",
       y = "log2 normalized expression", x = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8),
    strip.text = element_text(size = 6.5, face = "italic"),
    strip.background = element_blank(),
    panel.spacing = unit(0.8, "mm"),
    axis.text = element_text(size = 7),
    axis.title.y = element_text(size = 7),
    legend.position = "none",
    plot.margin = margin(2, 4, 2, 2)
  ) +
  coord_cartesian(clip = "off")

output_files <- c(output_files, save_panel(pB, "Figure4B_Representative_Gene_Expression_Boxplot", 180, 40))
source_files <- c(
  source_files,
  write_panel_source_data(expr_b, "Figure 4", "B_values",
                          "Sample-level expression values for representative genes in ESM and ASM.",
                          panel_data_dir, "Figure4B_Representative_Gene_values"),
  write_panel_source_data(stats_b, "Figure 4", "B_statistics",
                          "Wilcoxon rank-sum tests comparing ESM and ASM for each representative gene.",
                          panel_data_dir, "Figure4B_Representative_Gene_statistics")
)

# ============================================================
# Figure 4C - Exosome marker gene expression
# ============================================================
target_genes_c <- c("CD81", "SDCBP", "SMPD3", "TSG101", "VPS4A", "SYTL4")
expr_c <- expr %>%
  filter(gene_id %in% target_genes_c) %>%
  pivot_longer(-gene_id, names_to = "Sample", values_to = "Expression") %>%
  mutate(
    Group = factor(case_when(
      str_detect(Sample, "^ESM") ~ "ESM",
      str_detect(Sample, "^ASM") ~ "ASM",
      TRUE ~ NA_character_
    ), levels = c("ESM", "ASM")),
    Log2_expression = log2(Expression + 1),
    gene_id = factor(gene_id, levels = target_genes_c)
  ) %>%
  filter(!is.na(Group))

stats_c <- wilcox_by_feature(expr_c, "gene_id", "Log2_expression")
gene_lab_c <- setNames(paste0("italic('", target_genes_c, "')"), target_genes_c)

pC <- ggplot(expr_c, aes(x = Group, y = Log2_expression, fill = Group)) +
  geom_boxplot(outlier.shape = NA, width = 0.6, alpha = 0.85) +
  geom_jitter(width = 0.2, size = 0.95, alpha = 0.65) +
  stat_compare_means(method = "wilcox.test", comparisons = list(c("ESM", "ASM")),
                     label = "p.format", size = 2.0) +
  facet_wrap(~gene_id, scales = "free_y", ncol = 6,
             labeller = labeller(gene_id = as_labeller(gene_lab_c, label_parsed))) +
  scale_fill_manual(values = color_group[c("ESM", "ASM")]) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.16))) +
  labs(title = "Exosome marker genes in spent media",
       y = "log2 normalized expression", x = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8),
    strip.text = element_text(size = 6.5, face = "italic"),
    strip.background = element_blank(),
    panel.spacing = unit(0.8, "mm"),
    axis.text = element_text(size = 7),
    axis.title.y = element_text(size = 7),
    legend.position = "none",
    plot.margin = margin(2, 4, 2, 2)
  ) +
  coord_cartesian(clip = "off")

output_files <- c(output_files, save_panel(pC, "Figure4C_ExosomeMarkers_Boxplot", 180, 38))
source_files <- c(
  source_files,
  write_panel_source_data(expr_c, "Figure 4", "C_values",
                          "Sample-level expression values for exosome marker genes in ESM and ASM.",
                          panel_data_dir, "Figure4C_ExosomeMarker_values"),
  write_panel_source_data(stats_c, "Figure 4", "C_statistics",
                          "Wilcoxon rank-sum tests comparing ESM and ASM for each exosome marker gene.",
                          panel_data_dir, "Figure4C_ExosomeMarker_statistics")
)

# ============================================================
# Figure 4D - ssGSEA pathway scores
# ============================================================
expr_matrix <- expr %>% as.data.frame()
rownames(expr_matrix) <- expr_matrix[[1]]
expr_matrix <- expr_matrix[, -1]
cfRNA_samples <- colnames(expr_matrix) %>% str_subset("^(ESM|ASM)")
cfRNA_expr <- expr_matrix[, cfRNA_samples]

go_terms <- c("GO:0006914", "GO:0097734", "GO:0008380", "GO:0006119")
gene_sets <- vector("list", length(go_terms))
for (i in seq_along(go_terms)) {
  symbols <- AnnotationDbi::select(org.Hs.eg.db, keys = go_terms[i], keytype = "GOALL", columns = "SYMBOL")$SYMBOL
  gene_sets[[i]] <- unique(symbols[!is.na(symbols)])
}
names(gene_sets) <- c("Autophagy", "Exosome biogenesis", "RNA splicing", "Oxidative phosphorylation")

se <- SummarizedExperiment(assays = list(counts = as.matrix(cfRNA_expr)))
ssgsea_scores <- gsva(ssgseaParam(se, gene_sets))

df_scores <- assay(ssgsea_scores) %>%
  t() %>%
  as.data.frame() %>%
  rownames_to_column("Sample") %>%
  pivot_longer(-Sample, names_to = "Pathway", values_to = "Score") %>%
  mutate(
    Group = factor(if_else(str_detect(Sample, "^ESM"), "ESM", "ASM"),
                   levels = c("ESM", "ASM")),
    Pathway = factor(Pathway, levels = names(gene_sets))
  )

stats_d <- wilcox_by_feature(df_scores, "Pathway", "Score")

pD <- ggplot(df_scores, aes(x = Group, y = Score, fill = Group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, alpha = 0.85) +
  geom_jitter(width = 0.15, size = 0.95, alpha = 0.65) +
  facet_wrap(~Pathway, scales = "free_y", nrow = 1) +
  stat_compare_means(comparisons = list(c("ESM", "ASM")), label = "p.format",
                     method = "wilcox.test", size = 2.0) +
  scale_fill_manual(values = color_group[c("ESM", "ASM")]) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.15))) +
  labs(x = NULL, y = "ssGSEA enrichment score", title = "cfRNA-associated pathway activity (ssGSEA)") +
  theme_publication() +
  theme(
    legend.position = "none",
    strip.background = element_blank(),
    strip.text = element_text(size = 7),
    plot.title = element_text(size = 8, hjust = 0.5, face = "bold"),
    axis.text = element_text(size = 7),
    axis.title.y = element_text(size = 7),
    panel.spacing = unit(0.8, "mm"),
    plot.margin = margin(2, 4, 2, 2)
  ) +
  coord_cartesian(clip = "off")

output_files <- c(output_files, save_panel(pD, "Figure4D_ssGSEA_Boxplot_GO_BP", 180, 40))
source_files <- c(
  source_files,
  write_panel_source_data(df_scores, "Figure 4", "D_values",
                          "Sample-level ssGSEA pathway scores for ESM and ASM.",
                          panel_data_dir, "Figure4D_ssGSEA_values"),
  write_panel_source_data(stats_d, "Figure 4", "D_statistics",
                          "Wilcoxon rank-sum tests comparing ESM and ASM for each ssGSEA pathway.",
                          panel_data_dir, "Figure4D_ssGSEA_statistics"),
  write_panel_source_data(
    tibble(pathway = names(gene_sets), go_id = go_terms,
           gene_count = lengths(gene_sets),
           genes = vapply(gene_sets, paste, collapse = "; ", FUN.VALUE = character(1))),
    "Figure 4", "D_gene_sets",
    "GO gene sets used for ssGSEA pathway scoring.",
    panel_data_dir, "Figure4D_ssGSEA_gene_sets"
  )
)

write_run_manifest("Figure4", output_files, source_files, paths$log_dir)
message("Figure4 panels and source data completed.")
