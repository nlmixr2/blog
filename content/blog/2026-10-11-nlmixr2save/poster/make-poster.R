## ACoP 2026 poster for nlmixr2save, 36 in wide x 48 in high (portrait).
##
## Follows the layout of the other nlmixr2 ecosystem posters in ~/src/posters
## (navy header band with the hex logo and title, a blue abstract sidebar on
## the left, captioned figures on the right, authors and a QR code at the
## bottom).  The figures come from the slide deck in ../presentation:
##
##   (cd ../presentation && Rscript make-figures.R)   # plots  -> figs/*.png
##   node export-diagrams.js                          # SVGs   -> figs/*.png
##   Rscript make-poster.R                            # -> pptx (+ pdf)
##
## The PDF for the digital upload is converted with LibreOffice when it is
## available.  LibreOffice substitutes a wider font for Arial Nova Cond, so
## text that fits in that preview also fits in PowerPoint.
library(officer)
library(flextable)
library(magick)
library(qrcode)

## --- settings ---------------------------------------------------------
template <- path.expand("~/src/posters/acop2025-nlmixr2shiny-poster.pptx")
out      <- "acop2026-nlmixr2save-poster.pptx"
logo     <- path.expand("~/src/logos/nlmixr2save/nlmixr2save.png")
blogUrl  <- "https://blog.nlmixr2.org/blog/2026-10-11-nlmixr2save/"
docsUrl  <- "https://nlmixr2.github.io/nlmixr2save/"

navy  <- "#1F4E79"   # header band, as in the 2025 posters
blue  <- "#489BBC"   # abstract sidebar
red   <- "#B40000"   # nlmixr2 red, for emphasis
ink   <- "#0F243E"
font  <- "Arial Nova Cond"

## As in the 2025 posters, every author also carries "The nlmixr2 team".
## Affiliations are numbered in order of first appearance.
team <- "The nlmixr2 team"
authors <- list(
  c("Matthew Fidler",       "Novartis"),
  c("Brendan Bender",       "Genentech"),
  c("William Denney",       "Human Predictions"),
  c("John Harrold",         NA),
  c("Richard Hooijmaijers", "LAP&P"),
  c("Mutaz Jaber",          "Gilead"),
  c("Anne Keunecke",        "LAP&P"),
  c("Rik Schoemaker",       "Occams"),
  c("Max Taubert",          "Novartis"),
  c("Mirjam Trame",         "Certara"),
  c("Justin Wilkins",       "Occams"))

stopifnot(file.exists(template), file.exists(logo))
figs <- function(f) {
  p <- file.path("figs", f)
  if (!file.exists(p)) stop("missing ", p, " -- see the header of make-poster.R")
  p
}

## --- helpers ------------------------------------------------------------
txt <- function(size, color = ink, bold = FALSE, italic = FALSE,
                family = font) {
  fp_text(font.size = size, color = color, bold = bold, italic = italic,
          font.family = family)
}
para <- function(..., align = "left", after = 0) {
  fpar(..., fp_p = fp_par(text.align = align, padding.bottom = after,
                          line_spacing = 1))
}
box <- function(doc, left, top, width, height, fill) {
  ph_with(doc, "", location = ph_location(left = left, top = top,
                                          width = width, height = height,
                                          bg = fill))
}
text <- function(doc, value, left, top, width, height) {
  ph_with(doc, value, location = ph_location(left = left, top = top,
                                             width = width, height = height))
}
## place an image inside a box, keeping its aspect ratio, centered
image <- function(doc, path, left, top, width, height, trim = TRUE) {
  if (trim) {
    trimmed <- file.path(tempdir(), paste0("trim-", basename(path)))
    img <- image_trim(image_read(path), fuzz = 2)
    image_write(image_border(img, "white", "20x20"), trimmed)
    path <- trimmed
  }
  info <- image_info(image_read(path))
  ratio <- info$height / info$width
  w <- min(width, height / ratio)
  h <- w * ratio
  ph_with(doc, external_img(path, width = w, height = h),
          location = ph_location(left = left + (width - w) / 2,
                                 top = top + (height - h) / 2,
                                 width = w, height = h))
}
qr <- function(url, file) {
  png(file, width = 1200, height = 1200)
  par(mar = rep(0, 4))
  plot(qr_code(url, ecl = "M"))
  dev.off()
  file
}

