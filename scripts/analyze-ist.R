#!/usr/bin/env Rscript
# Exploratory IST pilot; run from repository root after fetch-ist-data.py.
# The models and validation strategy are specified in docs/ist-analysis-plan.md.
options(warn = 1)
stage <- commandArgs(trailingOnly = TRUE)
stage <- if (length(stage)) match.arg(stage, c("all", "classification")) else "all"
source("R/ist-data.R")
source("R/ist-analysis.R")
stopifnot(requireNamespace("SortedEffects", quietly = TRUE),
          as.character(packageVersion("SortedEffects")) == "1.7.0",
          requireNamespace("Hmisc", quietly = TRUE))
dir.create("results/ist", recursive = TRUE, showWarnings = FALSE)
save_csv <- function(x, filename) {
  write.csv(x, file.path("results/ist", filename), row.names = FALSE)
}
prepared <- prepare_ist_data()
dat <- prepared$data
save_csv(prepared$audit, "outcome-audit.csv")
save_csv(prepared$missingness, "baseline-missingness.csv")
formulas <- ist_formulas(dat)
fits <- lapply(formulas, function(fm) {
  fit <- glm(fm, data = dat, family = binomial())
  ist_check_fit(fit)
  fit
})
stopifnot(fits$interaction$rank - fits$constant$rank == 8L)
lrt <- anova(fits$constant, fits$interaction, test = "LRT")
save_csv(data.frame(
  test = "Eight specified aspirin interactions, log-odds scale",
  df = lrt$Df[2], statistic = lrt$Deviance[2], p_value = lrt$`Pr(>Chi)`[2],
  interpretation = "Exploratory likelihood-ratio test; not a test of constant risk differences"
), "interaction-test.csv")
benefits <- lapply(fits, contrast_ist, data = dat)
model_summary <- do.call(rbind, lapply(names(fits), function(name) {
  effect <- benefits[[name]]
  q <- as.numeric(Hmisc::wtd.quantile(effect, rep(1, nrow(dat)), c(.1, .5, .9)))
  data.frame(model = name, n = nrow(dat), parameters = fits[[name]]$rank,
             average = mean(effect), q10 = q[1], median = q[2], q90 = q[3],
             min = min(effect), max = max(effect),
             fitted_fraction_negative = mean(effect < 0), aic = AIC(fits[[name]]))
}))
save_csv(model_summary, "model-summary.csv")
message("Initial model summaries:")
print(model_summary)
print(lrt)

# Sensitivity to accounting explicitly for the randomized heparin component.
# Marginalize over its observed allocation proportions for both aspirin states.
heparin_summary <- do.call(rbind, lapply(names(fits), function(name) {
  fit <- glm(update(formulas[[name]], . ~ . + heparin), dat, family = binomial())
  ist_check_fit(fit)
  effect <- ist_heparin_standardized_contrast(fit, dat)
  q <- Hmisc::wtd.quantile(effect, rep(1, nrow(dat)), c(.1, .9))
  data.frame(model = name, average = mean(effect), q10 = q[1], q90 = q[2],
             mean_absolute_change = mean(abs(effect - benefits[[name]])),
             rank_correlation = cor(effect, benefits[[name]], method = "spearman"))
}))
save_csv(heparin_summary, "heparin-sensitivity.csv")

B <- as.integer(Sys.getenv("IST_BOOTSTRAPS", "499"))
stopifnot(B >= 99L)
grid <- seq(.10, .90, by = .01)
native <- list()
check_rows <- list()
for (name in names(fits)) {
  if (stage == "classification") {
    # Resume after a CA-only failure without rerunning completed SPE bootstraps.
    saved_spe <- read.csv(file.path("results/ist", paste0(name, "-spe.csv")))
    saved_ape <- read.csv(file.path("results/ist", paste0(name, "-ape.csv")))
    direct <- as.numeric(Hmisc::wtd.quantile(benefits[[name]], rep(1, nrow(dat)), grid))
    stopifnot(identical(saved_spe$percentile, grid) ||
                max(abs(saved_spe$percentile - grid)) < 1e-12,
              max(abs(saved_spe$estimate - direct)) < 1e-10,
              abs(saved_ape$estimate - mean(benefits[[name]])) < 1e-10)
    check_rows[[name]] <- data.frame(model = name,
      spe_point_error = max(abs(saved_spe$estimate - direct)),
      average_error = abs(saved_ape$estimate - mean(benefits[[name]])))
    next
  }
  message("Native SPE inference: ", name, " (", B, " draws)")
  estimate <- SortedEffects::spe(
    fm = formulas[[name]], data = dat, method = "logit",
    var_type = "categorical", var = "aspirin",
    compare = c("aspirin", "no_aspirin"), us = grid,
    b = B, alpha = .05, bc = FALSE, seed = 420
  )
  direct <- as.numeric(Hmisc::wtd.quantile(benefits[[name]], rep(1, nrow(dat)), grid))
  point_error <- max(abs(direct - estimate$spe[[1]]))
  average_error <- abs(mean(benefits[[name]]) - estimate$ape[[1]])
  stopifnot(point_error < 1e-10, average_error < 1e-10,
            all(is.finite(unlist(estimate))), all(estimate$spe[[4]] > 0))
  output <- data.frame(
    model = name, percentile = grid, estimate = estimate$spe[[1]],
    lower_uniform = estimate$spe[[3]], upper_uniform = estimate$spe[[2]],
    standard_error = estimate$spe[[4]]
  )
  save_csv(output, paste0(name, "-spe.csv"))
  save_csv(data.frame(model = name, estimate = estimate$ape[[1]],
                     lower = estimate$ape[[3]], upper = estimate$ape[[2]],
                     standard_error = estimate$ape[[4]]), paste0(name, "-ape.csv"))
  native[[name]] <- estimate
  saveRDS(estimate, file.path("results/ist", paste0(name, "-native-spe.rds")))
  check_rows[[name]] <- data.frame(
    model = name, spe_point_error = point_error, average_error = average_error
  )
}
save_csv(do.call(rbind, check_rows), "native-point-checks.csv")

