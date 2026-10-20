# Short, executable building blocks for the fictional heart-failure trial.
# outcome: unplanned readmission by 90 days (0/1).
# severity: standardized baseline congestion score, generated for teaching.
# No claim about a real treatment, risk model, or patient population is intended.

prepare_clinical_trial <- function(demo) {
  trial <- demo$scenarios$interaction$data
  trial$strategy <- factor(
    ifelse(trial$treatment == 1, "intensified", "usual"),
    levels = c("usual", "intensified")
  )
  trial
}

clinical_walkthrough <- function(demo) {
  trial <- prepare_clinical_trial(demo)
  fm <- outcome ~ strategy * severity + age_z + female
  environment(fm) <- baseenv()

  # 1. Fit the outcome model, including the prespecified congestion interaction.
  fit <- glm(fm, family = binomial(), data = trial)
  stopifnot(fit$converged, all(is.finite(coef(fit))))

  # 2. Predict both strategies for the same baseline patient profiles.
  usual <- transform(trial, strategy = "usual")
  intensified <- transform(trial, strategy = "intensified")
  p_usual <- predict(fit, newdata = usual, type = "response")
  p_intensified <- predict(fit, newdata = intensified, type = "response")
  benefit <- as.numeric(p_usual - p_intensified)

  # 3. Summarize the same contrasts with the package's weighted convention.
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
    colMeans(trial[i, c("age", "severity", "female")])
  })

  # Two hypothetical profiles from this same fitted clinical model.
  profiles <- data.frame(
    profile = c("Lower congestion", "Higher congestion"),
    age = 60, age_z = 0, severity = c(-1, 1), female = 0
  )
  profiles$risk_usual <- as.numeric(predict(
    fit, newdata = transform(profiles, strategy = "usual"), type = "response"
  ))
  profiles$risk_intensified <- as.numeric(predict(
    fit, newdata = transform(profiles, strategy = "intensified"), type = "response"
  ))
  profiles$benefit <- profiles$risk_usual - profiles$risk_intensified
  profiles$odds_ratio <- with(profiles,
    (risk_intensified / (1 - risk_intensified)) /
      (risk_usual / (1 - risk_usual)))

  list(trial = trial, formula = fm, fit = fit, benefit = benefit,
       p_usual = as.numeric(p_usual), p_intensified = as.numeric(p_intensified),
       percentile = u, spe_curve = spe_curve, mean_benefit = mean(benefit),
       groups = groups, tail_means = tail_means,
       profiles = profiles)
}
