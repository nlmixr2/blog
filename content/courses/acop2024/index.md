---
author: Matt Fidler, Bill Denney, Mirjam Trame, Theo Papathanasiou, Justin Wilkins
categories:
- workshop
date: "2024-11-08"
draft: false
event: ACoP (2024)
event_url: "https://www.go-acop.org/default.asp?id=46&keuze=meeting&mid=21"
excerpt: This is the course at ACoP in Phoenix, Arizona on 11 November 2024.
featured: true
layout: single
links:
- icon: door-open
  icon_pack: false
  name: website
  url: https://acop2024.eventscribe.net/agenda.asp?startdate=11/14/2024&enddate=11/14/2024&BCFO=&pfp=BrowsebyDay&fa=&fb=&fc=&fd=
- icon: github
  icon_pack: fab
  name: code
  url: https://github.com/nlmixr2/courses/tree/main/ACoP2024
- icon: file-powerpoint
  icon_pack: fa
  name: powerpoint
  url: https://github.com/nlmixr2/courses/raw/main/ACoP2024/Tutorial-nlmixr2_ACoP15.pptx
location: "Phoenix, Arizona USA"
show_post_time: true
subtitle: "ACoP 2024"
title: "Using Past Models to Bridge to Open Models and Open Science using nlmixr2"
---

## Workshop target audience

Pharmacometricians/modelers with basic knowledge on model building,
evaluation and qualification. Knowledge of `nlmixr2`, `Monolix` and/or
`NONMEM` helpful. Basic knowledge of writing and executing R scripts
is required.

## Workshop overview

Open science is a movement to make science available to all levels of
society. The science in much of population-based pharmacometrics in
the past has been focused on developing nonlinear mixed effects models
in proprietary tools like `NONMEM` and `Monolix`. This makes it necessary
to have licenses of whatever tool is being used to be able to explore
models with your data. Special populations in low to middle income
countries may not have access to these tools which makes analysis of
additional clinical data in these regions more challenging. This
tutorial discusses automated methods to import `NONMEM` and `Monolix` into
the open-source framework `rxode2` and `nlmixr2` using packages like
`nonmem2rx`, `monolix2rx` and `babelmixr2`. Once converted, you can use
these models to make patient-based adaptive dosing decisions, simulate
other dosing scenarios and even use the model to analyze new data and
explore any regional differences in drug effect.

## Learning Objectives

- Participants learn the basics of how a `nlmixr2`/`rxode2` model is
  written and can write a model themselves.

- Participants will know how to import `NONMEM` and `Monolix` models into
  the nlmixr2/rxode2 model function using `nonmem2rx` and `monolix2rx`

- Upon completion, participants will know how to simulate new dosing
  scenarios using `rxode2`

- Upon completion, participants will know how to (re-)estimate new
  data using `nlmixr2`

- Participants will learn how to use imported models to design new
  studies using `babelmixr2` and `PopED`

- Participants learn how to individualize dosing clinically using
  `posologyr`

## Workshop materials

The materials for the course are available in the [nlmixr2 courses repository](https://github.com/nlmixr2/courses/blob/main/ACoP2024/).
