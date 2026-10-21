# Reproducible sorted-effects teaching example.
# All outcomes and covariate profiles are simulated; no participant data are used.
# A generic randomized treated/control comparison with an adverse binary outcome.
# Age, a simulated binary sex indicator and their interactions determine risks.
# All coefficients are illustrative assumptions, not estimates for a real setting.
# Benefit is Pr(Y=1 | A=0, X) - Pr(Y=1 | A=1, X), so positive is favourable.
# The reference cohort is FIXED throughout bootstrap inference. The uncertainty
# therefore concerns the fitted conditional risks on this reference population,
# not the covariate distribution of a broader population.

scenario_labels <- c(
  constant = "Constant treatment odds ratio",
  interaction = "Treatment interactions with age and sex"
)

demo_quantiles <- function(x, probs) {
  as.numeric(stats::quantile(x, probs = probs, type = 8, names = FALSE))
}

make_patients <- function(n) {
  age <- stats::runif(n, 40, 80)
  female <- stats::rbinom(n, 1, 0.5)
  data.frame(
    age = age, age_z = (age - 60) / 10,
    female = female
  )
}

baseline_logit <- function(data) {
  -1.4 + 0.35 * data$age_z + 0.15 * data$female +
    0.10 * data$age_z * data$female
}

true_benefit <- function(data, scenario, interaction_intercept) {
  eta <- baseline_logit(data)
  log_or <- if (scenario == "constant") {
    rep(log(0.60), nrow(data))
  } else {
    interaction_intercept - 0.55 * data$age_z - 0.12 * data$female -
      0.08 * data$age_z * data$female
  }
  stats::plogis(eta) - stats::plogis(eta + log_or)
}

benefit_from_fit <- function(fit, reference) {
  untreated <- treated <- reference
  untreated$group <- "control"
  treated$group <- "treated"
  p0 <- stats::predict(fit, newdata = untreated, type = "response")
  p1 <- stats::predict(fit, newdata = treated, type = "response")
  list(p0 = as.numeric(p0), p1 = as.numeric(p1), benefit = as.numeric(p0 - p1))
}

tail_indices <- function(benefit, fraction = 0.1) {
  # Rank selection fixes each group's size. Stable order resolves numerical ties.
  n_tail <- floor(length(benefit) * fraction)
  ranked <- order(benefit, seq_along(benefit))
  list(
    smallest = ranked[seq_len(n_tail)],
    largest = ranked[length(ranked) - seq_len(n_tail) + 1L]
  )
}

bootstrap_scenario <- function(data, formula, reference, fitted_effect,
                               probs, B) {
  n <- nrow(data)
  quantiles <- matrix(NA_real_, nrow = B, ncol = length(probs))
  averages <- numeric(B)
  membership <- matrix(0L, nrow = nrow(reference), ncol = 2L,
                       dimnames = list(NULL, c("smallest", "largest")))
  tail_means <- array(NA_real_, dim = c(B, 2L, 3L), dimnames = list(
    NULL, c("smallest", "largest"), c("age", "female", "baseline_risk")
  ))
  converged <- logical(B)
  for (b in seq_len(B)) {
    # Resample whole randomized-trial observations, then REFIT and RE-SORT.
    draw <- data[sample.int(n, n, replace = TRUE), , drop = FALSE]
    fit <- stats::glm(formula, family = stats::binomial(), data = draw)
    converged[b] <- isTRUE(fit$converged) && all(is.finite(stats::coef(fit)))
    if (!converged[b]) {
      stop("Bootstrap fit ", b, " failed; no failed draws are silently removed.")
    }
    contrast <- benefit_from_fit(fit, reference)
    if (any(!is.finite(contrast$benefit))) stop("Non-finite bootstrap benefit.")
    quantiles[b, ] <- demo_quantiles(contrast$benefit, probs)
    averages[b] <- mean(contrast$benefit)
    groups <- tail_indices(contrast$benefit)
    for (g in names(groups)) {
      idx <- groups[[g]]
      membership[idx, g] <- membership[idx, g] + 1L
      tail_means[b, g, ] <- c(
        mean(reference$age[idx]), mean(reference$female[idx]),
        mean(contrast$p0[idx])
      )
    }
  }
  estimate <- demo_quantiles(fitted_effect, probs)
  standard_error <- apply(quantiles, 2L, stats::sd)
  if (any(!is.finite(standard_error) | standard_error <= 0)) {
    stop("A quantile has zero or invalid bootstrap uncertainty.")
  }
  deviations <- sweep(sweep(quantiles, 2L, estimate, "-"),
                      2L, standard_error, "/")
  maximum <- apply(abs(deviations), 1L, max)
  critical <- as.numeric(stats::quantile(maximum, 0.95, type = 8))
  pointwise <- apply(quantiles, 2L, stats::quantile,
                     probs = c(0.025, 0.975), type = 8)
  list(
    quantiles = quantiles, averages = averages,
    pointwise_lower = pointwise[1L, ], pointwise_upper = pointwise[2L, ],
    simultaneous_lower = estimate - critical * standard_error,
    simultaneous_upper = estimate + critical * standard_error,
    standard_error = standard_error, critical = critical,
    membership = membership / B, tail_means = tail_means,
    successful_draws = sum(converged), B = B
  )
}

