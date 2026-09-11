# source_data_helpers.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

write_panel_source_data <- function(data, figure, panel, description,
                                    source_data_dir, file_stub = NULL) {
  stopifnot(is.data.frame(data))
  dir.create(source_data_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(file_stub)) {
    file_stub <- paste0(figure, "_", panel)
  }

  out <- data %>%
    mutate(
      source_figure = figure,
      source_panel = panel,
      source_description = description,
      .before = 1
    )

  file <- file.path(source_data_dir, paste0(file_stub, ".csv"))
  readr::write_csv(out, file, na = "")
  invisible(file)
}

write_run_manifest <- function(figure, output_files, source_files, log_dir) {
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  manifest <- tibble::tibble(
    figure = figure,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    output_files = paste(output_files, collapse = "; "),
    source_data_files = paste(source_files, collapse = "; ")
  )
  file <- file.path(log_dir, paste0(figure, "_manifest.csv"))
  readr::write_csv(manifest, file)
  invisible(file)
}
