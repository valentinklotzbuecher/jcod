#!/usr/bin/env Rscript
# Independent reconstruction of the native colon SPE and CA bootstrap outputs.
# Run after analyze-colon.R; "reconstruct" can run before native files exist,
# "compare" checks a saved reconstruction without repeating the fits, and
# "stabilize" runs the separately labeled post-plan initialization diagnostic.
options(warn = 1)
source("R/colon-data.R")
source("R/colon-analysis.R")
stopifnot(requireNamespace("Hmisc", quietly = TRUE),
          requireNamespace("SortedEffects", quietly = TRUE),
          as.character(packageVersion("SortedEffects")) == "1.7.0")
args <- commandArgs(trailingOnly = TRUE)
stage <- if (length(args)) match.arg(args[1], c("all", "reconstruct", "compare", "stabilize")) else "all"
B <- as.integer(Sys.getenv("COLON_BOOTSTRAPS", "499"))
stopifnot(length(B) == 1L, is.finite(B), B >= 99L)
seed <- 420L
alpha <- .05
grid <- seq(.10, .90, by = .01)
output_dir <- "results/colon"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
cache_path <- file.path(output_dir, "bootstrap-reconstruction.rds")
write_result <- function(x, name) {
  write.csv(x, file.path(output_dir, name), row.names = FALSE)
}
data <- prepare_colon_data()$data
formulas <- colon_formulas()
traits <- colon_characteristics()$variable
n <- nrow(data)
stopifnot(n == 593L, !anyNA(data[, traits]), !anyDuplicated(data$id))

