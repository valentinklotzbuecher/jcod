# Project guidance

Read `AGENTS.md` and `README.md` for current commands and statistical scope.

The active session is **Who benefits most? Sorted partial effects**, a one-hour
clinical-statistics journal club with 35–40 minutes of presentation and discussion.
`slides.qmd` renders to RevealJS HTML and Beamer PDF; `index.qmd` is the landing page.
Speaker notes are in `::: notes` blocks. The current theme is `theme.scss`.

Two warm-up slides use constructed population risks with the same average
benefit and different effect distributions. These are known conditional-average
effects, not sampled outcomes or an inferential simulation. Generate and check
them with `Rscript scripts/illustrate-warmup.R`.

The empirical example is the public colon chemotherapy trial, with three-year
mortality, twelve classification traits and one fixed held-out split. Its
findings are preliminary: the primary interaction p=.014 changes to p=.054
in the all-618 working-imputation sensitivity. Do not claim harm in women,
individual effects or verified clinical novelty. The cohort is resected stage III
disease. Prior subgroup leads in `docs/evidence.md` are unverified and stay off the
slides; the PATH slide attributes only the risk- and effect-modeling definitions.
Colon is the sole empirical trial
in the deck; IST remains a separate report. Preserve the exploratory context:
colon was the third trial pilot, without adjustment across datasets.

The main slides use full `spe()` and `ca()` calls with stepwise argument
highlighting. A closing teaser introduces causal forests for a future session,
distinguishing flexible effect estimation from sorted summaries and the
assumptions needed for causal interpretation. No forest is fitted here.

`R/colon-walkthrough.R` fits both colon models and checks the saved point
estimates. `scripts/plot-colon-slides.R` draws slide figures from saved results;
rendering does not rerun bootstraps. SPE uses native SortedEffects 1.7.0.
Classification inference uses an explicitly labelled audited stabilized
reconstruction; the failed native CA output is retained separately.

`R/demo.R` and `R/example-walkthrough.R` retain the earlier simulated
randomized-trial example as a teaching resource. Preserve its fixed random
seeds, effect sign convention and uncertainty declarations.
`scripts/validate-demo.R` checks its numerical claims; the optional
`scripts/benchmark-sortedeffects.R` exercises the pinned original software.

All previous Synthetic Control Methods materials are in `archive/scm-2026/`,
excluded from the active render. Preserve those historical files. The active
website has not been published as part of this change.
