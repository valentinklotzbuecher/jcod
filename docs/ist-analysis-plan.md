# IST exploratory analysis plan

Written on 22 October 2026 before fitting the heterogeneity models below.
The data dimensions, variable dictionary and unadjusted treatment-arm risks
were already inspected. This is a teaching reanalysis, not a preregistered trial
analysis or a claim that a subgroup finding is new.

## Question and population

Estimate the absolute reduction in six-month death or dependence associated
with randomized aspirin allocation. Use corrected IST database version 2.
`OCCODE` 1/2 defines the adverse outcome; 3/4 defines its absence. Codes 0/9
are missing. The primary analysis includes participants with an observed
outcome, with missing-outcome counts and worst-case average-effect bounds
reported separately. Treatment is allocation, irrespective of adherence.

The aspirin contrast averages over the trial's randomized heparin allocation.
The primary outcome regressions therefore model risk conditional on aspirin
and baseline patient characteristics, without conditioning on heparin.
A sensitivity model adds heparin allocation and averages its predicted risks
over the observed allocation proportions. Heparin allocation is not a patient
characteristic in classification analysis. These working logistic models need
not equal a logistic model conditional on every treatment component.

## Two specified working models

Both models include age, sex, age-by-sex, systolic blood pressure, onset-to-
randomization delay, consciousness, atrial fibrillation, previous aspirin,
arm deficit, leg deficit, dysphasia and stroke subtype. Age, pressure and delay
use natural cubic splines with three degrees of freedom. Unknown or unassessable
categorical measurements retain their own categories; numerical predictors
have no missing values in the inspected data.

Implementation note: AF and previous-aspirin unknowns identify exactly the same
pilot participants. Use one shared unknown indicator (the AF factor) and the
recorded previous-aspirin indicator to avoid duplicate model-matrix columns.
This preserves the specified predictor space and does not select a model using
outcome associations.

1. **Constant odds ratio:** one aspirin coefficient. Absolute risk reductions
   can still vary with baseline risk.
2. **Treatment interactions:** additionally allow the aspirin log odds ratio
   to vary with age, sex, age-by-sex, pressure, delay, reduced consciousness,
   recorded atrial fibrillation and recorded leg deficit (eight coefficients).

Compare the models with one likelihood-ratio test of these eight added
coefficients. Report this as exploratory evidence on the log-odds scale.
Do not select interactions by their individual p-values. Report both models'
average effects and sorted distributions, including uncertainty. A sloping
SPE curve is not itself a test of treatment interaction.

## Sorted effects and classification

Use the original SortedEffects 1.7.0 implementation, `bc = FALSE`, 499 bootstrap
draws, seed 420 and the 10th–90th percentile grid in increments of 0.01. Positive
values are control risk minus aspirin risk. Check native point estimates against
direct predictions and weighted quantiles. The full-sample SPE path uses fixed
original prediction profiles and quantile weights; CA refits and reweights its
tail thresholds and characteristic means.

For the interaction model, compare bottom and top 10% in 12 specified baseline
characteristics: age, female proportion, systolic pressure, delay, recorded
atrial fibrillation, atrial-fibrillation status unknown, recorded previous
aspirin, reduced consciousness, recorded leg deficit, recorded dysphasia,
men aged at least 75, and women younger than 65. The two joint demographic
rows are descriptive summaries; overlapping rows do not establish interaction.
Report means, differences, native bootstrap SEs and joint adjusted p-values.
The joint adjustment concerns this specified family only. Do not create native
moment confidence intervals when the package does not return them.

## Validation before interpretation

Use one treatment-stratified 50/50 training/validation split with seed 20261022.
Fit both specified models on training observations only. Freeze their predictions
before examining validation outcomes. In validation data, report observed
randomized-arm risk differences in five predicted-benefit groups and the
top-minus-bottom quintile contrast. Group intervals are descriptive pointwise
intervals. Assess benefit-score calibration with an augmented inverse-probability
pseudo-outcome using training-only nuisance predictions and nominal assignment
probability 0.5, with HC3 standard errors. Report both models; do not choose a
split or specification because it gives the strongest result.
For transparency, the output also includes Holm-adjusted p-values across the
two rankings, separately for calibration slopes and top-minus-bottom contrasts.
These limited corrections do not cover every displayed diagnostic.

Patient bootstrap and validation calculations use an independent-observation
working analysis. They do not reproduce the exact allocation algorithm or
establish robustness to hospital clustering. Record design information that
can be verified. A full clinical reanalysis would need appropriate sensitivity
checks, missing-data assessment and external validation.

## Decision for the presentation

Choose the teaching narrative after inspecting uncertainty and validation.
Supported variation, uncertain apparent variation, and absolute-scale variation
with a common odds ratio are all informative outcomes. Do not search additional
datasets solely until a small heterogeneity p-value appears. Other public trials
remain alternatives for endpoint clarity or teaching value. Check existing
literature before describing a pattern as previously overlooked.
