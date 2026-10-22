#!/usr/bin/env Rscript
# Run against the patched package. Optional arguments: JCOD root, output CSV.
# Reconstruct every draw independently; do not modify the saved trial analysis.
library(SortedEffects)
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[1] else ".", mustWork = TRUE)
output <- if (length(args) >= 2L) args[2] else ""
source(file.path(root, "R", "colon-data.R"))
source(file.path(root, "R", "colon-analysis.R"))
d <- prepare_colon_data(file.path(root, "data", "colon", "cancer.rda"))$data
fm <- colon_formulas()$interaction
traits <- colon_characteristics()$variable
n <- nrow(d)
B <- 499L
seed <- 420L
stopifnot(n == 593L)

moments <- function(weights) {
  # Only fitting weights are normalized; empirical quantiles and tail means
  # retain the exact 20,000-total CA weights, including floating arithmetic.
  fit <- suppressWarnings(do.call(glm, list(formula = fm, data = d,
    weights = weights / mean(weights), family = binomial())))
  stopifnot(isTRUE(fit$converged), fit$rank == length(coef(fit)),
            all(is.finite(coef(fit))))
  risks <- colon_risks(fit, d)
  effects <- risks$control - risks$treated
  cut <- Hmisc::wtd.quantile(effects, weights, c(.1, .9))
  low <- effects <= cut[1]
  high <- effects >= cut[2]
  stopifnot(all(is.finite(as.matrix(risks))),
            sum(weights[low]) > 0, sum(weights[high]) > 0)
  out <- vapply(traits, function(trait) {
    weighted.mean(d[[trait]][high], weights[high]) -
      weighted.mean(d[[trait]][low], weights[low])
  }, numeric(1))
  stopifnot(all(is.finite(out)))
  out
}

point <- moments(rep(1, n))
set.seed(seed)
draws <- t(replicate(B, {
  counts <- tabulate(sample.int(n, n, replace = TRUE), nbins = n)
  moments(counts / sum(counts) * 20000)
}))
centered <- sweep(draws, 2, point, "-")
standard_error <- apply(centered, 2, IQR) / diff(qnorm(c(.25, .75)))
stopifnot(all(is.finite(standard_error)), all(standard_error > 0))
maximum <- apply(abs(sweep(centered, 2, standard_error, "/")), 1, max)
joint_p <- vapply(abs(point / standard_error), function(z) mean(maximum > z), numeric(1))

result <- ca(fm, d, method = "logit", var_type = "categorical",
             var = "treatment", compare = c("chemotherapy", "observation"),
             interest = "moment", cl = "diff", t = traits, u = .1,
             b = B, alpha = .05, bc = FALSE, seed = seed)
index <- match(traits, colnames(result$est))
stopifnot(!anyNA(index))
comparison <- data.frame(trait = traits,
  point = as.numeric(result$est)[index], reference_point = point,
  standard_error = as.numeric(result$bse)[index],
  reference_standard_error = standard_error,
  joint_p = as.numeric(result$joint_p)[index], reference_joint_p = joint_p,
  row.names = NULL)
errors <- c(point = max(abs(comparison$point - comparison$reference_point)),
  standard_error = max(abs(comparison$standard_error - comparison$reference_standard_error)),
  joint_p = max(abs(comparison$joint_p - comparison$reference_joint_p)))
print(errors)
stopifnot(all(is.finite(as.matrix(comparison[, -1]))), max(errors) < 1e-10,
          comparison$joint_p[comparison$trait == "perfor"] == 1)
if (nzchar(output)) write.csv(comparison, output, row.names = FALSE)
cat("All 499 draws retained; patched CA matches the independent reconstruction.\n")
