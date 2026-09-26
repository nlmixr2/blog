## Build the nlmixr2rpt Word and PowerPoint reports.  From nlmixr2rpt 0.2.3
## the default report opens with the model diagram and the model equations,
## so no configuration changes are needed.  Run from this directory:
##   Rscript make-report.R
library(nlmixr2)
library(nlmixr2rpt)
library(onbrand)

one.cmt <- function() {
  ini({
    tka <- log(1.57)
    tcl <- log(2.72)
    tv <- log(31.5)
    eta.ka ~ 0.6
    eta.cl ~ 0.3
    eta.v ~ 0.1
    add.sd <- 0.7
  })
  model({
    ka <- exp(tka + eta.ka)
    cl <- exp(tcl + eta.cl)
    v <- exp(tv + eta.v)
    d/dt(depot) <- -ka * depot
    d/dt(central) <- ka * depot - cl / v * central
    cp <- central / v
    cp ~ add(add.sd)
  })
}
fit <- nlmixr2(one.cmt, nlmixr2data::theo_sd, est = "saem",
               control = saemControl(print = 0),
               table = tableControl(cwres = TRUE))

## Report the fit with the package's templates and default configuration
for (ext in c("docx", "pptx")) {
  obnd <- read_template(
    template = system.file(package = "nlmixr2rpt", "templates",
                           paste0("nlmixr_obnd_template.", ext)),
    mapping  = system.file(package = "nlmixr2rpt", "templates",
                           "nlmixr_obnd_template.yaml"))
  obnd <- report_fit(fit = fit, obnd = obnd)
  save_report(obnd, paste0("fit-report.", ext))
}