## --- start from the 2025 poster so the page size and theme match -------
doc <- read_pptx(template)
doc <- add_slide(doc, layout = "Blank", master = "Office 2013 - 2022 Theme")
doc <- remove_slide(doc, index = 1)
doc <- on_slide(doc, index = 1)
stopifnot(slide_size(doc)$width == 36, slide_size(doc)$height == 48)

## --- header ---------------------------------------------------------------
doc <- box(doc, 0, 0, 36, 8.2, navy)          # full-width band
doc <- box(doc, 12.5, 8.2, 23.5, 10.3, navy)  # extends down beside the sidebar
doc <- image(doc, logo, 2.2, 0.35, 7.5, 7.5, trim = FALSE)

doc <- text(doc, block_list(
  para(ftext("nlmixr2save", txt(96, "white", bold = TRUE)), align = "center"),
  para(ftext("Fits you can ", txt(72, "white")),
       ftext("read", txt(72, "white", bold = TRUE)),
       ftext(", runs you don’t ", txt(72, "white")),
       ftext("repeat", txt(72, "white", bold = TRUE)),
       align = "center")),
  left = 13.5, top = 0.5, width = 21.5, height = 5.4)

doc <- text(doc, block_list(
  para(ftext("Change one operator: ", txt(48, "white")),
       ftext("fit := nlmixr2(model, data)",
             txt(48, "white", bold = TRUE, family = "Consolas")),
       align = "center")),
  left = 13.5, top = 5.2, width = 21.5, height = 1.4)

## the <- vs := diagram on a white card inside the header
doc <- box(doc, 14.2, 8.4, 20.2, 7.6, "#FFFFFF")
doc <- image(doc, figs("diagram-operator.png"), 14.5, 8.6, 19.6, 7.2)
doc <- text(doc, block_list(
  para(ftext("Re-sourcing a script or re-rendering a report reruns nothing ",
             txt(40, "white")),
       ftext("unless the model, data, or settings changed", txt(40, "white", bold = TRUE)),
       align = "center")),
  left = 13.5, top = 16.3, width = 21.5, height = 1.9)

## --- abstract sidebar ----------------------------------------------------
doc <- box(doc, 0.55, 8.8, 11.95, 39.2, blue)

h  <- function(s) ftext(s, txt(40, "white", bold = TRUE))
b  <- function(s) ftext(s, txt(35, "white"))
bi <- function(s) ftext(s, txt(35, "white", italic = TRUE))
gap <- 24

doc <- text(doc, block_list(
  para(ftext("Saving and caching nlmixr2 fits: portable text files and the := operator",
             txt(52, "white", bold = TRUE)), after = 36),
  para(h("Objectives: "),
       b("Nonlinear mixed-effects (NLME) estimation and simulation take minutes to weeks. In reproducible workflows, re-running models unnecessarily wastes time, and language-specific binary serialization limits sharing results. nlmixr2[1] relied on serialization that was removed from the R ecosystem, making this urgent. We aimed to (1) save nlmixr2 fits as primarily CSV and R source files, and (2) add a caching operator, :=, that re-runs only when the model, data, or settings changed."),
       after = gap),
  para(h("Methods: "),
       b("nlmixr2save was developed within the nlmixr2 ecosystem in R. Fits are decomposed into portable components – the final estimated model (as nlmixr2/rxode2[1–2] code), objective function values, tables, and metadata – written as R and CSV text and reconstructed without binary dependencies. "),
       b("The := operator is a drop-in replacement for <- when calling nlmixr2(), rxSolve(), or any long-running R function. It hashes the model, the estimation-relevant data columns, and all estimation or simulation options, plus the starting seed for random calls. A matching cache is loaded from disk and, for random calls, the final seed state restored; otherwise the call runs and the result is saved."),
       after = gap),
  para(h("Results: "),
       b("Fits round-trip through a single zip file. Loaded fits keep full functionality: diagnostic plots, VPCs, and use as initial estimates for new runs. Switching "),
       bi("fit <- nlmixr2(model, data, est=\"saem\")"), b(" to "),
       bi("fit := nlmixr2(model, data, est=\"saem\")"),
       b(" is the only change needed for caching. Other functions are cached in rds format. Version 0.2.0 adds cache directory and prefix options, package-version checks, and nlmixr2saveShare() to share a fit without the original data."),
       after = gap),
  para(h("Conclusions: "),
       b("nlmixr2save addresses two practical problems: long-term readable storage of nlmixr2 fits, and redundant runs during iterative development. The := operator gives intelligent result management with minimal effort, promoting efficient, reproducible, collaborative modeling – especially when scripts are re-sourced or rendered in dynamic documents."),
       after = gap),
  para(h("References"), after = 4),
  para(ftext("[1] Fidler M, et al. CPT Pharmacometrics Syst Pharmacol. 2019;8(9):621–633.",
             txt(30, "white")), after = 4),
  para(ftext("[2] Wang W, Hallow KM, James DA. CPT Pharmacometrics Syst Pharmacol. 2016;5(1):3–10.",
             txt(30, "white")), after = gap),
  para(h("Install: "), ftext("install.packages(\"nlmixr2save\")",
                             txt(35, "white", family = "Consolas")))),
  left = 1.0, top = 9.2, width = 11.1, height = 38.4)

