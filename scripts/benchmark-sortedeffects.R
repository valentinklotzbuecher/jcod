#!/usr/bin/env Rscript
# Run from the project root: Rscript scripts/benchmark-sortedeffects.R
# Optional dependency: SortedEffects 1.7.0 (CRAN GitHub mirror commit
# 18a1196e474ee1b62d6722754e8e377cba4ddc1f). See docs/software-validation.md.
# This benchmark uses its published mortgage example, not clinical data.

options(warn = 1)
stopifnot(requireNamespace("SortedEffects", quietly = TRUE))
stopifnot(as.character(utils::packageVersion("SortedEffects")) == "1.7.0")
stopifnot(requireNamespace("Hmisc", quietly = TRUE))
dir.create("results/benchmark", recursive = TRUE, showWarnings = FALSE)

data("mortgage", package = "SortedEffects", envir = environment())
fm <- deny ~ black + p_irat + hse_inc + ccred + mcred + pubrec +
  ltv_med + ltv_high + denpmi + selfemp + single + hischl
us <- seq(0.1, 0.9, by = 0.1)
b <- as.integer(Sys.getenv("SORTED_EFFECTS_BENCHMARK_B", "199"))
stopifnot(b >= 49L)

message("Running the original package's mortgage SPE example (", b, " draws).")
spe <- SortedEffects::spe(
  fm = fm, data = mortgage, var = "black", method = "logit",
  us = us, b = b, alpha = 0.05, bc = FALSE, seed = 420
)

# Independent direct glm calculation: same model, sample, finite contrast and
# weighted empirical quantile convention as the package. No internal estimator
# is called here. This example is a descriptive adjusted contrast, not a
# randomized treatment effect.
fit <- stats::glm(fm, data = mortgage, family = stats::binomial())
d0 <- d1 <- mortgage
d0$black <- 0
d1$black <- 1
delta <- stats::predict(fit, newdata = d1, type = "response") -
  stats::predict(fit, newdata = d0, type = "response")
manual_spe <- Hmisc::wtd.quantile(delta, weights = rep(1, nrow(mortgage)), probs = us)
spe_error <- max(abs(unname(manual_spe) - unname(spe$spe[[1]])))
ape_error <- abs(mean(delta) - spe$ape[[1]])
stopifnot(spe_error < 1e-10, ape_error < 1e-10)
stopifnot(all(is.finite(unlist(spe))), all(diff(spe$spe[[1]]) >= 0))
stopifnot(all(spe$spe[[2]] >= spe$spe[[1]]))
stopifnot(all(spe$spe[[3]] <= spe$spe[[1]]))
stopifnot(all(spe$spe[[4]] > 0))

message("Checking bootstrap reproducibility and non-degenerate uncertainty.")
spe_same <- SortedEffects::spe(
  fm = fm, data = mortgage, var = "black", method = "logit",
  us = us, b = b, alpha = 0.05, bc = FALSE, seed = 420
)
stopifnot(isTRUE(all.equal(spe, spe_same, tolerance = 0)))

# Reproduce the package's fixed-reference nonparametric-bootstrap SPE band
# independently: sample training counts, refit glm, predict on the original
# covariates, recompute quantiles, IQR-standardize, take the simultaneous maximum,
# and monotonically rearrange the resulting bounds. This checks the actual
# resampling/inference outputs, beyond agreement of point estimates.
message("Reconstructing the original bootstrap SPE confidence band.")
set.seed(420)
draws <- replicate(b, {
  counts <- tabulate(sample.int(nrow(mortgage), nrow(mortgage), replace = TRUE),
                     nbins = nrow(mortgage))
  boot_data <- mortgage
  boot_data$.counts <- counts
  boot_fit <- stats::glm(fm, data = boot_data, family = stats::binomial(),
                        weights = .counts)
  boot_delta <- stats::predict(boot_fit, newdata = d1, type = "response") -
    stats::predict(boot_fit, newdata = d0, type = "response")
  Hmisc::wtd.quantile(boot_delta, rep(1, length(boot_delta)), us)
})
centered <- sweep(draws, 1, as.numeric(manual_spe), "-")
manual_se <- apply(centered, 1, stats::IQR) /
  diff(stats::qnorm(c(0.25, 0.75)))
maxima <- apply(abs(sweep(centered, 1, manual_se, "/")), 2, max)
critical <- as.numeric(stats::quantile(maxima, 0.95))
manual_lower <- sort(as.numeric(manual_spe) - critical * manual_se)
manual_upper <- sort(as.numeric(manual_spe) + critical * manual_se)
bootstrap_error <- max(abs(c(
  manual_se - spe$spe[[4]], manual_lower - spe$spe[[3]],
  manual_upper - spe$spe[[2]]
)))
stopifnot(bootstrap_error < 1e-8)

message("Running original classification analysis and checking tail means.")
characteristics <- c("p_irat", "hse_inc")
ca <- SortedEffects::ca(
  fm = fm, data = mortgage, var = "black", method = "logit",
  u = 0.1, cl = "diff", interest = "moment", t = characteristics,
  b = b, alpha = 0.05, bc = FALSE, seed = 420
)
stopifnot(inherits(ca, "ca"))
stopifnot(all(is.finite(unlist(ca[c("est", "bse", "joint_p", "pointwise_p")]))))
thresholds <- Hmisc::wtd.quantile(delta, rep(1, length(delta)), c(0.1, 0.9))
least <- delta <= thresholds[1]
most <- delta >= thresholds[2]
manual_ca <- colMeans(mortgage[most, characteristics]) -
  colMeans(mortgage[least, characteristics])
