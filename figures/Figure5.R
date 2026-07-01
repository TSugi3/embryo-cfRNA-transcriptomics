# Figure5.R
# Rebuild Figure 5 panels with readability improvements and source-data outputs.

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(forcats)
  library(ggplot2)
  library(patchwork)
  library(scales)
  library(rtracklayer)
  library(circlize)
})

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure5.R"
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

save_circlize_panel <- function(draw_fun, name, width_mm, height_mm, dpi = 600) {
  png_file <- file.path(fig_dir, paste0(name, ".png"))
  tiff_file <- file.path(fig_dir, paste0(name, ".tiff"))
  pdf_file <- file.path(fig_dir, paste0(name, ".pdf"))
  grDevices::png(png_file, width = width_mm / 25.4, height = height_mm / 25.4,
                 units = "in", res = dpi, bg = "white")
  draw_fun()
  grDevices::dev.off()
  grDevices::tiff(tiff_file, width = width_mm / 25.4, height = height_mm / 25.4,
                  units = "in", res = dpi, compression = "lzw", bg = "white")
  draw_fun()
  grDevices::dev.off()
  grDevices::cairo_pdf(pdf_file, width = width_mm / 25.4, height = height_mm / 25.4,
                       bg = "white")
  draw_fun()
  grDevices::dev.off()
  c(pdf = pdf_file, png = png_file, tiff = tiff_file)
}

output_files <- character()
source_files <- character()

# ============================================================
# Figure 5A - non-DEG CV intersection
# ============================================================
file_es <- file.path(paths$human_analysis_dir, "nonDEG", "nonDEGfile_CV", "nonDEG_EWEvsESM_CV_lt_1.0.csv")
file_ea <- file.path(paths$human_analysis_dir, "nonDEG", "nonDEGfile_CV", "nonDEG_EWEvsAWE_CV_lt_1.0.csv")
genes_es <- readr::read_csv(file_es, show_col_types = FALSE) %>% pull(gene_id) %>% unique()
genes_ea <- readr::read_csv(file_ea, show_col_types = FALSE) %>% pull(gene_id) %>% unique()

gene_matrix <- tibble(gene_id = unique(c(genes_es, genes_ea))) %>%
  mutate(
    `EWE vs. ESM` = gene_id %in% genes_es,
    `EWE vs. AWE` = gene_id %in% genes_ea,
    membership = case_when(
      `EWE vs. ESM` & `EWE vs. AWE` ~ "Shared",
      `EWE vs. ESM` ~ "EWE vs. ESM only",
      `EWE vs. AWE` ~ "EWE vs. AWE only",
      TRUE ~ "Other"
    )
  )

intersection_counts <- gene_matrix %>%
  count(membership, `EWE vs. ESM`, `EWE vs. AWE`, name = "intersection_size") %>%
  filter(membership != "Other") %>%
  arrange(desc(intersection_size)) %>%
  mutate(membership = factor(membership, levels = membership))

set_labels <- tibble(
  membership = rep(intersection_counts$membership, each = 2),
  set = rep(c("EWE vs. ESM", "EWE vs. AWE"), times = nrow(intersection_counts)),
  present = c(rbind(intersection_counts$`EWE vs. ESM`, intersection_counts$`EWE vs. AWE`))
)

pA_bar <- ggplot(intersection_counts, aes(x = membership, y = intersection_size)) +
  geom_col(width = 0.58, fill = "gray25") +
  geom_text(aes(label = intersection_size), vjust = -0.25, size = 2.0) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(y = "Intersection size", x = NULL) +
  theme_publication() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 6),
    axis.title.y = element_text(size = 6.5),
    plot.margin = margin(1, 1, 0, 1)
  )

