#!/usr/bin/env Rscript
# Original SortedEffects inference for the ONE fictional clinical example.
# Run after Rscript R/demo.R, from the repository root.
options(warn = 1)
stopifnot(requireNamespace("SortedEffects", quietly = TRUE))
stopifnot(as.character(utils::packageVersion("SortedEffects")) == "1.7.0")
stopifnot(requireNamespace("Hmisc", quietly = TRUE))
source("R/clinical-walkthrough.R")

demo <- readRDS("results/demo.rds")
walkthrough <- clinical_walkthrough(demo)
trial <- walkthrough$trial
fm <- walkthrough$formula
benefit <- walkthrough$benefit
n <- nrow(trial)
stopifnot(n == 5000L)
# The demo and original package now use the same empirical trial profiles.
stopifnot(nrow(demo$reference) == n)
stopifnot(isTRUE(all.equal(
  demo$reference[, c("age", "age_z", "severity", "female")],
  trial[, c("age", "age_z", "severity", "female")], check.attributes = FALSE
)))
stopifnot(max(abs(benefit - demo$scenarios$interaction$contrast$benefit)) < 1e-10)

B <- as.integer(Sys.getenv("CLINICAL_BOOTSTRAPS", "499"))
stopifnot(B >= 99L)
seed <- 420L
alpha <- 0.05
us <- seq(0.10, 0.90, by = 0.01)
traits <- c("age", "severity", "female")
compare <- c("intensified", "usual")

# peestimate() returns prediction(compare[2]) - prediction(compare[1]).
# This supported categorical contrast therefore makes positive values beneficial:
# Pr(readmission | usual, X) - Pr(readmission | intensified, X).
message("Original-package clinical SPE inference (", B, " bootstrap draws).")
spe <- SortedEffects::spe(
  fm = fm, data = trial, method = "logit",
  var_type = "categorical", var = "strategy", compare = compare,
  us = us, alpha = alpha, b = B, seed = seed, bc = FALSE
)

message("Original-package clinical classification inference.")
ca <- SortedEffects::ca(
  fm = fm, data = trial, method = "logit",
  var_type = "categorical", var = "strategy", compare = compare,
  u = 0.10, interest = "moment", cl = "diff", t = traits,
  alpha = alpha, b = B, seed = seed, bc = FALSE
)

# Check sign, quantile convention, APE and classification endpoints independently.
weights <- rep(1, n)
direct_spe <- as.numeric(Hmisc::wtd.quantile(benefit, weights, us))
spe_point_error <- max(abs(direct_spe - spe$spe[[1]]))
ape_error <- abs(mean(benefit) - spe$ape[[1]])
thresholds <- Hmisc::wtd.quantile(benefit, weights, c(0.10, 0.90))
least <- benefit <= thresholds[1]
most <- benefit >= thresholds[2]
least_mean <- colMeans(trial[least, traits, drop = FALSE])
most_mean <- colMeans(trial[most, traits, drop = FALSE])
direct_ca <- most_mean - least_mean
ca_point_error <- max(abs(direct_ca - as.numeric(ca$est)))
stopifnot(max(abs(as.numeric(walkthrough$spe_curve) - direct_spe)) < 1e-12)
stopifnot(abs(walkthrough$mean_benefit - spe$ape[[1]]) < 1e-10)
stopifnot(identical(walkthrough$groups$low, least))
stopifnot(identical(walkthrough$groups$high, most))
stopifnot(max(abs(walkthrough$tail_means$low - least_mean)) < 1e-12)
stopifnot(max(abs(walkthrough$tail_means$high - most_mean)) < 1e-12)
stopifnot(spe_point_error < 1e-10, ape_error < 1e-10, ca_point_error < 1e-10)
stopifnot(all(is.finite(unlist(spe))))
stopifnot(all(is.finite(unlist(ca[c("est", "bse", "joint_p", "pointwise_p")]))))
stopifnot(all(spe$spe[[4]] > 0), all(ca$bse > 0))

