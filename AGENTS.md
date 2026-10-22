# Repository Guidelines

## Project Structure & Module Organization
This is a Quarto website with a sorted-partial-effects slide deck. Key paths:
- `_quarto.yml`, `_publish.yml` for site and publish settings.
- `index.qmd` (landing page), `slides.qmd` (main presentation and speaker notes).
- `references.bib` and `*.csl` for citations.
- Styling in `theme.scss` and `beamer-unibas.tex`.
- `R/demo.R` generates the age-and-sex simulation; `results/` holds its figures and tables.
- `scripts/` holds numerical validation and an optional original-package benchmark.
- `docs/` records evidence and software-validation scope.
- `ist-pilot.qmd` is a separate real-data report. `data/ist/` holds the corrected
  public trial data, original documentation and licence; preserve its raw bytes.
- `R/ist-data.R`, `R/ist-analysis.R` and the IST scripts implement the exploratory
  plan in `docs/ist-analysis-plan.md`; report both models and the fixed validation
  split. Do not select a model or split because it yields a stronger signal.
- `archive/scm-2026/` preserves the previous session. Do not change its historical files.
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

Keep simulated truth, model estimates, published study findings and uncertainty scopes distinct. The main example uses simulated randomized treated/control groups, a binary adverse outcome, age and sex. The model is `outcome ~ group * age_z * sex`, with `sex` coded 0 for male and 1 for female. Primary inference uses the original SortedEffects 1.7.0 `spe()` and `ca()` routines, with their inspected resampling targets documented in `docs/example-inference.md`. Dumbbell endpoints are descriptive means; report the separate native classification SEs and joint p-values without inventing moment confidence intervals. The transparent teaching bootstrap and membership frequencies remain separate diagnostics. Do not claim coverage guarantees or individual causal effects.

## Commit & Pull Request Guidelines
Recent commit messages are short, lowercase summaries (e.g., `landing page`). Follow the same style.
For PRs, include: what changed, what you rendered (e.g., `slides.qmd` revealjs + beamer), and screenshots for slide layout changes.

## Contributor Notes
If you need more context or common commands, check `CLAUDE.md`.
