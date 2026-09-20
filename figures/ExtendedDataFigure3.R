# ExtendedDataFigure3.R
# Generate Extended Data Figure 5, 6 and 7 panels with source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(forcats)
  library(viridis)
  library(clusterProfiler)
  library(enrichplot)
  library(patchwork)
  library(ggplotify)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "ExtendedDataFigure3.R"
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

format_p <- function(x) {
  case_when(
    is.na(x) ~ "NA",
    x < 1e-4 ~ formatC(x, format = "e", digits = 2),
    TRUE ~ formatC(x, format = "f", digits = 4)
  )
}

output_files <- character()
source_files <- character()

# ============================================================
# Extended Data Figure 3A - distribution of M and A values
# ============================================================
ma_file <- file.path(paths$human_analysis_dir, "MAplot", "MAplot_ALL.xlsx")
data_EWEvsESM <- read_excel(ma_file, sheet = "E_SMvsWE") %>% mutate(Comparison = "EWE vs. ESM")
data_AWEvsASM <- read_excel(ma_file, sheet = "A_SMvsWE") %>% mutate(Comparison = "AWE vs. ASM")
data_all <- bind_rows(data_EWEvsESM, data_AWEvsASM)

data_long <- data_all %>%
  pivot_longer(cols = c(m.value, a.value), names_to = "ValueType", values_to = "Value") %>%
  mutate(
    ValueType = factor(ValueType, levels = c("m.value", "a.value"),
                       labels = c("log2 fold change", "Average expression")),
    Comparison = factor(Comparison, levels = c("EWE vs. ESM", "AWE vs. ASM"))
  )

ks_m <- ks.test(
  data_all %>% filter(Comparison == "EWE vs. ESM") %>% pull(m.value),
  data_all %>% filter(Comparison == "AWE vs. ASM") %>% pull(m.value)
)
ks_a <- ks.test(
  data_all %>% filter(Comparison == "EWE vs. ESM") %>% pull(a.value),
  data_all %>% filter(Comparison == "AWE vs. ASM") %>% pull(a.value)
)

ks_source <- tibble(
  ValueType = c("log2 fold change", "Average expression"),
  statistic_D = c(unname(ks_m$statistic), unname(ks_a$statistic)),
  p_value = c(ks_m$p.value, ks_a$p.value),
  test = "Two-sample Kolmogorov-Smirnov test"
)

pval_df <- ks_source %>%
  mutate(
    ValueType = factor(ValueType, levels = levels(data_long$ValueType)),
    p_label = paste0("P = ", format_p(p_value))
  )

pA <- ggplot(data_long, aes(x = Value, fill = Comparison, color = Comparison)) +
  geom_density(alpha = 0.25, adjust = 1, linewidth = 0.35) +
  facet_wrap(~ValueType, scales = "free", nrow = 1) +
  geom_text(data = pval_df, aes(x = -Inf, y = Inf, label = p_label),
            inherit.aes = FALSE, hjust = -0.05, vjust = 1.35, size = 2.8) +
  scale_fill_manual(values = c("EWE vs. ESM" = "#00BFC4", "AWE vs. ASM" = "#F8766D")) +
  scale_color_manual(values = c("EWE vs. ESM" = "#00BFC4", "AWE vs. ASM" = "#F8766D")) +
  labs(x = expression(log[2]~"value"), y = "Density") +
  theme_publication() +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(size = 7.5, face = "bold"),
    legend.title = element_blank(),
    legend.text = element_text(size = 7.5),
    axis.text = element_text(size = 7.5),
    axis.title = element_text(size = 7.5),
    legend.key.size = unit(0.18, "cm"),
    plot.margin = margin(2, 2, 2, 2)
  )

output_files <- c(output_files, save_panel(pA, "FigureS3A_Distribution_KS_Density", 180, 45))
source_files <- c(source_files,
                  write_panel_source_data(data_long, "Extended Data Figure 3", "A_values",
                                          "M-value and A-value distributions plotted in panel A.",
                                          panel_data_dir, "FigureS3A_distribution_values"),
                  write_panel_source_data(ks_source, "Extended Data Figure 3", "A_statistics",
                                          "Kolmogorov-Smirnov test statistics for panel A.",
                                          panel_data_dir, "FigureS3A_KS_statistics"))

# ============================================================
# Extended Data Figure 3B/C - Reactome terms for up/downregulated genes
# ============================================================
compress_panel_width <- function(plot, panel_width_cm = 4.8) {
  grob <- ggplotGrob(plot)
  panel_cols <- unique(grob$layout$l[grepl("^panel", grob$layout$name)])
  grob$widths[panel_cols] <- unit(panel_width_cm, "cm")
  grob
}

