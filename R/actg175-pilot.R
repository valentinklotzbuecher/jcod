# Secondary, fixed ACTG175 pilot. Plan: docs/actg175-pilot.md.
# Run from the repository root after activating the prepared R toolchain.
options(warn = 1)
stopifnot(requireNamespace("SortedEffects", quietly = TRUE),
          requireNamespace("Hmisc", quietly = TRUE),
          requireNamespace("ggplot2", quietly = TRUE),
          as.character(utils::packageVersion("SortedEffects")) == "1.7.0")

out <- "results/actg175"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
write_result <- function(x, name) {
  utils::write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE)
}
expected_sha <- "7b52e6b3701a1f24090ef0388f1c148d5286450f97276d9c8fbe611ce0c76779"
actual_sha <- strsplit(system2("sha256sum", "data/actg175/ACTG175.txt",
                             stdout = TRUE), "[[:space:]]+")[[1]][1]
stopifnot(identical(actual_sha, expected_sha))
raw <- utils::read.table("data/actg175/ACTG175.txt", header = TRUE)
stopifnot(nrow(raw) == 2139L, ncol(raw) == 27L, !anyDuplicated(raw$pidnum))
traits <- c("age", "gender", "wtkg", "cd40", "cd80", "karnof", "symptom", "str2")
labels <- c("Age (years)", "Male (proportion)", "Weight (kg)",
            "Baseline CD4 (cells/mm3)", "Baseline CD8 (cells/mm3)",
            "Karnofsky score", "Symptomatic (proportion)", "Prior ART (proportion)")
units <- c("years", "proportion", "kg", "cells/mm3", "cells/mm3",
           "score points", "proportion", "proportion")
dat <- raw[raw$arms %in% c(0, 1), ]
stopifnot(nrow(dat) == 1054L, all(complete.cases(dat[, c("cd420", traits)])))
dat$group <- factor(ifelse(dat$arms == 1, "treated", "control"),
                    levels = c("control", "treated"))
dat$A <- as.integer(dat$arms == 1)
write_result(data.frame(
  field = names(raw), missing_export = colSums(is.na(raw)),
  missing_selected = colSums(is.na(dat[, names(raw)]))
), "missingness")
write_result(do.call(rbind, lapply(split(dat, dat$group), function(d) {
  data.frame(group = as.character(d$group[1]), n = nrow(d),
             mean_cd420 = mean(d$cd420), sd_cd420 = sd(d$cd420),
             age_mean = mean(d$age), age_min = min(d$age), age_max = max(d$age),
             male_n = sum(d$gender == 1), female_n = sum(d$gender == 0))
})), "cohort-audit")

fm_main <- reformulate(c("group", traits), response = "cd420")
fm_interaction <- as.formula(paste("cd420 ~ group * (", paste(traits, collapse = " + "), ")"))
environment(fm_main) <- environment(fm_interaction) <- baseenv()
formulas <- list(main = fm_main, interaction = fm_interaction)
fits <- lapply(formulas, lm, data = dat)
stopifnot(all(vapply(fits, function(f) all(is.finite(coef(f))), logical(1))))
f_test <- anova(fits$main, fits$interaction)
write_result(data.frame(
  test = "All eight treatment interactions together; classical nested-model F test",
  numerator_df = f_test$Df[2], denominator_df = f_test$Res.Df[2],
  statistic = f_test$F[2], p_value = f_test$`Pr(>F)`[2]
), "interaction-test")
contrast <- function(fit, data) {
  p0 <- as.numeric(predict(fit, transform(data, group = "control")))
  p1 <- as.numeric(predict(fit, transform(data, group = "treated")))
  list(control = p0, treated = p1, effect = p1 - p0)
}
predictions <- lapply(fits, contrast, data = dat)
write_result(do.call(rbind, lapply(names(fits), function(name) {
  effect <- predictions[[name]]$effect
  data.frame(model = name, n = nrow(dat), parameters = length(coef(fits[[name]])),
             average_effect = mean(effect), q10 = as.numeric(quantile(effect, .1)),
             q50 = median(effect), q90 = as.numeric(quantile(effect, .9)),
             min_effect = min(effect), max_effect = max(effect))
})), "model-summary")