# Independent reconstruction of BOTH original-package bootstrap routines.
# SPE: resampled training counts, fixed original quantile weights.
# CA: resampled training counts, resampled quantile weights AND tail means.
# This distinction is important; CA is not the same fixed-X conditional target.
message("Independently checking the clinical bootstrap outputs.")
set.seed(seed)
bootstrap_spe <- matrix(NA_real_, nrow = B, ncol = length(us))
bootstrap_ca <- matrix(NA_real_, nrow = B, ncol = length(traits))
colnames(bootstrap_ca) <- traits
bootstrap_ape <- numeric(B)
for (b in seq_len(B)) {
  counts <- tabulate(sample.int(n, n, replace = TRUE), nbins = n)
  boot_data <- trial
  boot_data$.counts <- counts
  fit <- glm(fm, data = boot_data, family = binomial(), weights = .counts)
  stopifnot(fit$converged, all(is.finite(coef(fit))))
  p0 <- predict(fit, transform(trial, strategy = "usual"), type = "response")
  p1 <- predict(fit, transform(trial, strategy = "intensified"), type = "response")
  effect <- as.numeric(p0 - p1)
  stopifnot(all(is.finite(effect)))
  bootstrap_spe[b, ] <- Hmisc::wtd.quantile(effect, weights, us)
  bootstrap_ape[b] <- mean(effect)

  # Reproduce ca()'s exact 20,000-total frequency-weight convention. A common
  # scaling cancels from weighted means but can affect empirical-quantile
  # interpolation, so it must also be retained in the threshold calculation.
  boot_data$.ca_weights <- (counts / sum(counts)) * weights * 20000
  fit_ca <- glm(fm, data = boot_data, family = binomial(), weights = .ca_weights)
  stopifnot(fit_ca$converged, all(is.finite(coef(fit_ca))))
  effect_ca <- as.numeric(
    predict(fit_ca, transform(trial, strategy = "usual"), type = "response") -
      predict(fit_ca, transform(trial, strategy = "intensified"), type = "response")
  )
  cut <- Hmisc::wtd.quantile(effect_ca, boot_data$.ca_weights, c(0.10, 0.90))
  lo <- effect_ca <= cut[1]
  hi <- effect_ca >= cut[2]
  bootstrap_ca[b, ] <- vapply(traits, function(trait) {
    weighted.mean(trial[[trait]][hi], boot_data$.ca_weights[hi]) -
      weighted.mean(trial[[trait]][lo], boot_data$.ca_weights[lo])
  }, numeric(1))
}

centered_spe <- sweep(bootstrap_spe, 2, direct_spe, "-")
spe_scale <- apply(centered_spe, 2, IQR) / diff(qnorm(c(0.25, 0.75)))
spe_max <- apply(abs(sweep(centered_spe, 2, spe_scale, "/")), 1, max)
spe_critical <- as.numeric(quantile(spe_max, 1 - alpha))
manual_lower <- sort(direct_spe - spe_critical * spe_scale)
manual_upper <- sort(direct_spe + spe_critical * spe_scale)
spe_band_error <- max(abs(c(
  spe_scale - spe$spe[[4]], manual_lower - spe$spe[[3]],
  manual_upper - spe$spe[[2]]
)))

centered_ca <- sweep(bootstrap_ca, 2, direct_ca, "-")
ca_scale <- apply(centered_ca, 2, IQR) / diff(qnorm(c(0.25, 0.75)))
ca_max <- apply(abs(sweep(centered_ca, 2, ca_scale, "/")), 1, max)
manual_joint_p <- vapply(abs(direct_ca / ca_scale),
                        function(z) mean(ca_max > z), numeric(1))
ca_scale_error <- max(abs(ca_scale - as.numeric(ca$bse)))
ca_joint_p_error <- max(abs(manual_joint_p - as.numeric(ca$joint_p)))
stopifnot(spe_band_error < 1e-8, ca_scale_error < 1e-8, ca_joint_p_error < 1e-8)

