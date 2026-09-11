# Figure1.R
# Generate Figure 1 panels B-G and panel-level source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(ggpubr)
  library(entropy)
  library(ggrepel)
  library(viridis)
  library(hexbin)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure1.R"
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
                  units = "mm", device = cairo_pdf)
  ggplot2::ggsave(png_file, plot = plot, width = width_mm, height = height_mm,
                  units = "mm", dpi = dpi)
  ggplot2::ggsave(tiff_file, plot = plot, width = width_mm, height = height_mm,
                  units = "mm", dpi = dpi, compression = "lzw", type = "cairo")
  c(pdf = pdf_file, png = png_file, tiff = tiff_file)
}

source_files <- character()
output_files <- character()

# ============================================================
# Figure 1B - Insert Size Distribution
# ============================================================
insert_data <- read_excel(file.path(paths$human_analysis_dir, "InsertLength", "InsertLengthWESM.xlsx"))
names(insert_data) <- gsub(" ", "", names(insert_data))

insert_long <- insert_data %>%
  select(InsertLength, RelativeWholeEmbryo, RelativeSpentMedia) %>%
  pivot_longer(
    cols = c(RelativeWholeEmbryo, RelativeSpentMedia),
    names_to = "SampleType",
    values_to = "RelativeFrequency"
  ) %>%
  mutate(SampleType = recode(
    SampleType,
    "RelativeWholeEmbryo" = "Whole Embryo",
    "RelativeSpentMedia" = "Spent Media"
  ))

ks_test <- ks.test(insert_data$RelativeWholeEmbryo, insert_data$RelativeSpentMedia)
ks_df <- tibble(
  test = "Kolmogorov-Smirnov test",
  statistic_D = unname(ks_test$statistic),
  p_value = ks_test$p.value,
  method = ks_test$method
)
ks_result <- paste0("KS Test: D = ", round(ks_test$statistic, 5),
                    ", p = ", format(ks_test$p.value, scientific = TRUE))

pB <- ggplot(insert_long, aes(x = InsertLength, y = RelativeFrequency,
                              fill = SampleType, color = SampleType)) +
  geom_area(alpha = 0.5, position = "identity") +
  geom_line(size = 0.4, alpha = 0.9) +
  scale_fill_manual(values = c("Whole Embryo" = "#F8766D", "Spent Media" = "#00BFC4")) +
  scale_color_manual(values = c("Whole Embryo" = "#F8766D", "Spent Media" = "#00BFC4")) +
  scale_x_continuous(breaks = seq(0, max(insert_data$InsertLength, na.rm = TRUE), by = 100)) +
  labs(x = "Insert Size (bp)", y = "Relative Read Fraction") +
  annotate("text", x = Inf, y = Inf, label = ks_result,
           hjust = 1, vjust = 1, size = 2.3, color = "black") +
  theme_publication() +
  theme(
    legend.position = c(0.7, 0.7),
    legend.background = element_rect(fill = "transparent"),
    legend.key = element_rect(fill = "transparent"),
    legend.title = element_blank(),
    legend.text = element_text(size = 6),
    plot.title = element_blank()
  )

output_files <- c(output_files, save_panel(pB, "Figure1B_InsertLength", 58, 60))
source_files <- c(
  source_files,
  write_panel_source_data(insert_long, "Figure 1", "B_values",
                          "Insert-size distribution values plotted for whole-embryo and spent-medium libraries.",
                          panel_data_dir, "Figure1B_InsertLength_values"),
  write_panel_source_data(ks_df, "Figure 1", "B_statistics",
                          "Kolmogorov-Smirnov test comparing insert-size distributions.",
                          panel_data_dir, "Figure1B_InsertLength_statistics")
)

# ============================================================
# Figure 1C - Biotype Composition
# ============================================================
biotype_df <- read_excel(file.path(paths$human_analysis_dir, "biotype", "biotype_all.xlsx"),
                         sheet = "biotype_AnalysisID")

