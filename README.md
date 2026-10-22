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