run_demo <- function(B = 499L, n_trial = 5000L,
                     seed = 20261020L, progress = TRUE) {
  stopifnot(B >= 99L, n_trial >= 500L)
  set.seed(seed)
  trial_covariates <- make_patients(n_trial)
  # Use the observed trial profiles as the fixed SPE reference, matching the
  # original package's full-sample spe() path used by the clinical workflow.
  reference <- trial_covariates
  target_average <- mean(true_benefit(reference, "constant", 0))
  interaction_intercept <- stats::uniroot(function(beta) {
    mean(true_benefit(reference, "interaction", beta)) - target_average
  }, interval = c(-3, 2), tol = 1e-12)$root
  treatment <- sample(rep(0:1, length.out = n_trial))
  # Shared uniforms reduce irrelevant Monte Carlo differences between scenarios.
  outcome_uniforms <- stats::runif(n_trial)
  probs <- seq(0.1, 0.9, by = 0.01)
  formulas <- list(
    constant = outcome ~ group + age_z * female,
    interaction = outcome ~ group * age_z * female
  )
  # Avoid retaining the complete simulation frame inside saved model formulas.
  formulas <- lapply(formulas, function(formula) {
    environment(formula) <- baseenv()
    formula
  })
  scenarios <- list()
  for (scenario in names(scenario_labels)) {
    if (progress) message("Fitting and bootstrapping: ", scenario_labels[[scenario]])
    data <- trial_covariates
    data$treatment <- treatment
    data$group <- factor(ifelse(treatment == 1, "treated", "control"),
                         levels = c("control", "treated"))
    log_or <- if (scenario == "constant") {
      rep(log(0.60), n_trial)
    } else {
      interaction_intercept - 0.55 * data$age_z - 0.12 * data$female -
        0.08 * data$age_z * data$female
    }
    data$outcome <- as.integer(outcome_uniforms < stats::plogis(
      baseline_logit(data) + treatment * log_or
    ))
    fit <- stats::glm(formulas[[scenario]], family = stats::binomial(), data = data)
    stopifnot(fit$converged, all(is.finite(stats::coef(fit))))
    contrast <- benefit_from_fit(fit, reference)
    truth <- true_benefit(reference, scenario, interaction_intercept)
    bootstrap <- bootstrap_scenario(
      data, formulas[[scenario]], reference, contrast$benefit, probs, B
    )
    scenarios[[scenario]] <- list(
      data = data, fit = fit, contrast = contrast, truth = truth,
      bootstrap = bootstrap, groups = tail_indices(contrast$benefit)
    )
  }
  structure(list(
    reference = reference, scenarios = scenarios, probs = probs,
    interaction_intercept = interaction_intercept,
    metadata = list(
      seed = seed, B = B, n_trial = n_trial, n_reference = nrow(reference),
      reference_scope = "Observed trial covariates, held fixed for sorted-effect prediction",
      quantile_type = 8L, nominal_level = 0.95,
      inference_target = paste(
        "Distribution of model-based conditional risk differences over the",
        "fixed reference cohort; uncertainty in fitted model parameters only."
      ),
      simultaneous_scope = "Each scenario separately, quantile grid 0.10:0.01:0.90",
      classification_scope = paste(
        "Descriptive covariate profiles of estimated effect tails.",
        "Bootstrap membership frequencies are sensitivity summaries,",
        "not posterior probabilities or validated original-method CA intervals."
      ),
      bootstrap = "Pairs resampling of trial observations; refit and re-sort every draw",
      package_benchmark = "This implementation is not a reproduction of SortedEffects inference."
    )
  ), class = "sorted_effects_demo")
}

classification_dumbbell_data <- function(classification) {
  selected <- classification[classification$scenario == "interaction", , drop = FALSE]
  do.call(rbind, lapply(seq_len(nrow(selected)), function(i) {
    row <- selected[i, ]
    data.frame(
      scenario = "interaction", group = row$group, n = row$n,
      characteristic = c("Age", "Female", "Control-group event risk"),
      units = c("years", "%", "%"),
      value = c(row$mean_age, 100 * row$proportion_female,
                100 * row$mean_baseline_risk)
    )
  }))
}

