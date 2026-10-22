#!/usr/bin/env Rscript
# Honest validation of two prespecified IST effect rankings.
# One fixed 50/50 split; neither the split nor the models are selected by results.
options(warn = 1)
source("R/ist-data.R")
source("R/ist-analysis.R")

seed <- 20261022L
output_dir <- "results/ist"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
data <- prepare_ist_data()$data
stopifnot(nrow(data) > 1000L, !anyNA(data$outcome),
          all(data$outcome %in% 0:1),
          setequal(levels(data$aspirin), c("no_aspirin", "aspirin")))

# Stratify only on randomized aspirin assignment, never on outcome or score.
set.seed(seed)
training_index <- sort(unlist(lapply(levels(data$aspirin), function(arm) {
  indices <- which(data$aspirin == arm)
  sample(indices, floor(length(indices) / 2L), replace = FALSE)
}), use.names = FALSE))
test_index <- setdiff(seq_len(nrow(data)), training_index)
stopifnot(length(intersect(training_index, test_index)) == 0L,
          setequal(c(training_index, test_index), seq_len(nrow(data))))
training <- data[training_index, , drop = FALSE]
test <- data[test_index, , drop = FALSE]
formulas <- ist_formulas(training)
stopifnot(all(c("constant", "interaction") %in% names(formulas)))