## --- figure panels ---------------------------------------------------------
caption <- function(doc, s, left, top, width) {
  text(doc, block_list(para(ftext(s, txt(40, ink, bold = TRUE)), align = "center")),
       left = left, top = top, width = width, height = 1.5)
}
colL <- 13.2; colR <- 24.8; colW <- 10.8

## row 1
doc <- caption(doc, "saveFit() writes R source and CSV into one zip", colL, 18.9, colW)
doc <- image(doc, figs("diagram-fitzip.png"), colL, 20.5, colW, 6.6)
doc <- caption(doc, "A loaded fit still makes VPCs", colR, 18.9, colW)
doc <- image(doc, figs("fig-loaded.png"), colR, 20.5, colW, 6.6)

## row 2
doc <- caption(doc, "The cache key hashes what the estimate depends on", colL, 27.6, colW)
doc <- image(doc, figs("diagram-cachekey.png"), colL, 29.2, colW, 5.6)
doc <- caption(doc, "Only changes that matter trigger a refit", colR, 27.6, colW)
doc <- image(doc, figs("fig-timing.png"), colR, 29.2, colW, 5.6)

## row 3
doc <- caption(doc, "Simulations restore the random seed", colL, 35.3, colW)
doc <- image(doc, figs("diagram-seed.png"), colL, 36.9, colW, 5.4)
doc <- caption(doc, "nlmixr2saveShare(): share a fit without the data", colR, 35.3, colW)

share <- data.frame(
  part = c("model, estimates, objective",
           "etas, parameter history",
           "predictions, residuals",
           "original data"),
  noData = c("kept", "kept", "kept", "removed"),
  noFit  = c("kept", "kept", "removed", "removed"))
ft <- flextable(share)
ft <- set_header_labels(ft, part = "", noData = "-noData",
                        noFit = "-noData-noFit")
ft <- font(ft, fontname = font, part = "all")
ft <- fontsize(ft, size = 28, part = "all")
ft <- bold(ft, part = "header")
ft <- color(ft, color = "white", part = "header")
ft <- bg(ft, bg = navy, part = "header")
ft <- bg(ft, i = c(1, 3), bg = "#E8F1F7", part = "body")
ft <- color(ft, color = ink, part = "body")
ft <- color(ft, i = ~ noData == "removed", j = "noData", color = red)
ft <- bold(ft, i = ~ noData == "removed", j = "noData")
ft <- color(ft, i = ~ noFit == "removed", j = "noFit", color = red)
ft <- bold(ft, i = ~ noFit == "removed", j = "noFit")
ft <- align(ft, j = 2:3, align = "center", part = "all")
ft <- padding(ft, padding = 8, part = "all")
ft <- border_remove(ft)
ft <- width(ft, j = 1:3, width = c(4.6, 2.7, 3.5))
doc <- ph_with(doc, ft, location = ph_location(left = colR, top = 37.0))
doc <- text(doc, block_list(
  para(ftext("fit.zip is left unchanged; copies are written next to it",
             txt(28, ink, italic = TRUE)), align = "center")),
  left = colR, top = 41.3, width = colW, height = 0.9)

