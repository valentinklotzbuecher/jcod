# International Stroke Trial: corrected public data

Contains information from the **International Stroke Trial database (version 2)**,
University of Edinburgh, <https://doi.org/10.7488/ds/104>, made available under
the **ODC Attribution License v1.0**:
<https://opendatacommons.org/licenses/by/1-0/>. The depositor's complete licence
is retained verbatim as `license_text`.

The canonical Edinburgh deposit was blocked by the cloud environment's network
policy when checked on 22 October 2026. These unchanged files were obtained from
the [public mirror](https://github.com/ebergel/ist-1-database) at commit
`e9ebea9d6202bed786abc89785740e13ac087fed`. Its documentation identifies the
corrected version and the original deposit. This is a provenance-pinned copy of
that mirror, not an independent checksum verification against Edinburgh.

`manifest.json` records each original path, exact download URL, size and SHA-256.
Run `python3 scripts/fetch-ist-data.py --verify-only` from the repository root to
verify this copy, or run without that option to download missing files from the
same pinned commit. Unexpected existing or downloaded bytes cause an error;
there is no unverified fallback.

Files are kept byte for byte, including the CSVs' original encoding and line
endings. Read the dataset and dictionary as Latin-1. The raw dataset has 19,435
rows and 112 columns. Retained documents are the variable dictionary, original
database paper and version-2 correction commentary. The correction supersedes
the original release and repairs errors introduced while anonymizing dates.

See [data preparation notes](../../docs/ist-data.md) for outcome coding,
baseline characteristics and missing-data handling.
