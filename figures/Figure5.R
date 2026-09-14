# Figure5.R
# Final-numbered entry point for Figure 5.

rm(list = ls())

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure5.R"
script_dir <- dirname(normalizePath(this_file, mustWork = FALSE))

message("Running final Figure 5 panel generator.")
source(file.path(script_dir, "Figure5_panels.R"), local = new.env(parent = globalenv()))
