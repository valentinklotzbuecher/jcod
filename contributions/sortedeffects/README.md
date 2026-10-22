Prepared upstream fix for [shuowencs/SortedEffects](https://github.com/shuowencs/SortedEffects): stabilize binomial bootstrap fits and reject invalid classification inference.

- Target: upstream `master`, version 1.6.0, base commit `dcd94a20efdb8f3db26a0ee6d2ba118b1d65381d`.
- Fix commit: `a88dce12b5bc70648133edf82f51274963fcd57f`, branch `fix/stable-binomial-ca-bootstrap`.
- [Reviewable patch](bootstrap-stability.patch), [prepared PR text](PR.md), and [validation details](validation.md).
- The same production changes and regression tests also pass against CRAN 1.7.0. The author repository's older version still imports the archived `dummies` package.

The fix normalizes only logit/probit fitting weights, retaining the original weights for quantiles and classification moments. Failed fits and invalid CA draws cause an explicit error. No draws are removed or replaced.

**PR status:** no upstream PR has been opened. GitHub rejected the fork request with HTTP 403 / `Forbidden` at `POST /repos/shuowencs/SortedEffects/forks`, including a retry with elevated network access. The completed patch and PR text are saved here for submission once repository access is available.

To apply the patch, run from the JCOD repository root:

```sh
git clone https://github.com/shuowencs/SortedEffects.git ../SortedEffects
git -C ../SortedEffects switch -c fix/stable-binomial-ca-bootstrap dcd94a20efdb8f3db26a0ee6d2ba118b1d65381d
git -C ../SortedEffects am "$PWD/contributions/sortedeffects/bootstrap-stability.patch"
```

With the package dependencies installed, use a separate R library for testing:

```sh
mkdir -p ../SortedEffects-library
export R_LIBS_USER="$PWD/../SortedEffects-library${R_LIBS_USER:+:$R_LIBS_USER}"
R CMD INSTALL --library=../SortedEffects-library ../SortedEffects
Rscript ../SortedEffects/tests/binomial-bootstrap.R
Rscript ../SortedEffects/tests/invalid-inference.R
```

For the public colon-trial check, run from the JCOD root:

```sh
python3 scripts/fetch-colon-data.py
Rscript contributions/sortedeffects/verify-colon.R . /tmp/colon-comparison.csv
```

The [saved comparison](colon-comparison.csv) has zero differences between patched `ca()` and an independent reconstruction across all 12 estimates, standard errors, and joint p-values, using all 499 draws. Full `R CMD check --no-manual` completed with no errors or warnings and one existing documentation NOTE.

Weighted-quantile boundary rounding remains a separate limitation. Predictions from different convergent fitting strategies can be nearly identical while strict tail membership changes at numerical cutoffs. The patch preserves the likelihood target and the original quantile algorithm; it does not claim identical classification results for every fitting strategy. The saved slide analysis remains the separately labelled warm-start reconstruction.
