# run_all_figures.R
# Driver script for the figure/source-data workflow.

rm(list = ls())

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
script_dir <- if (length(file_arg) > 0) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE))
} else {
  getwd()
}
source(file.path(script_dir, "R", "load_config.R"))
source(file.path(script_dir, "R", "figure_theme.R"))
source(file.path(script_dir, "R", "source_data_helpers.R"))

message("Figure workflow")
message("Figure directory: ", paths$figure_dir)
message("Panel source-data directory: ", paths$source_data_dir)

# Individual figure scripts will be added here as they are completed.
# Example:
# source(file.path(script_dir, "figures", "Figure1.R"))

if (dir.exists(paths$source_data_dir)) {
  csv_files <- list.files(paths$source_data_dir, pattern = "\\.csv$", full.names = TRUE)
  if (length(csv_files) > 0) {
    builder <- file.path(script_dir, "build_source_data_workbook.py")
    status <- system2(
      "python3",
      c(builder, "--panel-dir", paths$source_data_dir, "--output", paths$source_data_workbook)
    )
    if (!identical(status, 0L)) {
      stop("Source Data workbook build failed with status: ", status)
    }
    message("Updated Source Data workbook: ", paths$source_data_workbook)
  }
}