ca_error <- max(abs(unname(manual_ca) - as.numeric(ca$est)))
stopifnot(ca_error < 1e-10, all(ca$bse > 0))

# Probe the archived plotting method rather than assuming its reported failure
# occurs on every R version. It succeeds on the onboarding machine's R 4.5.0.
# Retain the installed estimator unchanged and also provide an explicitly named
# plotting adapter, which changes presentation only.
grDevices::pdf("results/benchmark/original-plot.pdf")
plot_failure <- tryCatch({
  plot(spe, main = "Mortgage example", ylab = "Adjusted probability contrast")
  NA_character_
}, error = function(e) conditionMessage(e))
grDevices::dev.off()

plot_spe_named <- function(x) {
  limits <- range(unlist(x$spe[1:3]), unlist(x$ape[1:3]))
  graphics::plot(
    x = x$us, y = x$spe[[1]], type = "n", xlim = range(x$us),
    ylim = limits, xlab = "Percentile of adjusted contrast",
    ylab = "Difference in predicted mortgage-denial probability",
    main = "SortedEffects 1.7.0: published mortgage example"
  )
  graphics::polygon(
    x = c(x$us, rev(x$us)), y = c(x$spe[[3]], rev(x$spe[[2]])),
    col = "#E0D5EB", border = NA
  )
  graphics::lines(x$us, x$spe[[1]], col = "#5A317E", lwd = 2)
  graphics::abline(h = x$ape[[1]], col = "#A34E2A", lty = 2)
  graphics::legend(
    "topleft", legend = c("Sorted adjusted contrasts", "Average contrast", "95% uniform band"),
    col = c("#5A317E", "#A34E2A", "#E0D5EB"), lwd = c(2, 1, 8),
    lty = c(1, 2, 1), bty = "n", cex = 0.8
  )
}
grDevices::pdf("results/benchmark/mortgage-spe.pdf", width = 9, height = 5.2)
plot_spe_named(spe)
grDevices::dev.off()

utils::write.csv(data.frame(
  percentile = us, direct_glm = as.numeric(manual_spe),
  package_spe = as.numeric(spe$spe[[1]]),
  lower_uniform = as.numeric(spe$spe[[3]]),
  upper_uniform = as.numeric(spe$spe[[2]])
), "results/benchmark/spe-comparison.csv", row.names = FALSE)
utils::write.csv(data.frame(
  characteristic = characteristics, direct_most_minus_least = unname(manual_ca),
  package_most_minus_least = as.numeric(ca$est),
  package_bootstrap_se = as.numeric(ca$bse),
  package_joint_p = as.numeric(ca$joint_p)
), "results/benchmark/ca-comparison.csv", row.names = FALSE)

stopifnot(requireNamespace("ggplot2", quietly = TRUE))
dir.create("results/figures", recursive = TRUE, showWarnings = FALSE)
figure_data <- data.frame(
  percentile = us * 100, estimate = spe$spe[[1]] * 100,
  lower = spe$spe[[3]] * 100, upper = spe$spe[[2]] * 100
)
figure <- ggplot2::ggplot(figure_data, ggplot2::aes(percentile, estimate)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = lower, ymax = upper),
                       fill = "#D9CBE5", alpha = 0.8) +
  ggplot2::geom_hline(yintercept = as.numeric(spe$ape[[1]]) * 100,
                      color = "#A34E2A", linetype = "dashed", linewidth = 0.8) +
  ggplot2::geom_line(color = "#5A317E", linewidth = 1.2) +
  ggplot2::scale_x_continuous(breaks = seq(10, 90, by = 20)) +
  ggplot2::labs(
    x = "Percentile of adjusted contrast", y = "Adjusted denial-probability contrast (pp)",
    subtitle = "Mortgage example: sorted contrasts and 95% uniform band",
    caption = paste0("SortedEffects 1.7.0 | n = 2,380 | B = ", b,
                     " | dashed: average contrast\nObservational association; no causal identification is established here.")
  ) +
  ggplot2::theme_minimal(base_size = 18) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    plot.caption = ggplot2::element_text(size = 11, hjust = 0),
    plot.background = ggplot2::element_rect(fill = "#FAFAFA", color = NA)
  )
ggplot2::ggsave("results/figures/mortgage-example.png", figure,
                width = 10, height = 5.4, dpi = 180)
ggplot2::ggsave("results/figures/mortgage-example.pdf", figure,
                width = 10, height = 5.4)
utils::capture.output(str(ca), file = "results/benchmark/ca-structure.txt")
saveRDS(list(spe = spe, ca = ca, direct_ca = manual_ca), "results/benchmark/original-results.rds")
utils::capture.output(sessionInfo(), file = "results/benchmark/session-info.txt")
utils::capture.output(list(
  package_version = as.character(utils::packageVersion("SortedEffects")),
  source_commit = "18a1196e474ee1b62d6722754e8e377cba4ddc1f",
  n = nrow(mortgage), bootstrap_draws = b, spe_max_error = spe_error,
  ape_error = ape_error, ca_max_error = ca_error,
  bootstrap_band_max_error = bootstrap_error, original_plot_error = plot_failure,
  spe_reproducibility = TRUE
), file = "results/benchmark/validation.txt")
message("Original package benchmark completed. See results/benchmark/validation.txt.")
