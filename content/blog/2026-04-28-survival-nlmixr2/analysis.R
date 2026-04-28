# analysis.R — Survival analysis of NCCTG colon cancer data with nlmixr2
# Run: Rscript analysis.R  (from the blog/content/blog/2026-04-28-survival-nlmixr2/ directory)

library(nlmixr2)
library(survival)
library(survminer)
library(dplyr)
library(ggplot2)

# Resolve script directory so ggsave() saves plots next to this file
args <- commandArgs(trailingOnly = FALSE)
file_flag <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_flag) > 0) {
  dirname(normalizePath(sub("^--file=", "", file_flag), mustWork = FALSE))
} else {
  "."
}

set.seed(2601)
message("=== Libraries loaded ===")
