#!/usr/bin/env Rscript
# One fixed held-out check of the two models in docs/colon-analysis-plan.md.
# Neither the split nor the model specifications are selected using outcomes.
options(warn = 1)
source("R/colon-data.R")
source("R/colon-analysis.R")

seed <- 20261024L
output_dir <- "results/colon"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
data <- prepare_colon_data()$data
stopifnot(nrow(data) == 593L, !anyNA(data$outcome),
          all(data$outcome %in% 0:1), !anyDuplicated(data$id),
          identical(levels(data$treatment), c("observation", "chemotherapy")))

# Stratify on treatment assignment only, without looking at outcomes or scores.
set.seed(seed)
training_index <- sort(unlist(lapply(levels(data$treatment), function(arm) {
  indices <- which(data$treatment == arm)
  sample(indices, floor(length(indices) / 2L), replace = FALSE)
}), use.names = FALSE))
test_index <- setdiff(seq_len(nrow(data)), training_index)
stopifnot(length(intersect(training_index, test_index)) == 0L,
          setequal(c(training_index, test_index), seq_len(nrow(data))))
training <- data[training_index, , drop = FALSE]
test <- data[test_index, , drop = FALSE]
formulas <- colon_formulas()
stopifnot(identical(names(formulas), c("constant", "interaction")))

arm_risk_difference <- function(outcome, treated) {
  n0 <- sum(!treated)
  n1 <- sum(treated)
  stopifnot(n0 > 1L, n1 > 1L)
  events0 <- sum(outcome[!treated])
  events1 <- sum(outcome[treated])
  p0 <- events0 / n0
  p1 <- events1 / n1
  se <- sqrt(p0 * (1 - p0) / n0 + p1 * (1 - p1) / n1)
  data.frame(n_control = n0, n_treated = n1, events_control = events0,
             events_treated = events1, risk_control = p0, risk_treated = p1,
             estimate = p0 - p1, standard_error = se,
             lower = p0 - p1 - qnorm(.975) * se,
             upper = p0 - p1 + qnorm(.975) * se)
}

hc3_calibration <- function(pseudo_outcome, score) {
  centered_score <- score - mean(score)
  design <- cbind(intercept = 1, centered_score = centered_score)
  stopifnot(sd(centered_score) > 1e-10)
  fit <- lm.fit(design, pseudo_outcome)
  stopifnot(fit$rank == 2L, all(is.finite(fit$coefficients)))
  bread <- solve(crossprod(design))
  leverage <- rowSums((design %*% bread) * design)
  stopifnot(all(leverage < 1))
  residual_weight <- (fit$residuals / (1 - leverage))^2
  covariance <- bread %*% crossprod(design, design * residual_weight) %*% bread
  se <- sqrt(diag(covariance))
  stopifnot(all(is.finite(se)), all(se > 0))
  # Independently verify HC3 using delete-one QR refits: the sum of outer
  # products of (beta_full - beta_without_i) equals HC3. This is the uncentered
  # deletion identity, not the usual centered/scaled jackknife estimator.
  deletion_changes <- vapply(seq_along(pseudo_outcome), function(i) {
    fit$coefficients - lm.fit(design[-i, , drop = FALSE],
                              pseudo_outcome[-i])$coefficients
  }, numeric(2))
  reference <- tcrossprod(deletion_changes)
  reference_error <- max(abs(unname(reference) - unname(covariance)))
  stopifnot(reference_error < 1e-8)
  output <- data.frame(
    term = c("mean_benefit", "ranking_slope"),
    estimate = unname(fit$coefficients), standard_error = se,
    lower = unname(fit$coefficients) - qnorm(.975) * se,
    upper = unname(fit$coefficients) + qnorm(.975) * se,
    p_zero = 2 * pnorm(-abs(unname(fit$coefficients) / se)),
    p_one = 2 * pnorm(-abs((unname(fit$coefficients) - 1) / se)),
    hc3_reference_error = reference_error, row.names = NULL
  )
  output$p_one[output$term != "ranking_slope"] <- NA_real_
  output
}

