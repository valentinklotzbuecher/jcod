#!/usr/bin/env Rscript
# Executable point-estimate walkthrough for the colon slides.
# Run from the repository root: Rscript R/colon-walkthrough.R
# This reproduces the existing analysis without rerunning bootstrap inference
# or writing any result files. See docs/colon-analysis-plan.md for the scope.

source("R/colon-data.R")
source("R/colon-analysis.R")
stopifnot(requireNamespace("Hmisc", quietly = TRUE))

# 1. Use the same complete-baseline cohort and specified interaction model.
# prepare_colon_data() selects observation versus levamisole + fluorouracil,
# one death record per person, and the known three-year mortality endpoint.
dat <- prepare_colon_data()$data
fm <- colon_formulas()$interaction
fit <- glm(fm, data = dat, family = binomial())
colon_check_fit(fit)
stopifnot(nrow(dat) == 593L, sum(dat$outcome) == 179L, fit$rank == 19L)

# 2. Predict both treatment conditions for each of the same observed profiles.
# Positive benefit means a lower fitted mortality risk under chemotherapy.
control <- transform(dat, treatment = "observation")
treated <- transform(dat, treatment = "chemotherapy")
p_control <- predict(fit, newdata = control, type = "response")
p_treated <- predict(fit, newdata = treated, type = "response")
benefit <- as.numeric(p_control - p_treated)
stopifnot(all(is.finite(benefit)))

# 3. Sort those contrasts using the package's weighted-quantile convention.
# The average uses all 593 profiles, not just the displayed percentile grid.
u <- seq(.10, .90, by = .01)
spe_curve <- Hmisc::wtd.quantile(
  benefit, weights = rep(1, nrow(dat)), probs = u
)
average_benefit <- mean(benefit)

# 4. Describe the lower and upper 10% tails using the same inclusive cutoffs.
# Membership is assigned using fitted benefit. The model was learned from
# full-sample treatments and outcomes, so this selection is data-dependent.
# These means describe selected profiles; they are not effects estimated
# separately within age, sex or tumour-characteristic subgroups.
cutoff <- Hmisc::wtd.quantile(
  benefit, weights = rep(1, nrow(dat)), probs = c(.10, .90)
)
low <- benefit <= cutoff[1]
high <- benefit >= cutoff[2]
traits <- colon_characteristics()
low_mean <- colMeans(dat[low, traits$variable])
high_mean <- colMeans(dat[high, traits$variable])
tail_means <- data.frame(
  traits,
  overall = as.numeric(colMeans(dat[, traits$variable])),
  low_mean = as.numeric(low_mean),
  high_mean = as.numeric(high_mean),
  difference = as.numeric(high_mean - low_mean),
  n_low = sum(low), n_high = sum(high), row.names = NULL
)
stopifnot(sum(low) == 60L, sum(high) == 60L, nrow(tail_means) == 12L)

# 5. Check the calculation against the saved results used in the slides.
# Native SPE/APE point estimates and audited CA point means must agree.
# The stabilized CA table has the same point estimates as native CA; only
# its bootstrap reconstruction addresses the native numerical failures.
saved_spe <- read.csv("results/colon/interaction-spe.csv")
saved_ape <- read.csv("results/colon/interaction-ape.csv")
saved_ca <- read.csv("results/colon/classification-stabilized.csv")
index <- match(traits$variable, saved_ca$variable)
stopifnot(nrow(saved_spe) == length(u), nrow(saved_ape) == 1L,
          all(saved_spe$model == "interaction"), saved_ape$model == "interaction",
          max(abs(saved_spe$percentile - u)) < 1e-12,
          !anyNA(index), !anyDuplicated(saved_ca$variable),
          all(saved_ca$n_low[index] == sum(low)),
          all(saved_ca$n_high[index] == sum(high)))
mean_columns <- c("overall", "low_mean", "high_mean", "difference")
checks <- c(
  interaction_SPE = max(abs(as.numeric(spe_curve) - saved_spe$estimate)),
  interaction_APE = abs(average_benefit - saved_ape$estimate),
  CA_means = max(abs(as.matrix(tail_means[, mean_columns]) -
                      as.matrix(saved_ca[index, mean_columns])))
)

# The comparison figure also includes the specified constant-odds-ratio model.
# Verify its saved point estimates without changing the main walkthrough model.
constant_fit <- glm(colon_formulas()$constant, data = dat, family = binomial())
colon_check_fit(constant_fit)
constant_benefit <- contrast_colon(constant_fit, dat)
constant_spe <- Hmisc::wtd.quantile(
  constant_benefit, weights = rep(1, nrow(dat)), probs = u
)
saved_constant_spe <- read.csv("results/colon/constant-spe.csv")
saved_constant_ape <- read.csv("results/colon/constant-ape.csv")
stopifnot(constant_fit$rank == 13L,
          nrow(saved_constant_spe) == length(u), nrow(saved_constant_ape) == 1L,
          all(saved_constant_spe$model == "constant"),
          saved_constant_ape$model == "constant",
          max(abs(saved_constant_spe$percentile - u)) < 1e-12)
checks <- c(checks,
  constant_SPE = max(abs(as.numeric(constant_spe) - saved_constant_spe$estimate)),
  constant_APE = abs(mean(constant_benefit) - saved_constant_ape$estimate)
)
stopifnot(all(is.finite(checks)), all(checks < 1e-10))

cat(sprintf("Verified both models, %d profiles, %d per tail; all point differences < 1e-10.\n",
            nrow(dat), sum(low)))
print(data.frame(
  summary = c("Average benefit", "10th percentile", "90th percentile"),
  percentage_points = 100 * c(average_benefit, spe_curve[1], tail(spe_curve, 1)),
  row.names = NULL
), row.names = FALSE, digits = 4)
cat("\nDescriptive tail means in the units shown; connecting lines are not CIs.\n")
print(data.frame(
  characteristic = traits$label,
  bottom_10_percent = tail_means$low_mean * traits$multiplier,
  top_10_percent = tail_means$high_mean * traits$multiplier
), row.names = FALSE, digits = 4)

# Inference calls below are documentation only; this walkthrough does not run
# them. The package's categorical compare convention below produces the same
# observation-minus-chemotherapy risk contrast calculated above.
#
# spe_fit <- SortedEffects::spe(
#   fm = fm, data = dat, method = "logit",
#   var_type = "categorical", var = "treatment",
#   compare = c("chemotherapy", "observation"), us = u,
#   b = 499, alpha = .05, bc = FALSE, seed = 420
# )
#
# IMPORTANT: Native ca() bootstrap fits fail numerically for these colon data.
# Do not interpret its raw SEs or p-values as valid inference for this pilot.
# The report uses a separately audited stabilization, implemented in
# scripts/verify-colon-inference.R (the "stabilize" mode), and labels its output
# as a post-plan reconstruction rather than native package inference.
# The raw ca() specification is retained here solely to document the analysis:
#
# ca_fit <- SortedEffects::ca(
#   fm = fm, data = dat, method = "logit",
#   var_type = "categorical", var = "treatment",
#   compare = c("chemotherapy", "observation"), u = .10,
#   interest = "moment", cl = "diff", t = traits$variable,
#   b = 499, alpha = .05, bc = FALSE, seed = 420
# )
