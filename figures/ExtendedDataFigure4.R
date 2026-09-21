# ExtendedDataFigure4.R
# Generate Extended Data Figure 8 and 9 panels with source data.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(forcats)
  library(viridis)
  library(pheatmap)
  library(circlize)
  library(grid)
  library(gridExtra)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "ExtendedDataFigure4.R"
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

save_heatmap <- function(pheatmap_obj, title, name, width_mm, height_mm, dpi = 600) {
  files <- c(
    pdf = file.path(fig_dir, paste0(name, ".pdf")),
    png = file.path(fig_dir, paste0(name, ".png")),
    tiff = file.path(fig_dir, paste0(name, ".tiff"))
  )
  draw_it <- function() {
    grid.newpage()
    title_grob <- textGrob(title, gp = gpar(fontsize = 7.5, fontface = "bold", fontfamily = "Arial"))
    grid.arrange(title_grob, pheatmap_obj$gtable, heights = unit(c(1.0, 22), c("lines", "null")))
  }
  grDevices::cairo_pdf(files["pdf"], width = width_mm / 25.4, height = height_mm / 25.4)
  draw_it()
  dev.off()
  png(files["png"], width = width_mm, height = height_mm, units = "mm", res = dpi, type = "cairo", bg = "white")
  draw_it()
  dev.off()
  tiff(files["tiff"], width = width_mm, height = height_mm, units = "mm", res = dpi,
       compression = "lzw", type = "cairo", bg = "white")
  draw_it()
  dev.off()
  files
}

save_chord <- function(chord_matrix, name, width_mm, height_mm, dpi = 600) {
  files <- c(
    pdf = file.path(fig_dir, paste0(name, ".pdf")),
    png = file.path(fig_dir, paste0(name, ".png")),
    tiff = file.path(fig_dir, paste0(name, ".tiff"))
  )
  draw_it <- function() {
    sectors <- c(rownames(chord_matrix), colnames(chord_matrix))
    sector_totals <- c(rowSums(chord_matrix), colSums(chord_matrix))
    sector_floor <- unname(quantile(sector_totals, 0.90))
    sector_xmax <- setNames(pmax(sector_totals, sector_floor), sectors)

    circos.clear()
    circos.par(
      canvas.xlim = c(-1.15, 1.15),
      canvas.ylim = c(-1.25, 1.15)
    )
    chordDiagram(
      chord_matrix,
      xmax = sector_xmax,
      transparency = 0.4,
      annotationTrack = "grid",
      preAllocateTracks = list(track.height = 0.05)
    )
    circos.track(track.index = 1, panel.fun = function(x, y) {
      circos.text(CELL_META$xcenter, CELL_META$ylim[1], CELL_META$sector.index,
                  facing = "clockwise", niceFacing = TRUE, adj = c(0, 0.5), cex = 0.59)
    }, bg.border = NA)
    circos.clear()
  }
  grDevices::cairo_pdf(files["pdf"], width = width_mm / 25.4, height = height_mm / 25.4)
  draw_it()
  dev.off()
  png(files["png"], width = width_mm, height = height_mm, units = "mm", res = dpi, type = "cairo", bg = "white")
  draw_it()
  dev.off()
  tiff(files["tiff"], width = width_mm, height = height_mm, units = "mm", res = dpi,
       compression = "lzw", type = "cairo", bg = "white")
  draw_it()
  dev.off()
  files
}

output_files <- character()
source_files <- character()

# ============================================================
# Extended Data Figure 4A - KEGG enrichment for WGCNA module
# ============================================================
kegg_file <- file.path(paths$human_analysis_dir, "nonDEG", "common_nonDEG_genes_CV",
                       "WGCNA", "Step12_output_1.0", "KEGG_enrichment.csv")
kegg_all <- read_csv(kegg_file, show_col_types = FALSE) %>%
  mutate(GeneRatio_numeric = parse_gene_ratio(GeneRatio),
         minus_log10_FDR = -log10(p.adjust))
kegg_plot <- kegg_all %>%
  filter(p.adjust < 0.05) %>%
  arrange(p.adjust) %>%
  slice_head(n = 15) %>%
  mutate(
    Description_wrapped = str_wrap(Description, width = 42),
    Description_wrapped = fct_reorder(Description_wrapped, GeneRatio_numeric)
  )

pA <- ggplot(kegg_plot, aes(x = GeneRatio_numeric, y = Description_wrapped)) +
  geom_point(aes(size = Count, color = minus_log10_FDR), alpha = 0.95) +
  scale_color_viridis_c(option = "D", name = expression(-log[10]~"(FDR)")) +
  scale_size_continuous(range = c(1.0, 3.6), name = "Gene count") +
  labs(title = "KEGG enrichment of mRNAs co-expressed with lncRNAs",
       x = "Gene ratio", y = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(face = "bold", size = 7.5, hjust = 0.5),
    axis.text.y = element_text(size = 7.5, lineheight = 0.92),
    axis.text.x = element_text(size = 7.5),
    axis.title.x = element_text(size = 7.5),
    legend.title = element_text(size = 7.5),
    legend.text = element_text(size = 7.5),
    legend.key.size = unit(0.18, "cm"),
    plot.margin = margin(2, 2, 2, 5)
  )

