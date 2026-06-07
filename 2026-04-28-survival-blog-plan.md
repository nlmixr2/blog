# Survival Analysis with nlmixr2 — Blog Post Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write a self-contained blog post demonstrating a parametric survival analysis (exponential and Weibull hazard models) in nlmixr2 using a publicly available dataset with a real drug effect.

**Architecture:** Load the `survival::veteran` dataset, wrangle it into nlmixr2 format with one treatment dummy variable (`test_trt`: 1 = experimental chemotherapy, 0 = standard), fit exponential and Weibull hazard models using `ll()` custom likelihood syntax, compare them with AIC and minus twice the log likelihood, and plot model-predicted survival curves against the Kaplan-Meier estimate for both arms.

**Two-phase approach:** All analysis code is first written and executed as a standalone `analysis.R` script (Phase 1). Only after the script runs end-to-end without errors is the code lifted into the blog post `.Rmd` with prose added (Phase 2). This prevents discovering R errors mid-knit.

**Tech Stack:** R, nlmixr2, rxode2, survival, survminer, dplyr, ggplot2, knitr (Hugo/blogdown `.Rmd` blog post)

---

## Dataset Choice

**Dataset:** `veteran` from the `survival` R package (Veterans' Administration Lung Cancer Trial)

- **Source:** Built into R — `data(veteran, package = "survival")`; no download required.
- **Reference:** Kalbfleisch JD, Prentice RL (1980). *The Statistical Analysis of Failure Time Data.* Wiley.
- **Patients:** 137 patients with advanced inoperable lung cancer; only ~7% censored — almost all patients died during follow-up.
- **Endpoint:** `time` (days to death or censoring), `status` (1 = dead, 0 = censored).
- **Treatment:** `trt` (1 = standard chemotherapy, 2 = test/experimental chemotherapy). Recoded as `test_trt = as.integer(trt == 2)`: 0 = standard (reference), 1 = test.
- **Why this dataset?** The hazard is *decreasing* over time — high early mortality in aggressive lung cancer, followed by a lower rate among survivors — giving a Weibull shape clearly below 1 (fitted value ≈ 0.85). This makes the exponential vs. Weibull contrast unambiguous: ΔAIC ≈ 4, Δ(-2LL) ≈ 6 (p ≈ 0.014). The near-null treatment effect (HR ≈ 0.96) is historically correct and honest.

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `content/blog/2026-04-28-survival-nlmixr2/analysis.R` | **Create** | Standalone script — all analysis code, fully executable |
| `content/blog/2026-04-28-survival-nlmixr2/index.Rmd` | **Create** | Blog post — prose + code chunks lifted from `analysis.R` |

`analysis.R` is a development artefact kept alongside the post so readers can reproduce the analysis without knitr.

---

## Blog Post Outline

The post should be ~800–1200 words of prose, plus code and output. Tone matches existing nlmixr2 blog posts: practical, pharmacometrics-aware, no excessive theory.

```
1. Introduction  (~100 words)
2. The veteran dataset  (~80 words + code)
3. Data wrangling for nlmixr2  (~100 words + code)
4. Exploratory analysis: Kaplan-Meier by treatment arm  (plot)
5. Model 1 — Exponential (constant hazard)  (~150 words + code + output)
6. Model 2 — Weibull (time-varying hazard)  (~150 words + code + output)
7. Model comparison (AIC table)  (~80 words + code)
8. Predicted survival curves vs. observed KM  (plot + ~100 words)
9. Summary  (~60 words)
```

---

# Phase 1: Analysis Script

Build `analysis.R` incrementally, running it after each addition to catch errors early. The script uses `message()` checkpoints and `ggsave()` for plots so all output is inspectable from the command line.

**Status: COMPLETE.** `analysis.R` was built and verified end-to-end. All checkpoints pass; both plots saved. Key results: exponential AIC = 1506.17, Weibull AIC = 1502.13 (ΔAIC = 4.04); Weibull shape = 0.853; Test arm HR = 0.960.

---

## Task 1: Create Directory and Script Skeleton ✓

**Files:**
- Create: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

- [x] **Step 1: Create the directory**

```bash
mkdir -p "blog/content/blog/2026-04-28-survival-nlmixr2"
```

- [x] **Step 2: Write the script header**

```r
# analysis.R — Survival analysis of VA lung cancer data with nlmixr2
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
```

- [x] **Step 3: Run the script to verify libraries load**

```bash
Rscript blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R
```

Expected: `=== Libraries loaded ===` printed; no errors.

---

## Task 2: Data Loading and Wrangling (analysis.R) ✓

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

`veteran` needs no pre-filter — one row per patient, `status` uses standard 0/1 coding. `test_trt` is 1 for the experimental arm, 0 for standard (reference).

- [x] **Step 1: Append data wrangling code**

```r
# ── Data ──────────────────────────────────────────────────────────────────────
# veteran: advanced inoperable lung cancer RCT (n=137).
# trt: 1 = standard chemotherapy (reference), 2 = test chemotherapy.
# status: 1 = dead, 0 = censored (only ~7% censored).
data(veteran, package = "survival")

tte_vet <- veteran %>%
  mutate(
    id       = row_number(),
    dv       = time,
    evid     = 0,
    event    = status,                   # 1 = dead, 0 = censored
    test_trt = as.integer(trt == 2)      # 1 = test arm, 0 = standard (reference)
  ) %>%
  select(id, time, dv, evid, event, test_trt, trt)

message(sprintf(
  "=== Data: %d patients | Standard %d events | Test %d events ===",
  nrow(tte_vet),
  sum(tte_vet$event[tte_vet$test_trt == 0]),
  sum(tte_vet$event[tte_vet$test_trt == 1])
))
```

- [x] **Step 2: Run the script**

```bash
Rscript blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R
```

Expected: 137 patients; Standard 64 events; Test 64 events.

---

## Task 3: Kaplan-Meier Plot (analysis.R) ✓

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

- [x] **Step 1: Append KM plot code**

```r
# ── Kaplan-Meier ──────────────────────────────────────────────────────────────
tte_vet$trt_label <- factor(
  tte_vet$test_trt,
  levels = c(0, 1),
  labels = c("Standard", "Test")
)

km_fit <- survfit(Surv(time, event) ~ trt_label, data = tte_vet)

km_ggsurv <- ggsurvplot(
  km_fit,
  data         = tte_vet,
  palette      = c("steelblue", "firebrick"),
  legend.labs  = c("Standard", "Test"),
  legend.title = "Treatment",
  xlab         = "Days",
  ylab         = "Survival probability",
  title        = "Kaplan-Meier curves by treatment (VA Lung Cancer Trial)",
  conf.int     = TRUE,
  ggtheme      = theme_bw()
)

ggsave(file.path(script_dir, "km_plot.png"), km_ggsurv$plot, width = 7, height = 5, dpi = 150)
message("=== KM plot saved to km_plot.png ===")
```

- [x] **Step 2: Run the script**

Expected: `km_plot.png` shows steep early decline (aggressive disease) then flattening tail; both arms track closely.

---

## Task 4: Exponential Model (analysis.R) ✓

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

The exponential model assumes constant hazard:
$$h_i(t) = h_0 \exp(\beta_\text{test} \cdot \text{test\_trt}_i)$$

- [x] **Step 1: Append exponential model code**

```r
# ── Exponential model ─────────────────────────────────────────────────────────
# h(t) = h0 * exp(beta_test * test_trt)
# Median survival ~80 days → h0 ≈ log(2)/80 ≈ 0.0087/day
exp_model <- function() {
  ini({
    log_h0      <- log(0.009)  # baseline log hazard (per day), standard arm
    test_log_hr <- -0.1        # log HR, test vs. standard
  })
  model({
    log_h  <- log_h0 + test_log_hr * test_trt
    h      <- exp(log_h)
    H      <- h * time
    tte_ll <- event * log_h - H
    ll(tte) ~ tte_ll
  })
}

fit_exp <- nlmixr(
  exp_model,
  tte_vet,
  est = "bobyqa",
  control = bobyqaControl(print = 0)
)

message("=== Exponential model fitted ===")
print(fit_exp$parFixedDf)
message(sprintf("  AIC = %.2f | -2LL = %.2f", AIC(fit_exp), -2 * logLik(fit_exp)))
```

- [x] **Step 2: Run the script**

Expected: `test_log_hr` near zero (null treatment effect); AIC ≈ 1506.

---

## Task 5: Weibull Model (analysis.R) ✓

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

The Weibull model adds a shape parameter $\gamma$. When $\gamma < 1$ the baseline hazard *decreases* over time — the expected pattern for aggressive lung cancer:
$$H_i(t) = \left(\frac{t}{\lambda}\right)^\gamma \exp(\beta_\text{test} \cdot \text{test\_trt}_i)$$

- [x] **Step 1: Append Weibull model code**

```r
# ── Weibull model ─────────────────────────────────────────────────────────────
# Aggressive lung cancer: many early deaths, survivors do better → expect shape < 1
weibull_model <- function() {
  ini({
    log_scale   <- log(100)   # time-scale in days
    log_shape   <- log(0.8)   # shape < 1 = decreasing hazard
    test_log_hr <- -0.1       # log HR, test vs. standard
  })
  model({
    scale <- exp(log_scale)
    shape <- exp(log_shape)
    t_adj <- time + 1e-6      # guard against time ≈ 0

    h0 <- (shape / scale) * (t_adj / scale)^(shape - 1)
    H0 <- (t_adj / scale)^shape

    hr     <- exp(test_log_hr * test_trt)
    h      <- h0 * hr
    H      <- H0 * hr

    tte_ll <- event * log(h) - H
    ll(tte) ~ tte_ll
  })
}

fit_weibull <- nlmixr(
  weibull_model,
  tte_vet,
  est = "bobyqa",
  control = bobyqaControl(print = 0)
)

message("=== Weibull model fitted ===")
print(fit_weibull$parFixedDf)
message(sprintf("  AIC = %.2f | -2LL = %.2f", AIC(fit_weibull), -2 * logLik(fit_weibull)))

theta <- fit_weibull$theta
message(sprintf(
  "  scale=%.1f days | shape=%.3f | Test HR=%.3f",
  exp(theta["log_scale"]),
  exp(theta["log_shape"]),
  exp(theta["test_log_hr"])
))
```

- [x] **Step 2: Run the script**

Expected: shape ≈ 0.85 (decreasing hazard); Test HR ≈ 0.96 (null effect); AIC ≈ 1502.

---

## Task 6: Model Comparison (analysis.R) ✓

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

- [x] **Step 1: Append model comparison code**

```r
# ── Model comparison ──────────────────────────────────────────────────────────
aic_table <- AIC(fit_exp, fit_weibull) %>%
  as.data.frame() %>%
  tibble::rownames_to_column("Model") %>%
  mutate(
    Model = c("Exponential", "Weibull"),
    m2LL  = round(c(-2 * logLik(fit_exp), -2 * logLik(fit_weibull)), 2)
  )

message("=== Model comparison ===")
print(aic_table)
```

- [x] **Step 2: Run the script**

Expected: Weibull AIC lower by ~4 units (ΔAIC ≈ 4.04 observed); Δ(-2LL) ≈ 6 (p ≈ 0.014 on 1 df).

---

## Task 7: Predicted Survival Curves Plot (analysis.R) ✓

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R`

- [x] **Step 1: Append prediction and plotting code**

```r
# ── Predicted survival curves ─────────────────────────────────────────────────
theta_w    <- fit_weibull$theta
scale_w    <- exp(theta_w["log_scale"])
shape_w    <- exp(theta_w["log_shape"])
hr_test    <- exp(theta_w["test_log_hr"])

t_grid <- seq(0, max(tte_vet$time), length.out = 400)

weibull_surv <- function(t, hr) exp(-(t / scale_w)^shape_w * hr)

pred_df <- bind_rows(
  data.frame(time = t_grid, survival = weibull_surv(t_grid, 1),       arm = "Standard (predicted)"),
  data.frame(time = t_grid, survival = weibull_surv(t_grid, hr_test), arm = "Test (predicted)")
)

km_arms <- lapply(c(0, 1), function(d) {
  label <- if (d == 0) "Standard" else "Test"
  fit   <- survfit(Surv(time, event) ~ 1, data = filter(tte_vet, test_trt == d))
  data.frame(time = c(0, fit$time), survival = c(1, fit$surv),
             arm = paste0(label, " (KM)"))
})
km_df2 <- bind_rows(km_arms)

cols <- c(
  "Standard (KM)"       = "steelblue", "Standard (predicted)"  = "steelblue",
  "Test (KM)"           = "firebrick", "Test (predicted)"      = "firebrick"
)

surv_plot <- ggplot() +
  geom_step(data = km_df2,  aes(time, survival, color = arm), linewidth = 0.8) +
  geom_line(data = pred_df, aes(time, survival, color = arm),
            linewidth = 1, linetype = "dashed") +
  scale_color_manual(values = cols) +
  labs(
    x = "Days", y = "Survival probability",
    title = "Weibull model vs. Kaplan-Meier (VA Lung Cancer Trial)",
    color = NULL
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(script_dir, "survival_plot.png"), surv_plot, width = 7, height = 5, dpi = 150)
message("=== Survival plot saved to survival_plot.png ===")
message("=== analysis.R complete ===")
```

- [x] **Step 2: Run the full script end-to-end and inspect outputs**

```bash
Rscript blog/content/blog/2026-04-28-survival-nlmixr2/analysis.R
```

Expected: all five `===` messages printed; `km_plot.png` shows steep early drop then flattening; `survival_plot.png` shows dashed Weibull curves tracking KM steps closely for both arms.

---

# Phase 2: Blog Post

All code in Phase 2 is copied verbatim from the verified `analysis.R`. Chunks that produce plots omit `ggsave()` — knitr renders inline. The `message()` checkpoints are not included in the Rmd.

---

## Task 8: Create the Blog Post Skeleton

**Files:**
- Create: `blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd`

- [x] **Step 1: Write the YAML front matter and setup chunk**

```rmd
---
title: "Survival Analysis with nlmixr2"
author: "Justin Wilkins and the nlmixr2 Development Team"
date: '2026-04-28'
slug: []
categories: [nlmixr2]
tags: [time-to-event, survival, tutorial]
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, message = FALSE, warning = FALSE)
library(nlmixr2)
library(survival)
library(survminer)
library(dplyr)
library(ggplot2)
library(knitr)

