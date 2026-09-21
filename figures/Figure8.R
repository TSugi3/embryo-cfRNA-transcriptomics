# ============================================================
# Figure8.R
# Figure 8 mouse perturbation analysis
#
# A: CQ GSEA dotplot
# B: CQ-responsive WE gene boxplots, log10(count + 1)
# C: CQ SM cfRNA release-associated barplot
# D: CB GSEA dotplot
# ============================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(patchwork)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure8.R"
script_dir <- dirname(normalizePath(this_file, mustWork = FALSE))
script_root <- normalizePath(file.path(script_dir, ".."), mustWork = FALSE)

source(file.path(script_root, "R", "load_config.R"))
source(file.path(script_root, "R", "figure_theme.R"))
source(file.path(script_root, "R", "source_data_helpers.R"))

base_dir <- paths$mouse_analysis_dir
fig_dir <- paths$figure_dir
table_dir <- paths$source_data_dir
aux_table_dir <- file.path(paths$log_dir, "Figure8_aux_tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(aux_table_dir, recursive = TRUE, showWarnings = FALSE)

gsea_file <- file.path(
  base_dir,
  "GSEA_Result",
  "Autophagy_Related_Terms",
  "Autophagy_related_terms_all_comparisons.csv"
)

cq_norm_file <- file.path(base_dir, "CQ_tmm_edger_3_0.1_0.05_TCC_Normalized.csv")
annot_file <- file.path(base_dir, "merged_featureCounts_allgene.xlsx")

exclude_samples <- c("SMCT06", "SMCQ06", "WECB04")

selected_terms <- tibble::tribble(
  ~Description, ~Category,
  "regulation of autophagy", "Autophagy",
  "macroautophagy", "Autophagy",
  "regulation of macroautophagy", "Autophagy",
  "positive regulation of autophagy", "Autophagy",
  "vacuole organization", "Lysosome / Endosome",
  "lysosomal transport", "Lysosome / Endosome",
  "endosomal transport", "Lysosome / Endosome",
  "retrograde transport, endosome to Golgi", "Lysosome / Endosome",
  "vesicle organization", "Vesicle / Secretion",
  "Golgi vesicle transport", "Vesicle / Secretion",
  "secretion", "Vesicle / Secretion",
  "positive regulation of secretion", "Vesicle / Secretion"
)

release_terms <- c(
  "vesicle organization",
  "Golgi vesicle transport",
  "secretion",
  "positive regulation of secretion"
)

comparison_map <- tibble::tribble(
  ~comparison, ~experiment, ~sample_type,
  "WECQ_vs_WECT", "CQ", "WE",
  "SMCQ_vs_SMCT", "CQ", "SM cfRNA",
  "WECB_vs_WEDS", "CB", "WE",
  "SMCB_vs_SMDS", "CB", "SM cfRNA"
)

# Main Figure B: selected genes
final_genes_for_panelB <- c(
  "Gabarapl2",
  "Map1lc3b",
  "Sqstm1",
  "Lamp1",
  "Rab11a",
  "Cd63"
)

make_gene_labeller <- function(genes) {
  labels <- setNames(paste0("italic(", genes, ")"), genes)
  labeller(gene_symbol = as_labeller(labels, label_parsed))
}

# Candidate screening list, saved separately
candidate_genes <- c(
  "Atg3", "Atg5", "Atg7", "Atg10", "Atg12", "Atg16l1",
  "Becn1", "Ulk1", "Map1lc3a", "Map1lc3b",
  "Gabarapl1", "Gabarapl2", "Sqstm1", "Nbr1",
  "Lamp1", "Lamp2", "Ctsb", "Ctsd", "Ctsl", "Tfeb", "Tfe3",
  "Rab5a", "Rab7", "Rab11a", "Rab27a", "Rab27b",
  "Vps4a", "Vps4b", "Vps35", "Chmp4b",
  "Cd63", "Cd81", "Tsg101", "Pdcd6ip",
  "Sdc1", "Sdc4", "Sdcbp", "Smpd3"
)

theme_fig <- function(base_size = 8.5) {
  theme_bw(base_size = base_size, base_family = "Arial") %+replace%
    theme(
      panel.background = element_blank(),
      panel.border = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(color = "black", linewidth = 0.3),
      axis.ticks = element_line(color = "black", linewidth = 0.3),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = max(7.5, base_size * 0.9), color = "black"),
      plot.title = element_text(face = "bold", size = base_size + 0.8, hjust = 0),
      plot.subtitle = element_text(size = max(7.5, base_size * 0.9), hjust = 0),
      axis.text.x = element_text(face = "bold"),
      strip.background = element_rect(fill = "grey92", color = "grey70", linewidth = 0.25),
      strip.text = element_text(face = "bold", size = max(7.5, base_size * 0.85)),
      strip.text.y = element_text(angle = 0, face = "bold"),
      legend.title = element_text(size = max(7.5, base_size * 0.85)),
      legend.text = element_text(size = max(7.5, base_size * 0.8)),
      legend.key = element_blank(),
      legend.spacing = unit(0.1, "cm"),
      legend.key.size = unit(0.15, "cm"),
      plot.margin = margin(2, 2, 2, 2)
    )
}

