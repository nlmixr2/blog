# Announcement: Dual absorption with one dose record

Post: https://blog.nlmixr2.org/blog/2026-11-04-dual-absorption/
Video: https://youtu.be/RCjb5hoFFDY

---

## Email

**Subject:** Dual absorption in rxode2 and nlmixr2 without duplicating dose records

Hi all,

If you've fit a dual absorption model in NONMEM, you've probably entered
every dose twice, once per depot, and split it with `F1` and `F2`. That
works, but your data no longer says what was given, and every time you
try a different absorption model you may have to rebuild the dataset.

rxode2 and nlmixr2 now split the dose inside the model instead. One line
does it:

```r
splitBolus(depot, depot, slowdepot)
f(depot)     <- fr
f(slowdepot) <- 1 - fr
```

Today's nlmixr2 blog post walks through it:

- **Four directives.** `splitBolus()` and `splitInfusion()` split boluses
  and infusions. `splitInfusionBolus()` and `splitBolusInfusion()` handle
  both, and can turn an oral bolus into a modeled zero-order input for one
  route.
- **Split, copy or move.** Each target gets the full dose, and `f()`
  divides it. Without `f()`, every target gets it all. With a single
  target, the dose moves to a different compartment.
- **The same model simulates and fits.** The post simulates fast/slow and
  zero-order/first-order absorption with rxode2, then fits the fast/slow
  model with FOCEi and SAEM. Both recover the parameters that generated
  the data, and VPCs and other post-fit tools apply the same split.
- **Adaptive dosing too.** `splitBolus()` also splits doses that a model
  adds while it solves, such as rescue doses.

Read the post: https://blog.nlmixr2.org/blog/2026-11-04-dual-absorption/

Or watch the narrated walkthrough: https://youtu.be/RCjb5hoFFDY

All of this works with the current CRAN releases. Bug reports and feature
requests are welcome at https://github.com/nlmixr2/rxode2/issues.

Best,
Matt

---

## LinkedIn

Dual absorption no longer means entering every dose twice.

In NONMEM, a fast and slow absorption model usually needs two dose records
per dose, split with F1 and F2. rxode2 and nlmixr2 now split one dose
record inside the model, so the data says what was given and the model says
where it goes:

💊 splitBolus(depot, depot, slowdepot) sends one dose to two depots, and
f() gives each its share
🔀 Four directives cover boluses, infusions, and a zero-order plus
first-order input from one oral dose
📈 The same model simulates in rxode2 and fits in nlmixr2: FOCEi and SAEM
both recover the true parameters, and VPCs keep the split
🔁 Change the absorption model without rebuilding your dataset

Works with the current CRAN releases.

Post: https://blog.nlmixr2.org/blog/2026-11-04-dual-absorption/
Narrated video: https://youtu.be/RCjb5hoFFDY

#pharmacometrics #nlmixr2 #rxode2 #rstats #popPK