arm_risk_difference <- function(outcome, treated) {
  n0 <- sum(!treated)
  n1 <- sum(treated)
  stopifnot(n0 > 1L, n1 > 1L)
  p0 <- mean(outcome[!treated])
  p1 <- mean(outcome[treated])
  # Unpooled binomial Wald intervals, conditional on the frozen training rule.
  se <- sqrt(p0 * (1 - p0) / n0 + p1 * (1 - p1) / n1)
  data.frame(n_control = n0, n_aspirin = n1, risk_control = p0,
             risk_aspirin = p1, estimate = p0 - p1, standard_error = se,
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
  residual_weight <- (fit$residuals / (1 - leverage))^2
  covariance <- bread %*% crossprod(design, design * residual_weight) %*% bread
  se <- sqrt(diag(covariance))
  data.frame(term = c("mean_benefit", "ranking_slope"),
             estimate = unname(fit$coefficients), standard_error = se,
             lower = unname(fit$coefficients) - qnorm(.975) * se,
             upper = unname(fit$coefficients) + qnorm(.975) * se,
             p_zero = 2 * pnorm(-abs(unname(fit$coefficients) / se)))
}

quintile_results <- list()
calibration_results <- list()
tail_results <- list()
diagnostics <- list()
fits <- list()
scores <- list()
for (model_name in c("constant", "interaction")) {
  message("Validating held-out IST ranking: ", model_name)
  fit <- glm(formulas[[model_name]], data = training, family = binomial())
  stopifnot(fit$converged, all(is.finite(coef(fit))), fit$rank == length(coef(fit)))
  score <- as.numeric(contrast_ist(fit, test))
  control <- treated <- test
  control$aspirin <- factor("no_aspirin", levels = levels(data$aspirin))
  treated$aspirin <- factor("aspirin", levels = levels(data$aspirin))
  m0 <- as.numeric(predict(fit, newdata = control, type = "response"))
  m1 <- as.numeric(predict(fit, newdata = treated, type = "response"))
  stopifnot(all(is.finite(score)), all(is.finite(c(m0, m1))),
            max(abs(score - (m0 - m1))) < 1e-10)

  # Thresholds use test covariates/predictions only, never test outcomes.
  cutoffs <- quantile(score, seq(0, 1, .2), names = FALSE, type = 8)
  stopifnot(all(diff(cutoffs) > 0))
  quintile <- cut(score, breaks = cutoffs, include.lowest = TRUE, labels = FALSE)
  stopifnot(!anyNA(quintile), all(tabulate(quintile, nbins = 5L) > 0L))
  observed_treated <- test$aspirin == "aspirin"
  table <- do.call(rbind, lapply(seq_len(5L), function(group) {
    in_group <- quintile == group
    cbind(data.frame(model = model_name, quintile = group,
                     mean_predicted_benefit = mean(score[in_group]),
                     min_predicted_benefit = min(score[in_group]),
                     max_predicted_benefit = max(score[in_group])),
          arm_risk_difference(test$outcome[in_group], observed_treated[in_group]))
  }))
  quintile_results[[model_name]] <- table

  # AIPW benefit pseudo-outcome with all nuisance fits frozen from training.
  # Under nominal 1:1 aspirin randomization its conditional mean is the CATE,
  # even if the working outcome model is imperfect. This is an exploratory
  # large-sample diagnostic, not an exact test of the trial allocation design.
  pseudo_outcome <- m0 - m1 +
    (1 - as.integer(observed_treated)) / .5 * (test$outcome - m0) -
    as.integer(observed_treated) / .5 * (test$outcome - m1)
  calibration <- hc3_calibration(pseudo_outcome, score)
  calibration$model <- model_name
  calibration$test_score_mean <- mean(score)
  calibration$test_score_sd <- sd(score)
  calibration$test_n <- nrow(test)
  calibration_results[[model_name]] <- calibration

  low <- table[table$quintile == 1L, ]
  high <- table[table$quintile == 5L, ]
  difference <- high$estimate - low$estimate
  difference_se <- sqrt(high$standard_error^2 + low$standard_error^2)
  tail_results[[model_name]] <- data.frame(
    model = model_name, comparison = "top minus bottom predicted-benefit quintile",
    estimate = difference, standard_error = difference_se,
    lower = difference - qnorm(.975) * difference_se,
    upper = difference + qnorm(.975) * difference_se,
    p_zero = 2 * pnorm(-abs(difference / difference_se)),
    predicted_difference = high$mean_predicted_benefit - low$mean_predicted_benefit
  )
  factual_risk <- ifelse(observed_treated, m1, m0)
  factual_risk <- pmax(1e-12, pmin(1 - 1e-12, factual_risk))
  diagnostics[[model_name]] <- data.frame(
    model = model_name, training_n = nrow(training), test_n = nrow(test),
    training_parameters = length(coef(fit)), converged = fit$converged,
    score_mean = mean(score), score_sd = sd(score),
    score_q10 = as.numeric(quantile(score, .1, type = 8)),
    score_q90 = as.numeric(quantile(score, .9, type = 8)),
    test_brier = mean((test$outcome - factual_risk)^2),
    test_log_loss = -mean(test$outcome * log(factual_risk) +
                          (1 - test$outcome) * log(1 - factual_risk))
  )
  fits[[model_name]] <- fit
  scores[[model_name]] <- score
}

quintile_table <- do.call(rbind, quintile_results)
calibration_table <- do.call(rbind, calibration_results)
tail_table <- do.call(rbind, tail_results)
diagnostic_table <- do.call(rbind, diagnostics)
calibration_table$p_holm_two_rankings <- NA_real_
ranking_rows <- calibration_table$term == "ranking_slope"
calibration_table$p_holm_two_rankings[ranking_rows] <- p.adjust(
  calibration_table$p_zero[ranking_rows], method = "holm"
)
tail_table$p_holm_two_rankings <- p.adjust(tail_table$p_zero, method = "holm")
for (name in c("quintile", "calibration", "tail", "diagnostic")) {
  write.csv(get(paste0(name, "_table")),
            file.path(output_dir, paste0("validation-", name, ".csv")),
            row.names = FALSE)
}
split_counts <- as.data.frame(table(
  split = ifelse(seq_len(nrow(data)) %in% training_index, "training", "test"),
  aspirin = data$aspirin
))
write.csv(split_counts, file.path(output_dir, "validation-split.csv"), row.names = FALSE)

metadata <- list(
  seed = seed, split = "Single 50/50 split stratified on aspirin assignment only",
  training_n = nrow(training), test_n = nrow(test),
  split_selected_using_outcome = FALSE, model_selected_using_test_results = FALSE,
  estimand = "No-aspirin minus aspirin risk of death/dependence at six months",
  quintiles = "Test-prediction quintiles; thresholds use covariates and frozen training fits only",
  quintile_intervals = "Unpooled binomial Wald 95% intervals; descriptive, not multiplicity-adjusted",
  calibration = "OLS of training-nuisance AIPW benefit pseudo-outcome on centered frozen score, HC3 SE",
  calibration_null = "Zero score slope; perfect linear calibration would have slope one",
  randomization = "Nominal aspirin propensity 0.5; exploratory iid large-sample diagnostics, not exact trial-allocation inference",
  multiplicity = paste(
    "p_zero fields are exploratory and unadjusted. Additional Holm columns",
    "adjust the two rankings within calibration and tail-comparison families separately;",
    "they do not adjust all diagnostics or the five displayed quintile intervals."
  ),
  scope = "Conditional on this one training sample; no repeated-split or external validation claim"
)
capture.output(str(metadata), split_counts, diagnostic_table, calibration_table,
               tail_table, sessionInfo(),
               file = file.path(output_dir, "validation-metadata.txt"))
saveRDS(list(metadata = metadata, training_index = training_index,
             test_index = test_index, fits = fits, scores = scores,
             quintiles = quintile_table, calibration = calibration_table,
             tails = tail_table, diagnostics = diagnostic_table),
        file.path(output_dir, "validation-analysis.rds"))

if (requireNamespace("ggplot2", quietly = TRUE)) {
  quintile_table$model_label <- factor(
    quintile_table$model, levels = c("constant", "interaction"),
    labels = c("Constant treatment odds ratio", "Prespecified treatment interactions")
  )
  plot <- ggplot2::ggplot(quintile_table, ggplot2::aes(quintile, estimate * 100)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#99919F", linewidth = .4) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower * 100, ymax = upper * 100),
                         width = .12, colour = "#5A317E", linewidth = .7) +
    ggplot2::geom_point(colour = "#5A317E", size = 2.5) +
    ggplot2::geom_line(ggplot2::aes(y = mean_predicted_benefit * 100),
                      colour = "#CF7045", linetype = "dashed", linewidth = .9) +
    ggplot2::facet_wrap(~model_label, nrow = 1) +
    ggplot2::scale_x_continuous(breaks = 1:5) +
    ggplot2::labs(
      x = "Quintile of benefit predicted by the training model (low to high)",
      y = "Risk reduction in held-out patients (percentage points)",
      subtitle = "Purple: randomized arm contrast with 95% interval; dashed: mean predicted benefit",
      caption = paste(
        "One fixed 50/50 split. Unadjusted intervals; exploratory validation.",
        "Contains IST v2 data (doi.org/10.7488/ds/104), ODC-By (opendatacommons.org/licenses/by/1-0/).",
        sep = "\n"
      )
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold"),
                   plot.caption = ggplot2::element_text(size = 8))
  for (extension in c("png", "pdf")) {
    ggplot2::ggsave(file.path(output_dir, paste0("validation-quintiles.", extension)),
                   plot, width = 11, height = 5, dpi = 180, bg = "#FAF9F6")
  }
}
print(diagnostic_table)
print(calibration_table)
print(tail_table)
message("Held-out IST ranking checks completed; see results/ist/validation-*.")
