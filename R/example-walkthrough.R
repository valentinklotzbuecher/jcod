# Executable calculations for the simulated treated/control example.
# outcome is a binary undesirable event; sex is 0 = male, 1 = female.
# All relationships are simulation assumptions, not demographic findings.

prepare_example_data <- function(demo) {
  data <- demo$scenarios$interaction$data
  data$group <- factor(
    ifelse(data$treatment == 1, "treated", "control"),
    levels = c("control", "treated")
  )
  data
}

example_walkthrough <- function(demo) {
  data <- prepare_example_data(demo)
  fm <- outcome ~ group * age_z * sex
  environment(fm) <- baseenv()

  # 1. Fit the same age-by-sex model used to generate the main figures.
  fit <- glm(fm, family = binomial(), data = data)
  stopifnot(fit$converged, all(is.finite(coef(fit))))

  # 2. Predict control and treatment for the same covariate profiles.
  control <- transform(data, group = "control")
  treated <- transform(data, group = "treated")
  p_control <- predict(fit, newdata = control, type = "response")
  p_treated <- predict(fit, newdata = treated, type = "response")
  benefit <- as.numeric(p_control - p_treated)

  # 3. Summarize the same contrasts with the package's weighted convention.
  u <- seq(.10, .90, by = .01)
  spe_curve <- Hmisc::wtd.quantile(
    benefit, weights = rep(1, nrow(data)), probs = u
  )

  # 4. Describe the lower and upper tails using the same cutoff convention.
  cutoff <- Hmisc::wtd.quantile(
    benefit, rep(1, nrow(data)), c(.10, .90)
  )
  groups <- list(low = benefit <= cutoff[1], high = benefit >= cutoff[2])
  tail_means <- lapply(groups, function(i) {
    colMeans(data[i, c("age", "sex")])
  })

  # Two age profiles from this same fitted model, both with sex = 0.
  profiles <- data.frame(
    profile = c("Age 50", "Age 70"),
    age = c(50, 70), age_z = c(-1, 1), sex = 0
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

  list(data = data, formula = fm, fit = fit, benefit = benefit,
       p_control = as.numeric(p_control), p_treated = as.numeric(p_treated),
       percentile = u, spe_curve = spe_curve, mean_benefit = mean(benefit),
       groups = groups, tail_means = tail_means,
       profiles = profiles)
}