set.seed(2601)
```
```

- [x] **Step 2: Commit skeleton**

```bash
git add blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd
git commit -m "feat: add blog post skeleton"
```

---

## Task 9: Introduction and Dataset Sections

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd`

- [x] **Step 1: Write introduction prose (no code chunk)**

```markdown
# Introduction

Time-to-event (TTE) analysis models *when* something happens, not just whether
it happens. The endpoint might be time to tumour progression, time to an adverse
event, or time to dropout. This post demonstrates how to do TTE analysis using
`nlmixr2`, using a real two-arm clinical trial in about 50 lines of model code.

We will use the Veterans' Administration lung cancer trial (shipped with R's
`survival` package) to fit an exponential and a Weibull hazard model, compare
them, and plot predicted survival curves for each treatment arm.
```

- [x] **Step 2: Write dataset section with code chunk**

````markdown
## The `veteran` Dataset

The `veteran` dataset contains 137 patients with advanced inoperable lung
cancer randomised to standard or experimental chemotherapy. Nearly all patients
died during follow-up (~93% events). The key columns are `time` (days to death
or last follow-up), `status` (1 = dead, 0 = censored), and `trt`
(1 = standard, 2 = test).

```{r data-load}
data(veteran, package = "survival")
glimpse(veteran[, c("time", "status", "trt", "celltype", "karno")])
```
````

- [x] **Step 3: Write wrangling section with code chunk**

````markdown
## Data Wrangling for nlmixr2

nlmixr2 TTE models need `id`, `time`, `dv` (= time for single-event TTE),
`evid` (= 0), and `event`. The treatment variable is recoded as `test_trt`:
0 for the standard arm (reference) and 1 for the experimental arm.

```{r data-wrangle}
tte_vet <- veteran %>%
  mutate(
    id       = row_number(),
    dv       = time,
    evid     = 0,
    event    = status,
    test_trt = as.integer(trt == 2)
  ) %>%
  select(id, time, dv, evid, event, test_trt, trt)
