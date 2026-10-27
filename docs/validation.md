# Validation of this session

Analyses validated on 22 October 2026; presentation revised and checked on
26 October 2026 in the prepared cloud environment: R 4.5.0, ggplot2 3.5.1,
Quarto 1.8.27 and XeLaTeX (TeX Live 2025/Debian). A second presentation revision
the same day used a fresh cloud environment: R 4.3.3, Quarto 1.8.27 and XeLaTeX
(TeX Live 2023/Debian). It re-rendered the slides only; no analysis, figure or
report was regenerated.

## Constructed warm-up

- `Rscript scripts/illustrate-warmup.R` generates six profile/scenario rows from
  specified probabilities. It checks probabilities in [0,1], weights summing to
  one within each scenario, equal marginal risks (40% control, 30% treated),
  equal 10 pp mean benefits, and the exact inverse-CDF step values and boundaries.
- The table and figure use the generated population quantities. No outcomes
  were sampled, no models fitted and no bootstrap inference attached. The
  earlier teaching simulation and all colon analysis outputs remain unchanged.

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

Second revision, 26 October 2026:

- **Baseline:** before any change, re-rendering reproduced the committed
  `presentation.html` byte for byte, and the PDF text exactly.
- **Dock fix:** the fixed chapter dock covered 35 of 44 slide headings on every
  16:9 viewport, from 1280×720 to 1920×1080. There was no overlap on 16:10 or
  4:3. The dock now tucks away on content slides.
- **Dock behaviour, 21 headless-Chromium checks:**
  - visible on the title and chapter covers;
  - shown when the pointer reaches the top edge, and on keyboard Tab focus;
  - stays tucked after a chapter click followed by arrow or PageDown keys;
  - hidden in the overview, always visible on touch devices, no transition
    under reduced motion;
  - zero heading overlaps at 1280×720, 1366×768, 1536×864 and 1920×1080.
- **Deck changes:**
  - title and chapter covers lost their dark backdrops;
  - three backup slides (estimand, uniform-band construction, native-CA
    failure) moved into the main chapters;
  - two discussion slides added (PATH positioning and questions);
  - the effect-scale illustration moved to chapter 01, ahead of the warm-up;
  - the average-effect and benefit-definition slides were rewritten as plain
    bullets, with denominators, the crude and standardized averages, and the
    potential-outcome reading of Δ(x).
- **Uniform critical values:** recovered from the saved bands and scales. They
  are 2.791 for the interaction model (72 of 81 upper endpoints unaffected by
  rearrangement) and 2.173 for the constant model. All other slide numbers were
  checked against `results/colon/*.csv`.
- **Portable export:** loaded from a local HTTP server with every other request
  blocked. All 47 slides and 9 images loaded, with no failed requests or
  JavaScript errors. Session-map links and both code-callout sequences worked.
- **Handout:** all 48 PDF pages were inspected; the reference list now spans two
  pages. The two trial reports differed only in unused slide CSS, so their
  committed exports were kept.

Third revision (intuitive redo), 26 October 2026:

- **Structure:** the main flow follows *The Effect* §22.3 in four chapters:
  question, sorted effects step by step, trust, discussion. Technical slides
  moved intact to the backup stack, renamed "Backup · …".
- **New script:** `scripts/plot-colon-patients.R` refits the specified
  interaction model, point estimates only. Before writing
  `results/colon/patient-benefits.csv` and two figures, it reproduces:
  - the saved native SPE grid and APE, within 1e-10;
  - the 60/60 tail sizes.
- **Inline numbers:** the share of patients within 3 pp of the average (15%) is
  computed from that file during rendering.
- **Step 4 table:** built from `classification-stabilized.csv`. The
  stabilized-bootstrap label is kept with its p-values.
- **Dock and overlap checks:** all 21 passed, with no heading overlaps on 43
  slides at four 16:9 sizes.
- **Portable export:** loaded offline. All 43 slides and 10 images loaded, with
  no external or failed requests and no JavaScript errors. The four
  session-map links and the backup code-callout sequences worked.
- **Handout:** all 44 PDF pages were inspected.
- **Slide-by-slide review:** figures now use the slides' wording: "estimated
  benefit", "patients, sorted by …", and warm-up panels named like the table
  rows. They were regenerated from saved results with `plot-colon-slides.R`
  and `illustrate-warmup.R` (under UTF-8); the warm-up CSVs are
  byte-identical. Callouts now carry the quote and the key message of Step 1
  and the band slide.
