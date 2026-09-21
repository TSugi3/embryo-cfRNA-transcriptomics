# Figure3.R
# Generate Figure 3 and Figure 4 panels with panel-level source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(forcats)
  library(viridis)
  library(ggpubr)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure3.R"
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

output_files <- character()
source_files <- character()

# ============================================================
# Figure 3A - DEG proportions
# ============================================================
ma_file <- file.path(paths$human_analysis_dir, "MAplot", "MAplot_ALL.xlsx")
EWEvsESM <- read_excel(ma_file, sheet = "E_SMvsWE") %>% mutate(Group = "EWE vs. ESM")
AWEvsASM <- read_excel(ma_file, sheet = "A_SMvsWE") %>% mutate(Group = "AWE vs. ASM")
all_data <- bind_rows(EWEvsESM, AWEvsASM)

deg_summary <- all_data %>%
  mutate(DEG_class = case_when(
    q.value < 0.05 & m.value > 0 ~ "Up",
    q.value < 0.05 & m.value < 0 ~ "Down",
    TRUE ~ "non-DEG"
  )) %>%
  group_by(Group, DEG_class) %>%
  summarise(Count = n(), .groups = "drop") %>%
  group_by(Group) %>%
  mutate(Percentage = 100 * Count / sum(Count)) %>%
  ungroup() %>%
  mutate(
    DEG_class = factor(DEG_class, levels = c("Up", "non-DEG", "Down")),
    Group = factor(Group, levels = c("EWE vs. ESM", "AWE vs. ASM"))
  )

pA <- ggplot(deg_summary, aes(x = Group, y = Percentage, fill = DEG_class)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = c("Up" = "#E41A1C", "non-DEG" = "gray70", "Down" = "#377EB8"),
                    breaks = c("Up", "non-DEG", "Down")) +
  labs(x = NULL, y = "Proportion (%)", fill = "Expression change") +
  coord_flip() +
  theme_publication() +
  theme(
    axis.text.y = element_text(size = 7.5),
    axis.text.x = element_text(size = 7.5),
    legend.position = "right",
    legend.title = element_text(size = 7.5),
    legend.text = element_text(size = 7.5),
    plot.margin = margin(2, 2, 2, 2)
  )

output_files <- c(output_files, save_panel(pA, "Figure3A_DEG_Proportion", 180, 30))
source_files <- c(source_files, write_panel_source_data(
  deg_summary, "Figure 3", "A",
  "Proportions of upregulated, downregulated and non-DEG genes.",
  panel_data_dir, "Figure3A_DEG_proportions"
))

# ============================================================
# Figure 3B/C - GO BP terms for up/downregulated genes
# ============================================================

make_go_dotplot <- function(files, title, output_name, panel_id, n_terms = 10) {
  combined <- imap_dfr(files, function(file, comparison) {
    read_csv(file, show_col_types = FALSE) %>%
      mutate(Comparison = comparison) %>%
      arrange(qvalue) %>%
      slice_head(n = n_terms)
  }) %>%
    mutate(
      qvalue = if_else(qvalue == 0, .Machine$double.xmin, qvalue),
      minus_log10_qvalue = -log10(qvalue),
      Comparison = factor(Comparison, levels = names(files)),
      Description_wrapped = Description,
      Description_full = paste(Description_wrapped, Comparison, sep = "___")
    ) %>%
    group_by(Comparison) %>%
    mutate(Description_full = factor(Description_full, levels = rev(unique(Description_full)))) %>%
    ungroup()

  p <- ggplot(combined, aes(x = minus_log10_qvalue, y = Description_full)) +
    geom_point(aes(size = Count, color = minus_log10_qvalue), alpha = 0.95) +
    scale_color_viridis_c(option = "D", name = expression(-log[10]~"(q-value)")) +
    scale_size(range = c(0.8, 3.3), name = "Gene count") +
    scale_x_continuous(expand = expansion(mult = c(0.04, 0.10))) +
    scale_y_discrete(labels = function(x) gsub("___.*", "", x)) +
    facet_grid(rows = vars(Comparison), scales = "free_y", space = "free_y", switch = "y") +
    labs(x = expression(-log[10]~"(q-value)"), y = NULL, title = title) +
    theme_publication() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 8.5),
      strip.text.y.left = element_text(angle = 90, size = 7.5),
      axis.text.y = element_text(size = 7.5, lineheight = 0.88),
      axis.text.x = element_text(size = 7.5),
      axis.title.x = element_text(size = 7.5),
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.direction = "horizontal",
      legend.title = element_text(size = 7.5),
      legend.text = element_text(size = 7.5),
      legend.key.height = unit(0.20, "cm"),
      legend.key.width = unit(0.34, "cm"),
      legend.spacing.x = unit(0.12, "cm"),
      plot.margin = margin(1, 2, 1, 5)
    ) +
    guides(
      color = guide_colorbar(
        order = 1, direction = "horizontal",
        barwidth = unit(22, "mm"), barheight = unit(2.0, "mm"),
        title.position = "top"
      ),
      size = guide_legend(order = 2, nrow = 1, title.position = "top")
    )

  output <- save_panel(p, output_name, 180, 82)
  source <- write_panel_source_data(
    combined %>% arrange(Comparison, qvalue),
    "Figure 3", panel_id,
    paste0("GO biological process terms plotted for ", title, "."),
    panel_data_dir, paste0(output_name, "_terms")
  )
  list(output = output, source = source)
}

