# JCOD: sorted partial effects

A one-hour session for statisticians, with about 35–40 minutes of presentation
and time for discussion. The public colon chemotherapy trial is the main
example: sorted partial effects describe differences in estimated three-year
mortality benefit, and classification compares twelve patient characteristics.
A brief International Stroke Trial comparison puts the held-out ranking check
in context. The earlier simulation remains a teaching resource; the previous
Synthetic Control Methods session is preserved in `archive/scm-2026/`.

## Build and preview

Use Quarto 1.8.27 or later, R 4.5, and ggplot2. PDF rendering uses XeLaTeX (with beamer, fontspec and the standard Pandoc LaTeX packages). In the prepared cloud environment, activate the local installation first:

```sh
source /workspace/.tools/activate
cd /workspace/jcod
bash scripts/render.sh
quarto preview --no-browser --host 127.0.0.1 --port 4200
```

On another machine, use your installed R and Quarto; the activation line is
specific to this cloud environment. Rendering reads the committed figures and
CSVs and does not rerun bootstraps. Regenerating the analysis requires ggplot2
and the original SortedEffects 1.7.0 package, including its dependencies. The
source version and installation are documented in `docs/software-validation.md`.

To check the slide calculations or refresh the slide figures from saved results:

```sh
Rscript R/colon-walkthrough.R
Rscript scripts/plot-colon-slides.R
```

## Presenting

Download [`presentation.html`](presentation.html) and open it in a modern browser.
The HTML embeds its figures, styles and scripts and uses no external assets.
[`presentation.pdf`](presentation.pdf) is the matching handout.
`bash scripts/render.sh` rebuilds the website and refreshes both portable exports.

The presentation uses two dimensions: six main chapters run horizontally, and
their examples run vertically. An optional seventh stack holds technical backup.
Use the clickable session map or chapter dock to jump to a topic.

- **Left / right:** switch chapters (or reveal the next fragment).
- **Up / down:** move within a chapter.
- **Space:** follow the complete sequence, including animated reveals.
- **Esc / O / Overview:** open the native two-dimensional slide overview.
- **S:** open Reveal's speaker view when supported by the browser.

Transitions and auto-animation respect reduced-motion preferences. The PDF shows
the completed slides in reading order, with fragment states consolidated.

The six main chapters cover the literature, trial data, effects, classification,
inference and discussion. Short R examples show the model, predictions and tail
summaries. The classification table and dumbbell plots describe the lowest- and
highest-benefit tails; one fixed held-out split checks whether the estimated
ranking predicts differences in observed benefit.

`R/colon-walkthrough.R` contains executable versions of the slide calculations.
It fits the two specified models and verifies the saved point estimates.
`scripts/plot-colon-slides.R` creates the slide figures under
`results/colon/slides/` from existing results. The full analysis commands are
listed below; rendering does not require rerunning them.

Colon SPE bands use the native SortedEffects 1.7.0 IQR/max bootstrap on the
observed profiles and have been independently reconstructed. Native colon CA
bootstrap fits fail numerically; classification inference therefore uses a
separately audited, explicitly labelled stabilized reconstruction. Dumbbell
endpoints are descriptive means. Tail-characteristic comparisons do not test
treatment effects in women or men, and a sorted-effect quantile is not an
average effect in a subgroup. These checks do not establish coverage or identify
individual causal effects.

The colon ranking is promising but preliminary. Its primary interaction test
has p=.014; the specified sensitivity retaining all 618 known outcomes with
working baseline imputation has p=.054. Neither the negative lower-tail
estimate nor the held-out low-ranked group's result establishes harm from
chemotherapy in women. Prior subgroup literature has not been checked well
enough to claim a new clinical finding.

## Trial reports and analysis

The [International Stroke Trial report](ist-pilot.html) compares two specified
aspirin-effect models and checks their rankings on one fixed held-out sample.
The corrected public data, dictionary, licence and source hashes are retained in
`data/ist/`. The deck uses this pilot as a brief comparison with the colon trial.
Download the HTML to read it in a browser; [its Quarto source](ist-pilot.qmd)
shows how the saved results enter the report.