make_reactome_dotplot <- function(files, title, output_name, panel_id) {
  combined <- imap_dfr(files, function(file, comparison) {
    read_csv(file, show_col_types = FALSE) %>%
      mutate(Comparison = comparison) %>%
      arrange(qvalue) %>%
      slice_head(n = 20)
  }) %>%
    mutate(
      qvalue = if_else(qvalue == 0, .Machine$double.xmin, qvalue),
      minus_log10_qvalue = -log10(qvalue),
      Comparison = factor(Comparison, levels = names(files)),
      Description_wrapped = str_wrap(Description, width = 50),
      Description_full = paste(Description_wrapped, Comparison, sep = "___")
    ) %>%
    group_by(Comparison) %>%
    mutate(Description_full = factor(Description_full, levels = rev(unique(Description_full)))) %>%
    ungroup()

  p <- ggplot(combined, aes(x = minus_log10_qvalue, y = Description_full)) +
    geom_point(aes(size = Count, color = minus_log10_qvalue), alpha = 0.95) +
    scale_color_viridis_c(option = "D", name = expression(-log[10]~"(q-value)")) +
    scale_size(range = c(1, 4), name = "Gene count") +
    scale_x_continuous(limits = c(0, 90), expand = c(0, 0)) +
    scale_y_discrete(labels = function(x) gsub("___.*", "", x)) +
    facet_grid(rows = vars(Comparison), scales = "free_y", space = "free_y", switch = "y") +
    labs(x = expression(-log[10]~"(q-value)"), y = NULL, title = title) +
    theme_publication() +
    theme(
      plot.title = element_text(hjust = 0.75, size = 8, face = "bold"),
      strip.text.y.left = element_text(angle = 90, size = 7.5),
      axis.text.y = element_text(size = 7.5, lineheight = 0.88),
      axis.text.x = element_text(size = 8),
      axis.title.x = element_text(size = 7.5),
      legend.title = element_text(size = 7.5),
      legend.text = element_text(size = 7.5),
      legend.key.size = unit(0.2, "cm"),
      plot.margin = margin(1, 1, 1, 8, unit = "mm")
    ) +
    guides(color = guide_colorbar(order = 1), size = guide_legend(order = 2))

  output <- save_panel(compress_panel_width(p, panel_width_cm = 4.4), output_name, 180, 170)
  source <- write_panel_source_data(
    combined %>% arrange(Comparison, qvalue),
    "Extended Data Figure 3", panel_id,
    paste0("Reactome terms plotted for ", title, "."),
    panel_data_dir, paste0(output_name, "_terms")
  )
  list(output = output, source = source)
}

up_files <- c(
  "EWE vs. ESM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_UpOnly", "Reactome", "Reactome_EWEvsESM.csv"),
  "AWE vs. ASM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_UpOnly", "Reactome", "Reactome_AWEvsASM.csv")
)
down_files <- c(
  "EWE vs. ESM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_DownOnly", "Reactome", "Reactome_EWEvsESM.csv"),
  "AWE vs. ASM" = file.path(paths$human_analysis_dir, "DEG", "EnrichmentResults_DownOnly", "Reactome", "Reactome_AWEvsASM.csv")
)

resB <- make_reactome_dotplot(up_files, "Top Reactome terms enriched in upregulated genes",
                              "FigureS3B_Reactome_UpregulatedOnly", "B")
resC <- make_reactome_dotplot(down_files, "Top Reactome terms enriched in downregulated genes",
                              "FigureS3C_Reactome_DownregulatedOnly", "C")
output_files <- c(output_files, resB$output, resC$output)
source_files <- c(source_files, resB$source, resC$source)

# ============================================================
# Extended Data Figure 3D - Reactome GSEA dotplot
# ============================================================
gsea_reactome <- read_csv(file.path(paths$human_analysis_dir, "DEG", "GSEA", "AWEvsASM", "GSEA_Reactome.csv"),
                          show_col_types = FALSE)
gsea_plot <- gsea_reactome %>%
  arrange(desc(abs(NES))) %>%
  slice_head(n = 14) %>%
  mutate(
    Description_wrapped = str_wrap(Description, width = 56),
    Description_wrapped = fct_reorder(Description_wrapped, NES),
    minus_log10_FDR = -log10(p.adjust)
  )