pA_matrix <- ggplot(set_labels, aes(x = membership, y = set)) +
  geom_line(aes(group = membership), color = "gray35", linewidth = 0.35) +
  geom_point(aes(fill = present), shape = 21, size = 2.2, color = "black", stroke = 0.2) +
  scale_fill_manual(values = c("TRUE" = "black", "FALSE" = "white"), guide = "none") +
  labs(x = NULL, y = NULL) +
  theme_publication() +
  theme(
    axis.text.x = element_text(size = 5.5, angle = 35, hjust = 1),
    axis.text.y = element_text(size = 6),
    axis.ticks = element_blank(),
    plot.margin = margin(0, 1, 1, 1)
  )

pA <- pA_bar / pA_matrix + plot_layout(heights = c(2.2, 1))

output_files <- c(output_files, save_panel(pA, "Figure5A_UpSetPlot_nonDEG_CV", 50, 50))
source_files <- c(
  source_files,
  write_panel_source_data(gene_matrix, "Figure 5", "A_membership",
                          "Gene-level membership of non-DEG CV < 1.0 sets.",
                          panel_data_dir, "Figure5A_nonDEG_CV_membership"),
  write_panel_source_data(intersection_counts, "Figure 5", "A_intersections",
                          "Intersection sizes for non-DEG CV < 1.0 sets.",
                          panel_data_dir, "Figure5A_nonDEG_CV_intersections")
)

# ============================================================
# Figure 5B - biotype composition
# ============================================================
cv_label <- "1.0"
gtf_path <- file.path(dirname(paths$human_analysis_dir), "ramdaq_annotation", "human", "gencode.v37.primary_assembly.annotation.gtf")
input_file_b <- file.path(paths$human_analysis_dir, "nonDEG", "common_nonDEG_genes_CV", "plot",
                          paste0("common_genes_EWEvsESM_EWEvsAWE_", cv_label, ".txt"))
gtf <- rtracklayer::import(gtf_path)
genes <- gtf[gtf$type == "gene"]
gtf_df <- as.data.frame(mcols(genes)) %>%
  select(gene_name, gene_type) %>%
  distinct()
gene_list <- readLines(input_file_b)
annotated_genes <- gtf_df %>% filter(gene_name %in% gene_list)

biotype_counts <- annotated_genes %>%
  count(gene_type, name = "count") %>%
  arrange(desc(count)) %>%
  mutate(group = if_else(gene_type == "protein_coding", "protein_coding", "others"))
main_df <- biotype_counts %>%
  group_by(group) %>%
  summarise(count = sum(count), .groups = "drop") %>%
  mutate(label = paste0(group, "\n", count))
etc_df <- biotype_counts %>%
  filter(group == "others") %>%
  mutate(label = paste0(gene_type, " (", count, ")"))

main_colors <- c("protein_coding" = "#1b9e77", "others" = "#d95f02")
etc_colors <- hue_pal()(nrow(etc_df))
names(etc_colors) <- etc_df$gene_type

pB1 <- ggplot(main_df, aes(x = "", y = count, fill = group)) +
  geom_col(width = 1) +
  coord_polar("y") +
  geom_text(aes(label = label), position = position_stack(vjust = 0.5), size = 2.3) +
  labs(title = "Biotype composition") +
  scale_fill_manual(values = main_colors) +
  theme_void(base_size = 8) +
  theme(plot.title = element_text(hjust = 0.5, size = 8), legend.position = "none")

pB2 <- ggplot(etc_df, aes(x = "", y = count, fill = gene_type)) +
  geom_col(width = 1) +
  coord_polar("y") +
  labs(title = "Other gene types") +
  scale_fill_manual(values = etc_colors) +
  theme_void(base_size = 8) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8),
    legend.title = element_blank(),
    legend.text = element_text(size = 5.6),
    legend.key.size = unit(2.5, "mm"),
    legend.spacing.y = unit(0.5, "mm"),
    legend.position = "right"
  )

pB <- pB1 + pB2 + plot_layout(ncol = 2, widths = c(1.0, 1.2))

