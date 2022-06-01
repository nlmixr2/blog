---
## Configure page content in wide column
title: "Why nlmixr?" # leave blank to exclude
number_featured: 1 # pulling from mainSections in config.toml
use_featured: false # if false, use most recent by date
number_categories: 3 # set to zero to exclude
show_intro: true
intro: |
  The goal of `nlmixr`, or more accurately `nlmixr2`, is to support easy and robust nonlinear mixed effects models (NLMEMs) in R. 
  
  NLMEMs are used to help identify and explain the relationships between drug exposure, safety, and efficacy and the differences among population subgroups. Most often, they are built using longitudinal PK and pharmacodynamic (PD) data collected during clinical studies. These models characterize the relationships between dose, exposure and biomarker and/or clinical endpoint response over time, variability between individuals and groups, residual variability, and uncertainty. 
  
  NLMEM development in the pharmaceutical space is dominated by a small number of proprietary, commercial software tools. Although this kind of approach to software has some advantages, adopting an open-source, open-science paradigm also has benefits - third-party auditing or adjustments are possible, and the precise model-fitting methodology employed can be determined by anyone with the time and energy to review the source code. We see `nlmixr2` being especially useful in being able to integrate into the rich R ecosystem, and it is well suited for use in scripted, literate-programming workflows of the kind flourishing in the R ecosystem by means of packages such as `knitr` and `rmarkdown`. 

show_outro: true
outro: |
  <i class="fas fa-glass-cheers pr2"></i>Sincere thanks to [Novartis](https://www.novartis.com/), [Certara](https://www.certara.com/), [Human Predictions](https://www.humanpredictions.com/), [Johnson & Johnson](https://https://www.jnj.com/), [LAP&P](https://www.lapp.nl/), [Occams](https://www.occams.com/) and [Seattle Genetics](https://www.seagen.com/) for allowing their associates the time to work on this project!
---

** index doesn't contain a body, just front matter above.
See about/list.html in the layouts folder **