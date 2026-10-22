#!/usr/bin/env Rscript
# Fixed exploratory colon pilot; see docs/colon-analysis-plan.md.
options(warn = 1)
source("R/colon-data.R")
source("R/colon-analysis.R")
stopifnot(requireNamespace("SortedEffects", quietly = TRUE),
          as.character(packageVersion("SortedEffects")) == "1.7.0",
          requireNamespace("Hmisc", quietly = TRUE))
output_dir <- "results/colon"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
save_csv <- function(x, name) write.csv(x, file.path(output_dir, name), row.names = FALSE)
prepared <- prepare_colon_data()
dat <- prepared$data
stopifnot(nrow(dat) == 593L)
for (name in c("audit", "missingness", "exclusions", "node4_disagreements", "cohort_flow")) {
  save_csv(prepared[[name]], paste0(gsub("_", "-", name), ".csv"))
}
formulas <- colon_formulas()
warning_log <- data.frame(stage = character(), warning = character())
fit_model <- function(fm, data, label) {
  fit <- withCallingHandlers(glm(fm, data = data, family = binomial()),
    warning = function(w) {
      warning_log <<- rbind(warning_log,
                            data.frame(stage = label, warning = conditionMessage(w)))
      invokeRestart("muffleWarning")
    })
  colon_check_fit(fit)
  fit
}
fits <- lapply(names(formulas), function(name) fit_model(formulas[[name]], dat, name))
names(fits) <- names(formulas)
stopifnot(fits$interaction$rank - fits$constant$rank == 6L)
benefits <- lapply(fits, contrast_colon, data = dat)
summarize_fit <- function(fit, data, model, scenario = "primary") {
  effect <- contrast_colon(fit, data)
  q <- as.numeric(Hmisc::wtd.quantile(effect, rep(1, nrow(data)), c(.1, .5, .9)))
  data.frame(scenario = scenario, model = model, n = nrow(data),
             events = sum(data$outcome), parameters = fit$rank,
             average = mean(effect), q10 = q[1], median = q[2], q90 = q[3],
             min = min(effect), max = max(effect),
             fitted_fraction_negative = mean(effect < 0), aic = AIC(fit),
             rank_correlation_primary = if (identical(data$id, dat$id))
               cor(effect, benefits[[model]], method = "spearman") else NA_real_)
}
summary <- do.call(rbind, lapply(names(fits), function(name) summarize_fit(fits[[name]], dat, name)))
save_csv(summary, "model-summary.csv")
interaction_test <- function(fits, scenario = "primary") {
  result <- anova(fits$constant, fits$interaction, test = "LRT")
  data.frame(scenario = scenario, df = result$Df[2], statistic = result$Deviance[2],
             p_value = result$`Pr(>Chi)`[2])
}
save_csv(interaction_test(fits), "interaction-test.csv")
print(summary)
print(interaction_test(fits))

# Prespecified point-estimate sensitivities; never select a specification by fit.
sensitivity_rows <- list(summary)
sensitivity_tests <- list(interaction_test(fits))
sensitivity_fits <- list()
run_sensitivity <- function(data, fms, scenario) {
  models <- lapply(names(fms), function(name) fit_model(fms[[name]], data, paste(scenario, name)))
  names(models) <- names(fms)
  sensitivity_rows[[length(sensitivity_rows) + 1L]] <<- do.call(rbind,
    lapply(names(models), function(name) summarize_fit(models[[name]], data, name, scenario)))
  sensitivity_tests[[length(sensitivity_tests) + 1L]] <<- interaction_test(models, scenario)
  sensitivity_fits[[scenario]] <<- models
  models
}
all_data <- prepared$all_outcomes
all_data$nodes_missing <- as.integer(is.na(all_data$nodes))
all_data$grade_missing <- as.integer(is.na(all_data$poor_diff))
all_data$nodes[is.na(all_data$nodes)] <- 2
all_data$log_nodes <- log1p(all_data$nodes)
all_data$poor_diff[is.na(all_data$poor_diff)] <- 0
all_formulas <- lapply(formulas, update, . ~ . + nodes_missing + grade_missing)
invisible(run_sensitivity(all_data, all_formulas, "all_known_endpoints_working_imputation"))
complete_baseline <- prepared$selected[
  complete.cases(prepared$selected[, c("age", "female", "nodes", "poor_diff", "extent")]), ]
stopifnot(sum(is.na(complete_baseline$outcome)) == 1L)
for (value in 0:1) {
  sensitivity_data <- complete_baseline
  sensitivity_data$outcome[is.na(sensitivity_data$outcome)] <- value
  invisible(run_sensitivity(sensitivity_data, formulas, paste0("unknown_endpoint_as_", value)))
}
binary_formulas <- lapply(formulas, function(fm) {
  as.formula(gsub("log_nodes", "node_indicator", paste(deparse(fm), collapse = " "),
                  fixed = TRUE), env = baseenv())
})
binary_effects <- list()
for (coding in c("count_derived", "source_indicator")) {
  binary_data <- dat
  binary_data$node_indicator <- if (coding == "count_derived") dat$nodes_over4 else dat$node4
  binary_fits <- run_sensitivity(binary_data, binary_formulas, paste0("binary_nodes_", coding))
  binary_effects[[coding]] <- lapply(binary_fits, contrast_colon, data = binary_data)
}
coding_comparison <- do.call(rbind, lapply(names(formulas), function(name) {
  a <- binary_effects$count_derived[[name]]
  b <- binary_effects$source_indicator[[name]]
  data.frame(model = name, n = nrow(dat), discordant_nodes = sum(dat$node4_disagreement),
             count_derived_average = mean(a), source_indicator_average = mean(b),
             mean_absolute_change = mean(abs(a - b)),
             rank_correlation = cor(a, b, method = "spearman"))
}))
save_csv(do.call(rbind, sensitivity_rows), "sensitivity-models.csv")
save_csv(do.call(rbind, sensitivity_tests), "sensitivity-interactions.csv")
save_csv(coding_comparison, "node-coding-sensitivity.csv")

