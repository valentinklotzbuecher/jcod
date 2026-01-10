# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Quarto website project containing academic presentations on Synthetic Control and Synthetic Difference-in-Differences methods. The site is published to Quarto Pub at https://valentink.quarto.pub/jcod.

## Common Commands

```bash
# Preview the site locally with live reload
quarto preview

# Render the entire site
quarto render

# Render a specific file
quarto render index.qmd

# Render to specific format (revealjs slides or beamer PDF)
quarto render index.qmd --to revealjs
quarto render index.qmd --to beamer

# Publish to Quarto Pub
quarto publish quarto-pub
```

## Project Structure

- `_quarto.yml` - Main Quarto configuration (site settings, theme, navbar)
- `index.qmd` - Main presentation slides (outputs to both RevealJS and Beamer)
- `about.qmd` - About page
- `references.bib` - BibTeX bibliography
- `nature.csl` - Citation style (Nature format)
- `styles.css` - Custom CSS styles
- `_publish.yml` - Quarto Pub deployment configuration

## Presentation Format

The main presentation (`index.qmd`) renders to two formats:
- **RevealJS** (HTML slides): 1280x720, incremental bullets
- **Beamer** (PDF slides): 16:9 aspect ratio

Speaker notes use the `::: notes` fence syntax.