```
````

- [x] **Step 4: Commit**

```bash
git add blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd
git commit -m "feat: add intro, dataset, and wrangling sections to blog post"
```

---

## Task 10: Kaplan-Meier Section

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd`

- [x] **Step 1: Write KM section with code chunk (copied from analysis.R Task 3, without ggsave)**

````markdown
## Exploratory Analysis

Before fitting any model, we inspect the raw survival curves. The steep early
decline reflects the aggressive nature of the disease; the two arms track
closely, consistent with the null treatment effect seen in this trial.

```{r km-plot, fig.width=7, fig.height=5}
tte_vet$trt_label <- factor(
  tte_vet$test_trt,
  levels = c(0, 1),
  labels = c("Standard", "Test")
)

km_fit <- survfit(Surv(time, event) ~ trt_label, data = tte_vet)

ggsurvplot(
  km_fit,
  data         = tte_vet,
  palette      = c("steelblue", "firebrick"),
  legend.labs  = c("Standard", "Test"),
  legend.title = "Treatment",
  xlab         = "Days",
  ylab         = "Survival probability",
  title        = "Kaplan-Meier curves by treatment (VA Lung Cancer Trial)",
  conf.int     = TRUE,
  ggtheme      = theme_bw()
)
```
````

- [x] **Step 2: Commit**

