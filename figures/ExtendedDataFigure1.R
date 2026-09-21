# ExtendedDataFigure1.R
# Generate Extended Data Figure 1 and 2 panels with source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(forcats)
  library(patchwork)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "ExtendedDataFigure1.R"
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

gini_coefficient <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) == 0 || sum(x) == 0) return(NA_real_)
  x <- sort(x)
  n <- length(x)
  (2 * sum(seq_len(n) * x) / (n * sum(x))) - (n + 1) / n
}

wilcox_two <- function(df, value_col, group_col = "Group", comparisons) {
  purrr::map_dfr(comparisons, function(comp) {
    sub <- df %>% filter(.data[[group_col]] %in% comp)
    wt <- wilcox.test(sub[[value_col]] ~ sub[[group_col]])
    tibble(comparison = paste(comp, collapse = " vs. "),
           test = "Wilcoxon rank-sum test",
           p_value = wt$p.value,
           statistic = unname(wt$statistic),
           n_group_1 = sum(sub[[group_col]] == comp[1]),
           n_group_2 = sum(sub[[group_col]] == comp[2]))
  })
}

output_files <- character()
source_files <- character()

qc_file <- file.path(paths$human_analysis_dir, "RNAseq_QC_Summary", "RNAseq_QC_Summary.xlsx")
raw_reads <- readxl::read_excel(qc_file, sheet = "Raw_Reads")
raw_reads <- raw_reads %>%
  rename(SampleID = 1, Raw_Reads = 2, Mapped_Reads = 3) %>%
  mutate(
    SampleType = substr(SampleID, 1, 3),
    SampleType = factor(SampleType, levels = c("EWE", "ESM", "AWE", "ASM", "MWE", "MSM")),
    MappingRate = Mapped_Reads / Raw_Reads * 100
  ) %>%
  arrange(SampleType, SampleID)

group_colors_ext <- c(color_group, MWE = "gold", MSM = "deeppink")

# A. Raw and mapped reads
df_a <- raw_reads %>%
  mutate(SampleID = factor(SampleID, levels = unique(SampleID))) %>%
  pivot_longer(c(Raw_Reads, Mapped_Reads), names_to = "ReadType", values_to = "ReadCount") %>%
  mutate(ReadType = factor(ReadType, levels = c("Raw_Reads", "Mapped_Reads")))

