# source_data_helpers.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(openxlsx)
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

combine_source_data_workbook <- function(panel_dir, output_xlsx) {
  files <- list.files(panel_dir, pattern = "\\.csv$", full.names = TRUE)
  if (length(files) == 0) {
    stop("No panel-level CSV files found in: ", panel_dir, call. = FALSE)
  }

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Index")
  index <- tibble::tibble(
    sheet = character(),
    file = character(),
    rows = integer(),
    columns = integer()
  )

  for (file in sort(files)) {
    df <- readr::read_csv(file, show_col_types = FALSE)
    base <- tools::file_path_sans_ext(basename(file))
    sheet <- substr(gsub("[^A-Za-z0-9_]", "_", base), 1, 31)
    original_sheet <- sheet
    i <- 1
    while (sheet %in% names(wb)) {
      suffix <- paste0("_", i)
      sheet <- substr(paste0(substr(original_sheet, 1, 31 - nchar(suffix)), suffix), 1, 31)
      i <- i + 1
    }
    openxlsx::addWorksheet(wb, sheet)
    openxlsx::writeData(wb, sheet, df)
    openxlsx::freezePane(wb, sheet, firstRow = TRUE)
    index <- bind_rows(index, tibble::tibble(
      sheet = sheet,
      file = basename(file),
      rows = nrow(df),
      columns = ncol(df)
    ))
  }

  openxlsx::writeData(wb, "Index", index)
  openxlsx::freezePane(wb, "Index", firstRow = TRUE)
  if (file.exists(output_xlsx)) {
    unlink(output_xlsx)
  }
  openxlsx::saveWorkbook(wb, output_xlsx, overwrite = TRUE)
  invisible(output_xlsx)
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
