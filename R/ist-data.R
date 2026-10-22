# Prepare the corrected public International Stroke Trial dataset.
# Treatment is randomized allocation, not medication actually received.
# No fitted model, imputation or data-dependent variable selection occurs here.

prepare_ist_data <- function(path = "data/ist/IST_corrected.csv") {
  raw <- utils::read.csv(
    path, stringsAsFactors = FALSE, fileEncoding = "latin1",
    na.strings = "", check.names = FALSE
  )
  required <- c(
    "RXASP", "RXHEP", "OCCODE", "AGE", "SEX", "RSBP", "RDELAY",
    "RCONSC", "RATRIAL", "RASP3", "RDEF2", "RDEF3", "RDEF4",
    "STYPE", "HOSPNUM", "COUNTRY"
  )
  stopifnot(nrow(raw) == 19435L, ncol(raw) == 112L,
            all(required %in% names(raw)))
  check_codes <- function(x, allowed, allow_na = FALSE) {
    stopifnot(all(is.na(x) | x %in% allowed))
    if (!allow_na) stopifnot(!anyNA(x))
  }
  check_codes(raw$RXASP, c("N", "Y"))
  check_codes(raw$RXHEP, c("N", "L", "M", "H"))
  check_codes(raw$OCCODE, c(0, 1, 2, 3, 4, 9))
  check_codes(raw$SEX, c("M", "F"))
  check_codes(raw$RCONSC, c("F", "D", "U"))
  check_codes(raw$RATRIAL, c("N", "Y"), allow_na = TRUE)
  check_codes(raw$RASP3, c("N", "Y"), allow_na = TRUE)
  for (column in c("RDEF2", "RDEF3", "RDEF4")) {
    check_codes(raw[[column]], c("N", "Y", "C"))
  }
  check_codes(raw$STYPE, c("LACS", "PACS", "POCS", "TACS", "OTH"))
  stopifnot(all(is.finite(raw$AGE)), all(raw$AGE >= 16 & raw$AGE <= 99),
            all(is.finite(raw$RSBP)), all(raw$RSBP >= 70 & raw$RSBP <= 295),
            all(is.finite(raw$RDELAY)), all(raw$RDELAY >= 1 & raw$RDELAY <= 48))

  known <- raw$OCCODE %in% 1:4
  outcome <- ifelse(known, as.integer(raw$OCCODE %in% 1:2), NA_integer_)
  audit <- do.call(rbind, lapply(c("all", "no_aspirin", "aspirin"), function(arm) {
    selected <- if (arm == "all") rep(TRUE, nrow(raw)) else
      raw$RXASP == if (arm == "aspirin") "Y" else "N"
    n <- sum(selected)
    observed <- sum(selected & known)
    events <- sum(outcome[selected], na.rm = TRUE)
    data.frame(
      arm = arm, n_randomized = n, n_observed = observed,
      n_missing = n - observed, events = events,
      observed_risk = events / observed,
      risk_lower = events / n, risk_upper = (events + n - observed) / n
    )
  }))

  unknown_factor <- function(x) {
    factor(ifelse(is.na(x), "unknown", x), levels = c("N", "Y", "unknown"))
  }
  heparin <- raw$RXHEP
  heparin[heparin == "H"] <- "M"
  data <- data.frame(
    rowid = seq_len(nrow(raw)), outcome = outcome,
    aspirin = factor(raw$RXASP, levels = c("N", "Y"),
                     labels = c("no_aspirin", "aspirin")),
    heparin = factor(heparin, levels = c("N", "L", "M"),
                    labels = c("none", "low", "medium")),
    age = raw$AGE, female = as.integer(raw$SEX == "F"),
    sbp = raw$RSBP, delay = raw$RDELAY,
    age_z = (raw$AGE - 70) / 10,
    sbp_z = (raw$RSBP - 160) / 20,
    delay_z = (raw$RDELAY - 24) / 24,
    consciousness = factor(raw$RCONSC, levels = c("F", "D", "U")),
    not_alert = as.integer(raw$RCONSC != "F"),
    af = unknown_factor(raw$RATRIAL),
    prior_aspirin = unknown_factor(raw$RASP3),
    arm_deficit = factor(raw$RDEF2, levels = c("N", "Y", "C")),
    leg_deficit = factor(raw$RDEF3, levels = c("N", "Y", "C")),
    dysphasia = factor(raw$RDEF4, levels = c("N", "Y", "C")),
    stroke_type = factor(raw$STYPE, levels = c("LACS", "PACS", "POCS", "TACS", "OTH")),
    hospital = factor(raw$HOSPNUM), country = factor(raw$COUNTRY),
    stringsAsFactors = FALSE
  )
  data$af_yes <- as.integer(data$af == "Y")
  data$af_unknown <- as.integer(data$af == "unknown")
  data$prior_aspirin_yes <- as.integer(data$prior_aspirin == "Y")
  data$prior_aspirin_unknown <- as.integer(data$prior_aspirin == "unknown")
  data$arm_yes <- as.integer(data$arm_deficit == "Y")
  data$arm_unknown <- as.integer(data$arm_deficit == "C")
  data$leg_yes <- as.integer(data$leg_deficit == "Y")
  data$leg_unknown <- as.integer(data$leg_deficit == "C")
  data$dysphasia_yes <- as.integer(data$dysphasia == "Y")
  data$dysphasia_unknown <- as.integer(data$dysphasia == "C")
  data$old_men <- as.integer(data$female == 0 & data$age >= 75)
  data$younger_women <- as.integer(data$female == 1 & data$age < 65)
  data <- data[known, , drop = FALSE]
  rownames(data) <- NULL

  variables <- c("AGE", "SEX", "RSBP", "RDELAY", "RCONSC", "RATRIAL", "RASP3",
                 "RDEF2", "RDEF3", "RDEF4", "STYPE", "HOSPNUM", "COUNTRY")
  missingness <- do.call(rbind, lapply(variables, function(column) {
    value <- raw[[column]]
    unassessable <- if (column %in% c("RDEF2", "RDEF3", "RDEF4")) {
      !is.na(value) & value == "C"
    } else rep(FALSE, length(value))
    unknown <- is.na(value) | unassessable
    data.frame(
      variable = column, n_total = nrow(raw),
      n_missing = sum(is.na(value)), n_unassessable = sum(unassessable),
      n_analysis = sum(known), n_unknown_analysis = sum(unknown & known)
    )
  }))
  stopifnot(nrow(data) == 19285L, !anyNA(data),
            identical(audit$n_missing, c(150L, 69L, 81L)),
            sum(data$outcome) == 12125L)
  list(data = data, audit = audit, missingness = missingness)
}