pA <- ggplot(df_a, aes(x = SampleID, y = ReadCount, fill = ReadType)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_log10(expand = expansion(mult = c(0, 0.06))) +
  scale_fill_manual(values = c(Raw_Reads = "#1f77b4", Mapped_Reads = "#ff7f0e")) +
  labs(x = "Analysis ID", y = "Read count (log10)") +
  theme_publication() +
  theme(
    axis.text.x = element_text(size = 5.0, angle = 90, vjust = 0.5, hjust = 1),
    axis.text.y = element_text(size = 7.5),
    axis.title = element_text(size = 7.5),
    legend.position = c(0.90, 0.30),
    legend.title = element_blank(),
    legend.text = element_text(size = 7.5),
    legend.background = element_rect(fill = "white", color = "black"),
    plot.margin = margin(2, 2, 2, 2)
  )
output_files <- c(output_files, save_panel(pA, "FigureS1A_Barplot_ReadCounts", 180, 50))
source_files <- c(source_files, write_panel_source_data(df_a, "Extended Data Figure 1", "A",
                                                        "Raw and mapped read counts for RNA-seq samples.",
                                                        panel_data_dir, "FigureS1A_read_counts"))

# B. Raw read distribution
pB <- ggplot(raw_reads, aes(x = SampleType, y = Raw_Reads, fill = SampleType)) +
  geom_violin(trim = FALSE, scale = "width") +
  geom_jitter(width = 0.18, size = 0.9, alpha = 0.65) +
  scale_fill_manual(values = group_colors_ext) +
  scale_y_log10(expand = expansion(mult = c(0, 0.06))) +
  labs(x = "Sample type", y = "Raw read count (log10)") +
  theme_publication() +
  theme(axis.text = element_text(size = 7.5), axis.title = element_text(size = 7.5),
        legend.position = "none", plot.margin = margin(2, 2, 2, 2))
output_files <- c(output_files, save_panel(pB, "FigureS1B_ViolinPlot_RawReads", 60, 52))
source_files <- c(source_files, write_panel_source_data(raw_reads, "Extended Data Figure 1", "B",
                                                        "Raw read counts by sample type.",
                                                        panel_data_dir, "FigureS1B_raw_read_values"))

# C. Mapping rate
df_c <- raw_reads %>%
  mutate(Group = str_extract(SampleID, "^(EWE|AWE|ESM|ASM)")) %>%
  filter(!is.na(Group)) %>%
  mutate(Group = factor(Group, levels = c("EWE", "AWE", "ESM", "ASM")))
stats_c <- wilcox_two(df_c, "MappingRate", comparisons = list(c("EWE", "AWE"), c("ESM", "ASM")))
pC <- ggplot(df_c, aes(x = Group, y = MappingRate, fill = Group)) +
  geom_violin(trim = FALSE, alpha = 0.6) +
  geom_boxplot(width = 0.12, outlier.shape = NA, color = "black") +
  geom_jitter(width = 0.1, size = 0.85, alpha = 0.8) +
  ggpubr::stat_compare_means(comparisons = list(c("EWE", "AWE"), c("ESM", "ASM")),
                             method = "wilcox.test", label = "p.signif",
                             step.increase = 0.14, tip.length = 0.02, size = 2.8) +
  scale_fill_manual(values = color_group[c("EWE", "AWE", "ESM", "ASM")]) +
  coord_cartesian(ylim = c(0, 130), clip = "off") +
  labs(x = "Sample type", y = "Mapping rate (%)") +
  theme_publication() +
  theme(axis.text = element_text(size = 7.5), axis.title = element_text(size = 7.5),
        legend.position = "none", plot.margin = margin(4, 3, 2, 2))
output_files <- c(output_files, save_panel(pC, "FigureS1C_MappingRate_PerGroup", 60, 52))
source_files <- c(source_files,
                  write_panel_source_data(df_c, "Extended Data Figure 1", "C_values",
                                          "Mapping rates by sample group.",
                                          panel_data_dir, "FigureS1C_mapping_rate_values"),
                  write_panel_source_data(stats_c, "Extended Data Figure 1", "C_statistics",
                                          "Wilcoxon tests for mapping rates.",
                                          panel_data_dir, "FigureS1C_mapping_rate_statistics"))

# D. Gini coefficient
expr <- readr::read_csv(file.path(paths$human_analysis_dir, "2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv"),
                        show_col_types = FALSE)
expr_mat <- expr %>% column_to_rownames(colnames(expr)[1])
gini <- apply(expr_mat, 2, gini_coefficient)
df_d <- tibble(Sample = names(gini), Gini = as.numeric(gini),
               Group = str_extract(Sample, "^(EWE|AWE|ESM|ASM)")) %>%
  filter(!is.na(Group)) %>%
  mutate(Group = factor(Group, levels = c("EWE", "AWE", "ESM", "ASM")))
stats_d <- wilcox_two(df_d, "Gini", comparisons = list(c("EWE", "AWE"), c("ESM", "ASM")))
pD <- ggplot(df_d, aes(x = Group, y = Gini, fill = Group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA) +
  geom_jitter(width = 0.18, size = 0.9, alpha = 0.8) +
  ggpubr::stat_compare_means(comparisons = list(c("EWE", "AWE"), c("ESM", "ASM")),
                             method = "wilcox.test", label = "p.signif",
                             step.increase = 0.12, tip.length = 0.02, size = 2.8) +
  scale_fill_manual(values = color_group[c("EWE", "AWE", "ESM", "ASM")]) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.18))) +
  coord_cartesian(clip = "off") +
  labs(x = "Sample type", y = "Gini coefficient") +
  theme_publication() +
  theme(axis.text = element_text(size = 7.5), axis.title = element_text(size = 7.5),
        legend.position = "none", plot.margin = margin(5, 5, 2, 2))
output_files <- c(output_files, save_panel(pD, "FigureS1D_GiniCoefficient_withPval", 55, 52))
source_files <- c(source_files,
                  write_panel_source_data(df_d, "Extended Data Figure 1", "D_values",
                                          "Sample-level Gini coefficients.",
                                          panel_data_dir, "FigureS1D_gini_values"),
                  write_panel_source_data(stats_d, "Extended Data Figure 1", "D_statistics",
                                          "Wilcoxon tests for Gini coefficients.",
                                          panel_data_dir, "FigureS1D_gini_statistics"))

