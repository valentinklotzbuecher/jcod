# Colon trial data: source and preparation

Checked on 22 October 2026. `R/colon-data.R` prepares the public colon trial
without fitting an outcome model or selecting a subgroup using outcomes.
The data acquisition script and manifest preserve the original source bytes.

## Source and trial design

The dataset is the `colon` object in the survival package's original
`cancer.rda`. The pinned
[maintainer source](https://github.com/therneau/survival/tree/b76de62301f2ed4efcdbd8c062acc6759a54e511)
declares survival 3.8-13. Its colon object was independently checked to be
identical to the object in the installed survival 3.8-3 runtime. Do not conflate
these two package version numbers.

The retained source vignette states that 929 patients were randomized to three
arms. The original dictionary identifies observation, levamisole, and levamisole
plus fluorouracil, and cites the original and final trial reports. These sources
establish randomized allocation, but we have not independently reconstructed
the trial's exact allocation algorithm or original data processing.

The dictionary title says stage C, whereas the vignette says stage B/C. This was
reconciled on 26 October 2026 using the trial abstracts. Neither publisher nor
PubMed pages were reachable from this environment, so the abstracts were read
from two independent captures each, held in public GitHub bibliographies.

- The 1990 report enrolled 1,296 patients with stage B2 or C disease. Only stage
  C patients could also be randomized to levamisole alone.
- The final report describes "929 eligible patients" with "stage III (Dukes stage
  C) colon cancer", randomized to observation, levamisole, or levamisole plus
  fluorouracil.
- The dictionary adds that the data set "is closest to that of the final report".

The three-arm 929-patient cohort is therefore described as **resected stage III
colon cancer**. Two records nevertheless report zero positive nodes (one
observation, one levamisole). This conflicts with stage III, and the records are
retained as recorded. The observation patient is in the 593-patient primary
cohort. The source describes historical therapies; the pilot is a method
illustration rather than a contemporary treatment recommendation.

The package declares LGPL >= 2; no separate dataset-specific license is supplied.
The complete declaration and GNU license texts are in `data/colon/`. Source
URLs, hashes and byte counts are in its manifest.

## One patient, one endpoint

The raw colon object has 1,858 rows: recurrence (`etype == 1`) and death
(`etype == 2`) records for each of 929 unique patients. The helper checks the
one-to-one pairing and agreement of baseline fields across the two records.
Only death records enter this pilot, so the two records are never treated as
independent patients.

The fixed treatment comparison retains observation (`rx == "Obs"`) and
levamisole plus fluorouracil (`rx == "Lev+5FU"`), giving 619 patients:
315 observation and 304 chemotherapy. Treatment represents randomized
allocation. Levamisole alone is outside this contrast.

The endpoint is death by **3 × 365.25 = 1,095.75 days**:

- `status == 1` and `time <= horizon`: death by the horizon (`outcome = 1`).
- Follow-up through the horizon, including a death after it: no death by the
  horizon (`outcome = 0`).
- `status == 0` and `time < horizon`: endpoint unknown, not a survivor.

One observation patient is censored early. The other 618 have known endpoint
status. There are 109 deaths among 314 observed observation outcomes and 78
among 304 chemotherapy outcomes. These are crude descriptive counts, already
inspected when choosing the trial, not heterogeneity findings.

Assigning the one unknown outcome either way gives a full-selected-cohort
average risk-reduction range of about 8.95–9.26 percentage points. This is a
missing-outcome sensitivity range, not a confidence interval.

## Primary cohort and baseline variables

The primary pilot requires observed endpoint, age, sex, node count,
differentiation and local extent. The 12 missing node counts and 13 missing
differentiation values occur in separate people; 25 known-endpoint patients are
excluded for these missing baseline fields. The resulting primary cohort has
**593 patients: 304 observation and 289 chemotherapy**. The complete-case
restriction changes the analysis population; it is not the full randomized
cohort. Its interpretation depends on assumptions about baseline recording
and endpoint missingness. The 618 known-endpoint records remain available for
the analysis plan's explicit sensitivity checks.

| Derived variable | Definition and interpretation |
|---|---|
| `treatment` | Factor: `observation`, `chemotherapy` |
| `outcome` | Death by 1,095.75 days, as defined above |
| `female` | One when the source `sex` code is zero; source one means male |
| `age_z` | `(age - 60) / 10` |
| `nodes`, `log_nodes` | Recorded positive-node count and `log1p(nodes)` |
| `nodes_over4` | More than four positive nodes, derived from the count; distinct from the supplied `node4` |
| `differ` | Factor: well, moderate, poor, from source codes 1, 2, 3 |
| `poor_diff` | One for source differentiation code 3 |
| `extent` | 1 submucosa; 2 muscle; 3 serosa; 4 contiguous structures |
| `extensive` | One for local extent 3 or 4 |
| `obstruct`, `perfor` | Tumour obstruction and perforation indicators |
| `adhere` | Tumour adherence to nearby organs; **not treatment adherence** |
| `surg_late` | Source `surg == 1`, long surgery-to-registration interval; the dictionary supplies no exact cutoff |
| `old_men` | Male and age at least 65 |
| `younger_women` | Female and age below 55 |

Age ranges from 18 to 85 in the selected comparison. The other baseline fields
are complete. Missing node counts and differentiation remain `NA` in the
known-endpoint and selected-cohort outputs; the helper performs no imputation.
The demographic combinations are descriptive CA traits, not pre-established
treatment-benefit subgroups.

## The node-variable inconsistency

The dictionary explicitly says that the maintainer does not know whether
`nodes` or `node4` is correct where they disagree. Eight selected participants
have a recorded `node4` different from `nodes > 4`; all eight enter the primary
cohort. No raw value is silently repaired. The helper provides a separate
disagreement audit with patient ID, allocation, both values, and primary-cohort
inclusion. A sensitivity using the recorded `node4` must be distinguished from
one that derives a threshold from the recorded count.

## Helper outputs and checks

`prepare_colon_data(path = "data/colon/cancer.rda", horizon = 3 * 365.25)` returns:

- `data`: 593 complete-baseline patients with known outcome.
- `all_outcomes`: 618 patients with known outcome, preserving baseline NAs.
- `selected`: all 619 patients in the fixed contrast, preserving all NAs.
- `audit`: selected, observed, missing and event counts by allocation, crude
  risks, missing-outcome bounds, and primary-cohort counts.
- `missingness`: missing baseline counts in each cohort.
- `exclusions`: the 26 omitted primary-cohort rows and their reasons.
- `node4_disagreements`: the eight unresolved count/indicator disagreements.
- `cohort_flow` and `horizon_days`: analysis population counts and endpoint time.

Checks cover source dimensions, unique patient pairing, matching baseline
records, legal codes, endpoint logic and absence of missing values in the
primary prepared data. They do not validate a fitted model or establish a
treatment-effect finding. The data helper does not depend on the installed
survival package once the pinned data file is present.
