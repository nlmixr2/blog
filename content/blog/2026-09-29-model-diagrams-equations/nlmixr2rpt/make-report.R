## Build the nlmixr2rpt Word and PowerPoint reports with the model diagram
## and equations.  Run from this directory:
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

## Start from the package's report YAML and merge in model-additions.yaml:
## the new figure, table and preamble, with the model listed first in
## each document.
rpt <- yaml::read_yaml(system.file(package = "nlmixr2rpt", "templates",
                                   "report_fit.yaml"))
add <- yaml::read_yaml("model-additions.yaml")
rpt$options$tabenv_preamble <- add$options$tabenv_preamble
rpt$options$output_dir <- "file.path(tempdir(), '===RUN===')"
rpt$figures <- c(add$figures, rpt$figures)
rpt$tables <- c(add$tables, rpt$tables)
rpt$docx$content <- c(add$docx$content, rpt$docx$content)
rpt$pptx$content <- c(add$pptx$content, rpt$pptx$content)
yaml::write_yaml(rpt, file.path(tempdir(), "report_model.yaml"))

for (ext in c("docx", "pptx")) {
  obnd <- read_template(
    template = system.file(package = "nlmixr2rpt", "templates",
                           paste0("nlmixr_obnd_template.", ext)),
    mapping  = system.file(package = "nlmixr2rpt", "templates",
                           "nlmixr_obnd_template.yaml"))
  obnd <- report_fit(fit = fit, obnd = obnd,
                     rptyaml = file.path(tempdir(), "report_model.yaml"))
  save_report(obnd, paste0("fit-report.", ext))
}
