# Stabilize binomial bootstrap fits and reject invalid CA inference

Classification and subpopulation bootstraps enlarge weights to a total near 20,000 for weighted quantiles. Those weights also reach the binomial GLM. With an interaction model this can destabilize the default IRLS fit even when the same draw fits successfully with mean-one weights. In CA, non-finite moments can then pass through `na.rm = TRUE`; an entirely invalid draw becomes `-Inf` in the bootstrap maximum and is counted as a non-exceedance in joint p-values.

This change normalizes only the logit/probit fitting weights inside `peestimate()`. A common positive scaling preserves the weighted likelihood maximizer. Original weights remain available for quantiles, subgroup weights, and classification moments. Nonconverged binomial fits now raise an error. CA also stops before inference if the point estimate or any bootstrap statistic is non-finite, or if a moment standard error is zero/non-finite. No bootstrap draws are discarded or replaced.

The new dependency-free tests include a deterministic 120-row reproduction, logit/probit scale invariance, factor and grouped-binomial responses, unchanged subgroup weights, protection against data columns shadowing fitting weights, an independent reconstruction of CA estimates/standard errors/joint p-values, and failure cases for nonconvergence, invalid draws, and zero IQR. A distribution-CA smoke test covers the shared validity check.

Validation:

- `R CMD build` and `R CMD check --no-manual` on R 4.5.0: no errors or warnings; one existing lost-braces NOTE in `man/spe.Rd:101`. Examples, tests, and vignette rebuilding pass.
- The production patch also applies to CRAN 1.7.0; both regression files pass against that version in a separate library. This PR targets this repository's current 1.6.0 branch.
- In a separate 593-person colon-trial interaction-model reproduction, all 499 patched CA draws converge and produce finite moments. Estimates, standard errors, and joint p-values exactly match an independent reconstruction using normalized fitting weights. A zero observed contrast now has joint p-value 1; the unpatched path returned 362/499 after 137 invalid draws.

The change preserves the estimator's target, but does not claim bit-for-bit equality with alternative convergent initialization schemes. Existing strict weighted-quantile boundary comparisons can change tail membership after tiny prediction differences; that separate numerical issue is left unchanged here.