output_files <- c(output_files, save_panel(pB, "Figure5B_Biotype_PieChart", 130, 50))
source_files <- c(
  source_files,
  write_panel_source_data(biotype_counts, "Figure 5", "B_biotype_counts",
                          "Biotype composition of common non-DEG genes with CV < 1.0.",
                          panel_data_dir, "Figure5B_biotype_counts"),
  write_panel_source_data(annotated_genes, "Figure 5", "B_gene_annotations",
                          "Gene-level biotype annotations for common non-DEG genes.",
                          panel_data_dir, "Figure5B_gene_biotypes")
)

# ============================================================
# Figure 5C - GO:BP enrichment of co-expressed mRNAs
# ============================================================
df_c <- readr::read_csv(file.path(paths$human_analysis_dir, "Figure", "Figure5C_GO_BP_enrichment.csv"),
                        show_col_types = FALSE)
top_terms_c <- df_c %>%
  filter(p.adjust < 0.05) %>%
  arrange(p.adjust) %>%
  slice_head(n = 15) %>%
  mutate(
    GeneRatio_numeric = vapply(GeneRatio, function(x) eval(parse(text = x)), numeric(1)),
    Description_wrapped = stringr::str_wrap(Description, width = 58),
    Description_wrapped = fct_reorder(Description_wrapped, GeneRatio_numeric)
  )

pC <- ggplot(top_terms_c, aes(x = GeneRatio_numeric, y = Description_wrapped, size = Count, color = p.adjust)) +
  geom_point(alpha = 0.95) +
  scale_color_viridis_c(option = "D", direction = -1, name = "Adjusted P") +
  scale_size_continuous(name = "Gene count", range = c(1.2, 4.0)) +
  labs(title = "GO:BP enrichment of mRNAs co-expressed with lncRNAs",
       x = "Gene ratio", y = NULL) +
  theme_publication() +
  theme(
    plot.title = element_text(face = "bold", size = 8, hjust = 0.5),
    legend.position = "right",
    legend.title = element_text(size = 6),
    legend.text = element_text(size = 6),
    legend.key.size = unit(0.22, "cm"),
    axis.text.y = element_text(size = 6.5, lineheight = 0.86),
    axis.text.x = element_text(size = 7),
    axis.title.x = element_text(size = 7),
    plot.margin = margin(1, 1, 1, 2, unit = "mm")
  )

output_files <- c(output_files, save_panel(pC, "Figure5C_GO_BP_dotplot_viridis", 180, 68))
source_files <- c(source_files, write_panel_source_data(
  top_terms_c %>% arrange(p.adjust),
  "Figure 5", "C",
  "GO biological process enrichment terms for mRNAs co-expressed with lncRNAs.",
  panel_data_dir, "Figure5C_GO_BP_enrichment_terms"
))

# ============================================================
# Figure 5D - autophagy-related release heatmap
# ============================================================
input_file_d <- file.path(paths$human_analysis_dir, "nonDEG", "common_nonDEG_genes_CV",
                          "Correlation_1.0", "Step15a_output",
                          "expression_Autophagy-related release_1.0.csv")
expr_d <- readr::read_csv(input_file_d, show_col_types = FALSE)
expr_mat <- expr_d %>% column_to_rownames("Gene") %>% as.matrix()
scaled_mat <- t(scale(t(expr_mat)))
scaled_mat[is.na(scaled_mat)] <- 0
row_order <- rownames(scaled_mat)[hclust(dist(scaled_mat))$order]
col_order <- colnames(scaled_mat)[hclust(dist(t(scaled_mat)))$order]
heat_df <- as.data.frame(scaled_mat) %>%
  rownames_to_column("Gene") %>%
  pivot_longer(-Gene, names_to = "Sample", values_to = "z_score") %>%
  mutate(
    Gene = factor(Gene, levels = rev(row_order)),
    Sample = factor(Sample, levels = col_order)
  )

