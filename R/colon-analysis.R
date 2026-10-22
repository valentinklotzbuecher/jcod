# Working models fixed in docs/colon-analysis-plan.md before fitting.

colon_formulas <- function() {
  constant <- outcome ~ treatment + splines::ns(age, df = 3) + female +
    age_z:female + log_nodes + poor_diff + extensive + obstruct + adhere + surg_late
  interaction <- update(constant, . ~ . +
    I((treatment == "chemotherapy") * age_z) +
    I((treatment == "chemotherapy") * female) +
    I((treatment == "chemotherapy") * age_z * female) +
    I((treatment == "chemotherapy") * log_nodes) +
    I((treatment == "chemotherapy") * poor_diff) +
    I((treatment == "chemotherapy") * extensive))
  environment(constant) <- environment(interaction) <- baseenv()
  list(constant = constant, interaction = interaction)
}

colon_risks <- function(fit, data) {
  control <- treated <- data
  control$treatment <- "observation"
  treated$treatment <- "chemotherapy"
  data.frame(control = as.numeric(predict(fit, control, type = "response")),
             treated = as.numeric(predict(fit, treated, type = "response")))
}

contrast_colon <- function(fit, data) {
  risk <- colon_risks(fit, data)
  risk$control - risk$treated
}

colon_check_fit <- function(fit) {
  stopifnot(isTRUE(fit$converged), all(is.finite(coef(fit))),
            fit$rank == length(coef(fit)))
  invisible(fit)
}

colon_characteristics <- function() {
  data.frame(
    variable = c("age", "female", "nodes", "poor_diff", "extensive", "obstruct",
                 "perfor", "adhere", "surg_late", "old_men", "younger_women",
                 "nodes_over4"),
    label = c("Age (years)", "Female (%)", "Positive nodes (count)",
              "Poor differentiation (%)", "Extent: serosa or beyond (%)",
              "Bowel obstruction (%)", "Perforation (%)", "Tumour adherence (%)",
              "Long surgery-to-registration interval (%)", "Men aged 65 or older (%)",
              "Women younger than 55 (%)", "More than four positive nodes (%)"),
    multiplier = c(1, 100, 1, rep(100, 9)), stringsAsFactors = FALSE
  )
}