tertile_results <- calibration_results <- tail_results <- diagnostics <- list()
prediction_results <- warning_rows <- fits <- scores <- list()
for (model_name in names(formulas)) {
  message("Validating held-out colon ranking: ", model_name)
  fit_warnings <- character()
  fit <- withCallingHandlers(
    glm(formulas[[model_name]], data = training, family = binomial()),
    warning = function(w) {
      fit_warnings <<- c(fit_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  warning_rows[[model_name]] <- data.frame(
    model = model_name, warning_count = length(fit_warnings),
    warnings = paste(unique(fit_warnings), collapse = " | ")
  )
  # Preserve warnings before any failure; do not change the split or omit a model.
  write.csv(do.call(rbind, warning_rows),
            file.path(output_dir, "validation-warnings.csv"), row.names = FALSE)
  colon_check_fit(fit)
  risks <- colon_risks(fit, test)
  m0 <- risks$control
  m1 <- risks$treated
  score <- as.numeric(contrast_colon(fit, test))
  stopifnot(all(is.finite(c(m0, m1, score))),
            all(c(m0, m1) >= 0 & c(m0, m1) <= 1),
            max(abs(score - (m0 - m1))) < 1e-10)

  # These thresholds use validation covariates and frozen predictions, not outcomes.
  cutoffs <- quantile(score, seq(0, 1, length.out = 4), names = FALSE, type = 8)
  stopifnot(all(diff(cutoffs) > 0))
  tertile <- cut(score, breaks = cutoffs, include.lowest = TRUE, labels = FALSE)
  stopifnot(!anyNA(tertile), all(tabulate(tertile, nbins = 3L) > 0L))
  observed_treated <- test$treatment == "chemotherapy"
  group_table <- do.call(rbind, lapply(seq_len(3L), function(group) {
    selected <- tertile == group
    cbind(data.frame(model = model_name, tertile = group,
                     mean_predicted_benefit = mean(score[selected]),
                     min_predicted_benefit = min(score[selected]),
                     max_predicted_benefit = max(score[selected])),
          arm_risk_difference(test$outcome[selected], observed_treated[selected]))
  }))
  tertile_results[[model_name]] <- group_table

  # Observation minus chemotherapy benefit, using nominal 1:1 allocation within
  # the retained two arms. Both nuisance predictions were learned in training.
  # These are working iid diagnostics, not exact randomization-based inference.
  pseudo_outcome <- m0 - m1 +
    (1 - as.integer(observed_treated)) / .5 * (test$outcome - m0) -
    as.integer(observed_treated) / .5 * (test$outcome - m1)
  calibration <- hc3_calibration(pseudo_outcome, score)
  calibration$model <- model_name
  calibration$test_score_mean <- mean(score)
  calibration$test_score_sd <- sd(score)
  calibration$test_n <- nrow(test)
  calibration_results[[model_name]] <- calibration

  low <- group_table[group_table$tertile == 1L, ]
  high <- group_table[group_table$tertile == 3L, ]
  difference <- high$estimate - low$estimate
  difference_se <- sqrt(high$standard_error^2 + low$standard_error^2)
  tail_results[[model_name]] <- data.frame(
    model = model_name, comparison = "top minus bottom predicted-benefit tertile",
    estimate = difference, standard_error = difference_se,
    lower = difference - qnorm(.975) * difference_se,
    upper = difference + qnorm(.975) * difference_se,
    p_zero = 2 * pnorm(-abs(difference / difference_se)),
    predicted_difference = high$mean_predicted_benefit - low$mean_predicted_benefit
  )
  factual_risk <- ifelse(observed_treated, m1, m0)
  clipped_risk <- pmax(1e-12, pmin(1 - 1e-12, factual_risk))
  diagnostics[[model_name]] <- data.frame(
    model = model_name, training_n = nrow(training), test_n = nrow(test),
    training_events = sum(training$outcome), test_events = sum(test$outcome),
    training_parameters = length(coef(fit)), rank = fit$rank,
    converged = fit$converged, warning_count = length(fit_warnings),
    fitted_min = min(fitted(fit)), fitted_max = max(fitted(fit)),
    fitted_near_boundary = sum(fitted(fit) < 1e-8 | fitted(fit) > 1 - 1e-8),
    score_mean = mean(score), score_sd = sd(score),
    score_q10 = as.numeric(quantile(score, .1, type = 8)),
    score_q90 = as.numeric(quantile(score, .9, type = 8)),
    test_brier = mean((test$outcome - factual_risk)^2),
    test_log_loss = -mean(test$outcome * log(clipped_risk) +
                          (1 - test$outcome) * log(1 - clipped_risk))
  )
  prediction_results[[model_name]] <- data.frame(
    model = model_name, id = test$id, treatment = test$treatment,
    outcome = test$outcome, risk_control = m0, risk_treated = m1,
    predicted_benefit = score, tertile = tertile, pseudo_outcome = pseudo_outcome
  )
  fits[[model_name]] <- fit
  scores[[model_name]] <- score
}

tertile_table <- do.call(rbind, tertile_results)
calibration_table <- do.call(rbind, calibration_results)
tail_table <- do.call(rbind, tail_results)
diagnostic_table <- do.call(rbind, diagnostics)
prediction_table <- do.call(rbind, prediction_results)
calibration_table$p_holm_two_rankings <- NA_real_
ranking_rows <- calibration_table$term == "ranking_slope"
calibration_table$p_holm_two_rankings[ranking_rows] <- p.adjust(
  calibration_table$p_zero[ranking_rows], method = "holm"
)
tail_table$p_holm_two_rankings <- p.adjust(tail_table$p_zero, method = "holm")
for (name in c("tertile", "calibration", "tail", "diagnostic", "prediction")) {
  write.csv(get(paste0(name, "_table")),
            file.path(output_dir, paste0("validation-", name, ".csv")),
            row.names = FALSE)
}
split_counts <- as.data.frame(table(
  split = ifelse(seq_len(nrow(data)) %in% training_index, "training", "test"),
  treatment = data$treatment
))
write.csv(split_counts, file.path(output_dir, "validation-split.csv"), row.names = FALSE)
split_membership <- data.frame(
  id = data$id, treatment = data$treatment,
  split = ifelse(seq_len(nrow(data)) %in% training_index, "training", "test")
)
write.csv(split_membership, file.path(output_dir, "validation-membership.csv"),
          row.names = FALSE)

metadata <- list(
  seed = seed, split = "Single 50/50 split stratified on treatment assignment only",
  training_n = nrow(training), test_n = nrow(test),
  split_selected_using_outcome = FALSE, model_selected_using_test_results = FALSE,
  estimand = "Observation minus chemotherapy risk of death within three years",
  population = "Known three-year endpoint and complete primary baseline measurements",
  tertiles = "Test-prediction tertiles; thresholds use covariates and frozen training fits only",
  tertile_intervals = "Unpooled binomial Wald 95% intervals; pointwise and unadjusted",
  calibration = "Training-nuisance AIPW benefit pseudo-outcome on centered frozen score, HC3 SE",
  calibration_null = "Zero score slope; perfect linear calibration would have slope one",
  randomization = "Nominal chemotherapy propensity 0.5 within the two retained arms; iid working analysis",
  multiplicity = paste(
    "Raw exploratory p-values plus Holm adjustment across the two ranking slopes.",
    "A separate Holm column adjusts the two top-minus-bottom contrasts.",
    "Neither adjustment covers all diagnostics, tertile intervals or pilot datasets."
  ),
  scope = "One small training sample; no repeated-split or external validation claim"
)
capture.output(str(metadata), split_counts, diagnostic_table, calibration_table,
               tail_table, sessionInfo(),
               file = file.path(output_dir, "validation-metadata.txt"))
saveRDS(list(metadata = metadata, training_index = training_index,
             test_index = test_index, fits = fits, scores = scores,
             tertiles = tertile_table, calibration = calibration_table,
             tails = tail_table, diagnostics = diagnostic_table),
        file.path(output_dir, "validation-analysis.rds"))

stopifnot(requireNamespace("ggplot2", quietly = TRUE))
tertile_table$model_label <- factor(
  tertile_table$model, levels = c("constant", "interaction"),
  labels = c("Constant treatment odds ratio", "Six treatment interactions")
)
plot <- ggplot2::ggplot(tertile_table, ggplot2::aes(tertile, estimate * 100)) +
  ggplot2::geom_hline(yintercept = 0, colour = "#99919F", linewidth = .4) +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = lower * 100, ymax = upper * 100),
                       width = .10, colour = "#5A317E", linewidth = .7) +
  ggplot2::geom_point(colour = "#5A317E", size = 2.7) +
  ggplot2::geom_line(ggplot2::aes(y = mean_predicted_benefit * 100),
                    colour = "#CF7045", linetype = "dashed", linewidth = .9) +
  ggplot2::facet_wrap(~model_label, nrow = 1) +
  ggplot2::scale_x_continuous(breaks = 1:3, labels = c("Bottom", "Middle", "Top")) +
  ggplot2::labs(
    title = "Does the predicted benefit ranking hold up?",
    x = "Tertile of benefit predicted by the training model",
    y = "Three-year mortality reduction (percentage points)",
    subtitle = "Purple: observed arm contrast with 95% interval; dashed: mean predicted benefit",
    caption = paste(
      "One fixed 50/50 split: 296 training and 297 validation patients. Pointwise, unadjusted intervals.",
      "Known three-year endpoint and complete primary baselines; exploratory internal validation.",
      sep = "\n"
    )
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                 strip.text = ggplot2::element_text(face = "bold"),
                 plot.title = ggplot2::element_text(face = "bold"),
                 plot.caption = ggplot2::element_text(size = 8))
for (extension in c("png", "pdf")) {
  ggplot2::ggsave(file.path(output_dir, paste0("validation-tertiles.", extension)),
                 plot, width = 11, height = 5.5, dpi = 180, bg = "#FAF9F6")
}
print(diagnostic_table)
print(calibration_table)
print(tail_table)
message("Held-out colon ranking checks completed; see results/colon/validation-*.")
