# run_all_figures.R
# Driver script for the figure/source-data workflow.
#
# The final manuscript contains Figures 1-8 and Extended Data Figures 1-9.
# Some scripts generate panels that were split into separate final display items;
# see inventory/final_figure_mapping.csv for the final display-item mapping.

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

figure_scripts <- c(
  "figures/Figure1.R",
  "figures/Figure2.R",
  "figures/Figure3.R",
  "figures/Figure4.R",
  "figures/Figure5.R",
  "figures/Figure8.R",
  "figures/ExtendedDataFigure1.R",
  "figures/ExtendedDataFigure2.R",
  "figures/ExtendedDataFigure3.R",
  "figures/ExtendedDataFigure4.R"
)

for (script in figure_scripts) {
  script_path <- file.path(script_dir, script)
  if (!file.exists(script_path)) {
    warning("Skipping missing script: ", script)
    next
  }
  message("Running ", script)
  source(script_path, local = new.env(parent = globalenv()))
}

if (dir.exists(paths$source_data_dir)) {
  csv_files <- list.files(paths$source_data_dir, pattern = "\\.csv$", full.names = TRUE)
  if (length(csv_files) > 0) {
    builder <- file.path(script_dir, "build_source_data_workbook.py")
    sheet_map <- file.path(script_dir, "inventory", "source_data_sheet_mapping.csv")
    args <- c(builder, "--panel-dir", paths$source_data_dir, "--output", paths$source_data_workbook)
    if (file.exists(sheet_map)) {
      args <- c(args, "--sheet-map", sheet_map)
    }
    status <- system2("python3", args)
    if (!identical(status, 0L)) {
      stop("Source Data workbook build failed with status: ", status)
    }
    message("Updated Source Data workbook: ", paths$source_data_workbook)
  }
}
