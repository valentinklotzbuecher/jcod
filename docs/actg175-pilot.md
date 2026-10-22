# ACTG175 secondary pilot

## Analysis plan recorded before model fitting

Recorded 22 October 2026. This is a secondary feasibility analysis alongside
the International Stroke Trial pilot. It is not a search over ACTG175 arms or
outcomes, and its role will not be chosen from whichever trial gives the
smallest heterogeneity p-value.

- Data: the publicly distributed ACTG175 export in `speff2trial` 1.0.5,
  pinned to CRAN-mirror commit `9fa954e262daa0dd8d078d8a843537467f7603df`.
- Comparison: arm 1 (zidovudine plus didanosine) versus arm 0 (zidovudine).
  Retain all 1,054 rows in those arms; do not use the package's pooled `treat`
  variable. Arm 1 is treated. Other arms will not be analyzed in this pilot.
- Outcome: CD4 count at 20 ± 5 weeks (`cd420`), complete in this export.
  A positive effect is treated minus control CD4 cells per cubic millimetre.
  Do not use the 96-week endpoint or construct alternative outcomes.
- Baseline characteristics: age, male indicator (`gender`: 0 female, 1 male),
  weight, baseline CD4, baseline CD8, Karnofsky score, symptomatic indicator,
  and prior antiretroviral experience (`str2`). All eight enter the main-effects
  ANCOVA. The interaction model adds the eight treatment-by-characteristic
  terms together. No stepwise selection, nonlinear search or demographic
  subgroup search will be used. Test all eight interactions with one nested
  model F test.
- Estimation: report both models, even if the interaction test is unconvincing.
  Use native SortedEffects 1.7.0 OLS SPE estimates and 95% uniform bands on the
  10th–90th percentile grid, 499 draws, seed 420, uncorrected point estimates.
  Compute native CA for the interaction model's bottom/top 10% across these
  same eight characteristics. Keep descriptive tail endpoints distinct from
  native standard errors and jointly adjusted p-values for their differences.
- Honest check: one 50:50 split, stratified by treatment, seed 20261023.
  Fit both prespecified models using training rows only. Predict control and
  treated CD4 in validation rows, then form AIPW outcomes with the nominal
  treatment probability 0.5. Report validation mean effect and the HC3 slope
  of the AIPW outcome on each model's predicted effect. The interaction-model
  slope assesses whether its ranking is supported in the held-out half.
  A constant-effect main model has no meaningful ranking slope. Do not repeat
  the split or tune the model against validation outcomes.

The data export has 2,139 rows, including 1,771 men and 368 women, and ages
12–70. Its selection relationship to the original randomized cohort has not
been verified; complete 20-week outcomes in the export do not prove complete
follow-up in the original trial. The original article was identified from the
package documentation, but its publisher/PubMed pages were blocked during
source checks. These are historical therapies and this is not current HIV
treatment guidance. Novel or previously overlooked heterogeneity is not
claimed.

## Reproduce

```sh
source /workspace/.tools/activate
Rscript R/actg175-pilot.R
```

The script will write descriptive audits, both model summaries, the global
interaction test, native SPE/CA outputs, and the single held-out check under
`results/actg175/`. Source details and hashes are under `data/actg175/`.

## Pilot findings

Both models estimate an average gain of about **71 CD4 cells/mm³** with the
combination at 20 weeks. The native interaction-model 95% interval is about
**58 to 84**. This is a secondary analysis of the public export, not a newly
verified reproduction of the original trial publication.

The eight-interaction model produces a visually wider effect distribution:
its fitted 10th and 90th percentiles are about **42 and 100 cells/mm³**. The
main-effects linear model gives a constant fitted contrast. However:

- The joint eight-interaction F test gives **F = 1.32**, 8 and 1,036 degrees
  of freedom, **p = 0.230**. This does not establish treatment-effect variation.
- The single split has 527 training and 527 validation observations.
  Held-out AIPW calibration slope is **0.295**, HC3 SE **0.368**, with
  95% interval **−0.428 to 1.018** and p = **0.423** against a zero slope.
  The held-out data do not convincingly support this ranking. The constant
  main-model ranking slope is undefined, as expected.
- Native classification gives a larger-table example: the top tail is older,
  has lower baseline CD4/CD8, includes fewer men and fewer symptomatic
  participants. Only age has a native joint p-value below .05 (about .034).
  These are comparisons of **model-selected tails**, not interaction tests.
  That classification p-value does not override the joint interaction test
  or the unsupported held-out ranking.

The two selected tails each contain 106 observations. Native CA comparisons
below use all eight characteristics as one joint family. Binary-variable
differences and SEs are shown in percentage points.

| Characteristic | Bottom 10% | Top 10% | Top minus bottom | Bootstrap SE | Joint p |
|---|---:|---:|---:|---:|---:|
| Age, years | 27.4 | 48.5 | 21.1 | 6.2 | .034 |
| Male, % | 89.6 | 64.2 | −25.5 pp | 35.0 pp | .992 |
| Weight, kg | 72.7 | 79.4 | 6.7 | 13.0 | .998 |
| Baseline CD4, cells/mm³ | 520.8 | 261.3 | −259.5 | 106.9 | .230 |
| Baseline CD8, cells/mm³ | 1192.1 | 907.1 | −285.1 | 413.3 | .992 |
| Karnofsky score | 94.3 | 95.8 | 1.5 | 4.8 | 1.000 |
| Symptomatic, % | 30.2 | 3.8 | −26.4 pp | 26.7 pp | .952 |
| Prior ART, % | 64.2 | 58.5 | −5.7 pp | 39.9 pp | 1.000 |

The result is useful for teaching why a plausible, detailed CA table and a
sloping SPE curve do not by themselves demonstrate reproducible heterogeneity.
It does **not** supply the strong, newly uncovered treatment subgroup pattern
we were looking for. No alternative treatment comparisons or outcomes were
tried in response to this finding.

## Verification and interpretation

The script checks native SPE quantiles and APE against direct predictions,
and classification means against direct cutoff calculations. It also
independently reconstructs all 499 bootstrap draws for both OLS SPE models and
the CA moment comparison, checking native bands, SEs and joint p-values.
All four maximum errors are exactly zero in the current run;
`bootstrap-checks.csv` records them. Native `ca()` orders traits
by their source columns, so results are explicitly matched by characteristic
name rather than assuming the order passed to `t` is returned.

The F test is the classical nested-model test; the held-out ranking uses HC3
uncertainty. The original package's SPE path retains original prediction-profile
quantile weights, whereas its CA path reweights thresholds and group means.
Neither numerical verification nor complete outcomes in this selected export
establishes coverage or transport to another population. Near-flat true effect
distributions also complicate the interpretation of classification inference.
The native CA moment call returns differences, standard errors and joint
p-values, not moment confidence intervals. A zero bootstrap p-value would mean
zero exceedances among 499 draws, not an exactly zero population probability.
