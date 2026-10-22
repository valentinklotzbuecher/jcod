# Colon chemotherapy exploratory analysis plan

Recorded on 22 October 2026 before fitting the models below. The trial arms,
baseline distributions, outcome availability and crude three-year arm risks
were inspected while choosing this dataset. This is an exploratory teaching
analysis, not a preregistration or a search for an unreported subgroup.

## Population, treatment and endpoint

Use the pinned public `survival::colon` data described in `colon-data.md`.
Retain the death record (`etype == 2`) once per person and compare randomized
levamisole plus fluorouracil with observation. Exclude the levamisole-only arm.
The selected comparison has 619 participants.

The endpoint is death by 3 * 365.25 days. Death at or before that horizon is an
event; follow-up to or beyond it establishes the outcome. One person censored
before the horizon has unknown status, not a zero outcome. Report treatment-arm
counts and worst-case crude risk-difference bounds for that one unknown outcome.
This horizon was chosen for outcome completeness and interpretability, before
any treatment-interaction fitting.

The primary reference population has known endpoint and complete baseline age,
sex, positive-node count, differentiation and extent: 593 participants. Other
listed baseline characteristics are complete in this population. This avoids
presenting imputed values as measured CA characteristics; it narrows the target
population. Report the exclusions and their arm distribution. Do not extrapolate
automatically to all trial participants. A specified sensitivity below retains
all 618 known endpoints.

## Two working logistic models

Define benefit as **observation risk minus chemotherapy risk**. Both models use:

- Age with a natural spline (three degrees of freedom), female indicator and
  centered linear age-by-female term; centered age is (age - 60) / 10.
- log(1 + number of positive nodes), poor differentiation (grade 3), and
  tumour extent at least 3 (serosa or adjacent structures).
- Bowel obstruction, tumour adherence to nearby organs, and a long interval
  between surgery and registration, as coded in the source dictionary.

The first model has one treatment coefficient, so its treatment odds ratio is
constant while absolute benefit may vary. The second adds six treatment
interactions: centered age, female indicator, their product, log node count,
poor differentiation and extent at least 3. Compare these six coefficients
jointly with a likelihood-ratio test. This is a log-odds interaction test, not a
test of constant risk differences.

The rare perforation indicator remains available for descriptive CA, but does
not enter either model. No stepwise interaction selection, alternative age
cutoff search, or model choice based on the resulting p-values will be used.
Check convergence, finite coefficients and full rank. Record numerical warnings
or unstable bootstrap fits; do not silently discard draws or change models
until a desired result appears.

## Sorted effects and classification

Use unmodified SortedEffects 1.7.0, logit, 499 bootstrap draws, seed 420,
`bc = FALSE`, and the 10th–90th percentiles in increments of .01. Report both
models' average effects and sorted curves with native 95% uniform bands.
Check point estimates directly and reconstruct native bootstrap calculations
independently if feasible. The native full-sample SPE path holds original
prediction profiles and quantile weights fixed.

For the interaction model, compare bottom and top 10% across these twelve
characteristics as one CA family:

1. Age.
2. Female proportion.
3. Positive-node count.
4. Poor differentiation.
5. Extent at least 3.
6. Bowel obstruction.
7. Perforation.
8. Tumour adherence to nearby organs.
9. Long surgery-to-registration interval.
10. Men aged at least 65.
11. Women younger than 55.
12. More than four positive nodes, derived from the count.

The demographic cutoffs are descriptive choices made before fitting, not
clinically established treatment rules. Native CA refits the model and
reweights thresholds and characteristic means. Align its returned columns by
name. Report tail means, differences, native SEs and joint p-values. Do not
invent native moment confidence intervals. A tail-characteristic comparison
is not an independent test of effect modification.

## One held-out ranking check

Use one 50/50 split stratified only on randomized treatment, seed 20261024.
Fit both specified models on training observations. Freeze predictions before
examining validation outcomes. Use **tertiles**, given the small validation
sample, with thresholds based on validation predictions alone. Report observed
arm risk differences with pointwise uncertainty and the top-minus-bottom
tertile contrast. Do not choose a new split in response to the result.

Regress an AIPW benefit pseudo-outcome, calculated from training-only risk
models and nominal treatment probability .5 within the two retained arms, on
the centered predicted benefit. Use HC3 standard errors. A slope of zero means
no linear association with the ranking; one corresponds to linear calibration.
Report both models, with raw and Holm-adjusted p-values across the two ranking
slopes. This limited adjustment does not cover all diagnostics, datasets,
figures or model choices in the journal-club project.

The validation is conditional on one small training sample. Wide intervals or
a nonsignificant test do not demonstrate absence of heterogeneity; successful
internal validation would still not establish an externally validated rule.

## Specified sensitivity checks

These are point-estimate/model checks; the primary analysis remains the one
above, regardless of which appears more favorable.

- **Missing baseline measurements:** retain all 618 known endpoints. Fill
  missing node counts with 2 (the selected sample's baseline median), add a
  node-missing indicator, code unknown poor differentiation as zero and add a
  grade-missing indicator. Apply both model specifications and report average
  effects and their joint interaction test. These working imputations are not
  multiple imputation or a proof that missingness is ignorable.
- **One unknown endpoint:** in the primary baseline-complete population,
  separately set the early-censored person's outcome to zero and one; refit
  both models and summarize how average effects and interactions change.
- **Inconsistent node coding:** the source flags disagreement between `nodes`
  and `node4`. Replace the log-node term and its treatment interaction with
  a more-than-four-nodes indicator. Fit this variant once using the count and
  once using the supplied indicator; compare average effects and rankings.
  This also changes functional form, so neither binary variant replaces the
  primary continuous-node model. Do not include both representations together.

All inference uses a working patient-level model and bootstrap. The precise
trial allocation algorithm and possible center dependence have not been
reconstructed. Numerical agreement with the package does not establish model
correctness, interval coverage, causal effects for individual people, or a
previously unknown clinical interaction. Report all specified results.

## Numerical amendment after the first fit

Recorded after inspecting the primary results on 22 October 2026. The native
classification bootstrap encountered a numerical failure: its 20,000-total
weights led to 141 nonconverged logistic fits out of 499 and 137 draws with
undefined tail means. The package's finite final SEs and p-values therefore
cannot be treated as successful classification inference. Those raw outputs
are retained for audit, not used to support findings.

A separate stabilized reconstruction will retain the **same 499 draws, model,
profiles, 20,000-total threshold weights, tail definitions and moment formulas**.
The ordinary count-weight logistic fits converged for all draws. A common
positive scaling of likelihood weights does not change the logistic maximum,
so use those coefficients to initialize the 20,000-weight fits. Check convergence,
rank, likelihood scores and prediction agreement before calculating CA moments.
No draw may be discarded. Report this as a stabilized reconstruction, distinct
from unmodified native output, with numerical comparisons and limitations.
This changes numerical initialization, not the subgroup hypotheses or model.