biotype_levels <- c(
  "protein_coding", "lncRNA", "miRNA", "snoRNA", "snRNA",
  "misc_RNA", "rRNA", "tRNA", "other"
)
biotype_colors <- c(
  "protein_coding" = "#377EB8",
  "lncRNA" = "#4DAF4A",
  "miRNA" = "#E41A1C",
  "snoRNA" = "#FF7F00",
  "snRNA" = "#F781BF",
  "misc_RNA" = "#A65628",
  "rRNA" = "#999999",
  "tRNA" = "#D9D9D9",
  "other" = "#CCCCCC"
)

biotype_long <- biotype_df %>%
  pivot_longer(-1, names_to = "Sample", values_to = "Count") %>%
  rename(Biotype = 1) %>%
  mutate(Group = if_else(str_detect(Sample, "^(EWE|AWE)"), "WE", "SM")) %>%
  group_by(Sample) %>%
  mutate(Total = sum(Count), Proportion = Count / Total * 100) %>%
  ungroup()

biotype_summary <- biotype_long %>%
  mutate(Biotype = if_else(Biotype %in% biotype_levels, Biotype, "other")) %>%
  group_by(Group, Biotype) %>%
  summarise(MeanProportion = mean(Proportion, na.rm = TRUE), .groups = "drop") %>%
  group_by(Group) %>%
  mutate(MeanProportion = MeanProportion / sum(MeanProportion) * 100) %>%
  ungroup() %>%
  mutate(Group = factor(Group, levels = c("WE", "SM")),
         Biotype = factor(Biotype, levels = biotype_levels))

pC <- ggplot(biotype_summary, aes(x = Group, y = MeanProportion, fill = Biotype)) +
  geom_bar(stat = "identity", width = 0.8) +
  scale_fill_manual(values = biotype_colors) +
  labs(x = "Sample type", y = "Percentage") +
  theme_publication() +
  theme(
    legend.position = "right",
    legend.title = element_blank(),
    legend.text = element_text(size = 6),
    plot.title = element_blank()
  )

output_files <- c(output_files, save_panel(pC, "Figure1C_Biotype_Comparison", 60, 60))
source_files <- c(
  source_files,
  write_panel_source_data(biotype_summary, "Figure 1", "C",
                          "Mean biotype proportions plotted for whole-embryo and spent-medium samples.",
                          panel_data_dir, "Figure1C_Biotype_summary")
)

# ============================================================
# Shared expression matrix for Figure 1D-G
# ============================================================
expr_mat <- read_csv(file.path(paths$human_analysis_dir, "2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv"),
                     show_col_types = FALSE)
expr <- column_to_rownames(expr_mat, var = colnames(expr_mat)[1])

group_colors <- c(
  "EWE" = "#009EBD",
  "AWE" = "#F8766D",
  "ESM" = "#619CFF",
  "ASM" = "#C77CFF"
)

# ============================================================
# Figure 1D - Non-zero Gene Count
# ============================================================
nonzero_counts <- apply(expr, 2, function(x) sum(x > 0))
gene_count_df <- tibble(
  Sample = names(nonzero_counts),
  Count = as.numeric(nonzero_counts),
  Group = str_extract(names(nonzero_counts), "^(EWE|AWE|ESM|ASM)")
) %>%
  mutate(Group = factor(Group, levels = c("EWE", "AWE", "ESM", "ASM")))

comparisons_d <- list(c("EWE", "AWE"), c("ESM", "ASM"), c("EWE", "ESM"), c("AWE", "ASM"))
stats_d <- purrr::map_dfr(comparisons_d, function(comp) {
  df_use <- gene_count_df %>% filter(Group %in% comp)
  wt <- wilcox.test(Count ~ Group, data = df_use)
  tibble(group1 = comp[1], group2 = comp[2], test = "Wilcoxon rank-sum test",
         p_value = wt$p.value, statistic = unname(wt$statistic),
         n_group1 = sum(df_use$Group == comp[1]), n_group2 = sum(df_use$Group == comp[2]))
})