```bash
git add blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd
git commit -m "feat: add KM plot section to blog post"
```

---

## Task 11: Exponential Model Section

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd`

- [x] **Step 1: Write exponential model section (code copied from analysis.R Task 4, without message() calls)**

````markdown
## Model 1 — Exponential (Constant Hazard)

The exponential model assumes the instantaneous risk is constant over time.
The hazard for subject $i$ is:

$$h_i(t) = h_0 \exp(\beta_\text{test} \cdot \text{test\_trt}_i)$$

`exp(test_log_hr)` is the hazard ratio for the experimental arm vs. standard;
values below 1 indicate a lower instantaneous death rate with the test drug.

```{r exp-model}
exp_model <- function() {
  ini({
    log_h0      <- log(0.009)
    test_log_hr <- -0.1
  })
  model({
    log_h  <- log_h0 + test_log_hr * test_trt
    h      <- exp(log_h)
    H      <- h * time
    tte_ll <- event * log_h - H
    ll(tte) ~ tte_ll
  })
}

fit_exp <- nlmixr(
  exp_model,
  tte_vet,
  est = "bobyqa",
  control = bobyqaControl(print = 0)
)

fit_exp$parFixedDf
```
````

- [x] **Step 2: Commit**

```bash
git add blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd
git commit -m "feat: add exponential model section to blog post"
```

---

## Task 12: Weibull Model Section

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd`