# ============================================================
# GSEA data
# ============================================================
gsea_df <- read.csv(gsea_file, stringsAsFactors = FALSE, check.names = FALSE)

plot_df <- gsea_df %>%
  inner_join(selected_terms, by = "Description") %>%
  inner_join(comparison_map, by = "comparison") %>%
  mutate(
    term_label = str_wrap(str_to_sentence(Description), width = 30),
    term_label = factor(term_label, levels = rev(str_wrap(str_to_sentence(selected_terms$Description), width = 30))),
    Category = factor(Category, levels = c("Autophagy", "Lysosome / Endosome", "Vesicle / Secretion")),
    experiment = factor(experiment, levels = c("CQ", "CB")),
    sample_type = factor(sample_type, levels = c("WE", "SM cfRNA")),
    neglogFDR = -log10(p.adjust),
    significance = ifelse(p.adjust < 0.05, "FDR < 0.05", "trend / n.s.")
  )

write.csv(plot_df, file.path(aux_table_dir, "Figure8_GSEA_selected_terms.csv"), row.names = FALSE)

make_gsea_dotplot <- function(df, exp_name, title_text, subtitle_text) {
  df_use <- df %>% filter(experiment == exp_name)

  ggplot(df_use, aes(x = sample_type, y = term_label)) +
    geom_point(
      aes(color = NES, size = neglogFDR, shape = significance),
      alpha = 0.95,
      stroke = 0.45
    ) +
    facet_grid(
      Category ~ ., scales = "free_y", space = "free_y",
      labeller = labeller(Category = c(
        "Autophagy" = "Autophagy",
        "Lysosome / Endosome" = "Endolysosome",
        "Vesicle / Secretion" = "Vesicle"
      ))
    ) +
    scale_color_gradient2(
      low = "#2166AC",
      mid = "white",
      high = "#F8766D",
      midpoint = 0,
      name = "NES"
    ) +
    scale_size_continuous(range = c(0.9, 3.4), name = "-log10(FDR)") +
    scale_shape_manual(
      values = c("FDR < 0.05" = 16, "trend / n.s." = 1),
      name = "Significance"
    ) +
    labs(title = title_text, subtitle = subtitle_text, x = NULL, y = NULL) +
    theme_fig(base_size = 8.5) +
    theme(
      axis.text.y = element_text(size = 7.5, lineheight = 0.92),
      axis.text.x = element_text(size = 7.5, face = "bold"),
      strip.text.y = element_text(size = 7.0, angle = 90, face = "bold"),
      legend.position = "right",
      legend.title = element_text(size = 7.0),
      legend.text = element_text(size = 7.0),
      plot.margin = margin(2, 3, 2, 2)
    ) +
    guides(
      color = guide_colorbar(barheight = unit(1.15, "cm"), barwidth = unit(0.16, "cm")),
      size = guide_legend(override.aes = list(color = "black")),
      shape = guide_legend(override.aes = list(size = 2))
    )
}