```sh
python3 scripts/fetch-ist-data.py --verify-only
Rscript scripts/analyze-ist.R
Rscript scripts/validate-ist-ranking.R
Rscript scripts/plot-ist.R
bash scripts/render.sh
```

The [analysis plan](docs/ist-analysis-plan.md) records the outcome, eight
interactions, 12 classification traits and validation strategy. The
[data notes](docs/ist-data.md) explain the endpoint and factorial design.
Patient bootstrap results are exploratory; this pilot does not establish a new
subgroup effect or a validated treatment rule.

A [fixed ACTG 175 secondary check](docs/actg175-pilot.md) uses a continuous CD4
endpoint and one treatment contrast. Run `Rscript R/actg175-pilot.R` to reproduce
its native inference and independent bootstrap reconstruction. Its source files
and licence provenance are under `data/actg175/`; results are under
`results/actg175/`. Neither pilot supports an established new interaction ranking.

The [comparison of other public trials](docs/trial-candidates.md) records the
candidate review that preceded the colon analysis, including a charitable
matching-gift experiment and the available data and design limitations.

The [colon chemotherapy report](colon-pilot.html) provides the main slide
example: 593 complete-baseline patients, six specified interactions, twelve
classification characteristics and one held-out split. Its [plan](docs/colon-analysis-plan.md)
records the sensitivities and a subsequent numerical amendment: native CA
bootstrap fits fail on this dataset, so the report distinguishes raw output
from an audited stabilized reconstruction. Download the HTML to read it in a
browser, or inspect its [Quarto source](colon-pilot.qmd).

```sh
python3 scripts/fetch-colon-data.py --verify-only
Rscript scripts/analyze-colon.R
Rscript scripts/validate-colon-ranking.R
Rscript scripts/verify-colon-inference.R
Rscript scripts/verify-colon-inference.R stabilize
Rscript scripts/plot-colon.R
Rscript scripts/plot-colon-slides.R
bash scripts/render.sh
```

## Earlier teaching simulation

`R/example-walkthrough.R` retains the simulated treated/control example with
age and sex. Its inference uses native SortedEffects `spe()` and `ca()`;
`docs/example-inference.md` documents the separate resampling targets. The
`*-teaching` outputs and membership frequencies are diagnostics, distinct from
native inference. To regenerate and check this resource:

```sh
Rscript R/demo.R
Rscript scripts/validate-demo.R
Rscript scripts/example-inference.R
# Optional original-package benchmark (SortedEffects 1.7.0 required)
Rscript scripts/benchmark-sortedeffects.R
```

## Session files

The [SortedEffects contribution](contributions/sortedeffects/README.md) contains
the tested bootstrap-stability patch, prepared upstream PR text and reproduction
instructions. Fork creation was blocked by an HTTP 403 response from the GitHub
API in this environment; no upstream PR has been opened. The installed package
and the saved analysis outputs were not replaced by this contribution.

- `slides.qmd`: HTML RevealJS and Beamer PDF, including speaker notes and technical backup slides.
- `presentation.html` and `presentation.pdf`: generated, portable exports retained on GitHub.
- `assets/deck.js`: chapter navigation and overview support.
- `index.qmd`: session landing page and reading links.
- `R/colon-walkthrough.R`: executable R calculations for the main trial example.
- `scripts/plot-colon-slides.R`: slide figures from the saved colon results.
- `colon-pilot.qmd` and `ist-pilot.qmd`: complete trial reports and their limitations.
- `R/demo.R`: simulated data, figures and teaching bootstrap.
- `R/example-walkthrough.R`: earlier simulated treated/control walkthrough.
- `scripts/example-inference.R`: original-package SPE/CA inference and independent bootstrap checks.
- `scripts/validate-demo.R`: statistical and output checks.
- `docs/evidence.md`: verified sources and boundaries of the application claims.
- `docs/software-validation.md`: original-package reproduction and benchmark results.
- `docs/example-inference.md`: inferential target, resampling and output interpretation.
- `docs/validation.md`: current scientific, rendering and runtime verification.
- `references.bib`: bibliography for this session.

The archived session is excluded from the active site render. Its R caches and original dependencies have been preserved as historical artifacts; the new session does not load them. Build it separately in a scratch directory if needed.

No website publication has been requested. `quarto publish` changes the live site and is a separate action.
