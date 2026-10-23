# Validation of this session

Analyses validated on 22 October 2026; presentation revised and checked on
23 October 2026 in the prepared cloud environment: R 4.5.0, ggplot2 3.5.1,
Quarto 1.8.27 and XeLaTeX (TeX Live 2025/Debian).

## Retained simulation and benchmark outputs

- `Rscript R/demo.R`: completed 499 successful refit-and-sort bootstrap draws
  for each scenario, using seed 20261020. Both true average benefits equal
  7.982 percentage points across the observed profiles. The interaction scenario uses
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
No repeated-sampling coverage study was performed. These teaching-analysis
checks were not full package checks. The SPE band conditions on the observed profile distribution;
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

## Colon pilot

- Verified all six pinned source-file hashes. The `colon` object in the
  downloaded survival 3.8-13 source snapshot is identical to the installed
  survival 3.8-3 object. Data preparation checks one death record per person,
  baseline agreement across paired records, endpoint coding, exclusions and
  the eight node-coding disagreements. Selected/known/primary counts are
  619/618/593.
- Models and sensitivity checks were recorded before fitting. Both primary
  models are full rank and converged, with 13 and 19 coefficients. Native SPE
  and APE estimates, scales, bands and intervals independently reconstruct
  exactly. All 998 count-weight bootstrap fits converged.
- Native CA failed numerically: 141/499 scaled-weight fits did not converge
  and 137 draws have nonfinite moments. Independent reconstruction matches
  these raw outputs exactly but explicitly rejects their inferential use.
  A documented subsequent initialization change gives 499 converged scaled
  fits, with no discarded draws or nonfinite moments. Prediction, score and
  likelihood agreement with count-weight fits were checked. Raw and stabilized
  classification tables remain separately labeled.
- The one fixed validation split uses 296 training and 297 test patients.
  IDs are disjoint, prediction thresholds do not use validation outcomes,
  and AIPW/HC3 calculations were independently reproduced. Delete-one QR
  calculations agree with HC3 covariance to within 4.8e-14. The interaction
  slope is 1.101, raw p .0127 and Holm p .0254; the all-618 sensitivity weakens
  the full-sample interaction test from .0136 to .0536. These are preliminary
  internal results, not independent replication or a novel clinical claim.
- Both SPE comparison and 12-trait classification figures were visually
  inspected as PNGs and one-page PDFs. Dumbbells are descriptive; no moment
  confidence intervals are invented. The validation figure has wide pointwise
  intervals and does not establish harm in the low-ranked group.
- `Rscript R/colon-walkthrough.R` verifies the two models' saved SPE/APE point
  estimates and all twelve CA means/differences within 1e-10, with 593 profiles
  and 60 in each tail. The slide figure script reads the saved CSVs without
  refitting models or rerunning inference. Native SPE bands and the separately
  stabilized CA inference remain explicitly distinguished in the deck.
- The full site renders with the added report. Its portable HTML passed a
  Chromium check through an isolated local HTTP server with all other network
  requests blocked: all four tables and three images load, with no JavaScript
  errors, failed requests or horizontal page overflow. Its CA table has all
  twelve rows and is explicitly labeled as stabilized reconstruction.

## Rendering and runtime

The separate SortedEffects repair is recorded in
[`contributions/sortedeffects`](../contributions/sortedeffects/README.md), including
its tests and full package-check results. It was developed and tested in isolated
libraries; the package used for the saved slide results remains unchanged.

- `bash scripts/render.sh`: passed full-site rendering, including the portable
  RevealJS HTML export and matching 43-page, 16:9 Beamer handout. The colon
  trial is the sole worked trial: 32 slides through discussion (including
  title and chapter covers), followed by 11 optional backup slides.
- All PDF pages were visually inspected. Figure sizes and source-note typography
  were adjusted to avoid caption clipping. The foundational and tutorial
  references render correctly.
- The revised model, full SPE/CA calls, forest teaser and assumptions backup
  were visually checked in the updated PDF. The teaser distinguishes flexible
  estimation from sorted summaries, with shared causal assumptions visible.
- The displayed full model reproduces the recorded model coefficients within
  1e-10. Displayed SPE/CA calls parse and match the recorded contrast, grid/tail,
  bootstrap and characteristic arguments; no new bootstrap analysis was run.
- Both full calls use native line-highlight fragments with synchronized visible
  explanations. Four groups per call passed 14 forward/backward states and six
  direct-jump/re-entry checks, including reduced motion. All explanations remain
  visible; static PDFs show complete code and explanations together.
- Headless Chromium exercised all 43 HTML slides, verified image loading,
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
- The previous local Quarto preview served the landing page, slides, PDF,
  simulation source, result CSV and evidence notes successfully. The updated
  colon deck was checked using its portable export on a local HTTP server.
- All 51 original tracked files at commit `c23405b` were compared byte for byte
  with `archive/scm-2026/`; every comparison passed.
- Source whitespace checks passed. The byte-preserved archive and generated
  HTML/session logs retain their original/upstream whitespace. Work is on `main`.

These checks validate the current instance and generated artifacts. Website
publication and restoration in a fresh cloud task have not been performed.
