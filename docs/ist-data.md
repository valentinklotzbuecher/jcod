# International Stroke Trial: data preparation

This is an exploratory reanalysis of a public randomized trial, not a new trial
finding. The data contain 19,435 participants allocated to aspirin or no aspirin
and, factorially, to heparin regimens. They were recruited in 1992–1996. The
database contains age, sex, blood pressure, delay from stroke onset,
consciousness, atrial fibrillation, prior aspirin, neurological deficits and
stroke subtype. Smoking and drinking are not recorded in the released data.

## Sources and retrieval

- Canonical dataset: University of Edinburgh, *International Stroke Trial
  database (version 2)*, <https://doi.org/10.7488/ds/104>.
- Database paper: Sandercock, Niewada and Członkowska (2011),
  *The International Stroke Trial database*, **Trials** 12:101,
  <https://doi.org/10.1186/1745-6215-12-101>.
- Correction: **Trials** (2012) 13:24,
  <https://doi.org/10.1186/1745-6215-13-24>.
- Primary trial report: International Stroke Trial Collaborative Group (1997),
  **Lancet** 349:1569–1581,
  <https://doi.org/10.1016/S0140-6736(97)04011-7>.

The Edinburgh host could not be fetched from this runtime. The committed copy
comes from the [public mirror](https://github.com/ebergel/ist-1-database) at
commit `e9ebea9d6202bed786abc89785740e13ac087fed`, together with its preserved
original dictionary, licence, database paper and correction commentary.
`data/ist/manifest.json` and `scripts/fetch-ist-data.py` pin every file's exact
source, size and SHA-256. There is no silent alternate source. This verifies
the mirror bytes; it does not claim an independent checksum match to Edinburgh.
The ODC Attribution License permits use and redistribution with attribution;
its full text and source notice are retained in `data/ist/`.

```sh
python3 scripts/fetch-ist-data.py
python3 scripts/fetch-ist-data.py --verify-only
```

## Outcome and analysis sample

Use randomized allocation `RXASP`, not aspirin actually received. `OCCODE`
is the derived six-month outcome: 1 = dead, 2 = dependent, 3 = not fully
recovered but independent, 4 = recovered. The adverse binary endpoint is
**death or dependence**, codes 1 or 2 versus 3 or 4. Codes 0 and 9 are missing
in this release. There are 19,285 observed endpoints and 150 missing (0.77%).

| Randomized arm | Total | Endpoint observed | Missing | Adverse events | Observed risk |
|---|---:|---:|---:|---:|---:|
| No aspirin | 9,715 | 9,646 | 69 | 6,125 | 63.498% |
| Aspirin | 9,720 | 9,639 | 81 | 6,000 | 62.247% |

The unadjusted complete-endpoint risk reduction is 1.251 percentage points.
Assigning all missing endpoints adverse or non-adverse separately in each arm
gives simple worst-case bounds for the full randomized-arm risks. The returned
audit includes these risk bounds; they are not confidence intervals. The
analysis sample is complete on the endpoint only, with baseline unknown values
retained explicitly. No endpoint or baseline imputation occurs here. Complete
endpoint analysis still requires an assumption about the missing outcomes.

Two coding traps matter: `DEAD6` is death from pulmonary embolism, not six-month
mortality; the follow-up death variable can include deaths outside exactly six
months. The analysis therefore uses the trial's derived `OCCODE` endpoint.

## Prepared data interface

```r
source("R/ist-data.R")
ist <- prepare_ist_data()
dat <- ist$data
ist$audit
ist$missingness
```

`prepare_ist_data()` returns `data`, `audit` and `missingness`. Data rows retain
`rowid`, their original position in the raw file, and contain:

- `outcome`: 0/1; `aspirin`: factor `no_aspirin`, `aspirin`.
- `heparin`: factor `none`, `low`, `medium`; original pilot code H is combined
  with M, as instructed by the dictionary.
- `age`, `female` (0 male, 1 female), `sbp` (mmHg), `delay` (hours).
  Scales are `age_z = (age - 70)/10`, `sbp_z = (sbp - 160)/20`, and
  `delay_z = (delay - 24)/24`.
- `consciousness`: F fully alert, D drowsy, U unconscious. U here is a known
  clinical state, not unknown. `not_alert` equals D or U.
- `af` and `prior_aspirin`: factors N, Y, unknown. Both are unrecorded for
  984 pilot participants in the full release.
- `arm_deficit`, `leg_deficit`, `dysphasia`: factors N, Y, C. C means cannot
  assess, affecting 123, 255 and 584 full-release records respectively.
- `stroke_type`: LACS, PACS, POCS, TACS, OTH; `hospital`, `country` factors.
- Numeric characteristic indicators: `af_yes`, `af_unknown`,
  `prior_aspirin_yes`, `prior_aspirin_unknown`, `arm_yes`, `arm_unknown`,
  `leg_yes`, `leg_unknown`, `dysphasia_yes`, `dysphasia_unknown`.
- `old_men`: male and age at least 75; `younger_women`: female and age below
  65. These are explicit descriptive profiles, not an exhaustive partition.

An indicator such as `af_yes` means **recorded AF present**; its complement
includes unknowns and must not be labelled AF absent. Unknown indicators are
retained to make that distinction available to models and classification.
There are no missing age, sex, systolic-pressure or delay values. Their observed
ranges are age 16–99, pressure 70–295 mmHg and delay 1–48 hours. No median
imputation or numeric missingness flags are needed.

## Design and scope

The database paper describes a randomized international trial and credits the
Oxford Clinical Trial Service Unit with randomization. There are 466 distinct
hospital codes and 36 country codes in the released data. The database paper
does not specify enough allocation detail to independently verify any claim
about minimization or stratification; consult the primary trial report or
protocol before making such a claim.

Heparin is a second randomized allocation, not a patient characteristic. An
aspirin contrast should state how it handles that factorial allocation and
what population is standardized. Patient-level pairs bootstrap is a modeling
choice for an exploratory analysis; it is not claimed here to reproduce the
original randomization scheme or account for possible centre-level structure.
Only baseline variables should define explanatory profiles. Derived outcome
prognoses, actual post-randomization medication and later events are not
baseline covariates for this analysis. Nothing in data preparation establishes
effect heterogeneity or that a resulting pattern was previously overlooked.
