---
author: Rik Schoemaker
categories:
- workshop
date: "2022-06-22"
date_end: "2022-06-28"
draft: false
event: PAGE (2022)
event_url: "https://www.page-meeting.org/default.asp?id=47&keuze=meeting"
excerpt: This is the course we presented at PAGE 2022 in Ljubljana, Slovenia.
featured: true
layout: single
links:
- icon: door-open
  icon_pack: fas
  name: website
  url: "https://www.page-meeting.org/default.asp?id=47&keuze=meeting"
- icon: github
  icon_pack: fab
  name: code
  url: https://github.com/nlmixr2/courses/tree/main/PAGE2022
- icon: file-download
  icon_pack: fas
  name: download
  url: https://github.com/nlmixr2/courses/raw/main/PAGE2022/CourseMaterial.zip
location: Ljubljana, Slovenia
show_post_time: false
subtitle: PAGE 2022
title: "An open-source pharmacometrician’s workflow in R: from exploration (xGx) to model building (nlmixr) and diagnostics (ggPMX)"
---

## Workshop target audience

Pharmacometricians/modelers with basic knowledge on model building, evaluation and qualification. Basic knowledge of writing and executing R scripts is required.

## Workshop overview

The workshop will provide a tutorial on three open–source R packages, supporting the pharmacometrics workflow in exploring and modeling clinical data:

* Exploration of the data using the Exploratory Graphics (`xgxr`) package, available on CRAN and GitHub (https://opensource.nibr.com/xgx/).
* Population PK and PKPD modeling of the data using `nlmixr2` package, available on CRAN and GitHub (https://www.nlmixr2.org). `nlmixr2` builds on the ODE simulation package `rxode2`, by implementing parameter estimation algorithms like SAEM and FOCE with interaction.
* Model building and validation using `ggPMX`, a library of reproducible diagnostic plots available on CRAN and on Github (https://github.com/ggPMXdevelopment/ggPMX).

The combination of the three open-source R packages provides the pharmacometrics modeling community the opportunity to reduce the learning curve needed to become proficient on each of the different tasks using a stepwise framework.

## Workshop Learning Objectives

During the workshop, the participants will have the opportunity to become familiar with the packages with extensive hands-on sessions, which will follow the initial lectures on `xgxr`, `ggPMX`, and `nlmixr2`. The participants will have a chance to experience the stepwise framework of the Pharmacometrics workflow. First, through a question-based approach, `xgxr` helps to uncover useful insights that can be revealed without complex modelling and to identify aspects of the data that may be explored further. Next, `nlmixr2` is used for building an adequate population model refined by the exploration of the data to characterize the dose-exposure-response relationship. Finally, the model evaluation, validation and reporting is driven by `ggPMX`. The model diagnostic plots help in selecting the model describing the data most accurately.

We're going to be delivering this course on Tuesday 28 June in Ljubljana! We'll expand this page with photos and suchlike after the course has been given.

## Partner materials

Our colleagues in the `ggPMX` team have made their course materials for this session available [here](https://github.com/ggPMXdevelopment/trainings/tree/main/PAGE2022)!


