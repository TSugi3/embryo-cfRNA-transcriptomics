# theme_ncb_revision.R

suppressPackageStartupMessages({
  library(ggplot2)
})

theme_ncb_revision <- function(base_size = 7.5, base_family = "Arial") {
  theme_bw(base_size = base_size, base_family = base_family) %+replace%
    theme(
      panel.background = element_blank(),
      panel.border = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(colour = "black", linewidth = 0.35),
      axis.ticks = element_line(colour = "black", linewidth = 0.35),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = base_size * 0.9, colour = "black"),
      plot.title = element_text(size = base_size + 1, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = base_size, hjust = 0),
      strip.background = element_rect(fill = "grey92", colour = "grey70", linewidth = 0.35),
      strip.text = element_text(size = base_size * 0.9, face = "bold"),
      legend.title = element_text(size = base_size),
      legend.text = element_text(size = base_size * 0.9),
      legend.key = element_blank(),
      legend.spacing = grid::unit(0.12, "cm"),
      plot.margin = margin(4, 4, 4, 4)
    )
}

group_colours <- c(
  "EWE" = "#009EBD",
  "AWE" = "#F8766D",
  "ESM" = "#619CFF",
  "ASM" = "#C77CFF",
  "WE control" = "#9E9E9E",
  "WE CQ" = "#C1283D",
  "SM control" = "#9E9E9E",
  "SM CQ" = "#C1283D",
  "WE DMSO" = "#9E9E9E",
  "WE CB" = "#2B6CB0",
  "SM DMSO" = "#9E9E9E",
  "SM CB" = "#2B6CB0"
)

gsea_nes_colours <- c(
  low = "#2166AC",
  mid = "white",
  high = "#B2182B"
)

save_ncb_plot <- function(plot, filename_base, width_mm, height_mm, output_dir,
                          dpi = 600, bg = "white") {
  stopifnot(dir.exists(output_dir))
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4

  pdf_file <- file.path(output_dir, paste0(filename_base, ".pdf"))
  png_file <- file.path(output_dir, paste0(filename_base, ".png"))
  tiff_file <- file.path(output_dir, paste0(filename_base, ".tiff"))

  ggplot2::ggsave(pdf_file, plot, width = width_in, height = height_in,
                  units = "in", device = cairo_pdf, bg = bg)
  ggplot2::ggsave(png_file, plot, width = width_in, height = height_in,
                  units = "in", dpi = dpi, bg = bg)
  ggplot2::ggsave(tiff_file, plot, width = width_in, height = height_in,
                  units = "in", dpi = dpi, compression = "lzw", bg = bg)

  invisible(c(pdf = pdf_file, png = png_file, tiff = tiff_file))
}