- [x] **Step 1: Write Weibull model section (code copied from analysis.R Task 5, without message() calls)**

````markdown
## Model 2 — Weibull (Time-Varying Hazard)

The Weibull model adds a shape parameter $\gamma$. When $\gamma < 1$ the
hazard *decreases* over time — patients who survive the initial acute phase
face progressively lower risk, a pattern typical of aggressive cancers.

$$H_i(t) = \left(\frac{t}{\lambda}\right)^\gamma \exp(\beta_\text{test} \cdot \text{test\_trt}_i)$$

```{r weibull-model}
weibull_model <- function() {
  ini({
    log_scale   <- log(100)
    log_shape   <- log(0.8)
    test_log_hr <- -0.1
  })
  model({
    scale <- exp(log_scale)
    shape <- exp(log_shape)
    t_adj <- time + 1e-6

    h0 <- (shape / scale) * (t_adj / scale)^(shape - 1)
    H0 <- (t_adj / scale)^shape

    hr     <- exp(test_log_hr * test_trt)
    h      <- h0 * hr
    H      <- H0 * hr

    tte_ll <- event * log(h) - H
    ll(tte) ~ tte_ll
  })
}

fit_weibull <- nlmixr(
  weibull_model,
  tte_vet,
  est = "bobyqa",
  control = bobyqaControl(print = 0)
)

fit_weibull$parFixedDf
```

