# load_config.R
# Shared configuration loader for public/repository use.
#
# Priority:
# 1. R/config.local.R, if present (private, ignored by git)
# 2. R/config_template.R, which reads paths from environment variables

ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
if (is.null(ofile) || is.na(ofile) || ofile == "") {
  config_dir <- file.path(getwd(), "R")
} else {
  config_dir <- dirname(normalizePath(ofile, mustWork = FALSE))
}
candidate_local <- file.path(config_dir, "config.local.R")
candidate_template <- file.path(config_dir, "config_template.R")

if (file.exists(candidate_local)) {
  source(candidate_local)
} else if (file.exists(candidate_template)) {
  source(candidate_template)
} else {
  stop("No configuration file found. Provide R/config.local.R or set environment variables and use R/config_template.R.", call. = FALSE)
}