pD <- ggplot(gene_count_df, aes(x = Group, y = Count, fill = Group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, alpha = 0.9) +
  geom_jitter(width = 0.2, size = 0.5, alpha = 0.8) +
  scale_fill_manual(values = group_colors) +
  stat_compare_means(comparisons = comparisons_d, method = "wilcox.test",
                     label = "p.signif", size = 2.5, tip.length = 0.01) +
  labs(x = NULL, y = "Number of Genes") +
  theme_publication() +
  theme(legend.position = "none", plot.title = element_blank())

output_files <- c(output_files, save_panel(pD, "Figure1D_GeneCount", 60, 60))
source_files <- c(
  source_files,
  write_panel_source_data(gene_count_df, "Figure 1", "D_values",
                          "Number of detected genes per sample.",
                          panel_data_dir, "Figure1D_GeneCount_values"),
  write_panel_source_data(stats_d, "Figure 1", "D_statistics",
                          "Wilcoxon rank-sum tests for detected gene counts.",
                          panel_data_dir, "Figure1D_GeneCount_statistics")
)

# ============================================================
# Figure 1E - Shannon Entropy
# ============================================================
shannon <- apply(expr, 2, function(x) {
  px <- x / sum(x)
  entropy.empirical(px, unit = "log2")
})
shannon_df <- tibble(
  Sample = names(shannon),
  Shannon = as.numeric(shannon),
  Group = str_extract(names(shannon), "^(EWE|AWE|ESM|ASM)")
) %>%
  mutate(Group = factor(Group, levels = c("EWE", "AWE", "ESM", "ASM")))

comparisons_e <- list(c("EWE", "AWE"), c("ESM", "ASM"))
stats_e <- purrr::map_dfr(comparisons_e, function(comp) {
  df_use <- shannon_df %>% filter(Group %in% comp)
  wt <- wilcox.test(Shannon ~ Group, data = df_use)
  tibble(group1 = comp[1], group2 = comp[2], test = "Wilcoxon rank-sum test",
         p_value = wt$p.value, statistic = unname(wt$statistic),
         n_group1 = sum(df_use$Group == comp[1]), n_group2 = sum(df_use$Group == comp[2]))
})

pE <- ggplot(shannon_df, aes(x = Group, y = Shannon, fill = Group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, alpha = 0.9) +
  geom_jitter(width = 0.2, size = 0.5, alpha = 0.8) +
  scale_fill_manual(values = group_colors) +
  stat_compare_means(comparisons = comparisons_e, method = "wilcox.test",
                     label = "p.signif", size = 2.5) +
  labs(x = NULL, y = "Shannon Entropy") +
  theme_publication() +
  theme(legend.position = "none", plot.title = element_blank())

output_files <- c(output_files, save_panel(pE, "Figure1E_ShannonEntropy", 60, 60))
source_files <- c(
  source_files,
  write_panel_source_data(shannon_df, "Figure 1", "E_values",
                          "Shannon entropy values per sample.",
                          panel_data_dir, "Figure1E_ShannonEntropy_values"),
  write_panel_source_data(stats_e, "Figure 1", "E_statistics",
                          "Wilcoxon rank-sum tests for Shannon entropy.",
                          panel_data_dir, "Figure1E_ShannonEntropy_statistics")
)

# ============================================================
# Figure 1F - PCA
# ============================================================
expr_t <- t(expr)
expr_t <- expr_t[, apply(expr_t, 2, function(x) var(x, na.rm = TRUE) > 0)]
pca <- prcomp(expr_t, scale. = TRUE)
pca_df <- as.data.frame(pca$x[, 1:2]) %>%
  rownames_to_column("Sample") %>%
  mutate(
    Group = str_extract(Sample, "^(EWE|AWE|ESM|ASM)"),
    Group = factor(Group, levels = c("EWE", "AWE", "ESM", "ASM"))
  )
var_explained <- summary(pca)$importance[2, 1:2]
x_label <- paste0("PC1 (", round(var_explained[1] * 100, 1), "%)")
y_label <- paste0("PC2 (", round(var_explained[2] * 100, 1), "%)")

pF <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Group)) +
  geom_point(size = 1, alpha = 0.9) +
  scale_color_manual(values = group_colors, name = "Group") +
  labs(x = x_label, y = y_label) +
  theme_publication() +
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    legend.box = "horizontal",
    legend.title = element_blank(),
    legend.text = element_text(size = 8),
    plot.title = element_blank()
  )

