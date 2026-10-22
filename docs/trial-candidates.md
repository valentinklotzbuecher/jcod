# Public trials for a second sorted-effects example

Checked on 22 October 2026. This is a comparison of data availability, study
design and teaching value. No new treatment-effect models were fitted and no
candidate was selected using a new heterogeneity p-value. Published findings
below remain distinct from our own descriptive data checks.

## Two leading choices

**Colon chemotherapy is the strongest clinical alternative.** It offers a
recognizable treatment decision, both sexes, a broad age range and detailed
tumour characteristics. A three-year mortality endpoint is almost completely
observed, so it can retain the current binary-outcome workflow.

**Charitable matching gifts is the strongest nonclinical alternative.** It has
a much larger sample, rich prior-giving histories and a published heterogeneity
result to revisit. The question would be what sorting and classification add
to an existing finding, rather than whether we can announce a new subgroup.

| Candidate | Verified usable data | Possible story | Main tradeoff |
|---|---|---|---|
| Colon chemotherapy | 619 randomized participants in combination chemotherapy versus observation; 618 known three-year death outcomes | Which patient and tumour profiles have larger absolute survival benefits? | Modest sample for interactions; some baseline values missing |
| Matching-gift experiment | 50,083 donors; 33,396 match offers and 16,687 controls; donation outcome complete | Does a matching gift change behavior differently across donor profiles? | Only 1,034 donations; several characteristics describe neighborhoods, not individuals |
| Online STI testing | Public file: 2,063 participants; 1,739 observed testing outcomes | Who takes up testing when access becomes easier? | Substantial, unequal outcome missingness between arms |
| Social-pressure voting | 344,084 voters in 180,002 randomized households | Which profiles change turnout after a social-pressure mailing? | Household/block design needs suitable resampling; published interaction evidence is limited |

None of these designs guarantees an informative or reproducible interaction
ranking. A strong average effect and a broad fitted SPE curve do not settle
that question. IST remains a useful worked example of this distinction.

## Colon chemotherapy: preferred clinical next check

The actual `survival::colon` dataset was inspected using survival 3.8-3.
It has 1,858 rows representing 929 people: one recurrence row and one death row
per person. These are not 1,858 independent participants.

A simple proposed comparison is **levamisole plus fluorouracil versus
observation**, using the death record (`etype == 2`). This gives:

- 315 observation and 304 combination-treatment participants.
- Ages 18–85; 312 women and 307 men in this comparison.
- One person censored before three years; the other 618 have known death status
  at that horizon. Someone censored early must not be coded as alive at three
  years. A missing-outcome sensitivity check can accompany the primary estimate.
- Among known outcomes, there are 109 deaths in 314 observation participants
  and 78 in 304 combination-treatment participants: crude risks of 34.7% and
  25.7%. These are descriptive counts, not evidence of effect modification.
- Baseline age, sex, bowel obstruction, perforation, tumour adherence to nearby
  organs, number of positive nodes, tumour differentiation, invasion extent,
  and time from surgery to registration. Here `adhere` describes the tumour;
  it is not adherence to treatment.
- Twelve missing node counts and 13 missing differentiation grades; 594 of the
  619 have complete values for these nine characteristics. A missing-data rule
  should be written before fitting.

The documentation flags a disagreement between `nodes` and the separate
`node4` indicator. Do not use both as if they were interchangeable verified
measurements. These are historical therapies and the example would concern
statistical interpretation, not present-day treatment selection.

The fitted model could have a common treatment odds ratio and a second model
with a small, specified set of treatment interactions. Age, sex and tumour
characteristics would support a larger CA table. A fixed validation split is
possible, but considerably less precise than in IST. We have not yet fitted
these models or chosen an interaction set.

