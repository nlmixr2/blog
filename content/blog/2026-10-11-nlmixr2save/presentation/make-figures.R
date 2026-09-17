## Figures for the nlmixr2save deck.  Same model as the post (../index.Rmd),
## timed with real `:=` calls in a scratch directory.  Run from presentation/:
##   Rscript make-figures.R
library(nlmixr2)
library(nlmixr2save)
library(ggplot2)

theme_set(theme_bw(base_size = 17))
slide <- function(p, file, w = 11, h = 5.6) {
  ggsave(file.path("images", file), p, width = w, height = h, dpi = 120)
  # the ACoP poster (../poster/make-poster.R) uses the same figures at print dpi
  dir.create("../poster/figs", showWarnings = FALSE)
  # drawn smaller, then scaled up on the poster, so the labels read at a distance
  ggsave(file.path("../poster/figs", file), p, width = 0.7 * w, height = 0.7 * h, dpi = 400)
}
navy <- "#1f497d"; red <- "#b40000"

one.cmt <- function() {
  ini({
    tka <- 0.45; label("Log Ka")
    tcl <- log(c(0, 2.7, 100)); label("Log Cl")
    tv <- 3.45; label("log V")
    eta.ka ~ 0.6
    eta.cl ~ 0.3
    eta.v ~ 0.1
    add.sd <- 0.7
  })
  model({
    ka <- exp(tka + eta.ka)
    cl <- exp(tcl + eta.cl)
    v <- exp(tv + eta.v)
    linCmt() ~ add(add.sd)
  })
}

## --- := on five calls in a row ---------------------------------------
figDir <- normalizePath("images")
scratch <- file.path(tempdir(), "nlmixr2save-deck")
dir.create(scratch, showWarnings = FALSE)
owd <- setwd(scratch)

elapsed <- function(expr) system.time(expr)[["elapsed"]]
ctl <- list(print = 0)

theoNotes <- theo_sd
theoNotes$notes <- "reviewed"
theoDv <- theo_sd
theoDv$DV <- theoDv$DV * 1.05

timing <- data.frame(
  step = c("1. first call",
           "2. same call again",
           "3. add a notes column to the data",
           "4. change DV",
           "5. change nBurn"),
  sec = c(
    elapsed(fitS := nlmixr2(one.cmt, theo_sd,   est = "saem", control = ctl)),
    elapsed(fitS := nlmixr2(one.cmt, theo_sd,   est = "saem", control = ctl)),
    elapsed(fitS := nlmixr2(one.cmt, theoNotes, est = "saem", control = ctl)),
    elapsed(fitS := nlmixr2(one.cmt, theoDv,    est = "saem", control = ctl)),
    elapsed(fitS := nlmixr2(one.cmt, theoDv,    est = "saem",
                            control = list(print = 0, nBurn = 250)))))
setwd(owd)

timing$what <- ifelse(timing$sec > 2, "estimated", "loaded from cache")
timing$step <- factor(timing$step, levels = rev(timing$step))
print(timing)
dir.create("../poster/figs", showWarnings = FALSE)
write.csv(timing, "../poster/figs/timing.csv", row.names = FALSE)

slide(ggplot(timing, aes(sec, step, fill = what)) +
        geom_col(width = 0.65) +
        geom_text(aes(label = sprintf("%.1f s", sec)), hjust = -0.15, size = 6) +
        scale_fill_manual(values = c(estimated = red, `loaded from cache` = navy)) +
        scale_x_continuous(expand = expansion(mult = c(0, 0.22))) +
        labs(x = "elapsed seconds (SAEM, theo_sd)", y = NULL, fill = NULL) +
        theme(legend.position = "top",
              panel.grid.major.y = element_blank()),
      "fig-timing.png", w = 11, h = 5.2)

## --- a loaded fit still makes a VPC ----------------------------------
owd <- setwd(scratch)
fit <- nlmixr2(one.cmt, theo_sd, est = "focei", control = list(print = 0))
saveFit(fit)
fit2 <- loadFit("fit")
setwd(owd)
set.seed(42)
p <- vpcPlot(fit2, n = 300, show = list(obs_dv = TRUE)) +
  labs(title = NULL, subtitle = NULL, caption = NULL,
       x = "time (h)", y = "theophylline concentration")
slide(p, "fig-loaded.png", w = 7, h = 5.2)
