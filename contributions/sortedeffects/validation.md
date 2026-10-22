Validation of commit `a88dce12b5bc70648133edf82f51274963fcd57f` completed on R 4.5.0. The patch targets upstream version 1.6.0; its production changes apply cleanly to CRAN 1.7.0 at `18a1196e474ee1b62d6722754e8e377cba4ddc1f`.

- `R CMD build` built the source package and vignette.
- `R CMD check --no-manual` completed with 0 errors, 0 warnings, and 1 existing NOTE: lost braces in `man/spe.Rd:101`. Examples, regression tests, and vignette rebuilding passed.
- Both base-R regression files passed against separately installed patched versions 1.6.0 and 1.7.0. The fitting-weight invariance regression fails on unpatched 1.7.0.
- Two independent reviews checked the fitting weights, preserved quantile weights, failure guards, and data-mask evaluation. Literal-vector argument passing prevents unrelated data columns from shadowing fitting weights.
- The original package installation and JCOD trial-analysis outputs were left unchanged.

The regression suite covers logit/probit scale invariance, numeric and factor Bernoulli responses, grouped-binomial responses, unchanged subgroup weights, colliding data-column names, public CA against an independent 39-draw reconstruction, a distribution-CA smoke check, nonconvergence, non-finite point estimates, partially and wholly invalid bootstrap draws, and zero bootstrap IQR. Tests add no package dependencies.

The [portable colon check](verify-colon.R) uses the same 593 participants, interaction formula, 499 draws, and seed 420 as the JCOD numerical audit. Every independent fit converges with finite coefficients and full rank, every tail has positive weight, and all classification moments are finite. No draw is dropped or replaced. The patched public `ca()` output equals the independent calculation exactly for all 12 point estimates, standard errors, and joint p-values: see [the comparison CSV](colon-comparison.csv). Perforation has zero observed contrast and joint p-value 1.

An additional audit compared these normalized fits with the earlier convergent warm-start reconstruction used in the slides. The maximum prediction difference was 8.36e-7, with median 8.77e-10 across draws. Tail membership nevertheless differed in 377 draws; every changed profile lay within 5e-16 of its own cutoff in both fits. The largest standard-error difference was 0.2548302 age-years and the largest joint-p difference was 0.03807615. These are differences between convergent numerical implementations of the same target, not agreement to machine precision.

Hmisc's weighted quantile path can round numeric effect values when it combines tied values. Together with strict `<=` / `>=` comparisons, this explains sensitivity at numerical boundaries. For example:

```r
x <- rep(c(.1234567890123454, .9234567890123456), each = 2)
w <- rep(5000, 4)
q <- Hmisc::wtd.quantile(x, w, c(.1, .9))
c(low = sum(x <= q[1]), high = sum(x >= q[2]))
```

In the tested Hmisc version, both tails are empty even though the quantiles should lie on observed values. This separate issue is left unchanged by the focused fitting patch. The new validity checks prevent resulting non-finite CA moments from silently producing p-values. Numerical convergence alone does not establish statistical coverage or validate a clinical subgroup claim.
