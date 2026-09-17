## Figures for the adaptive-dosing deck.  Same models and seed as the post
## (../index.Rmd), drawn larger for slides.  Run from presentation/:
##   Rscript make-figures.R
library(rxode2)
library(dplyr)
library(ggplot2)

theme_set(theme_bw(base_size = 17))
slide <- function(p, file, w = 11, h = 5.6) {
  ggsave(file.path("images", file), p, width = w, height = h, dpi = 120)
}
navy <- "#1f497d"; red <- "#b40000"

## --- the idea in three lines -----------------------------------------
titrate <- function() {
  ini({
    ka <- 0.5
    cl <- 1
    v <- 10
  })
  model({
    d/dt(depot)   <- -ka*depot
    d/dt(central) <-  ka*depot - cl/v*central
    cp <- central/v
    if (t > 0 && t %% 24 == 0 && cp < 1) {
      bolus(50)
    }
  })
}
titrateSolve <- rxSolve(titrate, et(amt = 100, time = 0) |> et(seq(0, 96, by = 1)))
slide(ggplot(titrateSolve, aes(time, cp)) +
        geom_hline(yintercept = 1, linetype = 2, colour = "grey50") +
        geom_vline(xintercept = c(24, 48, 72, 96), colour = "grey85") +
        geom_line(linewidth = 1.1, colour = navy) +
        scale_x_continuous(breaks = seq(0, 96, by = 24)) +
        labs(x = "time (h)", y = "concentration"),
      "fig-taste.png", w = 7, h = 5.2)

## --- docetaxel + Friberg ---------------------------------------------
doce <- function() {
  ini({
    cl <- 35.7; v1 <- 6.94; q2 <- 5.58; v2 <- 7.39; q3 <- 12.5; v3 <- 225
    circ0 <- 5.05; mtt <- 113; gam <- 0.196; slope <- 17.9
  })
  model({
    ktr <- 4/mtt
    cp  <- central/v1
    d/dt(central) <- -(cl/v1)*central - (q2/v1)*central + (q2/v2)*periph1 -
                      (q3/v1)*central + (q3/v3)*periph2
    d/dt(periph1) <-  (q2/v1)*central - (q2/v2)*periph1
    d/dt(periph2) <-  (q3/v1)*central - (q3/v3)*periph2
    circS <- max(circ, 1e-4)
    d/dt(prol) <- ktr*prol*(1 - slope*cp)*(circ0/circS)^gam - ktr*prol
    d/dt(tr1)  <- ktr*(prol - tr1)
    d/dt(tr2)  <- ktr*(tr1  - tr2)
    d/dt(tr3)  <- ktr*(tr2  - tr3)
    d/dt(circ) <- ktr*(tr3  - circ)
    prol(0) <- circ0; tr1(0) <- circ0; tr2(0) <- circ0; tr3(0) <- circ0
    circ(0) <- circ0
    anc <- circ
  })
}

bsa <- 1.8
fixedEv <- et(amt = 100*bsa, dur = 1, cmt = "central", ii = 21*24, addl = 5) |>
  et(seq(0, 126*24, by = 6))

set.seed(20260909)
n <- 50
pop <- data.frame(
  id    = 1:n,
  cl    = 35.7*exp(rnorm(n, 0, 0.30)),
  slope = 17.9*exp(rnorm(n, 0, 0.35)),
  circ0 = 5.05*exp(rnorm(n, 0, 0.25)),
  mtt   =  113*exp(rnorm(n, 0, 0.20)))
popFixed <- rxSolve(doce, fixedEv |> et(id = 1:n), params = pop,
                    returnType = "data.frame")

typical <- rxSolve(doce, fixedEv, returnType = "data.frame")

## population on the fixed schedule, the tail highlighted
tailIds <- popFixed |>
  mutate(cycle = pmin(6, floor(time/504) + 1)) |>
  group_by(id, cycle) |>
  summarise(days = sum(anc < 0.5)*6/24, .groups = "drop") |>
  filter(days > 7) |> pull(id) |> unique()
lowDose <- popFixed |> filter(time %in% ((1:5)*504), anc < 1.5) |> pull(id) |> unique()
flag <- union(tailIds, lowDose)
message("tail ids: ", paste(sort(flag), collapse = ", "))

