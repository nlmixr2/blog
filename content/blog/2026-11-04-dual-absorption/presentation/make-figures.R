## Figures for the dual-absorption deck.  Same models and seeds as the post
## (../index.Rmd), drawn larger for slides.  Run from presentation/:
##   Rscript make-figures.R
library(rxode2)
library(nlmixr2)
library(dplyr)
library(tidyr)
library(ggplot2)
rxSetProgressBar(FALSE)

theme_set(theme_bw(base_size = 17))
slide <- function(p, file, w = 11, h = 5.6) {
  ggsave(file.path("images", file), p, width = w, height = h, dpi = 120)
}
navy <- "#1f497d"; red <- "#b40000"; green <- "#4a7d18"; orange <- "#e08836"
cmtCols <- c(depot = red, slowdepot = orange, central = navy)

## --- two first-order routes: splitBolus() -------------------------------
dual <- function() {
  ini({
    tka1 <- log(1.5)
    tka2 <- log(0.15)
    tfr  <- logit(0.6)
    tcl  <- log(4)
    tv   <- log(40)
    eta.ka1 ~ 0.1
    eta.cl  ~ 0.09
    eta.v   ~ 0.04
    prop.sd <- 0.1
  })
  model({
    ka1 <- exp(tka1 + eta.ka1)
    ka2 <- exp(tka2)
    fr  <- expit(tfr)
    cl  <- exp(tcl + eta.cl)
    v   <- exp(tv + eta.v)
    splitBolus(depot, depot, slowdepot)
    f(depot)  <- fr
    f(slowdepot) <- 1 - fr
    d/dt(depot)   <- -ka1 * depot
    d/dt(slowdepot)  <- -ka2 * slowdepot
    d/dt(central) <-  ka1 * depot + ka2 * slowdepot - cl / v * central
    cp <- central / v
    cp ~ prop(prop.sd)
  })
}
typical <- rxSolve(dual |> zeroRe(), et(amt = 100, cmt = "depot") |> et(seq(0, 36, by = 0.1)))
slide(typical |> as.data.frame() |>
        select(time, depot, slowdepot, central) |>
        pivot_longer(-time, names_to = "compartment", values_to = "amount") |>
        mutate(compartment = factor(compartment, c("depot", "slowdepot", "central"))) |>
        ggplot(aes(time, amount, color = compartment)) +
        geom_line(linewidth = 1.4) +
        scale_color_manual(values = cmtCols) +
        labs(x = "time (h)", y = "amount (mg)", color = NULL) +
        theme(legend.position = "bottom"),
      "fig-dual.png", w = 9, h = 5.4)

## --- zero-order + first-order: splitInfusionBolus() ---------------------
zoFo <- function() {
  ini({tk0 <- 4; fr <- 0.7; ka2 <- 1.2; lag2 <- 1.5; cl <- 2; v <- 25})
  model({
    splitInfusionBolus(depot, central, depot)
    dur(central)  <- tk0
    f(central)    <- fr
    f(depot)      <- 1 - fr
    alag(depot)   <- lag2
    d/dt(depot)   <- -ka2 * depot
    d/dt(central) <-  ka2 * depot - cl / v * central
    cp <- central / v
  })
}
zo <- rxSolve(zoFo, et(amt = 100, cmt = "depot") |> et(seq(0, 24, by = 0.05)))
slide(ggplot(as.data.frame(zo), aes(time, cp)) +
        geom_vline(xintercept = c(1.5, 4), linetype = "dashed", colour = "grey55") +
        annotate("text", x = 1.5, y = 0.35, label = "lag ends", hjust = -0.08, size = 5.5, colour = "grey30") +
        annotate("text", x = 4, y = 3.55, label = "zero-order input ends", hjust = -0.05, size = 5.5, colour = "grey30") +
        geom_line(linewidth = 1.4, colour = navy) +
        labs(x = "time (h)", y = "concentration (mg/L)"),
      "fig-zofo.png", w = 9, h = 5.4)