demo_tables <- function(demo) {
  scenario_summary <- do.call(rbind, lapply(names(demo$scenarios), function(name) {
    s <- demo$scenarios[[name]]
    fitted_q <- demo_quantiles(s$contrast$benefit, c(0.1, 0.5, 0.9))
    true_q <- demo_quantiles(s$truth, c(0.1, 0.5, 0.9))
    data.frame(
      scenario = name, label = unname(scenario_labels[name]),
      n_trial = nrow(s$data), n_reference = nrow(demo$reference),
      n_treated = sum(s$data$treatment == 1),
      event_rate_control = mean(s$data$outcome[s$data$treatment == 0]),
      event_rate_treated = mean(s$data$outcome[s$data$treatment == 1]),
      mean_true_benefit = mean(s$truth),
      mean_estimated_benefit = mean(s$contrast$benefit),
      true_q10 = true_q[1], true_q50 = true_q[2], true_q90 = true_q[3],
      estimated_q10 = fitted_q[1], estimated_q50 = fitted_q[2],
      estimated_q90 = fitted_q[3],
      simultaneous_critical = s$bootstrap$critical,
      bootstrap_draws = s$bootstrap$B,
      successful_draws = s$bootstrap$successful_draws
    )
  }))
  sorted_effects <- do.call(rbind, lapply(names(demo$scenarios), function(name) {
    s <- demo$scenarios[[name]]
    data.frame(
      scenario = name, label = unname(scenario_labels[name]), percentile = demo$probs,
      estimate = demo_quantiles(s$contrast$benefit, demo$probs),
      truth = demo_quantiles(s$truth, demo$probs),
      pointwise_lower = s$bootstrap$pointwise_lower,
      pointwise_upper = s$bootstrap$pointwise_upper,
      simultaneous_lower = s$bootstrap$simultaneous_lower,
      simultaneous_upper = s$bootstrap$simultaneous_upper,
      standard_error = s$bootstrap$standard_error
    )
  }))
  classification <- do.call(rbind, lapply(names(demo$scenarios), function(name) {
    s <- demo$scenarios[[name]]
    do.call(rbind, lapply(names(s$groups), function(group) {
      idx <- s$groups[[group]]
      data.frame(
        scenario = name, label = unname(scenario_labels[name]), group = group,
        n = length(idx), mean_age = mean(demo$reference$age[idx]),
        proportion_female = mean(demo$reference$female[idx]),
        mean_baseline_risk = mean(s$contrast$p0[idx]),
        mean_benefit = mean(s$contrast$benefit[idx]),
        mean_true_benefit = mean(s$truth[idx]),
        mean_membership_frequency = mean(s$bootstrap$membership[idx, group])
      )
    }))
  }))
  # Exact illustrative risk profiles under the constant-OR model, not trial estimates.
  p0 <- c(0.10, 0.40)
  p1 <- 0.60 * p0 / (1 - p0 + 0.60 * p0)
  patient_profiles <- data.frame(
    profile = c("Lower baseline risk", "Higher baseline risk"),
    risk_without_treatment = p0, risk_with_treatment = p1,
    odds_ratio = 0.60, absolute_benefit = p0 - p1,
    source = "Illustrative known risks, constant odds ratio"
  )
  list(
    scenario_summary = scenario_summary, sorted_effects = sorted_effects,
    classification = classification, patient_profiles = patient_profiles,
    classification_dumbbells = classification_dumbbell_data(classification)
  )
}

demo_theme <- function() {
  ggplot2::theme_minimal(base_size = 17, base_family = "sans") +
    ggplot2::theme(
      text = ggplot2::element_text(colour = "#1A1A2E"),
      plot.background = ggplot2::element_rect(fill = "#FAFAFA", colour = NA),
      panel.background = ggplot2::element_rect(fill = "#FAFAFA", colour = NA),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#E8E5EC", linewidth = 0.3),
      strip.text = ggplot2::element_text(face = "bold", size = 15),
      legend.position = "bottom", legend.title = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = 19),
      plot.subtitle = ggplot2::element_text(size = 12),
      plot.caption = ggplot2::element_text(size = 10, hjust = 0),
      plot.margin = ggplot2::margin(10, 16, 10, 10)
    )
}

percent_label <- function(x) paste0(round(100 * x), "%")