traits <- ist_characteristics()
message("Native CA inference: twelve specified characteristics (", B, " draws)")
ca <- SortedEffects::ca(
  fm = formulas$interaction, data = dat, method = "logit",
  var_type = "categorical", var = "aspirin",
  compare = c("aspirin", "no_aspirin"), u = .10,
  interest = "moment", cl = "diff", t = traits$variable,
  b = B, alpha = .05, bc = FALSE, seed = 420
)
saveRDS(ca, "results/ist/native-ca.rds")
# ca() returns traits in source-data column order, not the requested t order.
# Match its named estimate columns before aligning SEs and joint p-values.
ca_index <- match(traits$variable, colnames(ca$est))
stopifnot(!anyNA(ca_index))
ca_estimate <- as.numeric(ca$est)[ca_index]
ca_se <- as.numeric(ca$bse)[ca_index]
ca_p <- as.numeric(ca$joint_p)[ca_index]
cutoff <- Hmisc::wtd.quantile(benefits$interaction, rep(1, nrow(dat)), c(.1, .9))
low <- benefits$interaction <= cutoff[1]
high <- benefits$interaction >= cutoff[2]
low_mean <- colMeans(dat[low, traits$variable])
high_mean <- colMeans(dat[high, traits$variable])
ca_error <- max(abs(as.numeric(high_mean - low_mean) - ca_estimate))
stopifnot(ca_error < 1e-10,
          all(is.finite(unlist(ca[c("est", "bse", "joint_p")]))),
          all(ca$bse > 0))
classification <- data.frame(
  traits, overall = colMeans(dat[, traits$variable]),
  low_mean = as.numeric(low_mean), high_mean = as.numeric(high_mean),
  difference = ca_estimate, standard_error = ca_se,
  joint_p = ca_p, n_low = sum(low), n_high = sum(high)
)
save_csv(classification, "classification.csv")

# Record coefficients for audit without screening or selecting individual terms.
coefficients <- do.call(rbind, lapply(names(fits), function(name) {
  output <- coef(summary(fits[[name]]))
  data.frame(model = name, term = rownames(output), estimate = output[, 1],
             standard_error = output[, 2], z = output[, 3],
             unadjusted_p = output[, 4], row.names = NULL)
}))
save_csv(coefficients, "coefficients-audit.csv")
metadata <- list(
  date = "2026-10-22", package = "SortedEffects 1.7.0", B = B, seed = 420,
  execution_stage = stage,
  n = nrow(dat), missing_outcomes = sum(prepared$audit$n_missing[-1]),
  contrast = "Randomized no-aspirin minus aspirin risk, marginal over heparin allocation",
  outcome = "OCCODE 1 or 2: death or dependence at six months; observed outcomes only",
  ca_point_error = ca_error, ca_family = traits$variable,
  inference = "Exploratory model-based patient bootstrap; no multiplicity correction across models",
  spe_scope = "Native full-sample SPE: fixed original covariates and quantile weights",
  ca_scope = "Native CA: refits, reweighted thresholds and characteristic means",
  coverage = "No coverage study; numerical agreement does not establish coverage",
  license = "Contains information from IST database v2, doi:10.7488/ds/104, under ODC-By 1.0"
)
capture.output(str(metadata), sessionInfo(), file = "results/ist/analysis-metadata.txt")
saveRDS(list(fits = fits, native = native, ca = ca, benefits = benefits,
             low = low, high = high, metadata = metadata), "results/ist/analysis.rds")
message("IST native analysis and point-estimate checks passed.")