## --- rate vs dur under f(): splitInfusion() -----------------------------
sc <- function() {
  ini({fr <- 0.6; ka1 <- 0.8; ka2 <- 0.05; cl <- 0.2; v <- 3})
  model({
    splitInfusion(sc, fast, slow)
    f(fast) <- fr
    f(slow) <- 1 - fr
    d/dt(sc)      <- 0
    d/dt(fast)    <- -ka1 * fast
    d/dt(slow)    <- -ka2 * slow
    d/dt(central) <-  ka1 * fast + ka2 * slow - cl / v * central
    cp <- central / v
  })
}
byRate <- rxSolve(sc, et(amt = 300, rate = 100, cmt = "sc") |> et(seq(0, 24, by = 0.05)))
byDur  <- rxSolve(sc, et(amt = 300, dur = 3,    cmt = "sc") |> et(seq(0, 24, by = 0.05)))
slide(bind_rows(
        as.data.frame(byRate) |> mutate(record = "rate = 100 mg/h"),
        as.data.frame(byDur)  |> mutate(record = "dur = 3 h")) |>
        ggplot(aes(time, cp, color = record)) +
        geom_line(linewidth = 1.4) +
        scale_color_manual(values = c("rate = 100 mg/h" = red, "dur = 3 h" = navy)) +
        coord_cartesian(xlim = c(0, 12)) +
        labs(x = "time (h)", y = "concentration (mg/L)", color = NULL) +
        theme(legend.position = "bottom"),
      "fig-ratedur.png", w = 9, h = 5.4)

## --- estimation: same data as the post ----------------------------------
set.seed(2026)
rxSetSeed(2026)
nsub <- 60
sampleTimes <- c(0.25, 0.5, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24,
                 48.5, 49, 50, 52, 54, 56, 60, 64, 72)
evPop <- et(amt = 100, cmt = "depot", ii = 24, addl = 2) |>
  et(sampleTimes) |>
  et(id = seq_len(nsub))
sim <- rxSolve(dual, evPop)
doses <- data.frame(ID = seq_len(nsub), TIME = 0, EVID = 1, AMT = 100,
                    II = 24, ADDL = 2, CMT = "depot", DV = NA)
obs <- as.data.frame(sim) |>
  transmute(ID = id, TIME = time, EVID = 0, AMT = 0, II = 0, ADDL = 0,
            CMT = "cp", DV = sim)
dat <- bind_rows(doses, obs) |> arrange(ID, TIME, desc(EVID))

fitF <- nlmixr(dual, dat, "focei", control = foceiControl(print = 0))
fitS <- nlmixr(dual, dat, "saem",  control = saemControl(print = 0))

truth <- c(tka1 = 1.5, tka2 = 0.15, tfr = 0.6, tcl = 4, tv = 40)
bt <- function(fit) fit$parFixedDf[names(truth), "Back-transformed"]
est <- data.frame(parameter = names(truth), truth = truth,
                  FOCEi = bt(fitF), SAEM = bt(fitS))
write.csv(est, "images/estimates.csv", row.names = FALSE)
print(est)

times <- c(0, sampleTimes)
bins  <- c(0, (head(times, -1) + tail(times, -1)) / 2, 80)
set.seed(2026)
slide(vpcPlot(fitS, n = 300, bins = bins, show = list(obs_dv = TRUE)) +
        labs(x = "time (h)", y = "concentration (mg/L)") +
        theme_bw(base_size = 17),
      "fig-vpc.png", w = 11, h = 5.4)

## --- doses added while solving ------------------------------------------
rescue <- function() {
  ini({ka1 <- 1.5; ka2 <- 0.15; fr <- 0.6; cl <- 4; v <- 40})
  model({
    splitBolus(depot, depot, slowdepot)
    f(depot)  <- fr
    f(slowdepot) <- 1 - fr
    d/dt(depot)   <- -ka1 * depot
    d/dt(slowdepot)  <- -ka2 * slowdepot
    d/dt(central) <-  ka1 * depot + ka2 * slowdepot - cl / v * central
    cp <- central / v
    if (t > 0 && t %% 24 == 0 && cp < 0.5) {
      bolus(100)
    }
  })
}
resc <- rxSolve(rescue, et(amt = 100, cmt = "depot") |> et(seq(0, 96, by = 0.05)))
slide(resc |> as.data.frame() |>
        select(time, depot, slowdepot) |>
        pivot_longer(-time, names_to = "compartment", values_to = "amount") |>
        ggplot(aes(time, amount, color = compartment)) +
        geom_vline(xintercept = c(24, 48, 72), colour = "grey85") +
        geom_line(linewidth = 1.3) +
        scale_color_manual(values = cmtCols) +
        scale_x_continuous(breaks = seq(0, 96, by = 24)) +
        labs(x = "time (h)", y = "amount (mg)", color = NULL) +
        theme(legend.position = "bottom"),
      "fig-rescue.png", w = 9, h = 5.4)