demo_figures <- function(demo, tables = demo_tables(demo)) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2 first.")
  # Both the exact OR relationship and fitted profile effects are informative.
  risk_grid <- seq(0.01, 0.90, length.out = 300)
  risk_curve <- data.frame(
    p0 = risk_grid,
    benefit = risk_grid - 0.60 * risk_grid / (1 - risk_grid + 0.60 * risk_grid)
  )
  labels <- tables$patient_profiles
  baseline_plot <- ggplot2::ggplot(risk_curve, ggplot2::aes(p0, benefit)) +
    ggplot2::geom_line(colour = "#5A317E", linewidth = 1.4) +
    ggplot2::geom_segment(data = labels, ggplot2::aes(
      x = risk_without_treatment, xend = risk_without_treatment,
      y = 0, yend = absolute_benefit
    ), linetype = "dashed", colour = "#A7A0B0") +
    ggplot2::geom_point(data = labels, ggplot2::aes(
      x = risk_without_treatment, y = absolute_benefit
    ), size = 4, colour = "#E07B53") +
    ggplot2::geom_text(data = labels, ggplot2::aes(
      x = risk_without_treatment, y = absolute_benefit,
      label = sprintf("%.1f pp", 100 * absolute_benefit)
    ), nudge_y = 0.011, size = 5.5, colour = "#1A1A2E") +
    ggplot2::scale_x_continuous(labels = percent_label, breaks = seq(0, 0.9, 0.1)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x),
                              limits = c(0, 0.13)) +
    ggplot2::labs(
      x = "Risk without treatment", y = "Absolute benefit (percentage points)",
      subtitle = "Exactly the same treatment odds ratio: 0.60 at every baseline risk",
      caption = "Known illustrative risks. Absolute benefit peaks at an intermediate baseline risk."
    ) + demo_theme()

  sorted_plot <- ggplot2::ggplot(tables$sorted_effects,
                               ggplot2::aes(percentile, estimate, colour = label)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 1.3) +
    ggplot2::geom_line(ggplot2::aes(y = truth), linetype = "dotted", linewidth = 0.9) +
    ggplot2::scale_colour_manual(values = c("#5A317E", "#E07B53")) +
    ggplot2::scale_x_continuous(labels = percent_label,
                              breaks = c(0.1, 0.25, 0.5, 0.75, 0.9)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x)) +
    ggplot2::labs(
      x = "Percentile of conditional benefit", y = "Absolute benefit (percentage points)",
      subtitle = "Solid: estimated effects   |   Dotted: known simulation truth",
      caption = sprintf(
        "Both scenarios have the same true average benefit: %.1f pp. Central 10th–90th percentiles shown.",
        100 * mean(demo$scenarios$constant$truth)
      )
    ) + demo_theme()

  band_data <- tables$sorted_effects
  uncertainty_plot <- ggplot2::ggplot(band_data, ggplot2::aes(percentile, estimate)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = simultaneous_lower,
                                    ymax = simultaneous_upper,
                                    fill = "95% simultaneous band"), alpha = 0.8) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = pointwise_lower,
                                    ymax = pointwise_upper,
                                    fill = "95% pointwise intervals"), alpha = 0.8) +
    ggplot2::geom_line(colour = "#5A317E", linewidth = 1.1) +
    ggplot2::facet_wrap(~label, nrow = 1) +
    ggplot2::scale_fill_manual(values = c(
      "95% simultaneous band" = "#D9CEE5", "95% pointwise intervals" = "#AD90C9"
    )) +
    ggplot2::scale_x_continuous(labels = percent_label, breaks = c(0.1, 0.5, 0.9)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x)) +
    ggplot2::labs(
      x = "Percentile of conditional benefit", y = "Absolute benefit (percentage points)",
      subtitle = "Refit the trial model and re-sort predictions in every bootstrap replicate",
      caption = sprintf(
        "%s pairs-bootstrap draws; fixed reference cohort. Simultaneous coverage targets each scenario's displayed quantile grid.",
        demo$metadata$B
      )
    ) + demo_theme()

  # Covariate scales are deliberately separated; no misleading common numeric axis.
  classification_data <- do.call(rbind, lapply(seq_len(nrow(tables$classification)), function(i) {
    row <- tables$classification[i, ]
    data.frame(
      label = row$label, group = row$group,
      characteristic = c("Age (years)", "Female (%)",
                         "Predicted control risk (%)"),
      value = c(row$mean_age, 100 * row$proportion_female, 100 * row$mean_baseline_risk)
    )
  }))
  classification_data$group <- factor(classification_data$group,
                                      levels = c("smallest", "largest"),
                                      labels = c("Smallest-benefit 10%", "Largest-benefit 10%"))
  classification_data$characteristic <- factor(classification_data$characteristic,
    levels = c("Age (years)", "Female (%)",
               "Predicted control risk (%)"))
  classification_plot <- ggplot2::ggplot(classification_data,
                                        ggplot2::aes(value, group, colour = group)) +
    ggplot2::geom_point(size = 3.5) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f", value)),
                      nudge_y = 0.22, size = 4.3, show.legend = FALSE) +
    ggplot2::facet_grid(label ~ characteristic, scales = "free_x", labeller = ggplot2::labeller(
      label = c("Constant treatment odds ratio" = "Constant OR",
                "Treatment interactions with age and sex" = "Interaction"),
      characteristic = c("Age (years)" = "Age (years)",
        "Female (%)" = "Female (%)",
        "Predicted control risk (%)" = "Predicted control\nrisk (%)")
    )) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.18)) +
    ggplot2::scale_colour_manual(values = c("#94A3B8", "#5A317E")) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = 0.5)) +
    ggplot2::labs(
      x = "Mean within each estimated tail", y = NULL,
      caption = "Descriptive classification of the fixed reference cohort; these are not treatment-assignment rules."
    ) + demo_theme() + ggplot2::theme(
      legend.position = "none", strip.text.y = ggplot2::element_text(size = 12),
      axis.text.y = ggplot2::element_text(size = 11)
    )

  membership_data <- do.call(rbind, lapply(names(demo$scenarios), function(name) {
    s <- demo$scenarios[[name]]
    idx <- s$groups$largest
    data.frame(
      rank_within_tail = seq_along(idx),
      frequency = s$bootstrap$membership[idx, "largest"],
      label = unname(scenario_labels[name])
    )
  }))
  membership_plot <- ggplot2::ggplot(membership_data,
    ggplot2::aes(rank_within_tail, frequency, colour = label)) +
    ggplot2::geom_line(linewidth = 0.9, alpha = 0.8) +
    ggplot2::scale_colour_manual(values = c("#5A317E", "#E07B53")) +
    ggplot2::scale_y_continuous(labels = percent_label, limits = c(0, 1)) +
    ggplot2::labs(
      x = "Rank within the estimated largest-benefit 10% (highest benefit first)",
      y = "Top-tail membership frequency",
      subtitle = "Group membership can change when the fitted model changes",
      caption = "Refit-and-reclassify sensitivity summary; frequencies are not probabilities that a profile truly belongs to a group."
    ) + demo_theme()

  # Keep the two-scenario views for optional backup, while the main session
  # follows the generic randomized example with age and sex interactions.
  comparisons <- list(
    "sorted-effects-comparison" = sorted_plot,
    "uncertainty-comparison" = uncertainty_plot,
    "classification-comparison" = classification_plot,
    "membership-stability-comparison" = membership_plot
  )
  clinical <- tables$sorted_effects[
    tables$sorted_effects$scenario == "interaction", , drop = FALSE
  ]
  clinical_scenario <- demo$scenarios$interaction
  clinical_sorted <- ggplot2::ggplot(clinical, ggplot2::aes(percentile, estimate)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_hline(yintercept = mean(clinical_scenario$contrast$benefit),
                       colour = "#A34E2A", linetype = "dashed", linewidth = 0.8) +
    ggplot2::geom_line(colour = "#5A317E", linewidth = 1.5) +
    ggplot2::geom_line(ggplot2::aes(y = truth), colour = "#5A317E",
                      linetype = "dotted", linewidth = 0.9) +
    ggplot2::scale_x_continuous(labels = percent_label,
                              breaks = c(0.1, 0.25, 0.5, 0.75, 0.9)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x)) +
    ggplot2::labs(
      x = "Percentile of conditional benefit", y = "Event risk reduction (pp)",
      subtitle = "Solid: fitted sorted effects   |   Dotted: known simulation truth",
      caption = sprintf(
        "Simulated treated/control comparison. Dashed: average fitted benefit (%.1f pp). Central 10th–90th percentiles shown.",
        100 * mean(clinical_scenario$contrast$benefit)
      )
    ) + demo_theme()

  clinical_uncertainty <- ggplot2::ggplot(clinical, ggplot2::aes(percentile, estimate)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = simultaneous_lower,
                                    ymax = simultaneous_upper,
                                    fill = "95% simultaneous band"), alpha = 0.8) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = pointwise_lower,
                                    ymax = pointwise_upper,
                                    fill = "95% pointwise intervals"), alpha = 0.8) +
    ggplot2::geom_line(colour = "#5A317E", linewidth = 1.3) +
    ggplot2::scale_fill_manual(values = c(
      "95% simultaneous band" = "#D9CEE5", "95% pointwise intervals" = "#AD90C9"
    )) +
    ggplot2::scale_x_continuous(labels = percent_label,
                              breaks = c(0.1, 0.25, 0.5, 0.75, 0.9)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x)) +
    ggplot2::labs(
      x = "Percentile of conditional benefit", y = "Event risk reduction (pp)",
      subtitle = "Refit the model and re-sort effects after every resample",
      caption = sprintf(
        "%s pairs-bootstrap draws; fixed reference cohort. Simultaneous coverage targets the displayed percentile grid.",
        demo$metadata$B
      )
    ) + demo_theme()

  # Separate axes retain the unit of each characteristic. The line
  # connects two descriptive group summaries; it is not a confidence interval.
  dumbbells <- tables$classification_dumbbells
  dumbbells$panel <- factor(
    dumbbells$characteristic,
    levels = c("Age", "Female", "Control-group event risk"),
    labels = c("Age (years)", "Female (%)", "Predicted control risk (%)")
  )
  low <- dumbbells[dumbbells$group == "smallest", , drop = FALSE]
  high <- dumbbells[dumbbells$group == "largest", , drop = FALSE]
  connectors <- data.frame(panel = low$panel, smallest = low$value, largest = high$value)
  dumbbell_bounds <- data.frame(
    panel = factor(rep(levels(dumbbells$panel), each = 2), levels = levels(dumbbells$panel)),
    value = c(40, 80, 0, 100, 0, 100)
  )
  dumbbells$group <- factor(dumbbells$group, levels = c("smallest", "largest"),
    labels = c("Smallest-benefit 10%", "Largest-benefit 10%"))
  dumbbell_plot <- ggplot2::ggplot(dumbbells, ggplot2::aes(value, 1)) +
    ggplot2::geom_blank(data = dumbbell_bounds, ggplot2::aes(value, 1), inherit.aes = FALSE) +
    ggplot2::geom_segment(data = connectors, ggplot2::aes(
      x = smallest, xend = largest, y = 1, yend = 1
    ), inherit.aes = FALSE, colour = "#C6BBCF", linewidth = 2.2) +
    ggplot2::geom_point(ggplot2::aes(colour = group, shape = group), size = 4.5) +
    ggplot2::geom_text(ggplot2::aes(
      y = ifelse(group == "Smallest-benefit 10%", 1.16, 0.84),
      label = sprintf("%.1f", value), colour = group
    ), size = 5.1, fontface = "bold", show.legend = FALSE) +
    ggplot2::facet_wrap(~panel, ncol = 2, scales = "free_x") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.05)) +
    ggplot2::scale_y_continuous(limits = c(0.75, 1.45), breaks = NULL) +
    ggplot2::scale_colour_manual(values = c("#A34E2A", "#5A317E")) +
    ggplot2::scale_shape_manual(values = c(16, 17)) +
    ggplot2::labs(
      x = NULL, y = NULL,
      caption = sprintf(
        "Simulated comparison; %s reference profiles per tail. Descriptive means/proportions with separate axes; no classification intervals.",
        floor(nrow(demo$reference) / 10)
      )
    ) + demo_theme() + ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", size = 14),
      panel.spacing = grid::unit(1.3, "lines")
    )

  clinical_membership <- membership_data[
    membership_data$label == scenario_labels[["interaction"]], , drop = FALSE
  ]
  clinical_membership_plot <- ggplot2::ggplot(clinical_membership,
    ggplot2::aes(rank_within_tail, frequency)) +
    ggplot2::geom_line(linewidth = 1.1, colour = "#5A317E") +
    ggplot2::scale_y_continuous(labels = percent_label, limits = c(0, 1)) +
    ggplot2::labs(
      x = "Rank within the largest-benefit 10%\n(highest benefit first)",
      y = "Top-tail membership frequency",
      subtitle = "Which profiles remain in the upper tail after refitting?",
      caption = "Refit-and-reclassify sensitivity summary; frequencies are not probabilities that a profile truly belongs to a group."
    ) + demo_theme()

  effect_grid <- expand.grid(age = seq(40, 80, length.out = 161), female = 0:1)
  effect_grid$age_z <- (effect_grid$age - 60) / 10
  effect_grid$benefit <- benefit_from_fit(clinical_scenario$fit, effect_grid)$benefit
  effect_grid$sex <- factor(effect_grid$female, levels = 0:1,
                           labels = c("Male", "Female"))
  demographic_plot <- ggplot2::ggplot(effect_grid,
    ggplot2::aes(age, benefit, colour = sex, linetype = sex)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 1.4) +
    ggplot2::scale_colour_manual(values = c("#5A317E", "#A34E2A")) +
    ggplot2::scale_linetype_manual(values = c("solid", "dashed")) +
    ggplot2::scale_x_continuous(breaks = seq(40, 80, 10)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x)) +
    ggplot2::labs(x = "Age (years)", y = "Event risk reduction (pp)",
      subtitle = "Conditional effects from the same fitted model",
      caption = "Simulated data. Positive values mean lower event risk in the treated group.") +
    demo_theme()

  # Main-slide figures retain explicit axes but leave explanatory prose to slides.
  main_figures <- list(
    "demographic-effects" = demographic_plot,
    "baseline-risk" = baseline_plot, "sorted-effects" = clinical_sorted,
    "uncertainty" = clinical_uncertainty, "classification" = dumbbell_plot,
    "membership-stability" = clinical_membership_plot
  )
  main_figures[c("demographic-effects", "membership-stability")] <- lapply(
    main_figures[c("demographic-effects", "membership-stability")],
    function(p) p + ggplot2::labs(subtitle = NULL, caption = NULL)
  )
  c(main_figures, comparisons)
}

