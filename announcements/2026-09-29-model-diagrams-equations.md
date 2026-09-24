# Announcement: Model diagrams and equations, straight from the code

Post: https://blog.nlmixr2.org/blog/2026-09-29-model-diagrams-equations/
Video: https://youtu.be/TsfkmEdiT7o

---

## Email

**Subject:** nlmixr2: model diagrams and equations generated straight from your model code

Hi all,

Most pharmacometric reports open their methods section with a compartment
diagram and the model equations, and both are usually made by hand. When
the model changes during the analysis, the code gets updated but the figure
and the math often don't.

Today's nlmixr2 blog post shows how to generate both from the model itself,
so they always match the model you actually ran:

- **Automatic model diagrams (nlmixr2plot 5.2.0).** `modelDiagram()` reads
  the model's ODEs and draws the compartment diagram: dosing, transit,
  peripheral and elimination compartments, plus pharmacodynamic stimulation
  and inhibition read directly from the equations. The layout was checked
  against all 3043 models in nlmixr2lib.
- **LaTeX model equations (nlmixr2extra).** A model or fit at the end of an
  R Markdown or Quarto chunk prints as aligned equations, including
  covariate switches on character values such as `SEX == "Female"`.
- **One report, three formats.** A complete R Markdown report that knits the
  diagram, equations and parameter table to Word, HTML and PDF, with native,
  editable Word equations.
- **nlmixr2rpt integration.** Two entries in your nlmixr2rpt configuration
  file put the diagram and native equations at the front of your Word and
  PowerPoint reports.

Read the post and download the example reports:
https://blog.nlmixr2.org/blog/2026-09-29-model-diagrams-equations/

Or watch the narrated walkthrough: https://youtu.be/TsfkmEdiT7o

Thanks to Bill Denney for the equation support in nlmixr2extra and to John
Harrold for nlmixr2rpt. If a diagram looks wrong for one of your models,
please open an issue at https://github.com/nlmixr2/nlmixr2plot/issues. The
models that trip up the parser are exactly the ones we want to see.

Best,
Matt

---

## LinkedIn

Your report's model diagram and equations should never disagree with the
model you ran.

In most pharmacometric reports, both are made by hand, and when the model
changes they quietly drift out of date. The new nlmixr2 post shows how to
generate them straight from the model code:

📐 Automatic compartment diagrams with nlmixr2plot's `modelDiagram()`,
covering PK, transit, TMDD and PD models (stimulation or inhibition is read
from the equations)
🧮 LaTeX model equations from nlmixr2extra, including covariate switches on
character values like `SEX == "Female"`
📄 One R Markdown report that knits to Word, HTML and PDF, with native,
editable Word equations
📊 A two-entry nlmixr2rpt setup that opens your Word and PowerPoint reports
with the model

Re-render the report and the diagram, equations and estimates all update
together.

Thanks to Bill Denney and John Harrold, whose work on nlmixr2extra and
nlmixr2rpt makes this possible.

Post: https://blog.nlmixr2.org/blog/2026-09-29-model-diagrams-equations/
Narrated video: https://youtu.be/TsfkmEdiT7o

#pharmacometrics #nlmixr2 #rstats #popPK #reproducibleresearch
