#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
quarto render
# Keep portable deliverables on GitHub as well as the website build.
cp _site/slides.html presentation.html
cp _site/slides.pdf presentation.pdf
cp _site/ist-pilot.html ist-pilot.html
cp presentation.html presentation.pdf _site/
cp ist-pilot.html _site/