# E/F. Subsampling curves
subsampling <- readxl::read_excel(qc_file, sheet = "SubSampling")
plot_subsampling <- function(data, y_col, y_label, title_label, show_legend = FALSE) {
  p <- ggplot(data, aes(x = Reads / 1e6, y = .data[[y_col]], color = Analysis_ID, group = Analysis_ID)) +
    geom_line(linewidth = 0.32, alpha = 0.9) +
    scale_y_log10() +
    labs(x = "# Reads (million)", y = y_label, title = title_label, color = "Sample") +
    theme_publication(base_size = 8) +
    theme(plot.title = element_text(size = 8, face = "bold", hjust = 0.5),
          axis.text = element_text(size = 7.5),
          axis.title = element_text(size = 7.5),
          legend.position = "none",
          legend.title = element_blank(),
          legend.text = element_text(size = 7.5),
          legend.key.size = unit(0.42, "lines"),
          plot.margin = margin(2, 2, 2, 2))
  p
}
pE <- plot_subsampling(subsampling, "Gene_Count_ALL", "Gene count (all, log10)",
                       "Subsampling curve: all genes", FALSE)
pF <- plot_subsampling(subsampling, "Gene_Count_Protein-coding", "Gene count (protein-coding, log10)",
                       "Subsampling curve: protein-coding genes", FALSE)
output_files <- c(output_files, save_panel(pE, "FigureS1E_Subsampling_Gene_Count_ALL_log10", 87, 69))
output_files <- c(output_files, save_panel(pF, "FigureS1F_Subsampling_Gene_Count_ProteinCoding_log10", 87, 69))
source_files <- c(source_files, write_panel_source_data(subsampling, "Extended Data Figure 1", "E_F",
                                                        "Subsampling read-depth curves.",
                                                        panel_data_dir, "FigureS1EF_subsampling_values"))

# G/H. MA and density plots
ma_file <- file.path(paths$human_analysis_dir, "MAplot", "MAplot_ALL.xlsx")
comparisons <- list("EWE vs. AWE" = 1, "ESM vs. ASM" = 2, "AWE vs. ASM" = 3, "EWE vs. ESM" = 4)
ma_df <- purrr::map_dfr(names(comparisons), function(comp_name) {
  readxl::read_xlsx(ma_file, sheet = comparisons[[comp_name]]) %>%
    rename(a.value = 4, m.value = 5, q.value = 7) %>%
    mutate(DEG = case_when(
      q.value < 0.05 & m.value > 0 ~ "Up",
      q.value < 0.05 & m.value < 0 ~ "Down",
      TRUE ~ "non-DEG"
    ),
    DEG = factor(DEG, levels = c("Up", "non-DEG", "Down")),
    Comparison = comp_name)
}) %>%
  mutate(Comparison = factor(Comparison, levels = c("EWE vs. ESM", "AWE vs. ASM", "EWE vs. AWE", "ESM vs. ASM")))
deg_colors <- c("Up" = "#E41A1C", "non-DEG" = "gray70", "Down" = "#377EB8")
pG <- ggplot(ma_df, aes(x = a.value, y = m.value, color = DEG)) +
  geom_point(alpha = 0.55, size = 0.35) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black", linewidth = 0.3) +
  facet_wrap(~Comparison, ncol = 2) +
  scale_color_manual(values = deg_colors, name = NULL) +
  labs(title = "MA plots of pairwise comparisons", x = "Average expression (log2 scale)", y = "log2 fold change") +
  theme_publication() +
  theme(plot.title = element_text(hjust = 0.5, size = 8, face = "bold"),
        legend.position = "none", strip.background = element_blank(),
        strip.text = element_text(size = 7.5, face = "bold"),
        axis.title = element_text(size = 7.5), axis.text = element_text(size = 7.5))
pH <- ggplot(ma_df, aes(x = a.value, fill = DEG)) +
  geom_density(alpha = 0.6) +
  facet_wrap(~Comparison, ncol = 2, scales = "free_x") +
  scale_fill_manual(values = deg_colors, name = NULL) +
  labs(title = "Density plots of average expression", x = "Average expression (log2 scale)", y = "Density") +
  theme_publication() +
  theme(plot.title = element_text(hjust = 0.5, size = 8, face = "bold"),
        axis.title = element_text(size = 7.5), axis.text = element_text(size = 7.5),
        strip.text = element_text(size = 7.5, face = "bold"), strip.background = element_blank(),
        panel.spacing.x = unit(0.50, "cm"),
        legend.position = "bottom", legend.direction = "horizontal",
        legend.title = element_blank(), legend.text = element_text(size = 7.0),
        legend.key.size = unit(0.35, "lines")) +
  guides(fill = guide_legend(nrow = 1, byrow = TRUE))