write_demo <- function(demo, output_dir = "results") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  figure_dir <- file.path(output_dir, "figures")
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- demo_tables(demo)
  for (name in names(tables)) {
    utils::write.csv(tables[[name]],
      file.path(output_dir, paste0(gsub("_", "-", name), ".csv")), row.names = FALSE)
  }
  saveRDS(demo, file.path(output_dir, "demo.rds"), version = 3)
  capture.output(str(demo$metadata), utils::sessionInfo(),
                 file = file.path(output_dir, "run-metadata.txt"))
  figures <- demo_figures(demo, tables)
  # The main session's SPE/classification figures are written only by the
  # original-package workflow. Running this teaching bootstrap alone must not
  # silently replace those formal outputs with approximate inference.
  teaching_names <- names(figures) %in% c("sorted-effects", "uncertainty", "classification")
  names(figures)[teaching_names] <- paste0(names(figures)[teaching_names], "-teaching")
  for (name in names(figures)) {
    main_figure <- name %in% c("demographic-effects", "membership-stability")
    width <- if (main_figure) 7.3 else if (grepl("^(uncertainty|classification)", name)) 12 else 11
    height <- if (main_figure) 4.8 else 5.5
    ggplot2::ggsave(file.path(figure_dir, paste0(name, ".png")), figures[[name]],
                    width = width, height = height, units = "in", dpi = 180,
                    bg = "#FAFAFA")
    ggplot2::ggsave(file.path(figure_dir, paste0(name, ".pdf")), figures[[name]],
                    width = width, height = height, units = "in", device = grDevices::cairo_pdf,
                    bg = "#FAFAFA")
  }
  invisible(tables)
}