dir.create("results", showWarnings = FALSE)
utils::write.csv(data.frame(
  percentile = us, estimate = as.numeric(spe$spe[[1]]),
  lower_uniform = as.numeric(spe$spe[[3]]),
  upper_uniform = as.numeric(spe$spe[[2]]),
  standard_error = as.numeric(spe$spe[[4]])
), "results/clinical-spe.csv", row.names = FALSE)
utils::write.csv(data.frame(
  estimate = as.numeric(spe$ape[[1]]), lower = as.numeric(spe$ape[[3]]),
  upper = as.numeric(spe$ape[[2]]), standard_error = as.numeric(spe$ape[[4]])
), "results/clinical-ape.csv", row.names = FALSE)
utils::write.csv(data.frame(
  characteristic = traits, least_mean = as.numeric(least_mean),
  most_mean = as.numeric(most_mean), difference = as.numeric(ca$est),
  standard_error = as.numeric(ca$bse), joint_p = as.numeric(ca$joint_p),
  unit = c("years", "SD", "proportion"),
  bootstrap_draws = B,
  # Preserve the native field for audit, not as a conventional two-sided p-value.
  package_pointwise_p = as.numeric(ca$pointwise_p),
  normal_two_sided_p = 2 * pnorm(-abs(as.numeric(ca$est) / as.numeric(ca$bse)))
), "results/clinical-inference.csv", row.names = FALSE)
utils::write.csv(walkthrough$profiles,
                 "results/clinical-profiles.csv", row.names = FALSE)

metadata <- list(
  package = "SortedEffects", package_version = "1.7.0",
  source_commit = "18a1196e474ee1b62d6722754e8e377cba4ddc1f",
  bootstrap_draws = B, seed = seed, alpha = alpha, bias_correction = FALSE,
  trial_n = n, reference_n = n,
  contrast = "Predicted readmission risk: usual minus intensified",
  comparison_order = compare, tail_fraction = 0.10,
  least_group_n = sum(least), most_group_n = sum(most),
  spe_scope = "SPE training bootstrap, fixed original trial covariates/quantile weights",
  ca_scope = "CA refits with resampled weights and reweights effect thresholds/tail means",
  ca_family = "Most-minus-least mean differences across age, congestion score and female proportion",
  ca_moment_ci = "Not returned by package; no native moment confidence intervals are claimed",
  native_pointwise_p = "Native ca() field is 1-Phi(abs(z)); not conventional two-sided p; main display uses joint_p only",
  joint_p_resolution = paste0("Multiples of 1/", B, "; zero means 0/", B,
    " bootstrap maxima exceeded the observed statistic, not a bound on the true p-value or an exactly zero population probability"),
  spe_point_error = spe_point_error, ape_error = ape_error,
  ca_point_error = ca_point_error, spe_band_error = spe_band_error,
  ca_scale_error = ca_scale_error, ca_joint_p_error = ca_joint_p_error,
  independent_bootstrap_converged = B
)
utils::capture.output(str(metadata), utils::sessionInfo(),
                      file = "results/clinical-inference-metadata.txt")
saveRDS(list(spe = spe, ca = ca, metadata = metadata,
             profiles = walkthrough$profiles, least = least, most = most,
             bootstrap_spe = bootstrap_spe, bootstrap_ca = bootstrap_ca),
        "results/clinical-inference.rds")

# Plot functions are owned by the scientific figure implementation in R/demo.R.
source("R/demo.R")
if (!exists("write_clinical_inference_figures", mode = "function")) {
  stop("R/demo.R must provide write_clinical_inference_figures(). CSV results were saved.")
}
write_clinical_inference_figures()
message("Clinical SPE/CA inference and independent checks passed. See results/clinical-inference-metadata.txt.")