make_sm_release_barplot <- function(df, exp_name, title_text, subtitle_text, fill_color) {
  df_use <- df %>%
    filter(experiment == exp_name, sample_type == "SM cfRNA", Description %in% release_terms) %>%
    mutate(
      term_label = factor(
        str_wrap(str_to_sentence(Description), width = 30),
        levels = rev(str_wrap(str_to_sentence(release_terms), width = 30))
      )
    )

  write.csv(
    df_use,
    file.path(aux_table_dir, paste0("Figure8_", exp_name, "_SM_release_terms.csv")),
    row.names = FALSE
  )

  ggplot(df_use, aes(x = NES, y = term_label)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey45", linewidth = 0.35) +
    geom_col(fill = fill_color, color = "black", width = 0.65, alpha = 0.9) +
    geom_point(aes(size = neglogFDR, shape = significance), color = "black", alpha = 0.9) +
    scale_size_continuous(range = c(1.0, 3.4), name = "-log10(FDR)") +
    scale_shape_manual(
      values = c("FDR < 0.05" = 16, "trend / n.s." = 1),
      name = "Significance"
    ) +
    labs(title = title_text, subtitle = subtitle_text, x = "NES in SM cfRNA", y = NULL) +
    theme_fig(base_size = 8.5) +
    theme(
      axis.text.y = element_text(size = 7.5, lineheight = 0.92),
      legend.position = "right"
    )
}

# ============================================================
# Annotation
# ============================================================
read_gene_map <- function(xlsx_file) {
  sheets <- excel_sheets(xlsx_file)

  for (sh in sheets) {
    tmp <- read_excel(xlsx_file, sheet = sh)
    tmp <- as.data.frame(tmp, check.names = FALSE)

    cn <- colnames(tmp)
    cn_lower <- tolower(cn)

    geneid_idx <- which(cn_lower %in% c("geneid", "gene_id", "gene.id"))
    symbol_idx <- which(cn_lower %in% c(
      "gene_name", "genename", "gene symbol",
      "symbol", "external_gene_name", "gene_symbol"
    ))

    if (length(geneid_idx) >= 1 && length(symbol_idx) >= 1) {
      message("Using annotation sheet: ", sh)

      return(
        tmp %>%
          transmute(
            Geneid_original = as.character(.data[[cn[geneid_idx[1]]]]),
            Geneid_clean = sub("\\..*$", "", Geneid_original),
            gene_symbol = as.character(.data[[cn[symbol_idx[1]]]])
          ) %>%
          filter(!is.na(Geneid_clean), Geneid_clean != "",
                 !is.na(gene_symbol), gene_symbol != "") %>%
          distinct(Geneid_clean, gene_symbol, .keep_all = TRUE)
      )
    }
  }

  stop("No annotation sheet containing Geneid and gene_name / gene_symbol columns was found.")
}

gene_map <- read_gene_map(annot_file)

# ============================================================
# CQ WE candidate genes
# ============================================================
cq_norm <- read.csv(cq_norm_file, stringsAsFactors = FALSE, check.names = FALSE)
colnames(cq_norm)[1] <- "Geneid_original"

cq_norm <- cq_norm %>%
  mutate(Geneid_clean = sub("\\..*$", "", Geneid_original)) %>%
  left_join(gene_map %>% select(Geneid_clean, gene_symbol), by = "Geneid_clean")

sample_cols <- setdiff(colnames(cq_norm), c("Geneid_original", "Geneid_clean", "gene_symbol"))
cq_norm[, sample_cols] <- lapply(cq_norm[, sample_cols, drop = FALSE], as.numeric)

cq_we_gene_long <- cq_norm %>%
  filter(gene_symbol %in% candidate_genes) %>%
  select(Geneid_clean, gene_symbol, all_of(sample_cols)) %>%
  pivot_longer(cols = all_of(sample_cols), names_to = "Sample", values_to = "count") %>%
  filter(!Sample %in% exclude_samples) %>%
  mutate(
    group = case_when(
      str_detect(Sample, "^WECT") ~ "WE control",
      str_detect(Sample, "^WECQ") ~ "WE CQ",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(group)) %>%
  mutate(
    group = factor(group, levels = c("WE control", "WE CQ")),
    log_count = log10(count + 1)
  )

write.csv(
  cq_we_gene_long,
  file.path(aux_table_dir, "Figure8B_CQ_WE_candidate_gene_counts_long.csv"),
  row.names = FALSE
)

gene_summary <- cq_we_gene_long %>%
  group_by(gene_symbol, group) %>%
  summarise(mean_log2 = mean(log2(count + 1), na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = group, values_from = mean_log2) %>%
  mutate(log2FC_CQ_vs_control = `WE CQ` - `WE control`)

stat_df <- cq_we_gene_long %>%
  group_by(gene_symbol) %>%
  summarise(
    p_value = tryCatch(wilcox.test(count ~ group)$p.value, error = function(e) NA_real_),
    y_position = max(log_count, na.rm = TRUE) * 1.08,
    .groups = "drop"
  ) %>%
  mutate(
    p_label = case_when(
      is.na(p_value) ~ "n.s.",
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "n.s."
    )
  ) %>%
  left_join(gene_summary, by = "gene_symbol")

write.csv(
  stat_df,
  file.path(aux_table_dir, "Figure8B_CQ_WE_candidate_gene_summary.csv"),
  row.names = FALSE
)

cq_we_gene_panel <- cq_we_gene_long %>%
  filter(gene_symbol %in% final_genes_for_panelB) %>%
  mutate(gene_symbol = factor(gene_symbol, levels = final_genes_for_panelB))

stat_panel <- stat_df %>%
  filter(gene_symbol %in% final_genes_for_panelB) %>%
  mutate(gene_symbol = factor(gene_symbol, levels = final_genes_for_panelB))

source_files <- c(
  write_panel_source_data(
    plot_df %>% filter(experiment == "CQ"),
    figure = "Figure 8",
    panel = "A",
    description = "Selected autophagy, lysosome/endosome and vesicle/secretion GO BP GSEA terms for CQ-treated whole embryos and spent-medium cfRNA.",
    source_data_dir = table_dir,
    file_stub = "Figure8A_CQ_GSEA_selected_terms"
  ),
  write_panel_source_data(
    cq_we_gene_panel,
    figure = "Figure 8",
    panel = "B_values",
    description = "Sample-level log10(normalized count + 1) values for selected CQ-responsive autophagy-lysosome-vesicle genes in whole embryos.",
    source_data_dir = table_dir,
    file_stub = "Figure8B_CQ_WE_gene_values"
  ),
  write_panel_source_data(
    stat_panel,
    figure = "Figure 8",
    panel = "B_statistics",
    description = "Wilcoxon rank-sum test outputs for selected CQ-responsive whole-embryo genes.",
    source_data_dir = table_dir,
    file_stub = "Figure8B_CQ_WE_gene_statistics"
  ),
  write_panel_source_data(
    plot_df %>% filter(experiment == "CQ", sample_type == "SM cfRNA", Description %in% release_terms),
    figure = "Figure 8",
    panel = "C",
    description = "CQ spent-medium cfRNA release-associated GSEA terms used for the barplot.",
    source_data_dir = table_dir,
    file_stub = "Figure8C_CQ_SM_release_terms"
  ),
  write_panel_source_data(
    plot_df %>% filter(experiment == "CB"),
    figure = "Figure 8",
    panel = "D",
    description = "Selected autophagy, lysosome/endosome and vesicle/secretion GO BP GSEA terms for CB-treated whole embryos and spent-medium cfRNA.",
    source_data_dir = table_dir,
    file_stub = "Figure8D_CB_GSEA_selected_terms"
  )
)

# ============================================================
# Panels
# ============================================================
pA <- make_gsea_dotplot(
  plot_df,
  "CQ",
  "A. CQ pathway signatures",
  "Whole embryos and spent-medium cfRNA."
)

pB <- ggplot(cq_we_gene_panel, aes(x = group, y = log_count, fill = group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, color = "black", linewidth = 0.35) +
  geom_jitter(width = 0.15, size = 1.2, alpha = 0.8, color = "black") +
  facet_wrap(
    ~ gene_symbol,
    scales = "free_y",
    ncol = 3,
    labeller = make_gene_labeller(final_genes_for_panelB)
  ) +
  scale_fill_manual(values = c("WE control" = "grey80", "WE CQ" = "#F8766D")) +
  geom_text(
    data = stat_panel,
    aes(x = 1.5, y = y_position, label = p_label),
    inherit.aes = FALSE,
    size = 3
  ) +
  labs(
    title = "B. CQ-responsive genes",
    subtitle = "Whole embryos.",
    x = NULL,
    y = "log10(normalized count + 1)"
  ) +
    theme_fig(base_size = 8.5) +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 30, hjust = 1, face = "bold", size = 7.5),
    axis.text.y = element_text(size = 7.5),
    strip.text = element_text(size = 7.5, face = "italic"),
    plot.margin = margin(2, 2, 8, 2)
  )

pC <- make_sm_release_barplot(
  plot_df,
  "CQ",
  "C. CQ cfRNA release response",
  "Spent-medium cfRNA.",
  "#F8766D"
)

pD <- make_gsea_dotplot(
  plot_df,
  "CB",
  "D. CB pathway signatures",
  "Whole embryos and spent-medium cfRNA."
)

# ============================================================
# Candidate screening, all genes
# ============================================================
pB_all <- ggplot(cq_we_gene_long, aes(x = group, y = log_count, fill = group)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, color = "black", linewidth = 0.25) +
  geom_jitter(width = 0.15, size = 0.8, alpha = 0.7, color = "black") +
  facet_wrap(
    ~ gene_symbol,
    scales = "free_y",
    ncol = 6,
    labeller = make_gene_labeller(candidate_genes)
  ) +
  scale_fill_manual(values = c("WE control" = "grey80", "WE CQ" = "#F8766D")) +
  labs(
    title = "Candidate screening: CQ-responsive WE genes",
    subtitle = "All candidate autophagy, lysosome, endosome and vesicle-related genes.",
    x = NULL,
    y = "log10(normalized count + 1)"
  ) +
  theme_fig(base_size = 8.5) +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 45, hjust = 1, face = "bold")
  )