up_files <- c(
  "EWE vs. ESM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_UpOnly", "GO_BP", "GO_BP_EWEvsESM.csv"),
  "AWE vs. ASM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_UpOnly", "GO_BP", "GO_BP_AWEvsASM.csv")
)
down_files <- c(
  "EWE vs. ESM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_DownOnly", "GO_BP", "GO_BP_EWEvsESM.csv"),
  "AWE vs. ASM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_DownOnly", "GO_BP", "GO_BP_AWEvsASM.csv")
)

resB <- make_go_dotplot(up_files, "Top GO:BP terms enriched in upregulated genes",
                        "Figure3B_GO_BP_UpregulatedOnly", "B", n_terms = 10)
resC <- make_go_dotplot(down_files, "Top GO:BP terms enriched in downregulated genes",
                        "Figure3C_GO_BP_DownregulatedOnly", "C", n_terms = 10)
output_files <- c(output_files, resB$output, resC$output)
source_files <- c(source_files, resB$source, resC$source)

# ============================================================
# Final Figure 4A - GSEA GO BP dotplot
# ============================================================
gsea <- read_csv(file.path(paths$human_analysis_dir, "DEG", "GSEA", "AWEvsASM", "GSEA_GO_BP.csv"),
                 show_col_types = FALSE)
gsea_plot <- gsea %>%
  arrange(desc(abs(NES))) %>%
  slice_head(n = 20) %>%
  mutate(
    Description_wrapped = Description,
    Description_wrapped = fct_reorder(Description_wrapped, NES),
    minus_log10_FDR = -log10(p.adjust)
  )

pD <- ggplot(gsea_plot, aes(x = NES, y = Description_wrapped)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.3) +
  geom_point(aes(size = setSize), color = "#2A9D8F", alpha = 0.95) +
  scale_size_continuous(name = "Gene set size", range = c(1, 4)) +
  labs(title = "GO:BP GSEA of AWE vs. ASM", x = "NES", y = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8.5),
    axis.text.y = element_text(size = 7.5, lineheight = 0.92),
    axis.text.x = element_text(size = 7.5),
    axis.title.x = element_text(size = 7.5),
    legend.position = "bottom",
    legend.title = element_text(size = 7.5),
    legend.text = element_text(size = 7.5),
    legend.key.size = unit(0.18, "cm"),
    plot.margin = margin(2, 2, 2, 8)
  ) +
  guides(size = guide_legend(nrow = 1, title.position = "top"))

output_files <- c(output_files, save_panel(pD, "Figure4A_GSEA_GO_BP_dotplot", 180, 113))
source_files <- c(source_files, write_panel_source_data(
  gsea_plot %>% arrange(desc(abs(NES))),
  "Figure 4", "A",
  "GO biological process GSEA terms. Points encode gene set size.",
  panel_data_dir, "Figure4A_GSEA_GO_BP_terms"
))

