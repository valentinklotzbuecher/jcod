# Fonts

The deck and landing page use the typefaces of
[valentinklotzbuecher.github.io](https://github.com/valentinklotzbuecher/valentinklotzbuecher.github.io):
Zen Kaku Gothic New for text and IBM Plex Mono for code and labels. They are
stored here so the self-contained HTML export works offline and the Beamer PDF
can embed them. `fonts.css` declares the web fonts; `beamer-unibas.tex` loads
the TTF files for XeLaTeX.

| Files | Source (27 October 2026) | Change |
|:--|:--|:--|
| `ZenKakuGothicNew-{400,500,700}.woff2`, `ZenKakuGothicNew-{Regular,Bold}.ttf` | `google/fonts`, `ofl/zenkakugothicnew` | Subset to Latin, punctuation, arrows and math operators with fontTools `pyftsubset` |
| `IBMPlexMono-*-latin*.woff2` | Google Fonts CSS2 API, Latin and Latin Extended files | None |
| `IBMPlexMono-{Regular,Medium,Italic}.ttf` | `google/fonts`, `ofl/ibmplexmono` | None |

Both families are licensed under the SIL Open Font License 1.1
(`OFL-ZenKakuGothicNew.txt`, `OFL-IBMPlexMono.txt`). Zen Kaku Gothic New has no
reserved font name; the IBM Plex Mono files are unmodified. Glyphs that Zen Kaku
Gothic New lacks (≥, ≤, ł) fall back to DejaVu Sans in the PDF and to system
fonts in the browser.
