# Project guidance

Read `AGENTS.md` and `README.md` for current commands and statistical scope.

The active session is **Who benefits most? Sorted partial effects**, a one-hour
clinical-statistics journal club with 35–40 minutes of presentation and discussion.
`slides.qmd` renders to RevealJS HTML and Beamer PDF; `index.qmd` is the landing page.
Speaker notes are in `::: notes` blocks. The current theme is `theme.scss`.

`R/demo.R` generates an explicitly simulated randomized-trial example. Preserve
its fixed random seeds, effect sign convention and uncertainty declarations.
`scripts/validate-demo.R` checks its numerical claims; the optional
`scripts/benchmark-sortedeffects.R` exercises the pinned original software.

All previous Synthetic Control Methods materials are in `archive/scm-2026/`,
excluded from the active render. Preserve those historical files. The active
website has not been published as part of this change.
