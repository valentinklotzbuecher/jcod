# Original-package inference for the simulated example

This analysis uses the unmodified **SortedEffects 1.7.0** package, pinned to
CRAN mirror commit `18a1196e474ee1b62d6722754e8e377cba4ddc1f`. The example has
5,000 simulated observations, randomized to treated or control. The binary
outcome is an undesirable event. Covariates are age (40–80 years) and sex
(0 = male, 1 = female). All fitted demographic relationships come from the
simulation; they are not findings about any real population.

## Reproduce

From the project root, with R and its dependencies activated:

```sh
Rscript R/demo.R
Rscript scripts/example-inference.R
```

The first command prepares the simulated dataset and teaching diagnostics; the
second runs the actual original-package `spe()` and `ca()` inference and updates
the main figures. The analysis uses all 5,000 observed covariate profiles for
the empirical distribution of conditional contrasts. `R/example-walkthrough.R`
contains the model, treated/control predictions, and two age-profile calculations
used by the displayed R examples. The model is
`outcome ~ group * age_z * sex`, where `age_z = (age - 60) / 10`. This includes
all main effects, all two-way interactions, and the group-by-age-by-sex
interaction. It allows the treatment contrast to vary with age and sex.
The executable walkthrough also returns the weighted-quantile curve, its
average, the two logical tail-membership vectors, and the tail mean summaries.
The inference script checks each displayed calculation against those returned
objects and the original package's point estimates.

## Contrast direction

The supported categorical API computes the prediction for `compare[2]` minus
the prediction for `compare[1]`. With group levels `control` and `treated`,
the call uses:

```r
var_type = "categorical"
var = "group"
compare = c("treated", "control")
```

Its positive contrast is therefore **control risk minus treated risk**:
an absolute risk reduction. The binary outcome is not inverted, and
no package code is patched. The script independently verifies this sign against
the direct `glm()` probability contrast.

## What is estimated and inferred

- `spe()` estimates the benefit quantiles on a prespecified 10th–90th percentile
  grid and the average benefit. The main uncertainty plot uses its original
  **95% uniform band**, with IQR bootstrap scaling and monotonic rearrangement.
- `ca()` describes the highest-benefit and lowest-benefit 10% and performs
  inference for their mean differences in **age and female proportion**.
  The displayed p-values come from its bootstrap maximum statistic, adjusted
  jointly across those two comparisons.
- The dumbbell endpoints show the two estimated tail means. The package's
  moment-mode `ca()` result returns differences, bootstrap standard errors and
  p-values; it does **not** return moment confidence intervals. No endpoint or
  simultaneous difference confidence intervals are invented from those outputs.
- Predicted untreated risk is a derived fitted quantity. It is not included as
  an observed characteristic in the classification inference family.

The run uses 499 bootstrap draws, seed 420, `alpha = 0.05`, and `bc = FALSE`.
The uncorrected setting makes the point estimates directly comparable with
the fitted regression and direct tail calculations. This setting and the
empirical cohort are explicit; the method's population interpretation still
requires its published assumptions and regularity conditions.

## Resampling scope: two package paths differ

Inspection and independent reconstruction of the installed source show:

1. The full-sample `spe()` path refits the model with bootstrap training counts,
   predicts on the original covariate profiles, and uses the original quantile
   weights. Its bands condition on that empirical reference distribution.
2. The `ca()` moment path refits with resampled weights and also uses those
   weights for effect quantile thresholds and tail covariate means. Its
   resampling is not the same fixed-covariate conditional calculation.

The main plots use each routine's actual output. The optional transparent
SD/max teaching bootstrap remains a separate diagnostic; it is not substituted
for the original package's inference or advertised as an identical method.

## Validation and p-value interpretation

`scripts/example-inference.R` verifies the sign, SPE quantiles, APE, and
classification mean differences against independent direct calculations. It
also reconstructs both bootstrap paths with explicit `glm()` refits, checks
every reconstruction fit for convergence, and compares the original package's
SPE scale/bands and CA scales/joint p-values with those reconstructed results.
Current-run errors and metadata are saved in
`results/example-inference-metadata.txt`.

The package's `ca()` moment-mode native `pointwise_p` field is calculated as
`1 - pnorm(abs(estimate / se))`. That is not a conventional two-sided normal
p-value. The CSV preserves the native field for audit and separately records
the conventional two-sided normal approximation. Neither is displayed as the
main classification evidence: the presentation uses the package's bootstrap
**joint adjusted p-values**. This documents an observed implementation detail;
no source repair is claimed.

With 499 draws, bootstrap p-values are multiples of 1/499. A returned zero
means **0 of 499 bootstrap maxima exceeded the observed statistic**. It is
neither a bound on the true p-value nor an exactly zero population probability.
When a table rounds such a result as `< 0.01`, that is a display of the empirical
Monte Carlo result, not a guarantee about an unknown population tail probability.
An example running and an independent numerical reconstruction do not establish
frequentist coverage for every possible dataset; no coverage study or full
package check is claimed.