pD <- ggplot(gsea_plot, aes(x = NES, y = Description_wrapped)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.3) +
  geom_point(aes(size = setSize, color = minus_log10_FDR), alpha = 0.95) +
  scale_color_viridis_c(option = "D", name = expression(-log[10]~"(FDR)")) +
  scale_size_continuous(name = "Gene set size", range = c(1.0, 3.6)) +
  labs(title = "Reactome GSEA of AWE vs. ASM", x = "NES", y = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8.5),
    axis.text.y = element_text(size = 7.5, lineheight = 0.92),
    axis.text.x = element_text(size = 7.5),
    axis.title.x = element_text(size = 7.5),
    legend.title = element_text(size = 7.5),
    legend.text = element_text(size = 7.5),
    legend.key.size = unit(0.18, "cm"),
    plot.margin = margin(2, 2, 2, 8)
  )

output_files <- c(output_files, save_panel(compress_panel_width(pD, panel_width_cm = 5.6), "FigureS3D_GSEA_Reactome_dotplot", 180, 82))
source_files <- c(source_files, write_panel_source_data(
  gsea_plot %>% arrange(desc(abs(NES))),
  "Extended Data Figure 3", "D",
  "Reactome GSEA terms. Points encode gene set size and colour encodes -log10(FDR).",
  panel_data_dir, "FigureS3D_GSEA_Reactome_terms"
))

# ============================================================
# Extended Data Figure 3E - Reactome GSEA curves with NES and P/FDR
# ============================================================
gsea_obj <- readRDS(file.path(paths$human_analysis_dir, "DEG", "GSEA", "EWEvsAWE", "GSEA_Reactome.rds"))
gsea_stats <- read_csv(file.path(paths$human_analysis_dir, "DEG", "GSEA", "EWEvsAWE", "GSEA_Reactome.csv"),
                       show_col_types = FALSE)

plot_info <- tibble(
  ID = c(
    "R-HSA-69541",
    "R-HSA-169911",
    "R-HSA-6803211",
    "R-HSA-69610",
    "R-HSA-75815",
    "R-HSA-450408"
  ),
  Display = c(
    "Stabilization of p53",
    "Regulation of apoptosis",
    "TP53 death receptor transcription",
    "p53-independent DNA damage response",
    "Ubiquitin-dependent degradation of cyclin D",
    "AUF1 binds and destabilizes mRNA"
  )
)

stats_E <- plot_info %>%
  left_join(gsea_stats, by = "ID") %>%
  mutate(
    annotation = paste0(
      "NES = ", sprintf("%.2f", NES),
      "\nP = ", format_p(pvalue),
      "\nFDR = ", format_p(p.adjust)
    ),
    annotation_inline = paste0(
      "NES=", sprintf("%.2f", NES),
      "; P=", format_p(pvalue),
      "; FDR=", format_p(p.adjust)
    )
  )

plot_list <- lapply(seq_len(nrow(stats_E)), function(i) {
  row <- stats_E[i, ]
  p <- tryCatch({
    gp <- gseaplot2(
      gsea_obj,
      geneSetID = row$ID,
      title = paste0(row$Display, "\n", row$annotation_inline),
      base_size = 7.5,
      rel_heights = c(1.35, 0.25, 0.85),
      color = "steelblue"
    )
    gp[[1]] <- gp[[1]] +
      theme(
        plot.title = element_text(size = 7.5, lineheight = 0.95, hjust = 0.5),
        axis.title.y = element_blank()
      )
    gp[[2]] <- gp[[2]] + theme(axis.title.y = element_blank())
    gp[[3]] <- gp[[3]] + theme(axis.title.y = element_blank())
    gp[[1]] / gp[[2]] / gp[[3]] + plot_layout(heights = c(1.35, 0.25, 0.85))
  }, error = function(e) {
    message(sprintf("Skip: %s - %s", row$Display, e$message))
    NULL
  })
  p
})
plot_list <- Filter(Negate(is.null), plot_list)

if (length(plot_list) > 0) {
  pE <- wrap_plots(plotlist = plot_list, ncol = 2)
  output_files <- c(output_files, save_panel(pE, "FigureS3E_GSEAplot_EWEvsAWE_Reactome", 180, 140, dpi = 600))
}
source_files <- c(source_files, write_panel_source_data(
  stats_E,
  "Extended Data Figure 3", "E",
  "Reactome GSEA curve statistics plotted in panel E.",
  panel_data_dir, "FigureS3E_GSEAplot_Reactome_statistics"
))

write_run_manifest("ExtendedDataFigure3", output_files, source_files, paths$log_dir)
message("Extended Data Figure 3 panels and source data completed.")
