# Repository Guidelines

## Project Structure & Module Organization
This is a Quarto website with a sorted-partial-effects slide deck. Key paths:
- `_quarto.yml`, `_publish.yml` for site and publish settings.
- `index.qmd` (landing page), `slides.qmd` (main presentation and speaker notes).
- `references.bib` and `*.csl` for citations.
- Styling in `theme.scss` and `beamer-unibas.tex`, after the light theme of
  valentinklotzbuecher.github.io. Fonts are local in `assets/fonts/` (`fonts.css`
  for HTML, TTF files for XeLaTeX; OFL licences and provenance in its README).
  Never import Google Fonts: the portable HTML must load nothing external.
- `R/colon-walkthrough.R` is the executable walkthrough for the main trial example;
  `scripts/plot-colon-slides.R` builds slide figures from saved colon results.
- `scripts/illustrate-warmup.R` generates the two-slide constructed population
  example and validates its risks, equal means and exact discrete quantiles.
  Its `results/warmup/` outputs are known quantities, not fitted trial results.
- `R/demo.R` generates the earlier age-and-sex simulation, retained as a teaching
  resource; `results/` holds its figures and tables.
- `scripts/` holds numerical validation and an optional original-package benchmark.
- `docs/` records evidence and software-validation scope.
- `ist-pilot.qmd` is a separate real-data report. `data/ist/` holds the corrected
  public trial data, original documentation and licence; preserve its raw bytes.
- `R/ist-data.R`, `R/ist-analysis.R` and the IST scripts implement the exploratory
  plan in `docs/ist-analysis-plan.md`; report both models and the fixed validation
  split. Do not select a model or split because it yields a stronger signal.
- `archive/scm-2026/` preserves the previous session. Do not change its historical files.
- `colon-pilot.qmd` and `docs/colon-analysis-plan.md` record the subsequent colon
  trial pilot. Native CA is numerically unstable for these data; raw output is
  retained in `classification-native.csv`, while the report uses the separately
  audited `classification-stabilized.csv`. Preserve that distinction.
Generated artifacts: `_site/`, `*_cache/`, `*_files/` (do not edit by hand).

## Build, Test, and Development Commands
- `quarto preview` - run a local dev server with live reload.
- `quarto render` - build the full site into `_site/`.
- `bash scripts/render.sh` - build and refresh tracked portable HTML/PDF exports; use after slide or theme changes.
- `quarto render slides.qmd` - render only the slides.
- `quarto render slides.qmd --to revealjs` - HTML slides; `--to beamer` - PDF slides.
- `Rscript R/demo.R` - regenerate simulated data summaries and figures (499 bootstrap draws by default).
- `Rscript scripts/validate-demo.R` - validate statistical claims and output artifacts.
- `Rscript scripts/example-inference.R` - run primary SPE/CA inference and refresh its figures after changing the simulation.
- `Rscript scripts/benchmark-sortedeffects.R` - rerun original-package integration checks, requiring SortedEffects 1.7.0.
- `python3 scripts/fetch-ist-data.py --verify-only` - verify pinned public IST files.
- `Rscript scripts/analyze-ist.R` - run the two IST models and native SPE/CA inference.
- `Rscript scripts/validate-ist-ranking.R` - validate both rankings on the fixed held-out sample.
- `Rscript scripts/plot-ist.R` - refresh IST report figures after inference.
- `python3 scripts/fetch-colon-data.py --verify-only` - verify pinned colon source files.
- `Rscript scripts/analyze-colon.R` - run the specified colon models and sensitivities.
- `Rscript scripts/validate-colon-ranking.R` - run the one fixed colon validation split.
- `Rscript scripts/verify-colon-inference.R` - audit and reconstruct all native bootstrap fits.
- `Rscript scripts/verify-colon-inference.R stabilize` - reconstruct CA with the documented numerical initialization change.
- `Rscript scripts/plot-colon.R` - refresh the descriptive colon figures.
- `Rscript R/colon-walkthrough.R` - fit the two colon models and verify the saved point estimates.
- `Rscript scripts/plot-colon-slides.R` - refresh slide figures from saved results without fitting models or bootstraps.
- `Rscript scripts/plot-colon-patients.R` - refit the interaction model for point predictions only, check them against the saved SPE/APE, and redraw the two per-patient figures.
- `LC_ALL=C.UTF-8 Rscript scripts/plot-trial-examples.R` - draw the closing colon/IST/ACTG 175 figure from saved SPE/APE results; nothing is refitted.
- `Rscript scripts/illustrate-warmup.R` - validate and redraw the constructed population warm-up. Run R under a UTF-8 locale (e.g. `LC_ALL=C.UTF-8` in a C-locale container) so its ⅓/⅔ tick labels render.
- `quarto publish quarto-pub` - publishes externally; run only when explicitly requested.

