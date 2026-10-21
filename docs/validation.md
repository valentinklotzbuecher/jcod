# Validation of this session

## Demographic example revision, 21 October 2026

The revised sources use generic treated/control groups, age and sex. All
figures and model-derived slide values must be regenerated together. The
branch-scoped GitHub Actions workflow runs the original R and Quarto toolchain
and retains its logs as an artifact. Execution and layout findings will be
recorded here after the build completes.

## Checks required for this revision

- Run the simulation with 499 bootstrap draws per scenario.
- Recompute `spe()` and `ca()` with original SortedEffects 1.7.0, including the
  independent point-estimate and bootstrap reconstruction checks.
- Run `scripts/validate-demo.R` after regenerating the main inference figures.
- Render the website, portable RevealJS HTML and Beamer PDF.
- Check the rendered plots, numerical examples, references and slide boundaries.

The original published-example benchmark and archived SCM session remain
unchanged. Their prior validation is documented in `software-validation.md`
and the retained benchmark outputs. The present revision requires its own
execution evidence; the earlier fictional trial's numerical results do not
validate this new simulation.