# ============================================================
# Save
# ============================================================
candidate_outputs <- save_publication_plot(
  pB_all,
  filename_base = "Figure8B_candidate_gene_screening",
  width_mm = 180,
  height_mm = 230,
  output_dir = fig_dir
)

panel_outputs <- c(
  save_publication_plot(pA, "Figure8A_CQ_GSEA_dotplot", 95, 75.3, fig_dir),
  save_publication_plot(pB, "Figure8B_CQ_WE_gene_boxplot", 93, 54.3, fig_dir),
  save_publication_plot(pC, "Figure8C_CQ_SM_release_barplot", 88, 45.4, fig_dir),
  save_publication_plot(pD, "Figure8D_CB_GSEA_dotplot", 95, 75.3, fig_dir)
)

combined <- (pA | pB) / (pC | pD) +
  plot_layout(widths = c(1.12, 1), heights = c(1.05, 1))

combined_outputs <- save_publication_plot(
  combined,
  filename_base = "Figure8_MouseValidation_Combined",
  width_mm = 180,
  height_mm = 170,
  output_dir = fig_dir
)

write_run_manifest(
  "Figure8",
  output_files = c(candidate_outputs, panel_outputs, combined_outputs),
  source_files = source_files,
  log_dir = paths$log_dir
)

message("Figure8 completed.")
message("Output directory: ", fig_dir)
