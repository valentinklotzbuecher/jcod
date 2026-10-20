# Validation of this session

Validated on 20 October 2026 in the prepared cloud environment: R 4.5.0,
ggplot2 3.5.1, Quarto 1.8.27 and XeLaTeX (TeX Live 2025/Debian).

## Scientific outputs

- `Rscript R/demo.R`: completed 499 successful refit-and-sort bootstrap draws
  for each scenario, using seed 20261020. Both true average benefits equal
  7.396 percentage points across the observed trial profiles. The scenario with a
  severity interaction includes conditional average harm in part of the population.
- `Rscript scripts/validate-demo.R`: passed analytic risk-contrast checks,
  matched true averages, differing true distributions, bootstrap monotonicity
  and finite uncertainty, tail-membership accounting, seed reproducibility,
  checks of the clinical dumbbell endpoints, and all 26 teaching figure artifacts.
- `Rscript scripts/clinical-inference.R`: completed original-package clinical
  SPE and classification inference with 499 draws, seed 420. Direct SPE/APE and
  classification point estimates match exactly. Independent bootstrap
  reconstructions agree within 3.61e-16 for SPE scales/bands and exactly for CA
  standard errors and joint adjusted p-values. All reconstruction fits converged.
  Clinical average benefit is 7.648 percentage points, with native 95% interval
  5.499–9.797 percentage points.
- `Rscript scripts/benchmark-sortedeffects.R`: original SortedEffects 1.7.0
  mortgage example completed with 199 draws. SPE/APE and classification point
  estimates match direct calculations exactly. An independent reconstruction
  of the package's IQR/max simultaneous band agrees within 3.33e-16. Identical
  seeds reproduce the package's SPE result exactly. Its native plot method
  succeeds on this runtime; no package repair is claimed.

See `clinical-inference.md` and `software-validation.md` for inferential scope.
Neither a repeated-sampling coverage study nor full package checks were
performed. The clinical SPE band conditions on the observed profile distribution;
CA uses its own reweighted threshold/moment bootstrap. Dumbbell endpoints are
descriptive means, with formal native SEs and joint p-values reported separately
for their differences. No moment confidence intervals or individual causal
effects are claimed.

## Rendering and runtime

- `bash scripts/render.sh`: passed full-site rendering, including the portable
  RevealJS HTML export and matching 40-page, 16:9 Beamer handout.
- All PDF pages were visually inspected. Figure sizes and source-note typography
  were adjusted to avoid caption clipping. The foundational and tutorial
  references render correctly.
- Headless Chromium exercised all 40 HTML slides, verified image loading,
  checked slide boundaries and JavaScript errors, and confirmed native MathML
  rendering. Math and fonts do not require external services.
- Six main chapter stacks and one backup stack form the two-dimensional deck.
  Session-map links, chapter buttons, native overview, fragment reveals and
  keyboard navigation passed browser checks. Overview thumbnails preload their
  figures. Reduced-motion settings and mobile navigation were checked.
- The self-contained HTML export was tested through an isolated local HTTP
  server with all other network requests blocked. It loaded without failed
  requests, missing images or JavaScript errors.
- The local Quarto preview served the landing page, slides, PDF, simulation
  source, result CSV and evidence notes successfully.
- All 51 original tracked files at commit `c23405b` were compared byte for byte
  with `archive/scm-2026/`; every comparison passed.
- Source whitespace checks passed. The byte-preserved archive and generated
  HTML/session logs retain their original/upstream whitespace. Work is on `main`.

These checks validate the current instance and generated artifacts. Website
publication and restoration in a fresh cloud task have not been performed.