sample_group_df <- tibble(
  Sample = factor(col_order, levels = col_order),
  Group = stringr::str_extract(col_order, "^[A-Z]+")
) %>%
  mutate(Group = factor(Group, levels = c("EWE", "AWE", "ESM", "ASM")))

pD_group <- ggplot(sample_group_df, aes(x = Sample, y = "Group", fill = Group)) +
  geom_tile(color = "white", linewidth = 0.08) +
  scale_fill_manual(values = color_group[c("EWE", "AWE", "ESM", "ASM")], na.value = "grey85") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = "Arial") +
  theme(
    legend.position = "top",
    legend.title = element_blank(),
    legend.text = element_text(size = 6),
    legend.key.width = unit(0.35, "cm"),
    plot.margin = margin(0, 1, 0, 1)
  )

pD_heat <- ggplot(heat_df, aes(x = Sample, y = Gene, fill = z_score)) +
  geom_tile(color = "white", linewidth = 0.05) +
  scale_fill_gradient2(low = "#3B0F70", mid = "white", high = "#F8766D",
                       midpoint = 0, name = "z-score") +
  labs(title = "Autophagy-related release genes", x = NULL, y = NULL) +
  theme_minimal(base_family = "Arial") +
  theme(
    plot.title = element_text(size = 8, face = "bold", hjust = 0.5),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 5.0, face = "italic"),
    panel.grid = element_blank(),
    legend.title = element_text(size = 6),
    legend.text = element_text(size = 6),
    legend.key.height = unit(0.35, "cm"),
    plot.margin = margin(1, 1, 1, 1)
  )

pD <- pD_group / pD_heat + patchwork::plot_layout(heights = c(0.11, 1))

output_files <- c(output_files, save_panel(pD, "Figure5D_heatmap_autophagy", 180, 100))
source_files <- c(
  source_files,
  write_panel_source_data(expr_d, "Figure 5", "D_expression",
                          "Expression matrix used for the autophagy-related release heatmap.",
                          panel_data_dir, "Figure5D_autophagy_heatmap_expression"),
  write_panel_source_data(heat_df, "Figure 5", "D_z_scores",
                          "Row-scaled z-scores plotted in the autophagy-related release heatmap.",
                          panel_data_dir, "Figure5D_autophagy_heatmap_zscores")
)

# ============================================================
# Figure 5E - autophagy-related release chord diagram
# ============================================================
input_file_e <- file.path(paths$human_analysis_dir, "nonDEG", "common_nonDEG_genes_CV",
                          "Correlation_1.0", "Step15a_output",
                          "correlation_Autophagy-related release_1.0.csv")
cor_df <- readr::read_csv(input_file_e, show_col_types = FALSE)
chord_data <- cor_df %>%
  select(lncRNA, mRNA) %>%
  count(lncRNA, mRNA, name = "weight")
chord_matrix <- as.matrix(xtabs(weight ~ lncRNA + mRNA, data = chord_data))

draw_chord <- function() {
  circos.clear()
  circos.par(start.degree = 90, gap.after = 1)
  chordDiagram(chord_matrix,
               transparency = 0.42,
               annotationTrack = "grid",
               preAllocateTracks = list(track.height = 0.06))
  circos.track(track.index = 1, panel.fun = function(x, y) {
    circos.text(CELL_META$xcenter, CELL_META$ylim[1],
                CELL_META$sector.index, facing = "clockwise",
                niceFacing = TRUE, adj = c(0, 0.5), cex = 0.48, font = 3)
  }, bg.border = NA)
  circos.clear()
}

output_files <- c(output_files, save_circlize_panel(draw_chord, "Figure5E_chord_autophagy", 180, 165))
source_files <- c(source_files, write_panel_source_data(
  cor_df, "Figure 5", "E",
  "lncRNA-mRNA correlation pairs used for the autophagy-related release chord diagram.",
  panel_data_dir, "Figure5E_autophagy_chord_correlations"
))

write_run_manifest("Figure5", output_files, source_files, paths$log_dir)
message("Figure5 panels and source data completed.")
