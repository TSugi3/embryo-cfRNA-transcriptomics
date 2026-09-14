# Figure4.R
# Final-numbered entry point for Figure 4.
#
# Figure 4 shares upstream DEG/GSEA panel generation with Figure 3. Running this
# wrapper regenerates the shared Figure 3/4 panel set and source-data tables.

rm(list = ls())

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- if (length(file_arg) > 0) sub("^--file=", "", file_arg[1]) else "Figure4.R"
script_dir <- dirname(normalizePath(this_file, mustWork = FALSE))

message("Running shared Figure 3/4 panel generator for final Figure 4.")
source(file.path(script_dir, "Figure3.R"), local = new.env(parent = globalenv()))