```{r weibull-table}
theta <- fit_weibull$theta
kable(
  data.frame(
    Parameter      = c("scale (days)", "shape", "Test arm HR"),
    Estimate       = round(c(
      exp(theta["log_scale"]),
      exp(theta["log_shape"]),
      exp(theta["test_log_hr"])
    ), 3),
    Interpretation = c(
      "Weibull time-scale for standard-arm patients",
      "Hazard shape; <1 means decreasing risk over time",
      "Instantaneous hazard ratio, test vs. standard (expect ~1.0)"
    )
  ),
  digits = 3
)
```
````

- [x] **Step 2: Commit**

```bash
git add blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd
git commit -m "feat: add Weibull model section to blog post"
```

---

## Task 13: Model Comparison, Prediction Plot, Summary, and Final Render

**Files:**
- Modify: `blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd`

- [x] **Step 1: Write model comparison section**

````markdown
## Model Comparison

```{r aic-table}
aic_table <- AIC(fit_exp, fit_weibull) %>%
  as.data.frame() %>%
  tibble::rownames_to_column("Model") %>%
  mutate(
    Model = c("Exponential", "Weibull"),
    m2LL  = round(c(-2 * logLik(fit_exp), -2 * logLik(fit_weibull)), 2)
  )

kable(aic_table, digits = 2,
      caption = "AIC and -2 log-likelihood: exponential vs. Weibull")
```

The Weibull model is preferred by ~4 AIC units (ΔAIC ≈ 4, Δ(-2LL) ≈ 6,
p ≈ 0.014 on 1 df), confirming that the time-varying hazard adds meaningful
explanatory power. The fitted shape below 1 captures the decreasing hazard
seen in the KM curve.
````

- [x] **Step 2: Write prediction plot section**

````markdown
## Predicted Survival Curves vs. Observed KM

```{r surv-plot, fig.width=7, fig.height=5}
theta_w    <- fit_weibull$theta
scale_w    <- exp(theta_w["log_scale"])
shape_w    <- exp(theta_w["log_shape"])
hr_test    <- exp(theta_w["test_log_hr"])

t_grid <- seq(0, max(tte_vet$time), length.out = 400)

weibull_surv <- function(t, hr) exp(-(t / scale_w)^shape_w * hr)

pred_df <- bind_rows(
  data.frame(time = t_grid, survival = weibull_surv(t_grid, 1),       arm = "Standard (predicted)"),
  data.frame(time = t_grid, survival = weibull_surv(t_grid, hr_test), arm = "Test (predicted)")
)

km_arms <- lapply(c(0, 1), function(d) {
  label <- if (d == 0) "Standard" else "Test"
  fit   <- survfit(Surv(time, event) ~ 1, data = filter(tte_vet, test_trt == d))
  data.frame(time = c(0, fit$time), survival = c(1, fit$surv),
             arm = paste0(label, " (KM)"))
})
km_df2 <- bind_rows(km_arms)

cols <- c(
  "Standard (KM)"       = "steelblue", "Standard (predicted)"  = "steelblue",
  "Test (KM)"           = "firebrick", "Test (predicted)"      = "firebrick"
)

ggplot() +
  geom_step(data = km_df2,  aes(time, survival, color = arm), linewidth = 0.8) +
  geom_line(data = pred_df, aes(time, survival, color = arm),
            linewidth = 1, linetype = "dashed") +
  scale_color_manual(values = cols) +
  labs(x = "Days", y = "Survival probability",
       title = "Weibull model vs. Kaplan-Meier (VA Lung Cancer Trial)",
       color = NULL) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_bw() +
  theme(legend.position = "bottom")
```

