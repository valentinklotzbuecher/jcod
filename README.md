# JCOD: sorted partial effects

A one-hour session for statisticians, with about 35–40 minutes of presentation and time for discussion. One simulated treated/control example shows how sorted partial effects describe variation in absolute risk reductions by age and sex. The previous Synthetic Control Methods session is preserved in `archive/scm-2026/`.

## Build and preview

Use Quarto 1.8.27 or later, R 4.5, and ggplot2. PDF rendering uses XeLaTeX (with beamer, fontspec and the standard Pandoc LaTeX packages). In the prepared cloud environment, activate the local installation first:

```sh
source /workspace/.tools/activate
cd /workspace/jcod
Rscript R/demo.R
Rscript scripts/validate-demo.R
Rscript scripts/example-inference.R
# Optional: rerun the original package benchmark (SortedEffects 1.7.0 required)
Rscript scripts/benchmark-sortedeffects.R
bash scripts/render.sh
quarto preview --no-browser --host 127.0.0.1 --port 4200
```

On another machine, use your installed R and Quarto; the activation line is specific to this cloud environment. Regenerating the analysis requires ggplot2 and the original SortedEffects 1.7.0 package, including its dependencies. The source version and installation are documented in `docs/software-validation.md`. Rendering the committed figures and CSVs does not require rerunning the analysis.

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

The six main chapters cover the literature, example data, effects, classification, inference and discussion. Short R examples show the model, predictions and tail summaries. An age-by-sex plot shows the fitted risk reductions before they are sorted; dumbbell plots compare the characteristics of the lowest- and highest-benefit tails.

`R/example-walkthrough.R` contains executable versions of the slide code. Run `R/demo.R` and then `scripts/example-inference.R` after analysis changes. The second script calls the original package, independently checks its calculations and writes the primary figures. Rendering reads the saved results.

Primary SPE bands use the package's IQR/max bootstrap on the observed profiles. Classification uses native standard errors and p-values adjusted jointly across age and female proportion. Dumbbell endpoints are descriptive means; inference for their differences is reported separately. The SPE and CA routines use different resampling weights, as documented in `docs/example-inference.md`. The separate `*-teaching` outputs and membership frequencies are diagnostics. These checks do not establish coverage or identify individual causal effects.

## Real-data pilot

The [International Stroke Trial report](ist-pilot.html) compares two specified
aspirin-effect models and checks their rankings on one fixed held-out sample.
The corrected public data, dictionary, licence and source hashes are retained in
`data/ist/`. The report is separate from the main simulated slide example.
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

The [comparison of other public trials](docs/trial-candidates.md) identifies
colon chemotherapy and a charitable matching-gift experiment as the strongest
options for a second example, with data checks and design limitations.

The [colon chemotherapy report](colon-pilot.html) now implements that next
check: 593 complete-baseline patients, six specified interactions, twelve
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
bash scripts/render.sh
```

## Session files

- `slides.qmd`: HTML RevealJS and Beamer PDF, including speaker notes and technical backup slides.
- `presentation.html` and `presentation.pdf`: generated, portable exports retained on GitHub.
- `assets/deck.js`: chapter navigation and overview support.
- `index.qmd`: session landing page and reading links.
- `R/demo.R`: simulated data, figures and teaching bootstrap.
- `R/example-walkthrough.R`: executable R examples for the treated/control analysis.
- `scripts/example-inference.R`: original-package SPE/CA inference and independent bootstrap checks.
- `scripts/validate-demo.R`: statistical and output checks.
- `docs/evidence.md`: verified sources and boundaries of the application claims.
- `docs/software-validation.md`: original-package reproduction and benchmark results.
- `docs/example-inference.md`: inferential target, resampling and output interpretation.
- `docs/validation.md`: current scientific, rendering and runtime verification.
- `references.bib`: bibliography for this session.

The archived session is excluded from the active site render. Its R caches and original dependencies have been preserved as historical artifacts; the new session does not load them. Build it separately in a scratch directory if needed.

No website publication has been requested. `quarto publish` changes the live site and is a separate action.
