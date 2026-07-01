# config_template.R
# Copy this file to config.local.R and edit paths for a local run.
# Do not commit or publicly share config.local.R if it contains private paths.

get_env_or_stop <- function(name) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || value == "") {
    stop(
      "Environment variable ", name, " is not set. ",
      "Set it in your shell or define it in config.local.R.",
      call. = FALSE
    )
  }
  normalizePath(value, mustWork = FALSE)
}

paths <- list(
  human_analysis_dir = get_env_or_stop("NCB_HUMAN_ANALYSIS_DIR"),
  human_figure_script_dir = get_env_or_stop("NCB_HUMAN_FIGURE_SCRIPT_DIR"),
  mouse_analysis_dir = get_env_or_stop("NCB_MOUSE_ANALYSIS_DIR"),
  revised_root = get_env_or_stop("NCB_REVISED_ROOT"),
  revised_figure_dir = get_env_or_stop("NCB_REVISED_FIGURE_DIR"),
  source_data_dir = get_env_or_stop("NCB_SOURCE_DATA_DIR"),
  source_data_workbook = get_env_or_stop("NCB_SOURCE_DATA_WORKBOOK"),
  log_dir = get_env_or_stop("NCB_LOG_DIR")
)

dir.create(paths$revised_figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(paths$source_data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(paths$log_dir, recursive = TRUE, showWarnings = FALSE)