write_clinical_inference_figures <- function(output_dir = "results") {
  # Called after scripts/clinical-inference.R has written fresh original-package
  # output. Keep the package estimates and multiplicity adjustment intact.
  paths <- file.path(output_dir, c("clinical-spe.csv", "clinical-ape.csv",
                                   "clinical-inference.csv", "demo.rds"))
  if (!all(file.exists(paths))) stop("Generate the clinical inference outputs first.")
  spe <- utils::read.csv(paths[1L])
  ape <- utils::read.csv(paths[2L])
  ca <- utils::read.csv(paths[3L])
  demo <- readRDS(paths[4L])
  stopifnot(all(c("percentile", "estimate", "lower_uniform", "upper_uniform") %in% names(spe)))
  stopifnot(all(c("characteristic", "least_mean", "most_mean", "difference",
                  "standard_error", "joint_p") %in% names(ca)))
  stopifnot(setequal(ca$characteristic, c("age", "female")))
  stopifnot(all(is.finite(spe$estimate)), all(is.finite(ca$joint_p)))
  stopifnot(nrow(ape) == 1L,
            abs(ape$estimate - mean(demo$scenarios$interaction$contrast$benefit)) < 1e-8)
  inference_B <- if ("bootstrap_draws" %in% names(ca)) {
    unique(ca$bootstrap_draws)
  } else demo$metadata$B
  stopifnot(length(inference_B) == 1L, inference_B >= 49L)
  figure_dir <- file.path(output_dir, "figures")
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

  # Preserve the simpler teaching bootstrap as separate backup figures.
  teaching <- demo_figures(demo)
  figures <- list(
    "sorted-effects-teaching" = teaching[["sorted-effects"]],
    "uncertainty-teaching" = teaching[["uncertainty"]],
    "classification-teaching" = teaching[["classification"]]
  )
  spe_plot <- ggplot2::ggplot(spe, ggplot2::aes(percentile, estimate)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_hline(yintercept = ape$estimate[1L], colour = "#A34E2A",
                       linetype = "dashed", linewidth = 0.8) +
    ggplot2::geom_line(colour = "#5A317E", linewidth = 1.5) +
    ggplot2::scale_x_continuous(labels = percent_label,
                              breaks = c(0.1, 0.25, 0.5, 0.75, 0.9)) +
    ggplot2::scale_y_continuous(labels = function(x) sprintf("%.0f", 100 * x)) +
    ggplot2::labs(
      x = "Percentile of conditional benefit", y = "Event risk reduction (pp)",
      subtitle = "Distribution of fitted effects across the simulated participants",
      caption = sprintf(
        "SortedEffects 1.7.0 estimates; observed trial profiles held fixed. Dashed: average benefit (%.1f pp).",
        100 * ape$estimate[1L]
      )
    ) + demo_theme()
  uniform_plot <- spe_plot +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_uniform, ymax = upper_uniform),
                         fill = "#D9CEE5", alpha = 0.8) +
    ggplot2::geom_hline(yintercept = 0, colour = "#A7A0B0", linewidth = 0.4) +
    ggplot2::geom_hline(yintercept = ape$estimate[1L], colour = "#A34E2A",
                       linetype = "dashed", linewidth = 0.8) +
    ggplot2::geom_line(colour = "#5A317E", linewidth = 1.3) +
    ggplot2::labs(
      subtitle = "Original-package inference: 95% simultaneous confidence band",
      caption = paste(
        "SortedEffects 1.7.0 refit-and-sort bootstrap; percentile grid shown.",
        "Uncertainty is conditional on the outcome model and fixed trial profiles."
      )
    )

  units <- c(age = "years", female = "percentage points")
  scale <- ifelse(ca$characteristic == "female", 100, 1)
  labels <- c(age = "Age (years)", female = "Female (%)")
  plot_data <- do.call(rbind, lapply(seq_len(nrow(ca)), function(i) {
    data.frame(
      characteristic = ca$characteristic[i], panel = unname(labels[ca$characteristic[i]]),
      group = c("Smallest-benefit 10%", "Largest-benefit 10%"),
      value = c(ca$least_mean[i], ca$most_mean[i]) * scale[i]
    )
  }))
  plot_data$panel <- factor(plot_data$panel, levels = unname(labels))
  plot_data$group <- factor(plot_data$group,
                            levels = c("Smallest-benefit 10%", "Largest-benefit 10%"))
  connectors <- data.frame(
    panel = factor(unname(labels[ca$characteristic]), levels = unname(labels)),
    smallest = ca$least_mean * scale, largest = ca$most_mean * scale
  )
  dumbbell_bounds <- data.frame(
    panel = factor(rep(unname(labels), each = 2), levels = unname(labels)),
    value = c(40, 80, 0, 100)
  )
  dumbbell_plot <- ggplot2::ggplot(plot_data, ggplot2::aes(value, 1)) +
    ggplot2::geom_blank(data = dumbbell_bounds, ggplot2::aes(value, 1), inherit.aes = FALSE) +
    ggplot2::geom_segment(data = connectors, ggplot2::aes(
      x = smallest, xend = largest, y = 1, yend = 1
    ), inherit.aes = FALSE, colour = "#C6BBCF", linewidth = 2.2) +
    ggplot2::geom_point(ggplot2::aes(colour = group, shape = group), size = 4.7) +
    ggplot2::geom_text(ggplot2::aes(
      y = ifelse(group == "Smallest-benefit 10%", 1.16, 0.84),
      label = sprintf("%.1f", value), colour = group
    ), size = 5.4, fontface = "bold", show.legend = FALSE) +
    ggplot2::facet_wrap(~panel, nrow = 1, scales = "free_x") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.05)) +
    ggplot2::scale_y_continuous(limits = c(0.58, 1.42), breaks = NULL) +
    ggplot2::scale_colour_manual(values = c("#A34E2A", "#5A317E")) +
    ggplot2::scale_shape_manual(values = c(16, 17)) +
    ggplot2::labs(
      x = NULL, y = NULL,
      caption = paste(
        "Original ca() tail means. Separate axes retain each characteristic's units.",
        "Connecting lines are not confidence intervals; inference for differences follows."
      )
    ) + demo_theme() + ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

  display <- data.frame(
    characteristic = ca$characteristic, label = unname(labels[ca$characteristic]),
    least_mean = ca$least_mean * scale, most_mean = ca$most_mean * scale,
    difference = ca$difference * scale, standard_error = ca$standard_error * scale,
    difference_unit = unname(units[ca$characteristic]), joint_p = ca$joint_p,
    joint_p_label = ifelse(ca$joint_p == 0, paste0("0 / ", inference_B),
                           format.pval(ca$joint_p, digits = 2)),
    bootstrap_draws = inference_B
  )
  utils::write.csv(display, file.path(output_dir, "clinical-classification-display.csv"),
                   row.names = FALSE)
  display$y <- nrow(display) + 1 - seq_len(nrow(display))
  display$difference_text <- sprintf("%+.2f", display$difference)
  display$se_text <- sprintf("%.2f", display$standard_error)
  display$p_text <- display$joint_p_label
  inference_plot <- ggplot2::ggplot(display, ggplot2::aes(y = y)) +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = 1, y = y - 0.43, yend = y - 0.43),
                          colour = "#E4DCEB", linewidth = 0.5) +
    ggplot2::geom_text(ggplot2::aes(x = 0.02, label = label), hjust = 0,
                       size = 6.2, colour = "#352348") +
    ggplot2::geom_text(ggplot2::aes(x = 0.56, label = difference_text),
                       size = 6.2, fontface = "bold", colour = "#5A317E") +
    ggplot2::geom_text(ggplot2::aes(x = 0.75, label = se_text), size = 6.2) +
    ggplot2::geom_text(ggplot2::aes(x = 0.93, label = p_text), size = 6.2) +
    ggplot2::annotate("text", x = c(0.02, 0.56, 0.75, 0.93), y = nrow(display) + 0.75,
                      label = c("Characteristic", "Largest − smallest", "Bootstrap SE", "Joint p"),
                      hjust = c(0, 0.5, 0.5, 0.5), size = 5, fontface = "bold", colour = "#5A317E") +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = c(0.3, nrow(display) + 1), expand = c(0, 0)) +
    ggplot2::labs(
      subtitle = "Differences between the estimated benefit tails, using original-package classification inference",
      caption = paste0(
        "Joint p values adjust across age and female proportion. Female differences/SE are in percentage points.\n",
        "B = ", inference_B,
        "; 0 / B denotes zero bootstrap exceedances, not a population p value of zero."
      )
    ) + demo_theme() + ggplot2::theme(
      axis.title = ggplot2::element_blank(), axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(), panel.grid = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank()
    )
  figures[["sorted-effects"]] <- spe_plot + ggplot2::labs(subtitle = NULL, caption = NULL)
  figures[["uncertainty"]] <- uniform_plot + ggplot2::labs(subtitle = NULL, caption = NULL)
  figures[["classification"]] <- dumbbell_plot + ggplot2::labs(subtitle = NULL, caption = NULL)
  figures[["classification-inference"]] <- inference_plot
  for (name in names(figures)) {
    main_figure <- name %in% c("sorted-effects", "uncertainty", "classification")
    width <- if (main_figure) 7.3 else if (grepl("^(uncertainty|classification)", name)) 12 else 11
    height <- if (name == "classification") 3.8 else if (main_figure) 4.8 else if (name == "classification-inference") 4.3 else 5.5
    ggplot2::ggsave(file.path(figure_dir, paste0(name, ".png")), figures[[name]],
                    width = width, height = height, units = "in", dpi = 180,
                    bg = "#FAFAFA")
    ggplot2::ggsave(file.path(figure_dir, paste0(name, ".pdf")), figures[[name]],
                    width = width, height = height, units = "in", device = grDevices::cairo_pdf,
                    bg = "#FAFAFA")
  }
  invisible(display)
}

if (sys.nframe() == 0L) {
  B <- as.integer(Sys.getenv("DEMO_BOOTSTRAPS", "499"))
  demo <- run_demo(B = B)
  tables <- write_demo(demo)
  print(tables$scenario_summary)
  message("Wrote teaching figures and data to results/. Run Rscript scripts/clinical-inference.R ",
          "to refresh the main inferential figures, then Rscript scripts/validate-demo.R.")
}
