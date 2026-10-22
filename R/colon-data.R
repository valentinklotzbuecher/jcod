# Prepare the public colon chemotherapy trial without fitting outcome models.
# See docs/colon-data.md and docs/colon-analysis-plan.md for the analysis scope.

prepare_colon_data <- function(path = "data/colon/cancer.rda", horizon = 3 * 365.25) {
  stopifnot(length(horizon) == 1L, is.finite(horizon), horizon > 0)
  source_data <- new.env(parent = emptyenv())
  objects <- load(path, envir = source_data)
  stopifnot("colon" %in% objects)
  raw <- source_data$colon
  required <- c("id", "rx", "sex", "age", "obstruct", "perfor", "adhere",
                "nodes", "status", "differ", "extent", "surg", "node4", "time", "etype")
  stopifnot(nrow(raw) == 1858L, length(unique(raw$id)) == 929L,
            all(required %in% names(raw)), !anyNA(raw$id),
            all(table(raw$id, raw$etype) == 1L),
            setequal(unique(raw$etype), c(1, 2)))
  death <- raw[raw$etype == 2, , drop = FALSE]
  recurrence <- raw[raw$etype == 1, , drop = FALSE]
  recurrence <- recurrence[match(death$id, recurrence$id), , drop = FALSE]
  baseline_columns <- c("id", "rx", "sex", "age", "obstruct", "perfor", "adhere",
                        "nodes", "differ", "extent", "surg", "node4")
  stopifnot(isTRUE(all.equal(death[, baseline_columns],
                            recurrence[, baseline_columns], check.attributes = FALSE)))
  raw_selected <- death[death$rx %in% c("Obs", "Lev+5FU"), , drop = FALSE]
  rownames(raw_selected) <- NULL
  stopifnot(nrow(raw_selected) == 619L, !anyDuplicated(raw_selected$id))
  check_codes <- function(x, allowed, allow_na = FALSE) {
    stopifnot(all(is.na(x) | x %in% allowed))
    if (!allow_na) stopifnot(!anyNA(x))
  }
  for (name in c("sex", "obstruct", "perfor", "adhere", "status", "surg", "node4")) {
    check_codes(raw_selected[[name]], 0:1)
  }
  check_codes(raw_selected$differ, 1:3, allow_na = TRUE)
  check_codes(raw_selected$extent, 1:4)
  stopifnot(all(is.finite(raw_selected$age)),
            all(raw_selected$age >= 18 & raw_selected$age <= 85),
            all(is.finite(raw_selected$time)), all(raw_selected$time > 0),
            all(is.na(raw_selected$nodes) | (raw_selected$nodes >= 0 &
                  raw_selected$nodes == floor(raw_selected$nodes))))

  # Death before/on the horizon is an event. Follow-up through the horizon,
  # including a later death, establishes no event by that horizon. Early
  # censoring never establishes survival to the requested horizon.
  known <- raw_selected$status == 1 | raw_selected$time >= horizon
  outcome <- ifelse(known,
                    as.integer(raw_selected$status == 1 & raw_selected$time <= horizon),
                    NA_integer_)
  selected <- data.frame(
    id = raw_selected$id,
    treatment = factor(as.character(raw_selected$rx), levels = c("Obs", "Lev+5FU"),
                       labels = c("observation", "chemotherapy")),
    outcome = outcome, age = raw_selected$age,
    female = as.integer(raw_selected$sex == 0),
    age_z = (raw_selected$age - 60) / 10,
    nodes = raw_selected$nodes, log_nodes = log1p(raw_selected$nodes),
    nodes_over4 = as.integer(raw_selected$nodes > 4),
    poor_diff = as.integer(raw_selected$differ == 3),
    differ = factor(raw_selected$differ, levels = 1:3,
                    labels = c("well", "moderate", "poor")),
    extent = raw_selected$extent,
    extensive = as.integer(raw_selected$extent >= 3),
    obstruct = raw_selected$obstruct, perfor = raw_selected$perfor,
    adhere = raw_selected$adhere,
    surg_late = as.integer(raw_selected$surg == 1),
    node4 = raw_selected$node4,
    node4_disagreement = !is.na(raw_selected$nodes) &
      (as.integer(raw_selected$nodes > 4) != raw_selected$node4),
    followup_days = raw_selected$time, death_record_status = raw_selected$status
  )
  selected$old_men <- as.integer(selected$female == 0 & selected$age >= 65)
  selected$younger_women <- as.integer(selected$female == 1 & selected$age < 55)
  baseline_complete <- complete.cases(selected[, c("age", "female", "nodes", "differ", "extent")])
  primary <- known & baseline_complete
  all_outcomes <- selected[known, , drop = FALSE]
  data <- selected[primary, , drop = FALSE]
  rownames(all_outcomes) <- rownames(data) <- NULL
  stopifnot(!anyNA(data), all(data$outcome %in% 0:1))

  audit <- do.call(rbind, lapply(c("all", levels(selected$treatment)), function(arm) {
    in_arm <- if (arm == "all") rep(TRUE, nrow(selected)) else selected$treatment == arm
    n <- sum(in_arm)
    events <- sum(outcome[in_arm], na.rm = TRUE)
    observed <- sum(in_arm & known)
    data.frame(arm = arm, n_randomized = n, n_observed = observed,
               n_missing = n - observed, events = events,
               observed_risk = events / observed,
               risk_lower = events / n, risk_upper = (events + n - observed) / n,
               n_primary = sum(in_arm & primary),
               n_excluded_baseline_known = sum(in_arm & known & !baseline_complete))
  }))
  variables <- c("age", "female", "nodes", "differ", "extent", "obstruct",
                 "perfor", "adhere", "surg_late")
  missingness <- data.frame(
    variable = variables,
    n_missing_selected = colSums(is.na(selected[, variables])),
    n_missing_known_outcome = colSums(is.na(all_outcomes[, variables])),
    n_missing_primary = colSums(is.na(data[, variables])), row.names = NULL
  )
  exclusions <- data.frame(
    id = selected$id, treatment = selected$treatment,
    outcome_known = known, baseline_complete = baseline_complete,
    included_primary = primary,
    reason = ifelse(!known & !baseline_complete, "early censoring and missing baseline",
                    ifelse(!known, "early censoring",
                           ifelse(!baseline_complete, "missing baseline", "included")))
  )
  exclusions <- exclusions[!primary, , drop = FALSE]
  rownames(exclusions) <- NULL
  node4_disagreements <- selected[selected$node4_disagreement,
                                  c("id", "treatment", "nodes", "node4")]
  node4_disagreements$included_primary <- primary[selected$node4_disagreement]
  rownames(node4_disagreements) <- NULL
  cohort_flow <- data.frame(
    stage = c("trial_people", "selected_comparison", "known_endpoint", "primary_complete_baselines"),
    n = c(nrow(death), nrow(selected), nrow(all_outcomes), nrow(data))
  )
  list(data = data, all_outcomes = all_outcomes, selected = selected,
       audit = audit, missingness = missingness, exclusions = exclusions,
       node4_disagreements = node4_disagreements, cohort_flow = cohort_flow,
       horizon_days = horizon)
}