if (!stage %in% c("compare", "stabilize")) {
  fit_rows <- list()
  warning_rows <- list()
  audit_fit <- function(formula, weights, model, purpose, draw) {
    fit_data <- data
    fit_data$.bootstrap_weight <- weights
    messages <- character()
    fit <- withCallingHandlers(
      glm(formula, data = fit_data, family = binomial(), weights = .bootstrap_weight),
      warning = function(w) {
        messages <<- c(messages, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    risks <- withCallingHandlers(
      colon_risks(fit, data),
      warning = function(w) {
        messages <<- c(messages, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    benign <- grepl("non-integer #successes in a binomial glm", messages, fixed = TRUE)
    fit_rows[[length(fit_rows) + 1L]] <<- data.frame(
      model = model, purpose = purpose, draw = draw,
      converged = isTRUE(fit$converged), rank = fit$rank,
      coefficients = length(coef(fit)), full_rank = fit$rank == length(coef(fit)),
      finite_coefficients = all(is.finite(coef(fit))),
      finite_risks = all(is.finite(as.matrix(risks))),
      min_risk = min(as.matrix(risks)), max_risk = max(as.matrix(risks)),
      near_boundary_risks = sum(as.matrix(risks) < 1e-6 | as.matrix(risks) > 1 - 1e-6),
      max_abs_coefficient = max(abs(coef(fit))),
      weight_noninteger_warnings = sum(benign), other_warnings = sum(!benign)
    )
    if (length(messages)) {
      warning_rows[[length(warning_rows) + 1L]] <<- data.frame(
        model = model, purpose = purpose, draw = draw,
        expected_weight_warning = benign, message = messages
      )
    }
    # Keep every draw, including one with a numerical warning, for comparison
    # with the native algorithm. Diagnostics determine what can be claimed.
    list(fit = fit, effect = risks$control - risks$treated)
  }

  point <- lapply(names(formulas), function(name) {
    result <- audit_fit(formulas[[name]], rep(1, n), name, "point", 0L)
    list(effect = result$effect,
         spe = as.numeric(Hmisc::wtd.quantile(result$effect, rep(1, n), grid)),
         ape = mean(result$effect))
  })
  names(point) <- names(formulas)
  cut <- Hmisc::wtd.quantile(point$interaction$effect, rep(1, n), c(.10, .90))
  direct_ca <- colMeans(data[point$interaction$effect >= cut[2], traits]) -
    colMeans(data[point$interaction$effect <= cut[1], traits])
  spe_draws <- lapply(formulas, function(fm) matrix(NA_real_, B, length(grid)))
  ape_draws <- lapply(formulas, function(fm) numeric(B))
  ca_draws <- matrix(NA_real_, B, length(traits), dimnames = list(NULL, traits))
  ca_tail_rows <- vector("list", B)

  # Each native call resets the seed. Sharing the sampled counts reproduces
  # that sequence for all three paths without invoking package bootstrap code.
  set.seed(seed)
  for (draw in seq_len(B)) {
    counts <- tabulate(sample.int(n, n, replace = TRUE), nbins = n)
    proportions <- counts / sum(counts)
    spe_weights <- proportions / mean(proportions)
    for (name in names(formulas)) {
      result <- audit_fit(formulas[[name]], spe_weights, name, "spe", draw)
      spe_draws[[name]][draw, ] <- Hmisc::wtd.quantile(result$effect, rep(1, n), grid)
      ape_draws[[name]][draw] <- mean(result$effect)
    }

    # Native CA uses total frequency weight 20,000. Keep this exact scaling
    # for the model and empirical quantile interpolation; means alone would
    # be insensitive to common weight scaling, but thresholds need not be.
    ca_weights <- proportions * 20000
    result <- audit_fit(formulas$interaction, ca_weights, "interaction", "ca", draw)
    cut <- Hmisc::wtd.quantile(result$effect, ca_weights, c(.10, .90))
    low <- result$effect <= cut[1]
    high <- result$effect >= cut[2]
    ca_tail_rows[[draw]] <- data.frame(
      draw = draw, low_n = sum(low), high_n = sum(high),
      low_weight = sum(ca_weights[low]), high_weight = sum(ca_weights[high]),
      low_cutoff = cut[1], high_cutoff = cut[2],
      min_effect = min(result$effect), max_effect = max(result$effect),
      low_cutoff_below_min = cut[1] < min(result$effect),
      high_cutoff_above_max = cut[2] > max(result$effect), row.names = NULL)
    ca_draws[draw, ] <- vapply(traits, function(trait) {
      weighted.mean(data[[trait]][high], ca_weights[high]) -
        weighted.mean(data[[trait]][low], ca_weights[low])
    }, numeric(1))
    if (draw %% 100L == 0L || draw == B) {
      message("Reconstructed colon bootstrap draw ", draw, "/", B)
    }
  }

  diagnostic <- do.call(rbind, fit_rows)
  warnings <- if (length(warning_rows)) do.call(rbind, warning_rows) else
    data.frame(model = character(), purpose = character(), draw = integer(),
               expected_weight_warning = logical(), message = character())
  write_result(diagnostic, "bootstrap-fit-diagnostics.csv")
  write_result(warnings, "bootstrap-warnings.csv")
  summary <- do.call(rbind, lapply(split(diagnostic, interaction(diagnostic$model,
      diagnostic$purpose, drop = TRUE)), function(x) {
    data.frame(model = x$model[1], purpose = x$purpose[1], fits = nrow(x),
      nonconverged = sum(!x$converged), rank_deficient = sum(!x$full_rank),
      nonfinite_coefficients = sum(!x$finite_coefficients),
      nonfinite_risks = sum(!x$finite_risks),
      fits_with_near_boundary_risks = sum(x$near_boundary_risks > 0),
      min_risk = min(x$min_risk), max_risk = max(x$max_risk),
      max_abs_coefficient = max(x$max_abs_coefficient),
      weight_noninteger_warnings = sum(x$weight_noninteger_warnings),
      other_warnings = sum(x$other_warnings), row.names = NULL)
  }))
  write_result(summary, "bootstrap-fit-summary.csv")
  missing_draws <- data.frame(draw = seq_len(B),
    nonfinite_ca_traits = rowSums(!is.finite(ca_draws)),
    all_ca_traits_nonfinite = rowSums(is.finite(ca_draws)) == 0L)
  write_result(missing_draws, "bootstrap-ca-missing-draws.csv")
  ca_tail_diagnostics <- do.call(rbind, ca_tail_rows)
  write_result(ca_tail_diagnostics, "bootstrap-ca-tail-diagnostics.csv")
  reconstructed <- list(B = B, seed = seed, alpha = alpha, grid = grid,
    data = data, formulas = formulas, traits = traits, point = point,
    direct_ca = direct_ca, spe_draws = spe_draws, ape_draws = ape_draws,
    ca_draws = ca_draws, diagnostics = diagnostic, warnings = warnings, summary = summary,
    ca_missing_draws = missing_draws, ca_tail_diagnostics = ca_tail_diagnostics)
  saveRDS(reconstructed, cache_path)
  print(summary)
  if (stage == "reconstruct") {
    message("Reconstruction saved; run with 'compare' after native inference finishes.")
    quit(save = "no", status = 0)
  }
} else {
  reconstructed <- readRDS(cache_path)
  stopifnot(identical(reconstructed$data, data), identical(reconstructed$B, B),
            identical(reconstructed$seed, seed), identical(reconstructed$grid, grid),
            identical(reconstructed$traits, traits),
            all(vapply(names(formulas), function(name) {
              identical(deparse(reconstructed$formulas[[name]]), deparse(formulas[[name]]))
            }, logical(1))))
}

if (stage == "stabilize") {
  # POST-PLAN NUMERICAL DIAGNOSTIC: native ca()'s 20,000-total weights caused
  # failed default-start glm fits. Preserve each draw, the weighted likelihood,
  # thresholds and tail means; only initialize at that draw's count-weight MLE.
  # These outputs are a stabilized reconstruction, NOT native package inference.
  stabilized <- matrix(NA_real_, B, length(traits), dimnames = list(NULL, traits))
  stabilization_rows <- list()
  stabilization_warnings <- list()
  design <- model.matrix(formulas$interaction, data)
  stable_fit <- function(weights, start = NULL, draw, path) {
    fit_data <- data
    fit_data$.bootstrap_weight <- weights
    messages <- character()
    fit <- withCallingHandlers(
      glm(formulas$interaction, data = fit_data, family = binomial(),
          weights = .bootstrap_weight, start = start),
      warning = function(w) {
        messages <<- c(messages, conditionMessage(w))
        invokeRestart("muffleWarning")
      })
    if (length(messages)) {
      stabilization_warnings[[length(stabilization_warnings) + 1L]] <<- data.frame(
        draw = draw, path = path, message = messages,
        expected_weight_warning = grepl("non-integer #successes in a binomial glm", messages, fixed = TRUE))
    }
    fit
  }
  log_likelihood <- function(fit, weights) {
    eta <- as.numeric(design %*% coef(fit))
    # Stable Bernoulli log-likelihood without the count-dependent constants.
    sum(weights * (data$outcome * (-pmax(-eta, 0) - log1p(exp(-abs(eta)))) +
                     (1 - data$outcome) * (-pmax(eta, 0) - log1p(exp(-abs(eta))))))
  }
  set.seed(seed)
  for (draw in seq_len(B)) {
    counts <- tabulate(sample.int(n, n, replace = TRUE), nbins = n)
    proportions <- counts / sum(counts)
    count_weights <- proportions / mean(proportions)
    ca_weights <- proportions * 20000
    count_fit <- stable_fit(count_weights, draw = draw, path = "count_start")
    warm_fit <- stable_fit(ca_weights, start = coef(count_fit), draw = draw, path = "warm_scaled")
    count_risk <- colon_risks(count_fit, data)
    warm_risk <- colon_risks(warm_fit, data)
    effect <- warm_risk$control - warm_risk$treated
    cut <- Hmisc::wtd.quantile(effect, ca_weights, c(.10, .90))
    low <- effect <= cut[1]
    high <- effect >= cut[2]
    stabilized[draw, ] <- vapply(traits, function(trait) {
      weighted.mean(data[[trait]][high], ca_weights[high]) -
        weighted.mean(data[[trait]][low], ca_weights[low])
    }, numeric(1))
    # The score is per total frequency weight, so count/scaled fits are
    # comparable. Evaluate both likelihoods with the same scaled weights.
    count_score <- as.numeric(crossprod(design, ca_weights * (data$outcome - fitted(count_fit)))) / sum(ca_weights)
    warm_score <- as.numeric(crossprod(design, ca_weights * (data$outcome - fitted(warm_fit)))) / sum(ca_weights)
    count_ll <- log_likelihood(count_fit, ca_weights) / sum(ca_weights)
    warm_ll <- log_likelihood(warm_fit, ca_weights) / sum(ca_weights)
    stabilization_rows[[draw]] <- data.frame(
      draw = draw, count_converged = isTRUE(count_fit$converged),
      warm_converged = isTRUE(warm_fit$converged),
      count_full_rank = count_fit$rank == length(coef(count_fit)),
      warm_full_rank = warm_fit$rank == length(coef(warm_fit)),
      finite_coefficients = all(is.finite(c(coef(count_fit), coef(warm_fit)))),
      finite_predictions = all(is.finite(c(as.matrix(count_risk), as.matrix(warm_risk)))),
      finite_ca_traits = all(is.finite(stabilized[draw, ])),
      low_weight = sum(ca_weights[low]), high_weight = sum(ca_weights[high]),
      max_prediction_difference = max(abs(as.matrix(count_risk) - as.matrix(warm_risk))),
      max_coefficient_difference = max(abs(coef(count_fit) - coef(warm_fit))),
      count_max_average_score = max(abs(count_score)), warm_max_average_score = max(abs(warm_score)),
      average_loglik_difference = warm_ll - count_ll,
      warm_max_abs_coefficient = max(abs(coef(warm_fit))),
      warm_min_risk = min(as.matrix(warm_risk)), warm_max_risk = max(as.matrix(warm_risk)),
      warm_near_boundary_risks = sum(as.matrix(warm_risk) < 1e-6 | as.matrix(warm_risk) > 1 - 1e-6)
    )
    if (draw %% 100L == 0L || draw == B) message("Stabilized CA draw ", draw, "/", B)
  }
  audit <- do.call(rbind, stabilization_rows)
  warnings <- if (length(stabilization_warnings)) do.call(rbind, stabilization_warnings) else
    data.frame(draw = integer(), path = character(), message = character(), expected_weight_warning = logical())
  write_result(audit, "bootstrap-stabilized-ca-fit-diagnostics.csv")
  write_result(warnings, "bootstrap-stabilized-ca-warnings.csv")
  saveRDS(list(draws = stabilized, diagnostics = audit, warnings = warnings),
          file.path(output_dir, "bootstrap-stabilized-ca.rds"))
  stopifnot(all(audit$count_converged), all(audit$warm_converged),
            all(audit$count_full_rank), all(audit$warm_full_rank),
            all(audit$finite_coefficients), all(audit$finite_predictions),
            all(audit$finite_ca_traits), all(audit$low_weight > 0), all(audit$high_weight > 0),
            max(audit$max_prediction_difference) < 1e-5,
            max(audit$warm_max_average_score) < 1e-6,
            max(abs(audit$average_loglik_difference)) < 1e-7)
  centered <- sweep(stabilized, 2, reconstructed$direct_ca, "-")
  scale <- apply(centered, 2, IQR) / diff(qnorm(c(.25, .75)))
  stopifnot(all(is.finite(scale)), all(scale > 0))
  maximum <- apply(abs(sweep(centered, 2, scale, "/")), 1, max)
  joint_p <- vapply(abs(reconstructed$direct_ca / scale), function(z) mean(maximum > z), numeric(1))
  native_ca <- readRDS(file.path(output_dir, "native-ca.rds"))
  index <- match(traits, colnames(native_ca$est))
  stopifnot(!anyNA(index), max(abs(reconstructed$direct_ca - as.numeric(native_ca$est)[index])) < 1e-10)
  output <- data.frame(trait = traits, point = as.numeric(reconstructed$direct_ca),
    stabilized_standard_error = scale, stabilized_joint_p = joint_p,
    native_standard_error_invalid = as.numeric(native_ca$bse)[index],
    native_joint_p_invalid = as.numeric(native_ca$joint_p)[index])
  write_result(output, "bootstrap-stabilized-ca-results.csv")
  point_cut <- Hmisc::wtd.quantile(reconstructed$point$interaction$effect, rep(1, n), c(.10, .90))
  point_low <- reconstructed$point$interaction$effect <= point_cut[1]
  point_high <- reconstructed$point$interaction$effect >= point_cut[2]
  classification <- data.frame(colon_characteristics(),
    overall = colMeans(data[, traits]),
    low_mean = as.numeric(colMeans(data[point_low, traits])),
    high_mean = as.numeric(colMeans(data[point_high, traits])),
    difference = as.numeric(reconstructed$direct_ca), standard_error = scale,
    joint_p = joint_p, n_low = sum(point_low), n_high = sum(point_high),
    method = "Post-plan stabilized CA reconstruction; not native inference", row.names = NULL)
  write_result(classification, "classification-stabilized.csv")
  native_bad <- sum(rowSums(is.finite(reconstructed$ca_draws)) == 0L)
  metadata <- list(date = "2026-10-22", analysis = "Post-plan stabilized CA reconstruction; not native inference",
    n = n, B = B, seed = seed,
    change = "Initialize each scaled-weight glm at the converged count-weight fit; retain native 20000-total weights everywhere else",
    reason = "Native default-start scaled-weight glm produced failed fits and nonfinite moments",
    native_ca_nonconverged = sum(!reconstructed$diagnostics$converged[reconstructed$diagnostics$purpose == "ca"]),
    native_ca_all_moments_missing = native_bad, native_zero_contrast_p_ceiling = 1 - native_bad / B,
    stable_ca_nonconverged = sum(!audit$warm_converged), stable_ca_missing = sum(!audit$finite_ca_traits),
    stable_ca_other_warning_count = sum(!warnings$expected_weight_warning),
    max_prediction_difference = max(audit$max_prediction_difference),
    prediction_agreement_tolerance = 1e-5,
    max_average_score = max(audit$warm_max_average_score),
    average_score_tolerance = 1e-6,
    max_abs_average_loglik_difference = max(abs(audit$average_loglik_difference)),
    average_loglik_tolerance = 1e-7,
    no_draws_discarded = TRUE,
    scope = "Numerical repair diagnostic on the same model/resampling target; not independent scientific validation or coverage evidence")
  capture.output(str(metadata), output, sessionInfo(),
                 file = file.path(output_dir, "bootstrap-stabilized-ca-metadata.txt"))
  print(metadata)
  print(output)
  message("Stabilized reconstruction completed; label separately from invalid native CA inference.")
  quit(save = "no", status = 0)
}

native_paths <- file.path(output_dir, c("constant-native-spe.rds",
                                       "interaction-native-spe.rds", "native-ca.rds"))
if (!all(file.exists(native_paths))) {
  stop("Native outputs are not yet available. Reconstruction is saved; rerun with 'compare'.")
}
checks <- list()
compare_values <- function(name, manual, native, tolerance = 1e-8) {
  stopifnot(length(manual) == length(native))
  finite <- all(is.finite(manual)) && all(is.finite(native))
  error <- if (finite) max(abs(as.numeric(manual) - as.numeric(native))) else Inf
  checks[[length(checks) + 1L]] <<- data.frame(
    check = name, max_absolute_error = error, tolerance = tolerance,
    finite = finite, passed = finite && error <= tolerance)
}
denominator <- diff(qnorm(c(.25, .75)))
for (name in names(formulas)) {
  native <- readRDS(file.path(output_dir, paste0(name, "-native-spe.rds")))
  stopifnot(max(abs(native$us - grid)) < 1e-12, native$alpha == alpha)
  point <- reconstructed$point[[name]]
  centered <- sweep(reconstructed$spe_draws[[name]], 2, point$spe, "-")
  scale <- apply(centered, 2, IQR) / denominator
  maximum <- apply(abs(sweep(centered, 2, scale, "/")), 1, max)
  critical <- as.numeric(quantile(maximum, 1 - alpha))
  lower <- sort(point$spe - critical * scale)
  upper <- sort(point$spe + critical * scale)
  compare_values(paste0(name, "_spe_point"), point$spe, native$spe[[1]])
  compare_values(paste0(name, "_spe_scale"), scale, native$spe[[4]])
  compare_values(paste0(name, "_spe_band"), c(lower, upper),
                 c(native$spe[[3]], native$spe[[2]]))

  ape_scale <- IQR(reconstructed$ape_draws[[name]]) / denominator
  ape_critical <- as.numeric(quantile(abs(reconstructed$ape_draws[[name]] -
                                        point$ape) / ape_scale, 1 - alpha))
  compare_values(paste0(name, "_ape_point"), point$ape, native$ape[[1]])
  compare_values(paste0(name, "_ape_scale"), ape_scale, native$ape[[4]])
  compare_values(paste0(name, "_ape_interval"),
                 c(point$ape - ape_critical * ape_scale, point$ape + ape_critical * ape_scale),
                 c(native$ape[[3]], native$ape[[2]]))
}

native_ca <- readRDS(file.path(output_dir, "native-ca.rds"))
index <- match(traits, colnames(native_ca$est))
stopifnot(!anyNA(index), length(index) == 12L)
centered <- sweep(reconstructed$ca_draws, 2, reconstructed$direct_ca, "-")
scale <- apply(centered, 2, IQR, na.rm = TRUE) / denominator
if (any(!is.finite(scale) | scale <= 0)) {
  write_result(data.frame(trait = traits, standard_error = scale), "bootstrap-ca-scales.csv")
  stop("The prespecified CA family has a nonpositive/nonfinite native-style scale; see bootstrap-ca-scales.csv.")
}
standardized <- abs(sweep(centered, 2, scale, "/"))
# Reproduce the native all-NA -> -Inf behavior explicitly, without endorsing
# it. These missing draws remain in the p-value denominator and invalidate the
# resulting inference. The fit/missing-draw audit exposes that failure.
maximum <- apply(standardized, 1, function(x) {
  if (all(is.na(x))) -Inf else max(x, na.rm = TRUE)
})
joint_p <- vapply(abs(reconstructed$direct_ca / scale), function(z) mean(maximum > z), numeric(1))
compare_values("ca_point", reconstructed$direct_ca, as.numeric(native_ca$est)[index])
compare_values("ca_scale", scale, as.numeric(native_ca$bse)[index])
compare_values("ca_joint_p", joint_p, as.numeric(native_ca$joint_p)[index])
write_result(data.frame(trait = traits, point = as.numeric(reconstructed$direct_ca),
                       standard_error = scale, joint_p = joint_p), "bootstrap-ca-scales.csv")
checks <- do.call(rbind, checks)
write_result(checks, "bootstrap-checks.csv")
critical_fit_failure <- with(reconstructed$diagnostics,
                             !converged | !full_rank | !finite_coefficients | !finite_risks)
metadata <- list(date = "2026-10-22", package = "SortedEffects 1.7.0", n = n,
  B = B, seed = seed, alpha = alpha, grid = grid,
  reconstruction = "Independent glm fits and weighted quantiles; no native bootstrap/bundle/ape/ca helper calls",
  random_counts = "Same fixed-seed multinomial counts for both SPE models and CA, as in separate native calls",
  spe_scope = "Model resampled with normalized counts; original profiles and quantile weights fixed",
  ca_scope = "Model, quantile thresholds and tail means use 20000-total bootstrap frequency weights",
  expected_warning = "Non-integer #successes can arise from normalized frequency weights; logged separately",
  near_boundary_threshold = 1e-6,
  near_boundary_scope = "Any counterfactual prediction on the original reference profiles, not only fitted observations",
  critical_fit_failures = sum(critical_fit_failure),
  native_ca_nonconverged = sum(!reconstructed$diagnostics$converged[reconstructed$diagnostics$purpose == "ca"]),
  native_ca_all_moments_missing = sum(rowSums(is.finite(reconstructed$ca_draws)) == 0L),
  native_ca_empty_tail_draws = sum(with(reconstructed$ca_tail_diagnostics, low_n == 0 | high_n == 0)),
  native_ca_inference_valid = !any(critical_fit_failure) && all(is.finite(reconstructed$ca_draws)),
  other_warning_count = sum(reconstructed$diagnostics$other_warnings),
  checks_passed = all(checks$passed),
  no_draws_discarded = TRUE,
  interpretation = "Numerical agreement does not establish interval coverage or model validity; review fit warnings and sensitivity")
capture.output(str(metadata), reconstructed$summary, checks, sessionInfo(),
               file = file.path(output_dir, "bootstrap-metadata.txt"))
print(checks)
if (!all(checks$passed)) stop("Native-bootstrap reconstruction comparison failed; see bootstrap-checks.csv.")
if (any(critical_fit_failure)) {
  warning("Outputs numerically matched, but native CA has failed fits/nonfinite draws; its inference is invalid. See bootstrap-fit-diagnostics.csv.")
}
if (sum(reconstructed$diagnostics$other_warnings) > 0) {
  warning("Outputs matched, with numerical warnings recorded in bootstrap-warnings.csv; interpret the audit explicitly.")
}
message("Colon native numerical comparisons completed; review the explicit inference-validity audit. All draws retained.")