B <- 499L
seed <- 420L
us <- seq(.1, .9, .01)
spe_objects <- list()
spe_tables <- list()
ape_tables <- list()
for (name in names(formulas)) {
  message("ACTG175 original OLS SPE: ", name, " (", B, " draws)")
  object <- SortedEffects::spe(
    fm = formulas[[name]], data = dat, method = "ols",
    var_type = "categorical", var = "group", compare = c("control", "treated"),
    us = us, alpha = .05, b = B, seed = seed, bc = FALSE
  )
  direct <- as.numeric(Hmisc::wtd.quantile(predictions[[name]]$effect,
                                          rep(1, nrow(dat)), us))
  stopifnot(max(abs(direct - object$spe[[1]])) < 1e-8,
            abs(mean(predictions[[name]]$effect) - object$ape[[1]]) < 1e-8,
            all(is.finite(unlist(object))), all(object$spe[[4]] > 0))
  spe_objects[[name]] <- object
  spe_tables[[name]] <- data.frame(
    model = name, percentile = us, estimate = as.numeric(object$spe[[1]]),
    lower_uniform = as.numeric(object$spe[[3]]),
    upper_uniform = as.numeric(object$spe[[2]]), standard_error = as.numeric(object$spe[[4]])
  )
  ape_tables[[name]] <- data.frame(
    model = name, estimate = as.numeric(object$ape[[1]]),
    lower = as.numeric(object$ape[[3]]), upper = as.numeric(object$ape[[2]]),
    standard_error = as.numeric(object$ape[[4]])
  )
}
spe_table <- do.call(rbind, spe_tables)
write_result(spe_table, "spe")
write_result(do.call(rbind, ape_tables), "ape")

message("ACTG175 original OLS CA: interaction model, all eight characteristics")
ca <- SortedEffects::ca(
  fm = fm_interaction, data = dat, method = "ols", var_type = "categorical",
  var = "group", compare = c("control", "treated"), u = .10,
  interest = "moment", cl = "diff", t = traits,
  alpha = .05, b = B, seed = seed, bc = FALSE
)
saveRDS(ca, file.path(out, "ca-native.rds"))
effect <- predictions$interaction$effect
cuts <- Hmisc::wtd.quantile(effect, rep(1, nrow(dat)), c(.10, .90))
low <- effect <= cuts[1]
high <- effect >= cuts[2]
low_means <- colMeans(dat[low, traits])
high_means <- colMeans(dat[high, traits])
# ca() follows source-column order, not the order supplied through t=.
ca_index <- match(traits, colnames(ca$est))
stopifnot(!anyNA(ca_index))
ca_estimate <- as.numeric(ca$est)[ca_index]
ca_se <- as.numeric(ca$bse)[ca_index]
ca_p <- as.numeric(ca$joint_p)[ca_index]
stopifnot(max(abs((high_means - low_means) - ca_estimate)) < 1e-8,
          all(is.finite(unlist(ca[c("est", "bse", "joint_p")]))), all(ca$bse > 0))
write_result(data.frame(
  characteristic = traits, label = labels, unit = units,
  bottom_mean = as.numeric(low_means), top_mean = as.numeric(high_means),
  difference = ca_estimate, standard_error = ca_se,
  joint_p = ca_p, bottom_n = sum(low), top_n = sum(high),
  bootstrap_draws = B
), "classification")

