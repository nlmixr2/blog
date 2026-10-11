# nlmixr2save announcement copy

Supporting copy for the [nlmixr2save blog
post](https://blog.nlmixr2.org/blog/2026-10-11-nlmixr2save/) and the ACoP 2026
poster.  Not published by Hugo (this folder is outside `content/`).

Links used below:

- Blog post: https://blog.nlmixr2.org/blog/2026-10-11-nlmixr2save/
- Video: https://youtu.be/TD7yhaaQToE
- Docs: https://nlmixr2.github.io/nlmixr2save/
- CRAN: https://cran.r-project.org/package=nlmixr2save

---

## LinkedIn post

Your model takes an hour to fit. You change a comment in the script, source it
again, and wait another hour.

`nlmixr2save` is on CRAN, and it fixes that with one character:

fit <- nlmixr2(model, data, est="saem")  # runs every time
fit := nlmixr2(model, data, est="saem")  # runs once, then loads

`:=` hashes the model, the estimation-relevant data columns, and every
estimation option. If nothing that matters changed, your fit is loaded from
disk in a fraction of a second. Add a notes column to your data and it still
loads. Change DV, a covariate, or a control setting and it refits. For
simulations, the random seed is part of the check and is restored on load, so
re-sourcing a script gives you the same random numbers you would have had.

The other half of the package is about keeping fits readable. `saveFit()`
writes a fit as R source and CSV inside a single zip: the final estimated
model, the parameter estimates, the objective function, the eta table, the
parameter history and the data. You can open it in a text editor or a
spreadsheet years from now, with no dependency on how a particular package
version serialized its internals. We learned that the hard way when `qs` left
CRAN. A loaded fit is a working fit, so diagnostic plots, VPCs and model piping
all still work.

New in 0.2.0: cache directory and prefix options for projects and reports,
package-version checks that tell you when a cache came from different nlmixr2
versions, and `nlmixr2saveShare()` to share a fitted model when the
subject-level data cannot leave your organization.

install.packages("nlmixr2save")

Write-up and runnable code: https://blog.nlmixr2.org/blog/2026-10-11-nlmixr2save/
Short talk (7 min): https://youtu.be/TD7yhaaQToE

At ACoP this week? Come find the poster and say hello.

#pharmacometrics #ACoP2026 #rstats #nlmixr2 #PKPD #reproducibility

---

## Email announcement

**Subject:** nlmixr2save on CRAN: readable saved fits and the `:=` caching
operator

Hello all,

`nlmixr2save` 0.2.0 is on CRAN. It addresses two everyday problems in
nonlinear mixed-effects workflows: fits that stop loading, and models that
re-run when nothing has changed.

**Saving fits you can still open later**

`saveFit(fit)` decomposes a fit into portable pieces and writes them as R
source and CSV inside one zip file: the final estimated model as
nlmixr2/rxode2 code, the parameter estimates, objective function values, eta
table, parameter history and the original data. The result is inspectable
outside R and does not depend on a binary serialization format. This matters
because that dependency already broke once, when `qs` was removed from CRAN and
nlmixr2est had to move to `qs2` and later to base R serialization.

`loadFit()` rebuilds a fit that still works: diagnostic plots, VPCs, and piping
into the next model run. Saved fits also record the nlmixr2est and rxode2
versions that produced them and warn when those differ from what is installed.

**Caching with `:=`**

Replace `<-` with `:=` when you call `nlmixr2()`:

    fit := nlmixr2(model, data, est = "saem")

The operator hashes the model, the estimation-relevant data columns, and all
estimation and table options. A matching cache loads from disk; otherwise the
model runs and the result is saved. Changes that do not affect the estimate,
such as adding an unused column to the data, do not trigger a refit, while
changing DV, a covariate or a control setting does.

`:=` works with any long-running function, not just `nlmixr2()`. Results that
are not fits are cached as `.rds`. For random calls such as `rxSolve()`, the
starting seed is part of the cache key and the ending seed state is restored on
load, so re-sourcing a script from the same seed reproduces the rest of the
script exactly.

**Also in 0.2.0**

- `nlmixr2save.dir` and `nlmixr2save.prefix` to keep caches together, per
  project or per report.
- `nlmixr2save.check = FALSE` to trust a committed cache, so a document renders
  identically on every machine, with `nlmixr2saveInvalidate()` to clear it.
- `nlmixr2saveShare()` to write a copy of a saved fit without the original data,
  and optionally without the per-observation table, for sharing a fitted model
  when the data cannot be shared.

**Getting it**

    install.packages("nlmixr2save")

- Write-up with runnable examples:
  https://blog.nlmixr2.org/blog/2026-10-11-nlmixr2save/
- Short talk (7 minutes): https://youtu.be/TD7yhaaQToE
- Documentation: https://nlmixr2.github.io/nlmixr2save/
- Issues and ideas: https://github.com/nlmixr2/nlmixr2save/issues

There is a poster on this at ACoP 2026 in National Harbor (October 11-14) if
you would like to talk it through in person.

Best regards,
Matthew Fidler
on behalf of the nlmixr2 team