B <- as.integer(Sys.getenv("COLON_BOOTSTRAPS", "499"))
stopifnot(B >= 99L)
grid <- seq(.10, .90, by = .01)
native <- list()
point_checks <- list()
for (name in names(fits)) {
  message("Native colon SPE: ", name, " (", B, " draws)")
  estimate <- SortedEffects::spe(
    fm = formulas[[name]], data = dat, method = "logit",
    var_type = "categorical", var = "treatment",
    compare = c("chemotherapy", "observation"), us = grid,
    b = B, alpha = .05, bc = FALSE, seed = 420
  )
  saveRDS(estimate, file.path(output_dir, paste0(name, "-native-spe.rds")))
  direct <- as.numeric(Hmisc::wtd.quantile(benefits[[name]], rep(1, nrow(dat)), grid))
  point_error <- max(abs(direct - estimate$spe[[1]]))
  average_error <- abs(mean(benefits[[name]]) - estimate$ape[[1]])
  stopifnot(point_error < 1e-10, average_error < 1e-10,
            all(is.finite(unlist(estimate))), all(estimate$spe[[4]] > 0))
  save_csv(data.frame(model = name, percentile = grid, estimate = estimate$spe[[1]],
                     lower_uniform = estimate$spe[[3]], upper_uniform = estimate$spe[[2]],
                     standard_error = estimate$spe[[4]]), paste0(name, "-spe.csv"))
  save_csv(data.frame(model = name, estimate = estimate$ape[[1]],
                     lower = estimate$ape[[3]], upper = estimate$ape[[2]],
                     standard_error = estimate$ape[[4]]), paste0(name, "-ape.csv"))
  native[[name]] <- estimate
  point_checks[[name]] <- data.frame(model = name, spe_point_error = point_error,
                                     average_error = average_error)
}
save_csv(do.call(rbind, point_checks), "native-point-checks.csv")
traits <- colon_characteristics()
message("Native colon classification: twelve specified characteristics")
ca <- SortedEffects::ca(
  fm = formulas$interaction, data = dat, method = "logit",
  var_type = "categorical", var = "treatment",
  compare = c("chemotherapy", "observation"), u = .10,
  interest = "moment", cl = "diff", t = traits$variable,
  b = B, alpha = .05, bc = FALSE, seed = 420
)
saveRDS(ca, file.path(output_dir, "native-ca.rds"))
# The package returns traits in source-column order rather than t order.
ca_index <- match(traits$variable, colnames(ca$est))
stopifnot(!anyNA(ca_index))
cut <- Hmisc::wtd.quantile(benefits$interaction, rep(1, nrow(dat)), c(.1, .9))
low <- benefits$interaction <= cut[1]
high <- benefits$interaction >= cut[2]
low_mean <- colMeans(dat[low, traits$variable])
high_mean <- colMeans(dat[high, traits$variable])
ca_error <- max(abs(as.numeric(high_mean - low_mean) - as.numeric(ca$est)[ca_index]))
classification <- data.frame(
  traits, overall = colMeans(dat[, traits$variable]),
  low_mean = as.numeric(low_mean), high_mean = as.numeric(high_mean),
  difference = as.numeric(ca$est)[ca_index],
  standard_error = as.numeric(ca$bse)[ca_index], joint_p = as.numeric(ca$joint_p)[ca_index],
  n_low = sum(low), n_high = sum(high)
)
classification$inference_status <- "Raw native output; numerically unstable in this pilot; not endorsed"
save_csv(classification, "classification-native.csv")
stopifnot(ca_error < 1e-10,
          all(is.finite(unlist(ca[c("est", "bse", "joint_p")]))), all(ca$bse > 0))

coefficients <- do.call(rbind, lapply(names(fits), function(name) {
  output <- coef(summary(fits[[name]]))
  data.frame(model = name, term = rownames(output), estimate = output[, 1],
             standard_error = output[, 2], z = output[, 3], unadjusted_p = output[, 4],
             row.names = NULL)
}))
save_csv(coefficients, "coefficients-audit.csv")
save_csv(warning_log, "model-warnings.csv")
metadata <- list(
  date = "2026-10-22", package = "SortedEffects 1.7.0", B = B, seed = 420,
  selected_n = nrow(prepared$selected), observed_n = nrow(prepared$all_outcomes),
  primary_n = nrow(dat), endpoint_horizon_days = prepared$horizon_days,
  contrast = "Observation minus levamisole plus fluorouracil three-year death risk",
  primary_target = "Complete-baseline selected comparison with known three-year outcomes",
  ca_point_error = ca_error, ca_family = traits$variable,
  spe_scope = "Native full-sample SPE: fixed original covariates and quantile weights",
  ca_scope = "Native CA raw output is numerically unstable; use separate audited stabilized reconstruction",
  bootstrap_audit = "See separate verify-colon-inference.R for all weighted-fit numerical checks",
  inference = "Exploratory working logistic model and patient bootstrap; no cross-dataset adjustment",
  model_warnings = nrow(warning_log)
)
capture.output(str(metadata), sessionInfo(), file = file.path(output_dir, "analysis-metadata.txt"))
saveRDS(list(fits = fits, native = native, ca = ca, benefits = benefits,
             low = low, high = high, metadata = metadata, sensitivity_fits = sensitivity_fits),
        file.path(output_dir, "analysis.rds"))
message("Colon SPE and point checks passed; native CA inference requires the separate numerical audit.")
