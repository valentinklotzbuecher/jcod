# Executable steps for the simulated treated/control comparison.
# outcome: an adverse binary event (0/1).
# age_z: age centered at 60 and divided by 10; female: simulated 0/1 indicator.
# The model and coefficients are illustrative teaching assumptions.

prepare_clinical_trial <- function(demo) {
  trial <- demo$scenarios$interaction$data
  trial$group <- factor(
    ifelse(trial$treatment == 1, "treated", "control"),
    levels = c("control", "treated")
  )
  trial
}

clinical_walkthrough <- function(demo) {
  trial <- prepare_clinical_trial(demo)
  fm <- outcome ~ group * age_z * female
  environment(fm) <- baseenv()

  # 1. Fit the model, including the specified age-by-sex treatment interactions.
  fit <- glm(fm, family = binomial(), data = trial)
  stopifnot(fit$converged, all(is.finite(coef(fit))))

  # 2. Predict control and treated risks for the same covariate profiles.
  control <- transform(trial, group = "control")
  treated <- transform(trial, group = "treated")
  p_control <- predict(fit, newdata = control, type = "response")
  p_treated <- predict(fit, newdata = treated, type = "response")
  benefit <- as.numeric(p_control - p_treated)

  # 3. Summarize those contrasts with the package's weighted-quantile convention.
  u <- seq(.10, .90, by = .01)
  spe_curve <- Hmisc::wtd.quantile(
    benefit, weights = rep(1, nrow(trial)), probs = u
  )

  # 4. Describe the lower and upper tails using the same cutoff convention.
  cutoff <- Hmisc::wtd.quantile(
    benefit, rep(1, nrow(trial)), c(.10, .90)
  )
  groups <- list(low = benefit <= cutoff[1], high = benefit >= cutoff[2])
  tail_means <- lapply(groups, function(i) {
    colMeans(trial[i, c("age", "female")])
  })

  # Two illustrative profiles differ in age and have the same sex indicator.
  profiles <- data.frame(
    profile = c("Age 45", "Age 75"),
    age = c(45, 75), age_z = c(-1.5, 1.5), female = 0
  )
  profiles$risk_control <- as.numeric(predict(
    fit, newdata = transform(profiles, group = "control"), type = "response"
  ))
  profiles$risk_treated <- as.numeric(predict(
    fit, newdata = transform(profiles, group = "treated"), type = "response"
  ))
  profiles$benefit <- profiles$risk_control - profiles$risk_treated
  profiles$odds_ratio <- with(profiles,
    (risk_treated / (1 - risk_treated)) /
      (risk_control / (1 - risk_control)))

  list(trial = trial, formula = fm, fit = fit, benefit = benefit,
       p_control = as.numeric(p_control), p_treated = as.numeric(p_treated),
       percentile = u, spe_curve = spe_curve, mean_benefit = mean(benefit),
       groups = groups, tail_means = tail_means,
       profiles = profiles)
}
