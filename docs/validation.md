# Validation of this session

Validated on 22 October 2026 in the prepared cloud environment: R 4.5.0,
ggplot2 3.5.1, Quarto 1.8.27 and XeLaTeX (TeX Live 2025/Debian).

## Scientific outputs

- `Rscript R/demo.R`: completed 499 successful refit-and-sort bootstrap draws
  for each scenario, using seed 20261020. Both true average benefits equal
  7.982 percentage points across the observed profiles. The main scenario uses
  treatment interactions with age and sex and includes negative risk reductions
  in part of the population. The full fitted model matches its specification.
- `Rscript scripts/validate-demo.R`: passed analytic risk-contrast checks,
  matched true averages, differing true distributions, bootstrap monotonicity
  and finite uncertainty, tail-membership accounting, seed reproducibility,
  checks of demographic dumbbell endpoints, an independent model-matrix check
  of age-by-sex risk differences, and all 28 current figure artifacts.
- `Rscript scripts/example-inference.R`: completed original-package
  SPE and classification inference with 499 draws, seed 420. Direct SPE/APE and
  classification point estimates match exactly. Independent bootstrap
  reconstructions agree within 5.55e-16 for SPE scales/bands and exactly for CA
  standard errors and joint adjusted p-values. All reconstruction fits converged.
  Average risk reduction is 8.350 percentage points, with native 95% interval
  6.311–10.389 percentage points. Mean age is 42.3 versus 78.0 in the bottom
  and top tails. Female proportion is 72% versus 60%; its native joint p-value
  is 0.88 and bootstrap SE for the difference is 31.5 percentage points.
- The unchanged original SortedEffects 1.7.0 benchmark was validated on 20 October:
  mortgage example completed with 199 draws. SPE/APE and classification point
  estimates match direct calculations exactly. An independent reconstruction
  of the package's IQR/max simultaneous band agrees within 3.33e-16. Identical
  seeds reproduce the package's SPE result exactly. Its native plot method
  succeeds on this runtime; no package repair is claimed.

See `example-inference.md` and `software-validation.md` for inferential scope.
Neither a repeated-sampling coverage study nor full package checks were
performed. The SPE band conditions on the observed profile distribution;
CA uses its own reweighted threshold/moment bootstrap. Dumbbell endpoints are
descriptive means, with formal native SEs and joint p-values reported separately
for their differences. No moment confidence intervals or individual causal
effects are claimed.

## Public-trial pilots

- IST: downloaded the corrected public dataset and four supporting files from
  a pinned mirror. All sizes and SHA-256 hashes pass `fetch-ist-data.py
  --verify-only`. This verifies the mirror copy, not an independent comparison
  against the inaccessible canonical deposit. Outcome coding and counts were
  checked against the original dictionary: 19,285 observed six-month endpoints,
  150 missing. Raw source bytes are preserved.
- Both IST logistic models converged with full-rank designs. The nested
  comparison has eight added coefficients. Native SortedEffects 1.7.0 SPE/APE
  estimates agree with direct contrasts to within 4.9e-17; all 81 grid points,
  bands and standard errors are finite. Both models use 499 bootstrap draws.
- IST CA estimates agree exactly with direct tail means. Native output follows
  source-column order, so estimates, SEs and p-values are matched by variable
  name. All 12 joint p-values are valid; the smallest is .156. Following an
  ordering-check failure, the corrected CA step was rerun with 499 draws;
  previously completed SPE outputs were retained and their point estimates
  checked against the current fits. Full IST bootstrap draws were not
  independently reconstructed.
- The fixed IST validation split has 9,642 training and 9,643 validation
  patients. Outcomes in the validation sample do not enter model fitting or
  ranking thresholds. The AIPW sign, nominal assignment probability, and HC3
  calculation were reviewed. The interaction ranking has slope p = .822;
  its predicted top–bottom quintile gap is 7.36 pp versus an observed 0.41 pp
  (95% interval −5.73 to 6.55). Both rankings are reported.
- ACTG 175: the fixed secondary comparison uses 1,054 observations, one
  treatment contrast and the 20-week CD4 endpoint. Both models' SPE/APE and CA
  point checks passed. Independent reconstruction of all 499 bootstrap draws
  matches both SPE bands/scales and CA SEs/joint p-values exactly. The joint
  interaction test gives p = .230; the held-out ranking slope gives p = .423.
  No further arms, endpoints or splits were searched.
- These checks support numerical reproducibility of these working analyses.
  They do not establish a new subgroup effect, repeated-sampling coverage,
  robustness to model misspecification, or external validation. See
  `ist-analysis-plan.md`, `ist-data.md` and `actg175-pilot.md` for scope.

## Rendering and runtime

- `bash scripts/render.sh`: passed full-site rendering, including the portable
  RevealJS HTML export and matching 39-page, 16:9 Beamer handout.
- All PDF pages were visually inspected. Figure sizes and source-note typography
  were adjusted to avoid caption clipping. The foundational and tutorial
  references render correctly.
- Headless Chromium exercised all 39 HTML slides, verified image loading,
  checked slide boundaries and JavaScript errors, and confirmed native MathML
  rendering. Math and fonts do not require external services.
- Six main chapter stacks and one backup stack form the two-dimensional deck.
  Session-map links, chapter buttons, native overview, fragment reveals and
  keyboard navigation passed browser checks. Overview thumbnails preload their
  figures. Reduced-motion settings and mobile navigation were checked.
- The self-contained HTML export was tested through an isolated local HTTP
  server with all other network requests blocked. It loaded without failed
  requests, missing images or JavaScript errors.
- The separate IST report renders all four tables (including the 12-row CA
  table) and three figures. Its portable HTML also passed an isolated HTTP
  check with every other network request blocked: no missing images,
  JavaScript errors or horizontal page overflow. Figures were visually checked
  for labels, units, separate model bands and descriptive dumbbell endpoints.
- The local Quarto preview served the landing page, slides, PDF, simulation
  source, result CSV and evidence notes successfully.
- All 51 original tracked files at commit `c23405b` were compared byte for byte
  with `archive/scm-2026/`; every comparison passed.
- Source whitespace checks passed. The byte-preserved archive and generated
  HTML/session logs retain their original/upstream whitespace. Work is on `main`.

These checks validate the current instance and generated artifacts. Website
publication and restoration in a fresh cloud task have not been performed.
