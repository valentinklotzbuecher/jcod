# Source and interpretation notes

Sources checked on 20 October 2026; pre-reading links and the health application updated on 21 October 2026. This is the evidence ledger for the sorted-effects
session; simulated trial results are generated separately and are not clinical
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
For the generic simulation we define *benefit* as control minus
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

## Health application for optional pre-reading

Pullabhotla and Souza (2022), *Air pollution from agricultural fires increases
hypertension risk*, **Journal of Environmental Economics and Management** 115,
102723. DOI [10.1016/j.jeem.2022.102723](https://doi.org/10.1016/j.jeem.2022.102723).

The [July 2022 author paper](https://eel107.s3.us-east-2.amazonaws.com/EEL_111.pdf)
was checked directly. Section 3, Figure 4 and Table 1 show sorted effects and
classification. Appendix B.2 describes marginal derivatives from a logistic
model and use of SortedEffects. Age and sex feature in the tail descriptions.
The exposure design uses fires and wind direction; sorting summarizes the
fitted heterogeneity. Probability-scale heterogeneity can also reflect baseline
risk. The published article's metadata was checked separately; the reading
pointers refer to the linked author version.

## Suggested preparation

Start with Chen et al. (2020), Section 1 and Sections 2.2–2.3. For the original
method, read the introduction and Section 2 of Chernozhukov et al. (2018),
available as a [free author version](https://arxiv.org/abs/1512.05635). The health
application is optional. The main slides continue to use a generic simulation.
