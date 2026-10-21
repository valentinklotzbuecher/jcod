# Numerical checks for the scientific claims made by the teaching example.
# Run after Rscript R/demo.R from the project root.
source("R/demo.R")
stopifnot(file.exists("results/demo.rds"))
demo <- readRDS("results/demo.rds")
tables <- demo_tables(demo)
stopifnot(identical(names(demo$reference), c("age", "age_z", "female")))
stopifnot(all(demo$reference$age >= 40 & demo$reference$age <= 80))
stopifnot(all(demo$reference$female %in% 0:1))
stopifnot(max(abs(demo$reference$age_z - (demo$reference$age - 60) / 10)) < 1e-12)
stopifnot(identical(levels(demo$scenarios$interaction$data$group),
                    c("control", "treated")))

# A known constant-OR identity tests the scale/sign calculation independently.
p0 <- c(0.1, 0.4)
p1 <- 0.60 * p0 / (1 - p0 + 0.60 * p0)
stopifnot(max(abs((p0 - p1) - c(0.0375, 0.1142857142857143))) < 1e-12)
stopifnot(all(tables$patient_profiles$absolute_benefit > 0))

# Each dumbbell endpoint must equal the estimated tail summary in its own units.
dumbbells <- tables$classification_dumbbells
stopifnot(nrow(dumbbells) == 6L,
          all(dumbbells$n == floor(nrow(demo$reference) / 10)))
stopifnot(nrow(demo$reference) == nrow(demo$scenarios$interaction$data))
stopifnot(identical(demo$reference, demo$scenarios$interaction$data[names(demo$reference)]))
for (group in c("smallest", "largest")) {
  source_row <- tables$classification[
    tables$classification$scenario == "interaction" & tables$classification$group == group,
    , drop = FALSE
  ]
  expected <- c(source_row$mean_age, 100 * source_row$proportion_female,
                100 * source_row$mean_baseline_risk)
  plotted <- dumbbells$value[dumbbells$group == group]
  stopifnot(max(abs(plotted - expected)) < 1e-12)
}

# The two true distributions share the intended average but differ in shape.
means <- vapply(demo$scenarios, function(s) mean(s$truth), numeric(1))
stopifnot(abs(diff(means)) < 1e-9)
true_spreads <- vapply(demo$scenarios, function(s) {
  diff(demo_quantiles(s$truth, c(0.1, 0.9)))
}, numeric(1))
stopifnot(true_spreads["interaction"] > 2 * true_spreads["constant"])

for (name in names(demo$scenarios)) {
  s <- demo$scenarios[[name]]
  b <- s$bootstrap
  target <- demo_quantiles(s$contrast$benefit, demo$probs)
  stopifnot(all(diff(target) >= 0), all(diff(demo_quantiles(s$truth, demo$probs)) >= 0))
  stopifnot(all(is.finite(s$contrast$benefit)), all(abs(s$contrast$benefit) <= 1))
  stopifnot(max(abs(s$contrast$benefit - (s$contrast$p0 - s$contrast$p1))) < 1e-14)
  stopifnot(b$successful_draws == demo$metadata$B)
  stopifnot(identical(dim(b$quantiles), c(demo$metadata$B, length(demo$probs))))
  stopifnot(all(apply(b$quantiles, 2, stats::sd) > 0))
  stopifnot(all(apply(b$quantiles, 1, function(x) all(diff(x) >= 0))))
  stopifnot(all(b$simultaneous_lower < target), all(b$simultaneous_upper > target))
  stopifnot(all(b$membership >= 0 & b$membership <= 1))
  stopifnot(all(abs(colSums(b$membership) - floor(nrow(demo$reference) / 10)) < 1e-8))
  stopifnot(length(intersect(s$groups$smallest, s$groups$largest)) == 0L)
  # Compare predicted coefficients and population contrasts with known DGP values.
  treatment_truth <- if (name == "constant") log(0.60) else demo$interaction_intercept
  stopifnot(abs(stats::coef(s$fit)["grouptreated"] - treatment_truth) < 0.3)
  stopifnot(abs(mean(s$contrast$benefit) - mean(s$truth)) < 0.035)
}

# Recompute a small deterministic subset twice to check seed-controlled resampling.
s <- demo$scenarios$constant
set.seed(421)
first <- bootstrap_scenario(s$data, stats::formula(s$fit), demo$reference,
                            s$contrast$benefit, demo$probs, B = 12L)
set.seed(421)
second <- bootstrap_scenario(s$data, stats::formula(s$fit), demo$reference,
                             s$contrast$benefit, demo$probs, B = 12L)
stopifnot(identical(first$quantiles, second$quantiles))

expected_figures <- c("demographic-effects", "baseline-risk", "sorted-effects-teaching", "uncertainty-teaching", "classification-teaching",
                      "membership-stability", "sorted-effects-comparison",
                      "uncertainty-comparison", "classification-comparison",
                      "membership-stability-comparison")
if (file.exists("results/clinical-spe.csv")) {
  expected_figures <- c(expected_figures, "sorted-effects", "uncertainty",
                        "classification", "classification-inference")
}
for (name in expected_figures) {
  for (extension in c("png", "pdf")) {
    path <- file.path("results", "figures", paste0(name, ".", extension))
    stopifnot(file.exists(path), file.info(path)$size > 1000)
  }
}

cat("Validated: exact risk contrast, matched true averages, different true distributions,\n",
    "refit-and-sort bootstrap, finite bands, tail membership, seeded reproducibility,\n",
    "generic demographic dumbbell endpoints, and ", 2L * length(expected_figures), " figure artifacts.\n", sep = "")
cat("Scope: numerical validation of a teaching simulation; no coverage study or formal\n",
    "validation of original SortedEffects classification inference is claimed.\n", sep = "")
