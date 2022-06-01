---
title: nlmixr2 is here
author: the nlmixr2 Development Team
date: '2022-06-01'
categories: [nlmixr2]
tags: [new-version]
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(collapse = TRUE)
library(blogdown)
```

# nlmixr2

Over the past half year, a lot of changes have been happening behind the scenes, and the time has finally come to reveal them! `nlmixr2` will be the version in active development going forward, taking over from `nlmixr`, starting with the current CRAN version, 2.0.6. Our new home on GitHub is [here](https://www.github.com/nlmixr2/nlmixr2), and on CRAN, we're [here](https://cran.r-project.org/package=nlmixr2). 

The reasons for the name and format change are many, but most importantly, we've taken this step to improve overall user experience and to help us maintain the project more effectively. 

These are the things that have changed that you might notice...

+ The big one: `nlmixr` has been split into several modular packages. `nlmixr2` is an umbrella package, wrapping up lower level packages `rxode2`, `nlmixr2est`, `nlmixr2extra`, `nlmixr2data`, `nlmixr2plot`, `lotri` and `PreciseSums`.
  + `rxode2` is an R package for solving and simulating from ODE-based models. Models are converted to C to maximise speed and efficiency. `rxode2` is the beating heart of `nlmixr2`.
  + `nlmixr2est` provides the core estimation routines for `nlmixr2`.
  + `nlmixr2extra` provides the tools to help with common pharmacometric tasks like bootstrapping and covariate selection, amongst others.
  + `nlmixr2plot` provides basic plotting support for `nlmixr2` models. You'd be better off using `xpose.nlmixr`, quite frankly, but it's here for legacy purposes. 
  + `nlmixr2data` rolls up all the `nlmixr2` example datasets in once convenient place.
  + `lotri` was developed to easily specify block-diagonal matrices with (lo)wer (tri)angular matrices. Think of it as having won the (badly spelled) lotri (or lottery). It's just that cool.
  + `PreciseSums` brings a few algorithms for precise sums and products to R. They are ported from Python and NumPy for the most part.
+ `rxode2` can simulate directly from `nlmixr2` models now. 
+ SAEM models no longer require MU-referencing to work.

# Dig in

We have a lot of HOWTOs, example models, and other bits and pieces for getting started up at our core site, https://www.nlmixr.org. Go take a look. 

# The Development Team

Our development team, led by *Matt Fidler*, is spread across the world, with contributors based in the United States (Matt, *Bill Denney*, *John Harrold*, *Mirjam Trame*, *Yuan Xiong* and *Huijuan Xu*), The Netherlands (*Richard Hooijmaijers* and *Rik Schoemaker*), Germany (*Justin Wilkins*) and Switzerland (*Theodoros Papathanasiou*). 