output_files <- c(output_files, save_panel(pA, "FigureS4A_KEGG_dotplot", 180, 80))
source_files <- c(source_files,
                  write_panel_source_data(kegg_all, "Extended Data Figure 4", "A_all",
                                          "All KEGG enrichment results for the WGCNA module.",
                                          panel_data_dir, "FigureS4A_KEGG_all_terms"),
                  write_panel_source_data(kegg_plot, "Extended Data Figure 4", "A_plotted",
                                          "Top KEGG enrichment terms plotted in panel A.",
                                          panel_data_dir, "FigureS4A_KEGG_plotted_terms"))

# ============================================================
# Extended Data Figure 4B - heatmap of vesicle-mediated release genes
# ============================================================
expr_file <- file.path(paths$human_analysis_dir, "nonDEG", "common_nonDEG_genes_CV",
                       "Correlation_1.0", "Step15a_output",
                       "expression_Vesicle-mediated release_1.0.csv")
expr_df <- read_csv(expr_file, show_col_types = FALSE)
expr_mat_all <- expr_df %>% column_to_rownames("Gene") %>% as.matrix()
gene_variance <- apply(expr_mat_all, 1, var, na.rm = TRUE)
top_genes <- names(sort(gene_variance, decreasing = TRUE))[seq_len(min(50, length(gene_variance)))]
expr_mat_plot <- expr_mat_all[top_genes, , drop = FALSE]

sample_groups <- tibble(Sample = colnames(expr_mat_plot)) %>%
  mutate(Group = case_when(
    str_detect(Sample, "^EWE") ~ "EWE",
    str_detect(Sample, "^ESM") ~ "ESM",
    str_detect(Sample, "^AWE") ~ "AWE",
    str_detect(Sample, "^ASM") ~ "ASM",
    TRUE ~ "Other"
  )) %>%
  arrange(factor(Group, levels = c("EWE", "ESM", "AWE", "ASM", "Other")), Sample)
expr_mat_plot <- expr_mat_plot[, sample_groups$Sample, drop = FALSE]
annotation_col <- data.frame(Group = sample_groups$Group)
rownames(annotation_col) <- sample_groups$Sample
annotation_colours <- list(Group = color_group[c("EWE", "AWE", "ESM", "ASM")])

pheat <- pheatmap(
  expr_mat_plot,
  scale = "row",
  cluster_rows = TRUE,
  cluster_cols = FALSE,
  show_rownames = TRUE,
  show_colnames = FALSE,
  fontsize = 7.5,
  fontsize_row = 7.5,
  annotation_col = annotation_col,
  annotation_colors = annotation_colours,
  color = colorRampPalette(c("#2166AC", "white", "#B2182B"))(101),
  border_color = NA,
  silent = TRUE
)

output_files <- c(output_files, save_heatmap(pheat, "Vesicle-mediated release genes", "FigureS4B_heatmap_vesicle", 180, 120))
source_files <- c(source_files,
                  write_panel_source_data(expr_df, "Extended Data Figure 4", "B_all",
                                          "Expression matrix for all vesicle-mediated release genes.",
                                          panel_data_dir, "FigureS4B_heatmap_all_expression"),
                  write_panel_source_data(
                    as.data.frame(expr_mat_plot) %>% rownames_to_column("Gene"),
                    "Extended Data Figure 4", "B_plotted",
                    "Expression matrix for the top-variance genes plotted in panel B.",
                    panel_data_dir, "FigureS4B_heatmap_plotted_expression"
                  ))

# ============================================================
# Extended Data Figure 4C - lncRNA-mRNA correlation chord diagram
# ============================================================
cor_file <- file.path(paths$human_analysis_dir, "nonDEG", "common_nonDEG_genes_CV",
                      "Correlation_1.0", "Step15a_output",
                      "correlation_Vesicle-mediated release_1.0.csv")
cor_all <- read_csv(cor_file, show_col_types = FALSE) %>%
  mutate(abs_cor = abs(cor))
cor_plot <- cor_all %>%
  select(lncRNA, mRNA) %>%
  distinct() %>%
  mutate(weight = 1)
chord_matrix <- table(cor_plot$lncRNA, cor_plot$mRNA)

output_files <- c(output_files, save_chord(chord_matrix, "FigureS4C_chord_vesicle", 180, 190))
source_files <- c(source_files,
                  write_panel_source_data(cor_all, "Extended Data Figure 4", "C_all",
                                          "All lncRNA-mRNA correlations for vesicle-mediated release genes.",
                                          panel_data_dir, "FigureS4C_chord_all_correlations"),
                  write_panel_source_data(cor_plot, "Extended Data Figure 4", "C_plotted",
                                          "lncRNA-mRNA correlations plotted in panel C.",
                                          panel_data_dir, "FigureS4C_chord_plotted_correlations"))

write_run_manifest("ExtendedDataFigure4", output_files, source_files, paths$log_dir)
message("Extended Data Figure 4 panels and source data completed.")
