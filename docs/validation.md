# Validation of this session

## Demographic example revision, 21 October 2026

The generic treated/control example, its figures and all model-derived slide
values were regenerated together. The final source build is commit
`c33e3037702640052b43a1991f9adbecc9f0ac33`.
[GitHub Actions run 39621401307](https://github.com/valentinklotzbuecher/jcod/actions/runs/39621401307)
completed successfully, including simulation, original-package inference,
independent numerical checks, both presentation formats and browser inspection.
The rendered exports and generated results were copied from that run's artifact;
the subsequent commit records those outputs and this validation report.

## Executed environment

- R 4.5.0 on Ubuntu 24.04.5 LTS.
- Quarto 1.8.27; XeLaTeX / TeX Live 2026; DejaVu Sans.
- Original SortedEffects 1.7.0, installed from CRAN-mirror source commit
  `18a1196e474ee1b62d6722754e8e377cba4ddc1f` without estimator changes.
- Hmisc 5.3-0, ggplot2 4.0.3, knitr 1.52 and rmarkdown 2.32.
- Chromium through Playwright 1.62.1 for the portable HTML inspection.

The workflow retains its complete runtime and command logs as
`jcod-preview-build-logs`. Numerical session information is also recorded in
`results/run-metadata.txt` and `results/clinical-inference-metadata.txt`.

## Numerical checks

The workflow executed, in order:

```sh
Rscript R/demo.R
Rscript scripts/clinical-inference.R
Rscript scripts/validate-demo.R
bash scripts/render.sh
```

The simulation uses 5,000 profiles, simulation seed 20261020 and 499 teaching
bootstrap draws per scenario. Primary original-package inference uses 499
draws, seed 420, alpha 0.05 and uncorrected point estimates.

| Check | Result |
|:--|:--|
| SPE point estimates versus direct model contrasts | Maximum absolute difference 0 |
| APE versus the direct mean contrast | Absolute difference 0 |
| CA point estimates versus direct tail means | Maximum absolute difference 0 |
| Independently reconstructed SPE uniform band | Maximum absolute difference 3.05e-16 |
| Independently reconstructed CA bootstrap scales | Maximum absolute difference 0 |
| Independently reconstructed CA joint p-values | Maximum absolute difference 0 |
| Independent reconstruction fits | All 499 converged |

`scripts/validate-demo.R` passed its checks of the exact risk contrast,
matched true averages and different true distributions across scenarios,
refit-and-sort resampling, finite bands, seeded reproducibility, tail
membership, demographic dumbbell endpoints and 28 generated figure artifacts.

Selected values were also checked against the rendered slides:

| Quantity | Value |
|:--|:--|
| Average fitted benefit | 7.357 percentage points |
| 80th percentile of fitted benefit | 19.2 percentage points, rounded |
| Age 45 profile, female = 0: control / treated risk | 12.2% / 19.6% |
| Age 75 profile, female = 0: control / treated risk | 28.4% / 8.5% |
| Mean age, lowest / highest benefit tails | 41.91 / 77.20 years |
| Female proportion, lowest / highest benefit tails | 49.2% / 83.6% |
| Female-proportion difference, bootstrap SE, joint p | 34.4 pp; 25.75 pp; 0.275 |

The age comparison's native zero joint p-value is displayed as `0 / 499` to
show the finite bootstrap resolution. The two-characteristic family contains
age and female proportion. Descriptive tail means, uncertainty in their
differences and the separate membership sensitivity diagnostic remain distinct.

## Render and visual review

The portable RevealJS HTML and Beamer PDF both contain 39 slides, including
technical backup. `scripts/render.sh` also rendered the session landing page.
The browser check visited every slide at 1600 by 900 pixels, revealed fragments,
waited for fonts and figures, and saved one screenshot per slide.

Final browser findings:

- No text or figure overflow beyond the slide canvas.
- No navigation overlap with visible text or figures.
- No broken images, missing local resources or external requests.
- No JavaScript page errors or console errors.

The PDF was rendered to PNGs with Poppler for visual review. All slides were
reviewed for layout and content, with particular attention to equations,
two-column figures, numerical tables, code and references. Review found a
navigation/title collision in the first HTML render, small HTML references and
a Markdown `+` parsed as an empty bullet in the backup cover. These were
corrected; affected slides were rechecked in the final render. The browser
check now also detects navigation collisions.

Representative final screenshots and the complete browser findings are retained
in `docs/preview/`:

- [Fitted benefit by age and sex](preview/demographics.png)
- [Age and sex in the two tails](preview/classification.png)
- [Uniform band and average](preview/uncertainty.png)
- [Browser report](preview/layout-report.json)
- [Browser check output](preview/browser-check.txt)

## Scope

These checks establish numerical consistency and successful rendering of this
teaching example. They are not a coverage study, a full `R CMD check`, or a
validation under model misspecification. The figures describe conditional
average risk contrasts; they do not identify individual realized effects.
The SPE reference population is the observed 5,000 profiles. The separate CA
resampling convention is documented in `clinical-inference.md`.

The original published-example benchmark and archived SCM session remain
unchanged. Their earlier validation is recorded in `software-validation.md`
and the retained benchmark outputs. No website publication was performed.
