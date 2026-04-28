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

# ── Data ──────────────────────────────────────────────────────────────────────
data(colon, package = "survival")
colon_death <- filter(colon, etype == 2)

tte_colon <- colon_death %>%
  filter(!is.na(time), !is.na(status), !is.na(rx)) %>%
  mutate(
    ID     = row_number(),
    TIME   = time,
    DV     = time,
    EVID   = 0,
    EVENT  = as.integer(status),           # 1 = dead, 0 = censored
    LEV    = as.integer(rx == "Lev"),      # 1 = Lev arm, 0 = Obs or Lev+5FU
    LEV5FU = as.integer(rx == "Lev+5FU")  # 1 = Lev+5FU arm, 0 = Obs or Lev
  ) %>%
  select(ID, TIME, DV, EVID, EVENT, LEV, LEV5FU, rx)

message(sprintf(
  "=== Data: %d rows | Obs %d events | Lev %d events | Lev+5FU %d events ===",
  nrow(tte_colon),
  sum(tte_colon$EVENT[tte_colon$rx == "Obs"]),
  sum(tte_colon$EVENT[tte_colon$rx == "Lev"]),
  sum(tte_colon$EVENT[tte_colon$rx == "Lev+5FU"])
))
