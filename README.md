# JCOD: sorted partial effects

A journal-club session for statisticians, with 35–40 minutes of presentation and discussion during a one-hour slot. The active session is about sorted partial effects. The previous Synthetic Control Methods session is preserved in `archive/scm-2026/`.

## Build and preview

Use R 4.5, Quarto 1.8.27 or later, ggplot2, and the original SortedEffects 1.7.0 package. PDF rendering uses XeLaTeX and DejaVu Sans. Package provenance and installation commands are in `docs/software-validation.md`.

```sh
Rscript R/demo.R
Rscript scripts/clinical-inference.R
Rscript scripts/validate-demo.R
bash scripts/render.sh
quarto preview --no-browser --host 127.0.0.1 --port 4200
```

The optional published-example benchmark is `Rscript scripts/benchmark-sortedeffects.R`. Rendering committed figures and CSVs does not require rerunning the analysis. In the earlier prepared cloud environment, `source /workspace/.tools/activate` selected the installed tools; that path is environment-specific.

A branch-scoped GitHub Actions workflow in `.github/workflows/preview.yml` installs the runtime, regenerates the example, runs its numerical checks, and renders both slide formats. It uploads build outputs and logs without publishing the website.

## Presenting

Download [`presentation.html`](presentation.html) and open it in a modern browser. It embeds the figures, styles, fonts, and scripts. [`presentation.pdf`](presentation.pdf) is the matching handout. `bash scripts/render.sh` refreshes both portable exports and the site build.

Six main chapters run horizontally, with examples vertically beneath them. A seventh stack contains technical backup. The session map and chapter dock link directly to each topic.

- **Left / right:** switch chapters, or reveal the next fragment.
- **Up / down:** move within a chapter.
- **Space:** follow the complete sequence.
- **Esc / O / Overview:** open the slide overview.
- **S:** open Reveal's speaker view when supported by the browser.

The PDF consolidates fragment states. Transitions respect reduced-motion preferences.

## Example and inference

The example is a simulated randomized comparison of treated and control groups. It uses a generic adverse binary outcome, age, and a simulated binary sex indicator. The fitted model is `outcome ~ group * age_z * female`, with `age_z = (age - 60) / 10`. All numerical results are illustrative.

Benefit is control event risk minus treated event risk, in percentage points. The main figures show fitted benefit by age and sex, the sorted-effect curve, characteristics of the two effect tails, and uncertainty. Classification describes the age and female proportion in the highest- and lowest-benefit 10%.

`R/demo.R` generates the simulation and teaching diagnostics. `R/clinical-walkthrough.R` contains the executable model, prediction, quantile and classification examples. `scripts/clinical-inference.R` runs the original `spe()` and `ca()` routines, independently checks their calculations, and writes the primary plots. The historical script filenames remain stable.

Primary SPE bands use the package's IQR/max bootstrap over the observed trial profiles. Primary classification reports native standard errors and p-values adjusted jointly across age and female proportion. The two routines have different resampling-weight conventions, described in `docs/clinical-inference.md`. Dumbbell endpoints are descriptive means. Membership frequencies and separate `*-teaching` outputs are sensitivity diagnostics. These summaries concern conditional average effects rather than individual realized treatment effects.

## Session files

- `slides.qmd`: RevealJS and Beamer presentation with speaker notes and backup slides.
- `presentation.html` and `presentation.pdf`: portable rendered outputs.
- `index.qmd`: landing page and suggested pre-reading.
- `R/`: simulation and executable walkthrough.
- `scripts/`: original-package inference, numerical validation, benchmark, and render commands.
- `results/`: generated summary tables and figures.
- `docs/evidence.md`: sources and application interpretation.
- `docs/software-validation.md`: package provenance and benchmark scope.
- `docs/clinical-inference.md`: inferential targets and resampling details.
- `docs/validation.md`: execution and rendering evidence.
- `references.bib`: session bibliography.

The archive is excluded from the active render. Website publication is a separate action: run `quarto publish quarto-pub` only when requested.
