## Figures for the model diagrams and equations deck.  Same models as the
## post (../index.Rmd), drawn larger for slides.  Needs nlmixr2plot with
## white arrow-label backgrounds (nlmixr2/nlmixr2plot#77).  Run from
## presentation/:
##   Rscript make-figures.R
library(nlmixr2plot)
library(ggplot2)

## a small canvas keeps the fixed-size node labels readable once scaled up
slide <- function(p, file, w = 6, h = 3.8) {
  p <- p + theme(text = element_text(size = 12))
  ggsave(file.path("images", file), p, width = w, height = h, dpi = 200)
}

## --- two-compartment model ---------------------------------------------
two.cmt <- function() {
  ini({
    tka <- log(1.5)
    tcl <- log(3)
    tv <- log(20)
    tq <- log(2)
    tvp <- log(40)
    eta.ka ~ 0.1
    eta.cl ~ 0.1
    add.sd <- 0.2
  })
  model({
    ka <- exp(tka + eta.ka)
    cl <- exp(tcl + eta.cl)
    v <- exp(tv)
    q <- exp(tq)
    vp <- exp(tvp)
    d/dt(depot) <- -ka * depot
    d/dt(central) <- ka * depot - cl / v * central - q / v * central +
      q / vp * periph
    d/dt(periph) <- q / v * central - q / vp * periph
    cp <- central / v
    cp ~ add(add.sd)
  })
}
slide(modelDiagram(two.cmt, engine = "ggplot2", labels = TRUE),
      "fig-two-cmt.png")

## --- indirect response (inhibition of production) ----------------------
pk.turnover <- function() {
  ini({
    tktr <- log(1)
    tka <- log(1)
    tcl <- log(0.1)
    tv <- log(10)
    poplogit <- 2
    tec50 <- log(0.5)
    tkout <- log(0.05)
    te0 <- log(100)
    prop.err <- 0.1
    pdadd.err <- 10
  })
  model({
    ktr <- exp(tktr)
    ka <- exp(tka)
    cl <- exp(tcl)
    v <- exp(tv)
    emax <- expit(poplogit)
    ec50 <- exp(tec50)
    kout <- exp(tkout)
    e0 <- exp(te0)
    DCP <- center / v
    PD <- 1 - emax * DCP / (ec50 + DCP)
    effect(0) <- e0
    kin <- e0 * kout
    d/dt(depot) <- -ktr * depot
    d/dt(gut) <- ktr * depot - ka * gut
    d/dt(center) <- ka * gut - cl / v * center
    d/dt(effect) <- kin * PD - kout * effect
    cp <- center / v
    cp ~ prop(prop.err)
    effect ~ add(pdadd.err)
  })
}
slide(modelDiagram(pk.turnover, engine = "ggplot2"), "fig-turnover.png")

## --- target-mediated drug disposition ----------------------------------
tmdd <- rxode2::rxode2({
  d/dt(central) <- -kel * central - kon * central * target + koff * complex
  d/dt(target) <- ksyn - kdeg * target - kon * central * target +
    koff * complex
  d/dt(complex) <- kon * central * target - koff * complex - kint * complex
})
slide(modelDiagram(tmdd, dosing = "central", engine = "ggplot2"),
      "fig-tmdd.png", h = 2.4)

## --- report preview (rendered by ../report/_model-report.Rmd) ----------
file.copy("../report/model-report-pages.png", "images/fig-report-pages.png",
          overwrite = TRUE)

## --- nlmixr2rpt Word report preview (built by ../nlmixr2rpt/make-report.R)
file.copy("../nlmixr2rpt/nlmixr2rpt-pages.png", "images/fig-rpt-pages.png",
          overwrite = TRUE)