# Independently reconstruct both native OLS bootstrap paths. The package's
# full-sample SPE keeps original quantile weights; CA reweights its cutoffs.
message("Independently reconstructing ACTG175 OLS SPE and CA bootstrap outputs")
set.seed(seed)
boot_spe <- lapply(formulas, function(f) matrix(NA_real_, B, length(us)))
boot_ca <- matrix(NA_real_, B, length(traits))
for (b in seq_len(B)) {
  counts <- tabulate(sample.int(nrow(dat), nrow(dat), replace = TRUE), nrow(dat))
  weighted <- dat
  weighted$.counts <- counts
  for (name in names(formulas)) {
    f <- lm(formulas[[name]], data = weighted, weights = .counts)
    stopifnot(all(is.finite(coef(f))))
    boot_spe[[name]][b, ] <- Hmisc::wtd.quantile(
      contrast(f, dat)$effect, rep(1, nrow(dat)), us
    )
  }
  weighted$.ca_weights <- (counts / sum(counts)) * rep(1, nrow(dat)) * 20000
  f_ca <- lm(fm_interaction, data = weighted, weights = .ca_weights)
  stopifnot(all(is.finite(coef(f_ca))))
  delta <- contrast(f_ca, dat)$effect
  thresholds <- Hmisc::wtd.quantile(delta, weighted$.ca_weights, c(.10, .90))
  bottom <- delta <= thresholds[1]
  top <- delta >= thresholds[2]
  boot_ca[b, ] <- vapply(traits, function(trait) {
    weighted.mean(dat[[trait]][top], weighted$.ca_weights[top]) -
      weighted.mean(dat[[trait]][bottom], weighted$.ca_weights[bottom])
  }, numeric(1))
}
spe_check_errors <- vapply(names(formulas), function(name) {
  centered <- sweep(boot_spe[[name]], 2, spe_tables[[name]]$estimate, "-")
  scale <- apply(centered, 2, IQR) / diff(qnorm(c(.25, .75)))
  maximum <- apply(abs(sweep(centered, 2, scale, "/")), 1, max)
  critical <- as.numeric(quantile(maximum, .95))
  max(abs(c(
    scale - spe_tables[[name]]$standard_error,
    sort(spe_tables[[name]]$estimate - critical * scale) - spe_tables[[name]]$lower_uniform,
    sort(spe_tables[[name]]$estimate + critical * scale) - spe_tables[[name]]$upper_uniform
  )))
}, numeric(1))
centered_ca <- sweep(boot_ca, 2, ca_estimate, "-")
scale_ca <- apply(centered_ca, 2, IQR) / diff(qnorm(c(.25, .75)))
maximum_ca <- apply(abs(sweep(centered_ca, 2, scale_ca, "/")), 1, max)
joint_p_ca <- vapply(abs(ca_estimate / scale_ca), function(z) mean(maximum_ca > z), numeric(1))
ca_check_errors <- c(standard_error = max(abs(scale_ca - ca_se)),
                     joint_p = max(abs(joint_p_ca - ca_p)))
stopifnot(max(spe_check_errors) < 1e-8, max(ca_check_errors) < 1e-8)
write_result(data.frame(
  check = c(paste0("spe_", names(spe_check_errors)), paste0("ca_", names(ca_check_errors))),
  max_absolute_error = c(spe_check_errors, ca_check_errors)
), "bootstrap-checks")

# One prespecified treatment-stratified 50:50 split. No split search or tuning.
set.seed(20261023L)
train_indices <- unlist(lapply(split(seq_len(nrow(dat)), dat$group), function(i) {
  sample(i, floor(length(i) / 2))
}), use.names = FALSE)
train <- dat[train_indices, ]
validation <- dat[-train_indices, ]
write_result(data.frame(pidnum = dat$pidnum, group = dat$group,
                        partition = ifelse(seq_len(nrow(dat)) %in% train_indices,
                                           "training", "validation")), "validation-split")
hc3_summary <- function(model) {
  x <- model.matrix(model)
  inv <- solve(crossprod(x))
  omega <- (residuals(model) / (1 - hatvalues(model)))^2
  covariance <- inv %*% crossprod(x, x * omega) %*% inv
  standard_error <- sqrt(diag(covariance))
  critical <- qt(.975, df.residual(model))
  data.frame(term = names(coef(model)), estimate = as.numeric(coef(model)),
             standard_error = standard_error,
             lower = coef(model) - critical * standard_error,
             upper = coef(model) + critical * standard_error,
             p_null_zero = 2 * pt(-abs(coef(model) / standard_error), df.residual(model)),
             row.names = NULL)
}
validation_results <- list()
validation_mean_results <- list()
validation_predictions <- list()
for (name in names(formulas)) {
  train_fit <- lm(formulas[[name]], data = train)
  predicted <- contrast(train_fit, validation)
  p <- .5
  aipw <- predicted$effect + validation$A / p * (validation$cd420 - predicted$treated) -
    (1 - validation$A) / (1 - p) * (validation$cd420 - predicted$control)
  validation_mean_results[[name]] <- data.frame(
    model = name, train_n = nrow(train), validation_n = nrow(validation),
    estimate = mean(aipw), standard_error = sd(aipw) / sqrt(length(aipw)),
    lower = mean(aipw) - qt(.975, length(aipw) - 1) * sd(aipw) / sqrt(length(aipw)),
    upper = mean(aipw) + qt(.975, length(aipw) - 1) * sd(aipw) / sqrt(length(aipw))
  )
  validation_predictions[[name]] <- data.frame(
    model = name, pidnum = validation$pidnum, predicted_effect = predicted$effect,
    aipw_outcome = aipw
  )
  if (sd(predicted$effect) < 1e-8) {
    validation_results[[name]] <- data.frame(
      model = name, estimate = NA_real_, standard_error = NA_real_,
      lower = NA_real_, upper = NA_real_, p_null_zero = NA_real_,
      p_null_one = NA_real_, predicted_sd = sd(predicted$effect),
      interpretation = "Constant effect: ranking slope undefined"
    )
  } else {
    calibration <- hc3_summary(lm(aipw ~ score,
                                  data = data.frame(aipw = aipw, score = predicted$effect)))
    slope <- calibration[calibration$term == "score", ]
    validation_results[[name]] <- data.frame(
      model = name, slope[, setdiff(names(slope), "term")],
      p_null_one = 2 * pt(-abs((slope$estimate - 1) / slope$standard_error), nrow(validation) - 2),
      predicted_sd = sd(predicted$effect),
      interpretation = "Held-out AIPW slope; zero=no supported ranking, one=ideal calibration"
    )
  }
}
write_result(do.call(rbind, validation_results), "validation-calibration")
write_result(do.call(rbind, validation_mean_results), "validation-average")
write_result(do.call(rbind, validation_predictions), "validation-predictions")