output_files <- c(output_files, save_panel(pF, "Figure1F_PCA", 70, 60))
source_files <- c(
  source_files,
  write_panel_source_data(
    pca_df %>% mutate(PC1_percent_variance = var_explained[1] * 100,
                      PC2_percent_variance = var_explained[2] * 100),
    "Figure 1", "F",
    "PCA coordinates and variance explained for RNA-seq samples.",
    panel_data_dir, "Figure1F_PCA_coordinates"
  )
)

# ============================================================
# Figure 1G - Hexbin plot
# ============================================================
expr_data <- expr_mat
colnames(expr_data)[1] <- "Gene"
EWE_samples <- grep("^EWE", colnames(expr_data), value = TRUE)
ESM_samples <- grep("^ESM", colnames(expr_data), value = TRUE)
AWE_samples <- grep("^AWE", colnames(expr_data), value = TRUE)
ASM_samples <- grep("^ASM", colnames(expr_data), value = TRUE)

ewe_esm <- expr_data %>%
  mutate(
    WE_mean = log10(rowMeans(select(., all_of(EWE_samples))) + 1),
    SM_mean = log10(rowMeans(select(., all_of(ESM_samples))) + 1),
    Comparison = "EWE vs. ESM"
  ) %>%
  select(Gene, WE_mean, SM_mean, Comparison)

awe_asm <- expr_data %>%
  mutate(
    WE_mean = log10(rowMeans(select(., all_of(AWE_samples))) + 1),
    SM_mean = log10(rowMeans(select(., all_of(ASM_samples))) + 1),
    Comparison = "AWE vs. ASM"
  ) %>%
  select(Gene, WE_mean, SM_mean, Comparison)

hex_data <- bind_rows(ewe_esm, awe_asm) %>%
  mutate(Comparison = factor(Comparison, levels = c("EWE vs. ESM", "AWE vs. ASM")))

cor_results <- hex_data %>%
  group_by(Comparison) %>%
  summarise(
    r = cor(WE_mean, SM_mean, method = "pearson"),
    x_pos = 0.2,
    y_pos = 3.7,
    .groups = "drop"
  )

pG <- ggplot(hex_data, aes(x = WE_mean, y = SM_mean)) +
  stat_binhex(bins = 50) +
  scale_fill_viridis(option = "D", name = "Gene Count", limits = c(0, 500), oob = scales::squish) +
  facet_wrap(~Comparison, ncol = 2, scales = "fixed") +
  geom_text(
    data = cor_results,
    aes(x = x_pos, y = y_pos, label = paste0("r = ", round(r, 3))),
    inherit.aes = FALSE,
    hjust = 0, vjust = 1.2, size = 3
  ) +
  labs(
    x = "Whole Embryo Mean Expression (log10 scale)",
    y = "Spent Media Mean Expression (log10 scale)"
  ) +
  theme_publication() +
  theme(
    legend.position = "right",
    strip.background = element_blank(),
    strip.text = element_text(size = 9, face = "bold"),
    plot.title = element_blank()
  )

output_files <- c(output_files, save_panel(pG, "Figure1G_HexbinPlot", 110, 60))
source_files <- c(
  source_files,
  write_panel_source_data(hex_data, "Figure 1", "G_values",
                          "Gene-level mean expression values used for the hexbin plots.",
                          panel_data_dir, "Figure1G_Hexbin_values"),
  write_panel_source_data(cor_results, "Figure 1", "G_statistics",
                          "Pearson correlation coefficients for Figure 1G.",
                          panel_data_dir, "Figure1G_Hexbin_statistics")
)

write_run_manifest("Figure1", output_files, source_files, paths$log_dir)
message("Figure1 panels B-G completed.")
message("Output directory: ", fig_dir)
