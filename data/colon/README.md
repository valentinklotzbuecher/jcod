# Public colon chemotherapy trial data

The unchanged `cancer.rda` is from the
[survival package maintainer's repository](https://github.com/therneau/survival),
pinned to commit `b76de62301f2ed4efcdbd8c062acc6759a54e511`.
The accompanying source `DESCRIPTION` declares survival **3.8-13**. Its `colon`
object was checked against the installed survival **3.8-3** object and is
identical. The different version numbers concern the package source/runtime,
not two different colon datasets.

The original data file contains several package datasets. Our helper loads it
into a private environment and uses only the object named `colon`; it does not
alter, rename or reserialize the original file. The colon object has 1,858 rows
for 929 patients, with separate recurrence and death records for each patient.

The source dictionary `colon.Rd`, package `DESCRIPTION`, and full source vignette
`survival.Rnw` are retained byte for byte. The vignette states that the 929
patients were randomized to three treatment arms. The dictionary cites Laurie
(1989), Moertel (1990), and the final Moertel (1995) report. It also documents
the unresolved discrepancy between `nodes` and `node4`.

The package declares **LGPL (>= 2)**. No separate dataset-specific license was
supplied. Copies of the GNU Library GPL version 2 and GPL version 2 are included
as `LGPL-2` and `GPL-2`, obtained unchanged from a pinned R source distribution;
their source is distinguished from the survival package in `manifest.json`.

Every retained original file's exact URL, size and SHA-256 are recorded in
`manifest.json`. From the repository root:

```sh
python3 scripts/fetch-colon-data.py --verify-only
```

Omit `--verify-only` to download missing files from those same pinned sources.
Unexpected existing or downloaded bytes cause an error. There is no unverified
fallback download. See [data preparation notes](../../docs/colon-data.md) for
the treatment contrast, endpoint, exclusions and dictionary interpretations.