Sources: [pinned dataset documentation](https://github.com/therneau/survival/blob/b76de62301f2ed4efcdbd8c062acc6759a54e511/man/colon.Rd),
[maintainer's randomization description](https://github.com/therneau/survival/blob/b76de62301f2ed4efcdbd8c062acc6759a54e511/vignettes/survival.Rnw#L3508),
[original package data file](https://raw.githubusercontent.com/therneau/survival/b76de62301f2ed4efcdbd8c062acc6759a54e511/data/cancer.rda).
The downloaded `colon` object is identical to the installed survival 3.8-3
version. The package declares LGPL >= 2. Its documentation cites the original
Moertel et al. trial reports and records the known node-variable issue. The
dictionary title says stage C while the vignette says stage B/C; use "resected
colon cancer" until the primary cohort description is reconciled.

## Matching gifts: preferred nonclinical alternative

Karlan and List (2007), *Does Price Matter in Charitable Giving? Evidence from
a Large-Scale Natural Field Experiment*, AER 97(5):1774–1793,
[DOI](https://doi.org/10.1257/aer.97.5.1774).
The full paper and actual 50,083-by-51 Stata file were inspected in the
[public replication mirror](https://github.com/gsbDBI/ExperimentData/tree/97a11199ba559f01c7b3803a1493ffa08631732e/Charitable).

The study randomized matching-gift offers to previous donors to a politically
oriented charity. A fixed contrast could be **any matching offer versus none**,
averaging over randomized match ratios, limits and suggested amounts. The
binary donation outcome is complete. Donation amount is also available, but
changing endpoints after inspecting interaction results would not be a sound
way to choose the example.

Potential CA traits include time since the last gift, previous donation
frequency and amounts, gender/couple indicators and neighborhood context.
ZIP-code age, income, education and population composition are area measures;
they must not be labeled as the individual donor's characteristics.

The original paper's Table 5 reports stronger responses in states that voted
Republican in 2004. One reported treatment-by-state interaction is about .009
with SE .003. This is an existing published result, not our discovery, and it
does not establish a political mechanism or guarantee validation of an SPE
ranking. It provides a concrete comparison for the method: does a sorted
distribution reveal more than the original subgroup summary?

Before fitting:

- Exclude `stateresponse`, `stateresponset`, `stateresponsec` and
  `stateresponsetminc`: they summarize outcomes and would leak outcome
  information into predictors.
- Handle 1,111 missing/sentinel gender values, 1,148 for couple status, and
  roughly 1,870 missing values in the ZIP characteristics explicitly.
- Match validation and inference to the unequal assignment proportions and
  the actual randomization design.
- Record original-data terms before redistributing the raw file. The mirror
  is publicly accessible; a separate data reuse license was not verified.

## Other options and why they rank lower

**Online STI testing (Wilson et al., 2017).** The raw spreadsheet and cleaning
code are accessible in the same
[Stanford collection](https://github.com/gsbDBI/ExperimentData/tree/97a11199ba559f01c7b3803a1493ffa08631732e/eSTI).
The cited trial is [PLoS Medicine 14:e1002479](https://doi.org/10.1371/journal.pmed.1002479).
The public file has 1,032 controls and 1,031 SH:24 participants, ages 16–30.
Baseline variables include gender, ethnicity, deprivation, number of partners
and an MSM indicator. Objective testing outcomes are missing for 214 controls
(20.7%) and 110 intervention participants (10.7%). The processed file silently
restricts to the 1,739 observed outcomes. Unknown MSM status should also remain
distinct rather than be recoded as known absence. This is a relatable public
health story, but handling follow-up properly adds work. The original paper's
full text was blocked here, so its trial flow and estimands need checking before
analysis.

**Social pressure and voter turnout (Gerber, Green and Larimer, 2008).**
The [paper and original data](https://github.com/gsbDBI/ExperimentData/tree/97a11199ba559f01c7b3803a1493ffa08631732e/Social)
were downloaded and inspected. The published neighbors-mailing contrast has
29.7% control versus 37.8% intervention turnout. Original baseline variables
include age, sex, household size and five previous election indicators.
Randomization is by household within geographic blocks. The paper reports
little support for its tested logit-scale interactions, so a large sample and
average effect are not evidence of new modifiers. The processed export appends
2011 census data to a 2006 trial; those columns cannot be called baseline.

**Job Corps.** The [public package export](https://github.com/cran/causalweight/tree/84b6412a13a2b7953e73ae2cacc8b696f7a6a18a)
has 9,240 observations and 46 variables, including randomized offer, year-four
earnings, education, parenthood, work history, health, smoking and alcohol.
However, the R object records 2,073 omitted rows without explaining the original
selection, while smoking and alcohol are flagged missing for 47.8% and 42.5%
of the retained observations. Their zero-filled values cannot be interpreted
as nonsmoking or nondrinking. This is worth revisiting if rich social/behavioral
characteristics become the priority, after resolving selection and missingness.

**Project STAR.** The actual [AER data](https://github.com/cran/AER/blob/master/man/STAR.Rd)
give 4,094 kindergarten students in small versus regular classes, with 3,743
observed reading and math scores, across 79 schools. The continuous outcome is
attractive, but school/classroom dependence, attrition and relatively few
baseline student traits make it a less direct replacement.

**Small clinical trials and benchmark datasets.** The breast-cancer recovery
trial in `quint::bcrp` is genuine but has only 252 participants across three arms
and 28 missing nine-month outcomes. Common IHDP benchmark exports may alter
treatment assignment or replace outcomes with simulations; an apparently richer
full IHDP file still has unresolved preprocessing. `aVirtualTwins::sepsis` is
explicitly simulated. These are not stronger choices for a transparent new
real-trial analysis. Hillstrom's email experiment is another lead, but its
primary download and provenance could not be independently checked here.

The indomethacin trial after ERCP is another verified clinical alternative:
602 participants, a complete pancreatitis endpoint, and 52/307 versus 27/295
events. Its 79 events limit a rich interaction model, and the timing of
procedural characteristics relative to randomization needs checking. The
GBSG2 breast-cancer export offers hormone receptors and a plausible biological
story, but its 686 selected complete cases and censored outcome require more
methodological setup. Neither is as straightforward as the proposed colon
mortality endpoint.

## Recommendation

For this audience, check **colon chemotherapy** next, with three-year mortality
and a small model specified before fitting. Use **matching gifts** if the group
prefers a large field experiment with a published heterogeneity story. Preserve
IST as a comparison and report all planned checks, including inconclusive ones.
