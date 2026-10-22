# Working models for the prespecified exploratory IST pilot.
# See docs/ist-analysis-plan.md for target, interpretation and validation split.

ist_formulas <- function(data = NULL) {
  constant <- outcome ~ aspirin + splines::ns(age, df = 3) + female +
    age_z:female + splines::ns(sbp, df = 3) + splines::ns(delay, df = 3) +
    consciousness + af + prior_aspirin_yes + arm_deficit + leg_deficit +
    dysphasia + stroke_type
  # AF and prior-aspirin unknowns identify exactly the same pilot participants.
  # The af factor supplies their shared unknown indicator; prior_aspirin_yes
  # supplies the remaining prior-aspirin contrast without an aliased column.
  # Explicit treatment products avoid duplicate factor-level columns when a
  # linear main effect is already spanned by splines or categorical indicators.
  # They are recomputed by predict() when the package toggles aspirin allocation.
  interaction <- update(constant, . ~ . +
    I((aspirin == "aspirin") * age_z) +
    I((aspirin == "aspirin") * female) +
    I((aspirin == "aspirin") * age_z * female) +
    I((aspirin == "aspirin") * sbp_z) +
    I((aspirin == "aspirin") * delay_z) +
    I((aspirin == "aspirin") * not_alert) +
    I((aspirin == "aspirin") * af_yes) +
    I((aspirin == "aspirin") * leg_yes))
  # Preserve the namespace-qualified spline function without capturing callers.
  environment(constant) <- environment(interaction) <- baseenv()
  list(constant = constant, interaction = interaction)
}

contrast_ist <- function(fit, data) {
  control <- treated <- data
  control$aspirin <- "no_aspirin"
  treated$aspirin <- "aspirin"
  as.numeric(predict(fit, control, type = "response") -
               predict(fit, treated, type = "response"))
}

ist_characteristics <- function() {
  data.frame(
    variable = c("age", "female", "sbp", "delay", "af_yes", "af_unknown",
                 "prior_aspirin_yes", "not_alert", "leg_yes", "dysphasia_yes",
                 "old_men", "younger_women"),
    label = c("Age (years)", "Female (%)", "Systolic BP (mmHg)",
              "Delay to randomization (hours)", "Atrial fibrillation recorded (%)",
              "Atrial fibrillation unknown (%)", "Prior aspirin recorded (%)",
              "Drowsy or unconscious (%)", "Leg deficit recorded (%)",
              "Dysphasia recorded (%)", "Men aged 75 or older (%)",
              "Women younger than 65 (%)"),
    multiplier = c(1, 100, 1, 1, rep(100, 8)),
    stringsAsFactors = FALSE
  )
}

ist_check_fit <- function(fit) {
  stopifnot(isTRUE(fit$converged), all(is.finite(coef(fit))),
            fit$rank == length(coef(fit)))
  invisible(fit)
}

ist_heparin_standardized_contrast <- function(fit, data) {
  weights <- prop.table(table(data$heparin))
  predictions <- vapply(names(weights), function(level) {
    profiles <- data
    profiles$heparin <- factor(level, levels = levels(data$heparin))
    contrast_ist(fit, profiles)
  }, numeric(nrow(data)))
  as.numeric(predictions %*% as.numeric(weights))
}