output_files <- c(output_files, save_panel(pG, "FigureS1G_MAplot_Facet", 90, 90))
output_files <- c(output_files, save_panel(pH, "FigureS1H_DensityPlot_Facet", 90, 90))
source_files <- c(source_files, write_panel_source_data(ma_df, "Extended Data Figure 1", "G_H",
                                                        "Pairwise MA-plot and density-plot values.",
                                                        panel_data_dir, "FigureS1GH_MA_density_values"))

# I. DEG UpSet-like intersection
deg_file <- file.path(paths$human_analysis_dir, "DEG", "DEGlist.xlsx")
comparison_list <- c("AWEvsASM", "ESMvsASM", "EWEvsAWE", "EWEvsESM")
comparison_labels <- c(AWEvsASM = "AWE vs. ASM", ESMvsASM = "ESM vs. ASM",
                       EWEvsAWE = "EWE vs. AWE", EWEvsESM = "EWE vs. ESM")
deg_lists <- setNames(vector("list", length(comparison_list)), comparison_list)
for (comparison in comparison_list) {
  deg_lists[[comparison]] <- readxl::read_excel(deg_file, sheet = comparison) %>%
    filter(q.value < 0.05) %>% pull(gene_id) %>% unique()
}
deg_matrix <- tibble(gene_id = unique(unlist(deg_lists)))
for (comp in names(deg_lists)) {
  deg_matrix[[comparison_labels[[comp]]]] <- deg_matrix$gene_id %in% deg_lists[[comp]]
}
set_cols <- names(deg_matrix)[-1]
intersection_i <- deg_matrix %>%
  unite("pattern", all_of(set_cols), remove = FALSE, sep = "|") %>%
  count(pattern, across(all_of(set_cols)), name = "intersection_size") %>%
  arrange(desc(intersection_size)) %>%
  slice_head(n = 12) %>%
  mutate(pattern = factor(pattern, levels = pattern))
matrix_i <- intersection_i %>%
  select(pattern, all_of(set_cols)) %>%
  pivot_longer(-pattern, names_to = "Comparison", values_to = "present") %>%
  mutate(Comparison = factor(Comparison, levels = rev(set_cols)))
pI_bar <- ggplot(intersection_i, aes(x = pattern, y = intersection_size)) +
  geom_col(width = 0.6, fill = "gray25") +
  geom_text(aes(label = intersection_size), vjust = -0.25, size = 2.8) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(y = "Intersection size", x = NULL) +
  theme_publication() +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
        axis.text.y = element_text(size = 7.5), axis.title.y = element_text(size = 7.5),
        plot.margin = margin(1, 1, 0, 1))
pI_matrix <- ggplot(matrix_i, aes(x = pattern, y = Comparison)) +
  geom_line(aes(group = pattern), color = "gray35", linewidth = 0.25) +
  geom_point(aes(fill = present), shape = 21, size = 1.8, color = "black", stroke = 0.2) +
  scale_fill_manual(values = c("TRUE" = "black", "FALSE" = "white"), guide = "none") +
  labs(x = NULL, y = NULL) +
  theme_publication() +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
        axis.text.y = element_text(size = 7.5),
        plot.margin = margin(0, 1, 1, 1))
pI <- pI_bar / pI_matrix + plot_layout(heights = c(2.1, 1))
output_files <- c(output_files, save_panel(pI, "FigureS1I_UpSetPlot_DEG", 180, 80))
source_files <- c(source_files,
                  write_panel_source_data(deg_matrix, "Extended Data Figure 1", "I_membership",
                                          "Gene-level DEG membership matrix.",
                                          panel_data_dir, "FigureS1I_DEG_membership"),
                  write_panel_source_data(intersection_i, "Extended Data Figure 1", "I_intersections",
                                          "Top DEG intersections plotted in the UpSet-like panel.",
                                          panel_data_dir, "FigureS1I_DEG_intersections"))

write_run_manifest("ExtendedDataFigure1", output_files, source_files, paths$log_dir)
message("Extended Data Figure 1 panels and source data completed.")