In the prepared cloud environment, first run `source /workspace/.tools/activate`.
Use the existing checkout; do not create a worktree unless explicitly requested.

## Coding Style & Naming Conventions
- Use 2-space indentation in YAML front matter; keep existing key order where possible.
- Quarto markdown should stay clean and readable; prefer short sections, callouts, and lists.
- R chunks: label them with `#| label: snake_case_name` and keep defaults (`echo: false`, `warning: false`, `message: false`) unless you need output.
- CSS/SCSS: use kebab-case class names and keep theme overrides in `theme.scss` rather than inline style.

## Testing Guidelines
For changes to the simulation, regenerate its outputs and run the numerical validation script. Validate slide changes by rendering:
- `quarto render` for a full build.
- For slides, render both formats to check layout and citations.

Keep simulated truth, model estimates, published study findings and uncertainty scopes distinct. The main example uses the public colon trial, comparing observation with levamisole plus fluorouracil for three-year mortality in 593 complete-baseline patients. Benefit is observation risk minus chemotherapy risk. The six-interaction model is compared with a constant-treatment-odds-ratio model; twelve characteristics describe the fitted tails. Preserve the one fixed held-out split and all specified sensitivities: the interaction test changes from p=.014 in the primary analysis to p=.054 in the all-618 working-imputation sensitivity. This is preliminary ranking evidence, not a finding of harm in women or a verified new clinical discovery.

Colon SPE bands use native SortedEffects 1.7.0 and have been independently reconstructed. Native colon CA is numerically invalid; any displayed CA inference must be explicitly identified as the separately audited stabilized reconstruction. Plain words are fine on slides: the package's own tail bootstrap broke down for these data, and the p-values come from a checked re-run with stable starting values. Dumbbell endpoints are descriptive means, not confidence intervals. A sorted-effect quantile is not the average effect in a tail or a women-specific treatment effect. Held-out tertiles differ from the full-sample classification deciles. Do not claim coverage guarantees or individual causal effects: sorted effects describe conditional average effects across patient profiles. Describe the held-out check as internal validation in one split, not replication; a missing ranking signal in another pilot is not proof of no heterogeneity. The tails differ in modelled traits partly by design, so classification is not a test of effect modification. Rendering reads saved results and does not require new bootstrap runs.

Colon is the worked trial example. The closing three-trial slides show only saved IST and ACTG 175 pilot results (SPE curves, averages, interaction tests, held-out slopes) with their own plans and caveats; keep the IST data attribution on the figure slide. The preceding two-slide warm-up uses constructed population risks: three equally common profiles, control risk 40%, treated risks 30/30/30% or 50/30/10%. Both average benefits are 10 pp. Do not label these quantities as sampled or fitted outcomes, attach sampling intervals, or use this discrete illustration to claim inferential coverage. IST remains a separate report with its data and analysis intact. Retain the exploratory provenance: colon was the third trial pilot, with no across-dataset inference adjustment. The earlier simulated treated/control example is retained for teaching and backup; its model is `outcome ~ group * age_z * sex`, with `sex` coded 0 for male and 1 for female. Its original-package inference, resampling scope, separate teaching bootstrap and membership diagnostics remain documented in `docs/example-inference.md`.

The trial abstracts identify the three-arm cohort as resected stage III (Dukes' C) colon cancer; see `docs/colon-data.md`. The PATH backup slide maps the constant-odds-ratio model to risk-based heterogeneity and the interaction model to effect modeling, and presents sorted effects as a summary of estimated effects rather than a competing model. It attributes only those definitions to the PATH statement; the model-comparison slide cites the same two terms. Prior subgroup findings listed in `docs/evidence.md` are unverified search extracts; keep them off the slides until they are checked against the full texts.

The main slides follow the intuitive framing of Huntington-Klein's *The Effect* (§22.3): model, predict, sort, describe, then trust. The main flow also presents today's papers; chapter 02 tells the four steps first (ending with both tail profiles), then the three estimands in symbols and the full `spe()` and `ca()` calls with argument highlighting; chapter 03 shows their inference (uniform band, jointly adjusted tail table). The band construction, model code and native CA failure are in the backup stack. Preserve the CA numerical-stability disclosure wherever CA inference or its call appears. The closing causal-forest teaser is for a future session: distinguish causal identification assumptions, effect estimation and sorted summaries. Do not imply that sorting creates causality, that SPE requires a parametric model, or that a forest was fitted in this session.

## Commit & Pull Request Guidelines
Recent commit messages are short, lowercase summaries (e.g., `landing page`). Follow the same style.
For PRs, include: what changed, what you rendered (e.g., `slides.qmd` revealjs + beamer), and screenshots for slide layout changes.

## Contributor Notes
If you need more context or common commands, check `CLAUDE.md`.