Dashed lines are Weibull model predictions; solid stepped lines are the
Kaplan-Meier estimates. The predicted curves closely track both arms,
confirming the Weibull captures the characteristic steep early decline and
subsequent flattening of survival in this aggressive cancer setting.
````

- [x] **Step 3: Write summary section**

```markdown
## Summary

This post showed how to fit parametric TTE models in nlmixr2 using custom
log-likelihood syntax (`ll(tte) ~ tte_ll`). The workflow — wrangle data into
id/time/event/dv/evid format, define hazard and cumulative hazard in the
`model()` block, fit with `nlmixr()` using `bobyqa` — extends naturally to
drug exposure-driven hazard models and repeated time-to-event endpoints.
The Weibull shape parameter (≈ 0.85) quantified the decreasing hazard in
advanced lung cancer, a finding the simpler exponential model cannot capture.
See Chapter 25 of the nlmixr2 book for the full treatment.
```

- [ ] **Step 4: Render the blog post and verify** ← *run this manually*

```r
# In R console (or RStudio), from the repo root:
rmarkdown::render(
  "blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd",
  quiet = TRUE
)
```

Expected: no errors; HTML output created in the same directory; both plots and parameter table render correctly.

- [ ] **Step 5: Final commit**

```bash
git add blog/content/blog/2026-04-28-survival-nlmixr2/index.Rmd
git commit -m "feat: add survival analysis with nlmixr2 blog post"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Introduction, EDA, exponential model, Weibull model, AIC + -2LL comparison, survival curve plot, summary — all sections covered.
- [x] **No placeholders:** All code blocks are complete in both `analysis.R` and `index.Rmd`; no "TBD" or "implement later".
- [x] **Type consistency:** `fit_exp`, `fit_weibull`, `tte_vet`, `theta_w`, `test_trt`, `km_df2`, `pred_df` — names are identical between `analysis.R` and `index.Rmd`. `ll(tte) ~ tte_ll` syntax matches chapter 25 pattern.
- [x] **Script verified first:** Phase 1 complete; all checkpoints pass; ΔAIC = 4.04 confirmed; both plots visually checked.
- [x] **Dataset access:** `survival::veteran` is built into R — no download, no external URL, available on every R installation.
- [x] **Blog format:** Front matter matches existing posts (`title`, `author`, `date`, `slug`, `categories`, `tags`); setup chunk uses `knitr::opts_chunk$set(echo = TRUE)`; post goes in `content/blog/YYYY-MM-DD-slug/index.Rmd`.

---

## Notes for the Author

- `veteran` has one row per patient and requires no pre-filtering. `status` uses standard 0/1 coding.
- `trt` in `veteran` is 1/2 (not 0/1). The wrangling step recodes it as `test_trt = as.integer(trt == 2)` so the parameter is interpretable as a log HR for test vs. standard.
- Do not start `test_log_hr` at exactly 0 — `bobyqa` may not explore away from a boundary. Use a small non-zero value (e.g., `-0.1`).
- The `+ 1e-6` offset on `time` in the Weibull model guards against `(0/scale)^(shape-1)` being undefined; this pattern is taken directly from Chapter 25.
- `bobyqa` is the recommended estimator for custom log-likelihoods in nlmixr2 (no symbolic gradient needed).
- `ggsave()` calls in `analysis.R` are intentionally absent from `index.Rmd` — knitr renders plots inline automatically.
- If the blog is rendered with `blogdown::serve_site()` you can preview the post locally before publishing.
