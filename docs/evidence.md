# Source and interpretation notes

Checked on 20 October 2026. This is the evidence ledger for the sorted-effects
session; simulated example results are generated separately and are not clinical
study findings.

## Sources checked directly

### Method and original software tutorial

Chen, Chernozhukov, Fernández-Val and Luo (2020), *SortedEffects: Sorted Causal
Effects in R*, **The R Journal** 12(1), 131–146.
[Published article](https://journal.r-project.org/articles/RJ-2020-006/),
DOI [10.32614/RJ-2020-006](https://doi.org/10.32614/RJ-2020-006).

The article's full source was read from the R Journal's public GitHub repository:
[R Markdown source](https://raw.githubusercontent.com/rjournal/rjournal.github.io/master/_articles/RJ-2020-006/RJ-2020-006.Rmd).
This is the journal's article source, not a secondary summary. The direct journal
domain returned HTTP 403 in this environment; GitHub delivery succeeded.

It verifies the foundational reference: Chernozhukov, Fernández-Val and Luo
(2018), *The Sorted Effects Method: Discovering Heterogeneous Effects Beyond Their
Averages*, **Econometrica** 86(6), 1911–1938,
DOI [10.3982/ECTA14415](https://doi.org/10.3982/ECTA14415).
The tutorial's bibliography and description were used to check that citation;
the foundational paper's full text was not fetched during this source check.

Teaching implications grounded in the tutorial:

- A partial effect can be a binary contrast in predicted outcomes or a derivative
  for a continuous exposure. The distribution is taken over a specified covariate
  population. Its quantiles are the sorted partial effects.
- Regression contrasts can be descriptive. Causal interpretation needs additional
  identifying assumptions; sorting alone supplies none.
- Classification analysis describes characteristics of observations in tails of
  the effect distribution. It includes estimation and uncertainty for those
  descriptions, as well as confidence sets for tail membership.
- The package implements both nonparametric pairs bootstrap and exponential
  weighted bootstrap. The inspected full-sample `spe()` path refits the model
  with resampled training counts, predicts on the original covariates, and
  retains the original quantile weights. Our independent reconstruction checks
  that fixed-reference behavior; it does not establish that the package
  includes sampling uncertainty in a broader population's covariate
  distribution. Match the resampling design to the intended target.
- Pointwise and uniform bands answer different questions. A uniform band is
  calibrated over the selected quantile-index range. The tutorial rearranges
  endpoints when needed to preserve monotonicity.
- Classification inference includes multiplicity-adjusted comparisons. A simple
  tail-characteristics table is a descriptive illustration unless the matching
  inference has actually been performed.

### Verified published application: mortgage denial

The R Journal tutorial uses Boston mortgage applications from 1990, with data
from Munnell et al. (1996), *Mortgage Lending in Boston: Interpreting HMDA Data*,
**American Economic Review** 86(1), 25–53.

- Sample: 2,380 applications, comprising 2,041 White and 339 Black applicants
  (the counts are stated in the package author's companion README).
- Outcome: denial of the application.
- Contrast: predicted denial probability with the Black indicator set to one
  versus zero, at the same financial and demographic covariates.
- Model: logit, with debt-to-income and housing-expense-to-income ratios, credit
  history, mortgage insurance, loan-to-value categories, self-employment,
  marital status and education controls. The tutorial does not require exposure
  interactions to obtain heterogeneous probability differences.
- In its published Table 1, the **bias-corrected** average partial effect is
  **0.051**, with a **90% interval of 0.021–0.081**. In percentage points this is
  **5.1**, with an interval **2.1–8.1**. These are the article's numbers, not a
  claim that a newly rerun model has identical output.
- The article describes probability contrasts ranging approximately from zero
  to 14 percentage points. Treat that range as the article's descriptive
  statement, not as an uncertainty interval or a clinical effect range.
- The example uses `us = (2:98)/100`, 500 bootstrap replicates, bias correction,
  and 90% pointwise/uniform bands. Classification compares the bottom and top
  10%; example inference considers 13 characteristics jointly.

Pedagogical framing: a model estimates larger conditional disparities for some
profiles than others. This does not identify individual causal effects of race.
For the teaching simulation we instead define *benefit* as control minus
treated event probability, so its positive direction differs from this denial
contrast. Label the sign on every figure.

The [author repository README](https://github.com/shuowencs/SortedEffects)
independently documents the same application and the sample composition.

## Software provenance

The [CRAN Git mirror](https://github.com/cran/SortedEffects) at commit
`18a1196e474ee1b62d6722754e8e377cba4ddc1f` contains version **1.7.0**, with a
CRAN publication date of **22 March 2022** in `DESCRIPTION`.
The [author GitHub repository](https://github.com/shuowencs/SortedEffects), checked
at the same time, reports **1.6.0**. Do not substitute it silently for the CRAN
release when reproducing the tutorial. The reported CRAN archival date from the
brainstorming notes was not independently verified here.

The benchmark implementation and any local plotting compatibility fix must be
documented alongside the benchmark output. Successful plotting alone does not
validate bootstrap or classification inference.

## Clinical applications: useful leads, not verified teaching claims

The following references came from the supplied brainstorming notes. Their
abstracts/full texts could not be retrieved under the current network policy.
They are retained as reading leads rather than used as sources for numerical
findings, causal claims or subgroup conclusions in the slides:

- Pullabhotla and Souza (2022), *Air pollution from agricultural fires increases
  hypertension risk*, **Journal of Environmental Economics and Management**,
  DOI [10.1016/j.jeem.2022.102723](https://doi.org/10.1016/j.jeem.2022.102723).
  The proposed sample size and age/sex/smoking subgroup findings remain unchecked.
- *Prosocial behavior in emergencies: Evidence from blood donors* (2022),
  **Social Science & Medicine**,
  [PMC record](https://pmc.ncbi.nlm.nih.gov/articles/PMC9595396/).
  The claim of little convincing heterogeneity remains unchecked.
- *Heterogeneous gender gaps in mental wellbeing* (2023),
  [PubMed 37535987](https://pubmed.ncbi.nlm.nih.gov/37535987/).
- *Lessons on the COVID-19 pandemic: who are the most affected* (2023),
  [Scientific Reports](https://www.nature.com/articles/s41598-023-36493-7).

Do not present these application summaries as verified findings without reading
the corresponding papers. A verified original tutorial application plus the
simulated treated/control example provide the material used in the presentation.
