# Sorted-effects software validation

The clinical teaching example in `R/demo.R` uses transparent `glm()` contrasts
and a fixed reference cohort. It can run without the archived `SortedEffects`
package. An additional benchmark exercises the original package's published
mortgage example and checks the estimator against direct calculations.

## Original package source

- Package: `SortedEffects`, version **1.7.0**, released **22 March 2022**.
- Source: <https://github.com/cran/SortedEffects>.
- Exact CRAN-mirror Git commit:
  `18a1196e474ee1b62d6722754e8e377cba4ddc1f`.
- Authors' repository: <https://github.com/shuowencs/SortedEffects>.
- The retained source archive in this cloud machine is
  `/workspace/.tools/SortedEffects-1.7.0-18a1196.tar.gz`, generated directly with
  `git archive` from that commit. Its SHA-256 is
  `1b31197721c3d0f609e32720e2afc405ac2225512d28bb5a880234de53447b0a`.

The source version and release date were checked in its `DESCRIPTION` and Git
history. The package imported and installed successfully on R 4.5.0. Its `boot`,
`Hmisc`, `pbapply`, `quantreg`, and `SparseM` dependencies were installed locally
from signed Debian trixie repositories. TLS and APT package verification were
retained. No package estimator source was changed.

For a normal R installation with these dependencies, the pinned source can be
installed with:

```sh
git clone https://github.com/cran/SortedEffects.git /tmp/SortedEffects-source
git -C /tmp/SortedEffects-source checkout 18a1196e474ee1b62d6722754e8e377cba4ddc1f
R CMD INSTALL /tmp/SortedEffects-source
```

In this prepared cloud machine, activate the tools first:

```sh
source /workspace/.tools/activate
cd /workspace/jcod
R --vanilla --slave --file=scripts/benchmark-sortedeffects.R
```

## What the benchmark checks

`scripts/benchmark-sortedeffects.R` runs the package's logit mortgage example on
2,380 observations, with 199 bootstrap draws, seed 420, a 10th–90th percentile
grid, 95% bands, and `bc = FALSE` so the original estimates can be compared
directly. It verifies:

1. SPE point estimates equal quantiles of directly computed `glm()` probability
   contrasts, using the same `Hmisc::wtd.quantile()` convention.
2. The APE equals the direct average probability contrast.
3. Identical seeds reproduce the entire SPE object exactly.
4. A separate implementation resamples training counts, refits the logit model,
   predicts contrasts on the original fixed covariates, re-sorts them,
   IQR-standardizes bootstrap deviations, takes the maximum across percentiles,
   and rearranges the band endpoints. Its band and scale estimates are checked
   against the package's outputs.
5. `ca()` runs with two continuous characteristics (`p_irat`, `hse_inc`), and its
   uncorrected most-minus-least tail means equal the direct tail calculations.
   It checks finite, positive bootstrap standard errors and records the package's
   joint p-values. This is an integration check of the classification workflow;
   it is not a coverage study or an independent validation of those p-values.

Current-run numeric errors, package output, source identity, and session details
are written under `results/benchmark/`. The benchmark produces
`results/figures/mortgage-example.png` and `.pdf` using a plot independent of the
package's plotting method. The mortgage contrast is an observational adjusted
association. This demonstration does not establish a causal interpretation of
the race indicator in that regression.

## Plotting issue

The archived `plot.spe()` method supplies several positional arguments to
`plot()`, matching the source location implicated in the reported plotting
problem. **Its plotting example succeeds on this machine's R 4.5.0.** A reported
failure on a different runtime is not evidence that it fails here, and no
successful package repair is claimed. The benchmark records the actual
`plot.spe()` error string, or `NA` when it succeeds. Its additional plotting
adapter uses explicit argument names; it changes presentation only.

## Interpretation and limits

The main clinical demo uses a separate, fixed empirical reference cohort;
bootstrap training samples are refitted and predictions are re-sorted on that
same cohort. Its bands therefore describe model-estimation uncertainty
conditional on those covariates. They do not include uncertainty in a newly
sampled target population, model misspecification, or individual causal effects.

The clinical demo deliberately uses a simpler SD-standardized bootstrap band
on its declared percentile grid, while the original package uses an IQR scale
and monotonic rearrangement. Quantile conventions also differ. The main demo
is not advertised as an exact reproduction of the original package's inference.
Its classification table is descriptive; formal clinical classification
inference and confidence sets for individual membership are not claimed.

199 draws support the reproducibility/integration benchmark. They do not
establish frequentist coverage or reproduce every empirical result in the
Econometrica paper. No full `R CMD check` is claimed. The main deck's HTML/PDF
render checks are recorded separately in the project README.