## --- authors and QR codes ----------------------------------------------------
orgs <- unique(c(na.omit(vapply(authors, `[`, "", 2)), team))
sup <- function(s, size) ftext(s, update(txt(size, ink), vertical.align = "superscript"))
authorRuns <- unlist(lapply(seq_along(authors), function(i) {
  a <- authors[[i]]
  n <- match(c(if (!is.na(a[2])) a[2], team), orgs)
  sep <- if (i < length(authors)) ", " else ""
  list(ftext(a[1], txt(30, ink)), sup(paste(n, collapse = ","), 30),
       ftext(sep, txt(30, ink)))
}), recursive = FALSE)
affilRuns <- unlist(lapply(seq_along(orgs), function(i) {
  sep <- if (i < length(orgs)) ", " else ""
  list(sup(i, 26), ftext(paste0(orgs[i], sep), txt(26, ink)))
}), recursive = FALSE)

doc <- text(doc, block_list(
  para(ftext("Authors", txt(36, ink, bold = TRUE))),
  do.call(para, c(authorRuns, list(after = 12))),
  do.call(para, affilRuns)),
  left = 13.4, top = 42.9, width = 13.6, height = 4.9)

qrBlog <- qr(blogUrl, file.path(tempdir(), "qr-blog.png"))
qrDocs <- qr(docsUrl, file.path(tempdir(), "qr-docs.png"))
doc <- image(doc, qrBlog, 27.3, 43.0, 3.6, 3.6, trim = FALSE)
doc <- text(doc, block_list(para(ftext("Blog post + video", txt(26, ink, bold = TRUE)),
                                 align = "center")),
            left = 26.8, top = 46.7, width = 4.6, height = 0.8)
doc <- image(doc, qrDocs, 31.8, 43.0, 3.6, 3.6, trim = FALSE)
doc <- text(doc, block_list(para(ftext("Documentation", txt(26, ink, bold = TRUE)),
                                 align = "center")),
            left = 31.3, top = 46.7, width = 4.6, height = 0.8)

print(doc, target = out)

## officer writes every shape as a placeholder (<p:ph/>).  An empty
## placeholder -- the colored header and sidebar rectangles -- is neither
## printed nor exported, so turn them all into ordinary shapes and text boxes.
unplaceholder <- function(pptx) {
  dir <- file.path(tempdir(), "unph")
  unlink(dir, recursive = TRUE)
  zip::unzip(pptx, exdir = dir)
  for (f in list.files(file.path(dir, "ppt", "slides"), "\\.xml$", full.names = TRUE)) {
    x <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    x <- gsub("<p:nvPr>\\s*<p:ph/>\\s*</p:nvPr>", "<p:nvPr/>", x)
    x <- gsub("<a:spLocks noGrp=\"1\"/>", "", x, fixed = TRUE)
    x <- gsub("<p:cNvSpPr>\\s*</p:cNvSpPr>", "<p:cNvSpPr txBox=\"1\"/>", x)
    # a placeholder inherits its outline from the layout; a plain shape needs
    # its own geometry, or its fill has nothing to paint
    # (only in a shape's <p:spPr> -- a group's <p:grpSpPr> must not get one)
    x <- gsub("(?s)(<p:spPr>\\s*<a:xfrm>(?:(?!</a:xfrm>).)*</a:xfrm>)(?!\\s*<a:prstGeom)",
              "\\1<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>",
              x, perl = TRUE)
    writeLines(x, f, useBytes = TRUE)
  }
  files <- list.files(dir, recursive = TRUE, all.files = TRUE)
  files <- c("[Content_Types].xml", setdiff(files, "[Content_Types].xml"))
  target <- file.path(normalizePath(dirname(pptx)), basename(pptx))
  unlink(target)
  zip::zip(target, files = files, root = dir)
}
unplaceholder(out)
message("wrote ", out)

## --- PDF for the digital upload ------------------------------------------------
pdf <- sub("pptx$", "pdf", out)
unlink(pdf)
if (nzchar(Sys.which("soffice"))) {
  # R's own LD_LIBRARY_PATH breaks LibreOffice's shared libraries
  status <- system2("env", c("-u", "LD_LIBRARY_PATH", "soffice", "--headless",
                             "--convert-to", "pdf", out), stdout = FALSE)
  if (status == 0 && file.exists(pdf)) message("wrote ", pdf)
  else warning("LibreOffice could not convert ", out, " to PDF")
}