slide(ggplot(popFixed, aes(time/24, anc, group = id)) +
        geom_hline(yintercept = c(0.5, 1.5), linetype = 2, colour = "grey40") +
        geom_line(data = ~ filter(.x, !id %in% flag), colour = "grey80",
                  linewidth = 0.4) +
        geom_line(data = typical |> mutate(id = 0), colour = navy,
                  linewidth = 1.1) +
        geom_line(data = ~ filter(.x, id %in% flag), colour = red,
                  linewidth = 0.8) +
        annotate("text", x = 127, y = c(0.5, 1.5), hjust = 0, vjust = -0.3,
                 label = c("grade 4", "dose floor"), size = 5, colour = "grey30") +
        scale_x_continuous(breaks = seq(0, 126, by = 21),
                           expand = expansion(mult = c(0.01, 0.12))) +
        scale_y_log10() +
        labs(x = "day", y = "ANC (10^9/L, log scale)"),
      "fig-tail.png", w = 10, h = 7)

## --- the label protocol ----------------------------------------------
doceProtocol <- doce |>
  model({
    if (is.na(level)) {
      level   <- 1
      nextDue <- 21*24
      dayLow  <- 0
      lastT   <- 0
    }
    dayLow <- dayLow + (anc < 0.5)*(time - lastT)/24
    lastT  <- time
    newLevel <- level
    if (dayLow > 7) {
      newLevel <- level + 1
    }
    if (newLevel > 3) {
      newLevel <- 3
    }
    mgm2 <- 100
    if (newLevel > 1.5) {
      mgm2 <- 75
    }
    if (newLevel > 2.5) {
      mgm2 <- 55
    }
    doseMg  <- mgm2*bsa
    startMg <- 100*bsa
    if (t == 0) {
      infuseDur(startMg, 1, central)
    }
    if (t > 0 && t < 126*24 && t %% 168 == 0 && t >= nextDue) {
      if (anc >= 1.5) {
        infuseDur(doseMg, 1, central)
        level   <- newLevel
        dayLow  <- 0
        nextDue <- t + 21*24
      } else {
        nextDue <- t + 7*24
      }
    }
  }, append = TRUE, auto = FALSE) |>
  ini(bsa <- 1.8)

popAdapt <- rxSolve(doceProtocol,
                    et(seq(0, 126*24, by = 6)) |> et(id = 1:n),
                    params = pop, maxExtra = 500, returnType = "data.frame")

lab <- c("24" = "subject 24: dose reduced 100, 75, then 55 mg/m2",
         "47" = "subject 47: each cycle delayed one week")
cmp <- bind_rows(
  popFixed |> filter(id %in% c(24, 47)) |> mutate(schedule = "fixed q3w"),
  popAdapt |> filter(id %in% c(24, 47)) |> mutate(schedule = "label protocol")) |>
  mutate(who = lab[as.character(id)])
slide(ggplot(cmp, aes(time/24, anc, colour = schedule)) +
        geom_hline(yintercept = c(0.5, 1.5), linetype = 2, colour = "grey50") +
        geom_line(linewidth = 1) +
        facet_wrap(~who, ncol = 1, scales = "free_y") +
        scale_x_continuous(breaks = seq(0, 126, by = 21)) +
        scale_colour_manual(values = c("fixed q3w" = "grey60",
                                       "label protocol" = navy)) +
        labs(x = "day", y = "ANC (10^9/L)", colour = NULL) +
        theme(legend.position = "top"),
      "fig-compare.png", w = 11, h = 6)

## decisions read back out of the sticky nextDue
decisions <- popAdapt |>
  group_by(id) |> arrange(id, time) |>
  mutate(step = c(0, diff(nextDue))) |> ungroup()
given <- decisions |> filter(step == 504)
held  <- decisions |> filter(step == 168)
print(data.frame(given = nrow(given), minAnc = min(given$anc),
                 held = nrow(held), heldIds = n_distinct(held$id)))
print(table(given$mgm2))
print(decisions |>
        mutate(window = pmin(6, floor(time/504) + 1)) |>
        group_by(id, window) |>
        summarise(days = sum(anc < 0.5)*6/24, .groups = "drop") |>
        summarise(g4 = sum(days > 7)))
print(given |> filter(id %in% c(24, 47)) |> select(id, time, anc, mgm2))
print(held |> select(id, time, anc))
