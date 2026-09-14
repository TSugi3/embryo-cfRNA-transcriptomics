# load_config.R
# Shared configuration loader for public/repository use.
#
# Priority:
# 1. R/config.local.R, if present (private, ignored by git)
# 2. R/config_template.R, which reads paths from environment variables

find_config_dir <- function() {
  ofiles <- vapply(sys.frames(), function(frame) {
    if (exists("ofile", envir = frame, inherits = FALSE)) {
      get("ofile", envir = frame)
    } else {
      NA_character_
    }
  }, character(1))
  ofiles <- ofiles[!is.na(ofiles) & nzchar(ofiles)]
  load_config_files <- ofiles[basename(ofiles) == "load_config.R"]
  if (length(load_config_files) > 0) {
    return(dirname(normalizePath(tail(load_config_files, 1), mustWork = FALSE)))
  }
  file.path(getwd(), "R")
}

config_dir <- find_config_dir()
candidate_local <- file.path(config_dir, "config.local.R")
candidate_template <- file.path(config_dir, "config_template.R")

if (file.exists(candidate_local)) {
  source(candidate_local)
} else if (file.exists(candidate_template)) {
  source(candidate_template)
} else {
  stop("No configuration file found. Provide R/config.local.R or set environment variables and use R/config_template.R.", call. = FALSE)
}