# ============================================================
# Final Figure 4B - NMD/apoptosis gene expression
# ============================================================
expr <- read_csv(file.path(paths$human_analysis_dir, "2024-06-03_tmm_edger_3_0.1_0.05_TCC_Normalized.csv"),
                 show_col_types = FALSE)
NMD_genes <- c("UPF1", "SMG1", "SMG7", "EIF4A3", "RBM8A", "CASC3")
Apoptosis_genes <- c("TP53", "BAX", "CASP3", "AURKA", "BUB1", "PLK1")

expr_long <- expr %>%
  filter(gene_id %in% c(NMD_genes, Apoptosis_genes)) %>%
  pivot_longer(-gene_id, names_to = "Sample", values_to = "Expression") %>%
  mutate(
    Group = case_when(str_detect(Sample, "^EWE") ~ "EWE",
                      str_detect(Sample, "^AWE") ~ "AWE",
                      TRUE ~ NA_character_),
    Category = case_when(gene_id %in% NMD_genes ~ "NMD",
                         gene_id %in% Apoptosis_genes ~ "Apoptosis")
  ) %>%
  filter(!is.na(Group)) %>%
  mutate(
    gene_id = factor(gene_id, levels = c(NMD_genes, Apoptosis_genes)),
    Group = factor(Group, levels = c("EWE", "AWE"))
  )

stats_e <- expr_long %>%
  group_by(gene_id, Category) %>%
  group_modify(~ {
    wt <- wilcox.test(Expression ~ Group, data = .x)
    tibble(test = "Wilcoxon rank-sum test",
           p_value = wt$p.value,
           statistic = unname(wt$statistic),
           n_EWE = sum(.x$Group == "EWE"),
           n_AWE = sum(.x$Group == "AWE"))
  }) %>%
  ungroup()

gene_lab <- setNames(paste0("italic('", c(NMD_genes, Apoptosis_genes), "')"),
                     c(NMD_genes, Apoptosis_genes))

pE <- ggplot(expr_long, aes(x = Group, y = Expression, fill = Group)) +
  geom_boxplot(outlier.shape = NA, width = 0.6, alpha = 0.8) +
  geom_jitter(width = 0.2, size = 0.55, alpha = 0.8) +
  stat_compare_means(method = "wilcox.test", comparisons = list(c("EWE", "AWE")),
                     label = "p.format", size = 2.8) +
  facet_wrap(~gene_id, scales = "free_y", nrow = 2,
             labeller = labeller(gene_id = as_labeller(gene_lab, label_parsed))) +
  scale_y_continuous(expand = expansion(mult = c(0.04, 0.18))) +
  scale_fill_manual(values = c("EWE" = "#00BFC4", "AWE" = "#F8766D")) +
  labs(title = "Expression of NMD and apoptosis-associated genes",
       y = "Expression (TMM-normalized)", x = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8.5),
    strip.text = element_text(size = 7.5, face = "italic"),
    strip.background = element_blank(),
    panel.spacing = unit(1.2, "mm"),
    axis.text = element_text(size = 7.5),
    axis.title.y = element_text(size = 7.5),
    legend.position = "none",
    panel.border = element_blank(),
    axis.line.x = element_line(colour = "black", linewidth = 0.3),
    axis.line.y = element_line(colour = "black", linewidth = 0.3),
    plot.margin = margin(2, 2, 2, 2)
  )

output_files <- c(output_files, save_panel(pE, "Figure4B_Expression_NMD_Apoptosis", 180, 65))
source_files <- c(
  source_files,
  write_panel_source_data(expr_long, "Figure 4", "B_values",
                          "Sample-level expression values for NMD and apoptosis-associated genes.",
                          panel_data_dir, "Figure4B_NMD_Apoptosis_values"),
  write_panel_source_data(stats_e, "Figure 4", "B_statistics",
                          "Wilcoxon rank-sum tests comparing EWE and AWE for each gene.",
                          panel_data_dir, "Figure4B_NMD_Apoptosis_statistics")
)

write_run_manifest("Figure3", output_files, source_files, paths$log_dir)
message("Figure3 panels and source data completed.")