plot_data <- spe_table
plot_data$model <- factor(plot_data$model, levels = c("main", "interaction"),
                          labels = c("Main effects only", "All eight treatment interactions"))
plot <- ggplot2::ggplot(plot_data, ggplot2::aes(percentile, estimate)) +
  ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0") +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_uniform, ymax = upper_uniform),
                       fill = "#5A317E", alpha = .14) +
  ggplot2::geom_line(colour = "#5A317E", linewidth = 1.1) +
  ggplot2::facet_wrap(~model, nrow = 1) +
  ggplot2::scale_x_continuous(labels = function(x) paste0(100 * x, "%")) +
  ggplot2::labs(
    x = "Percentile of fitted CD4 gain", y = "Additional CD4 cells/mm3 at 20 weeks",
    subtitle = "ACTG175: zidovudine + didanosine minus zidovudine, public 1,054-row subset",
    caption = "Original SortedEffects OLS estimates and 95% uniform bands (499 draws). Secondary prespecified pilot, not a search for new subgroups."
  ) + ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(legend.position = "none", strip.text = ggplot2::element_text(face = "bold"),
                  plot.caption = ggplot2::element_text(size = 8))
for (extension in c("png", "pdf")) {
  ggplot2::ggsave(file.path(out, paste0("spe-model-comparison.", extension)), plot,
                  width = 11, height = 5, dpi = 180, bg = "#FAF9F6")
}
metadata <- list(
  analysis_date = "2026-10-22", role = "Secondary trial pilot; IST remains primary",
  source_commit = "9fa954e262daa0dd8d078d8a843537467f7603df", data_sha256 = actual_sha,
  cohort_n = nrow(dat), treated_n = sum(dat$A), control_n = sum(1 - dat$A),
  endpoint = "CD4 at20weeks; treated minus control cells/mm3", traits = traits,
  package = "SortedEffects1.7.0 unmodified", bootstrap_draws = B,
  independent_spe_bootstrap_errors = spe_check_errors,
  independent_ca_bootstrap_errors = ca_check_errors,
  bootstrap_seed = seed, split_seed = 20261023L,
  training_n = nrow(train), validation_n = nrow(validation),
  assignment_probability = .5,
  spe_scope = "Native full-sample SPE: training weights resampled, original quantile weights retained",
  ca_scope = "Native CA moments: training, thresholds and tail means reweighted",
  ca_intervals = "Native moment confidence intervals are not returned or invented",
  p_zero = "0/499 Monte Carlo exceedances is not an exactly zero population p-value",
  limitations = c("Public export selection relative to original trial unverified",
    "Classical joint F test; model and subgroup claims exploratory",
    "No alternative arms/endpoints/splits selected; no new discovery claim",
    "Original-paper full text access blocked; historical therapies, no current clinical recommendation")
)
utils::capture.output(str(metadata), utils::sessionInfo(),
                       file = file.path(out, "metadata.txt"))
saveRDS(list(models = fits, spe = spe_objects, ca = ca, metadata = metadata),
         file.path(out, "objects.rds"))
message("ACTG175 fixed secondary pilot complete. See ", out, ".")