- **Clarity pass:** slide text now explains technical terms in plain words.
  The package's tail bootstrap "broke down for these data", and the p-values
  come from "our checked re-run with stable starting values". The adjusted
  p-values state what they adjust for. Speaker notes keep the technical terms.

Fourth revision (journal-club statistics pass), 27 October 2026:

- **References up front:** a "Today's papers" slide presents the method paper,
  the R Journal tutorial and *The Effect* §22.3. The reading slide again lists
  PATH and the suggested Bilancini application. The IST trial report, the IST
  database paper and the ACTG 175 trial report were added to `references.bib`
  (sources in `docs/evidence.md`).
- **More statistics in the main flow:**
  - the three estimands (Δ(x), APE and SPE, CA) in symbols after Step 3;
  - Step 4 shows both tail-profile figures, then a table of tail differences
    with stabilized-bootstrap SEs and jointly adjusted p-values, computed from
    `classification-stabilized.csv` during rendering (the other six traits have
    adjusted p ≥ .76);
  - "Why is the band so wide?": critical value 2.79 (constant odds ratio 2.17)
    versus 1.96. The pointwise (−20.2 to +0.6 pp) and uniform (−24.6 to
    +5.1 pp) intervals at the 10th percentile are computed from the saved
    scales during rendering;
  - the PATH comparison moved from backup to the discussion chapter.
- **Three trials:** `scripts/plot-trial-examples.R` draws the saved native SPE
  results of colon, IST and ACTG 175 without refitting. It checks each 81-point
  grid and the band ordering. The table slide reads averages, 10th/90th
  percentiles, interaction tests and held-out slopes from the three result
  directories. The IST attribution (ODC-By 1.0) is on the figure slide.
- **Figure wording:** dumbbell legends now read "10% least benefit" and "10%
  most benefit", as on the slides.
- **Locale:** under the container's POSIX locale, knitr printed `<U+2212>` in
  table cells. R output now uses HTML entities for "−" and "³", which pandoc
  converts in both formats.
- **Checks:**
  - 47 slides (31 main, 16 backup) passed all 21 dock checks, with zero heading
    overlaps at four 16:9 sizes and no slide overflow;
  - the portable export loaded all 11 images offline, with no failed requests
    or JavaScript errors;
  - the new PDF pages were inspected (49 pages; the references span three).

- `bash scripts/render.sh`: passed full-site rendering, including the portable
  RevealJS HTML export and matching 49-page, 16:9 Beamer handout. The colon
  trial is the worked example, and the closing three-trial slides draw saved
  IST and ACTG 175 results: 31 main-flow slides (including title, session map
  and chapter covers), followed by 16 backup slides including references.
- Two warm-up slides precede the trial and replace two basic percentile slides.
  The overall slide count is unchanged. Speaker notes were reduced from roughly
  2,000 to 750 words, retaining estimand, inference and interpretation details.
  Repeated caveats and drafting directions were removed from the presentation.
- All PDF pages were visually inspected. Figure sizes and source-note typography
  were adjusted to avoid caption clipping. The foundational and tutorial
  references render correctly.
- The revised model, full SPE/CA calls, forest teaser and assumptions backup
  were visually checked in the updated PDF. The teaser distinguishes flexible
  estimation from sorted summaries, with shared causal assumptions visible.
- The additional forest-intuition slide was checked in HTML and PDF, including
  its three sequential reveals. It explains shared tree groups and weighted
  treatment comparisons without adding a fitted forest or simulated trial.
- The displayed full model reproduces the recorded model coefficients within
  1e-10. Displayed SPE/CA calls parse and match the recorded contrast, grid/tail,
  bootstrap and characteristic arguments; no new bootstrap analysis was run.
- Both full calls use native line-highlight fragments with synchronized visible
  explanations. Four groups per call passed 14 forward/backward states and six
  direct-jump/re-entry checks, including reduced motion. All explanations remain
  visible; static PDFs show complete code and explanations together.
- Headless Chromium exercised all HTML slides (44, then 47, then 43, now 47), verified image loading,
  checked slide boundaries and JavaScript errors, and confirmed native MathML
  rendering. Math and fonts do not require external services.
- Four main chapter stacks and one backup stack form the two-dimensional deck.
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
  HTML/session logs retain their original/upstream whitespace. The first
  revision was made on `main`; the second was made on
  `claude/happy-volta-rzbbhy` and fast-forwarded into `main`.

These checks validate the current instance and generated artifacts. Website
publication and restoration in a fresh cloud task have not been performed.
