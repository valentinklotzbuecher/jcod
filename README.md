# JCOD: sorted partial effects

An application-led session for statisticians: approximately 35–40 minutes of presentation with discussion during a one-hour slot. The active site is about sorted partial effects. All files from the former Synthetic Control Methods session are preserved in `archive/scm-2026/`.

## Build and preview

Use Quarto 1.8.27 or later, R 4.5, and ggplot2. PDF rendering uses XeLaTeX (with beamer, fontspec and the standard Pandoc LaTeX packages). In the prepared cloud environment, activate the local installation first:

```sh
source /workspace/.tools/activate
cd /workspace/jcod
Rscript R/demo.R
Rscript scripts/validate-demo.R
Rscript scripts/clinical-inference.R
# Optional: rerun the original package benchmark (SortedEffects 1.7.0 required)
Rscript scripts/benchmark-sortedeffects.R
bash scripts/render.sh
quarto preview --no-browser --host 127.0.0.1 --port 4200
```

On another machine, use your installed R and Quarto; the activation line is cloud-specific. Regenerating the clinical analysis requires ggplot2 and the pinned original SortedEffects 1.7.0 package, including its dependencies. The installation source is documented in `docs/software-validation.md`. Rendering the committed figures and CSVs does not require rerunning the analysis. `scpi` and `marginaleffects` are not required.

## Presenting

Download [`presentation.html`](presentation.html) and open it in a modern browser.
The HTML embeds its figures, styles, fonts and scripts and works without external
assets. [`presentation.pdf`](presentation.pdf) is the matching handout.
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

The main presentation introduces the literature and follows one fictional heart-failure discharge trial throughout. `R/clinical-walkthrough.R` supplies executable counterparts of the visible model, prediction, quantile and classification code. `R/demo.R` generates simulated data and teaching diagnostics; `scripts/clinical-inference.R` then runs original-package SPE and classification inference, validates its calculations independently, and writes the primary plots. Keep outputs in sync by running both steps after analysis changes. Rendering reads those results rather than repeating the bootstrap for each format.

Primary SPE bands use the package's IQR/max bootstrap on the observed trial profiles. Primary classification uses `ca()` standard errors and p-values adjusted jointly across age, congestion and female proportion. Dumbbell endpoints show means, with no invented endpoint confidence intervals. The package's SPE and CA routines use different resampling-weight conventions; see `docs/clinical-inference.md`. Separate `*-teaching` outputs and membership frequencies remain diagnostics. No frequentist coverage study or individual causal-effect inference is claimed.

## Session files

- `slides.qmd`: HTML RevealJS and Beamer PDF, including speaker notes and technical backup slides.
- `presentation.html` and `presentation.pdf`: generated, portable exports retained on GitHub.
- `assets/deck.js`: chapter navigation and overview support.
- `index.qmd`: session landing page and reading links.
- `R/demo.R`: reproducible simulated trial, sorted curves and bootstrap.
- `R/clinical-walkthrough.R`: executable core R examples for the fictional trial.
- `scripts/clinical-inference.R`: original-package clinical SPE/CA inference and independent bootstrap checks.
- `scripts/validate-demo.R`: statistical and output checks.
- `docs/evidence.md`: verified sources and boundaries of the application claims.
- `docs/software-validation.md`: original-package reproduction and benchmark results.
- `docs/clinical-inference.md`: clinical inferential target, resampling and output interpretation.
- `docs/validation.md`: current scientific, rendering and runtime verification.
- `references.bib`: bibliography for this session.

The archived session is excluded from the active site render. Its R caches and original dependencies have been preserved as historical artifacts; the new session does not load them. Build it separately in a scratch directory if needed.

No website publication has been requested. `quarto publish` changes the live site and is a separate action.
