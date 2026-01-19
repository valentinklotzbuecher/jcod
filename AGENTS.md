# Repository Guidelines

## Project Structure & Module Organization
This is a Quarto website with a slide deck. Key paths:
- `_quarto.yml`, `_publish.yml` for site and publish settings.
- `index.qmd` (landing page), `slides.qmd` (main presentation), `about.qmd`.
- `references.bib` and `*.csl` for citations.
- Styling in `styles.css`, `theme-dark.scss`, `custom-unibas.scss`, and `beamer-unibas.tex`.
- `literature/` holds source PDFs.
Generated artifacts: `_site/`, `*_cache/`, `*_files/` (do not edit by hand).

## Build, Test, and Development Commands
- `quarto preview` - run a local dev server with live reload.
- `quarto render` - build the full site into `_site/`.
- `quarto render slides.qmd` - render only the slides.
- `quarto render slides.qmd --to revealjs` - HTML slides; `--to beamer` - PDF slides.
- `quarto publish quarto-pub` - publish to Quarto Pub.

## Coding Style & Naming Conventions
- Use 2-space indentation in YAML front matter; keep existing key order where possible.
- Quarto markdown should stay clean and readable; prefer short sections, callouts, and lists.
- R chunks: label them with `#| label: snake_case_name` and keep defaults (`echo: false`, `warning: false`, `message: false`) unless you need output.
- CSS/SCSS: use kebab-case class names and keep theme overrides in `theme-dark.scss` or `custom-unibas.scss` rather than inline style.

## Testing Guidelines
There are no automated tests. Validate changes by rendering:
- `quarto render` for a full build.
- For slides, render both formats to check layout and citations.

## Commit & Pull Request Guidelines
Recent commit messages are short, lowercase summaries (e.g., `landing page`). Follow the same style.
For PRs, include: what changed, what you rendered (e.g., `slides.qmd` revealjs + beamer), and screenshots for slide layout changes.

## Contributor Notes
If you need more context or common commands, check `CLAUDE.md`.
