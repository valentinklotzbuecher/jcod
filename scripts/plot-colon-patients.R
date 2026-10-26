#!/usr/bin/env Rscript
# Per-patient slide figures for the colon example: two predicted risks per
# patient, then all 593 estimated benefits sorted. Point estimates only: the
# specified interaction model is refitted, no resamples are drawn, and the
# saved SPE/APE estimates are reproduced before anything is written.
# Run from the repository root: Rscript scripts/plot-colon-patients.R
stopifnot(requireNamespace("ggplot2", quietly = TRUE))
library(ggplot2)
source("R/colon-data.R")
source("R/colon-analysis.R")

output_dir <- "results/colon/slides"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dat <- prepare_colon_data()$data
fit <- glm(colon_formulas()$interaction, data = dat, family = binomial())
colon_check_fit(fit)
stopifnot(nrow(dat) == 593L, sum(dat$outcome) == 179L, fit$rank == 19L)
risk <- colon_risks(fit, dat)
benefit <- risk$control - risk$treated

# With unit weights, the package's Hmisc::wtd.quantile convention equals
# quantile type 7. Check against the saved native estimates before plotting.
saved_spe <- read.csv("results/colon/interaction-spe.csv")
saved_ape <- read.csv("results/colon/interaction-ape.csv")
spe_check <- quantile(benefit, saved_spe$percentile, type = 7, names = FALSE)
cutoff <- quantile(benefit, c(.10, .90), type = 7, names = FALSE)
tail <- ifelse(benefit <= cutoff[1], "low", ifelse(benefit >= cutoff[2], "high", "middle"))
stopifnot(max(abs(spe_check - saved_spe$estimate)) < 1e-10,
          abs(mean(benefit) - saved_ape$estimate) < 1e-10,
          sum(tail == "low") == 60L, sum(tail == "high") == 60L)

patients <- data.frame(id = dat$id, risk_observation = risk$control,
                       risk_chemotherapy = risk$treated, benefit = benefit,
                       rank = rank(benefit, ties.method = "first"), tail = tail)
patients <- patients[order(patients$rank), ]
patients$percentile <- (patients$rank - .5) / nrow(patients)
write.csv(patients, "results/colon/patient-benefits.csv", row.names = FALSE)

purple <- "#5A317E"
orange <- "#A34E2A"
ink <- "#252438"
grey <- "#9A9FAB"
slide_theme <- function(base_size = 19) {
  theme_minimal(base_size = base_size, base_family = "DejaVu Sans") +
    theme(
      text = element_text(colour = ink),
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "#FCFBFD", colour = NA),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E9E5EC", linewidth = 0.4),
      axis.text = element_text(colour = ink, size = base_size * 0.88),
      axis.title = element_text(size = base_size, margin = margin(t = 10, r = 10)),
      legend.position = "bottom", legend.title = element_blank(),
      legend.text = element_text(size = base_size * 0.92),
      plot.margin = margin(12, 20, 12, 12)
    )
}
save_figure <- function(plot, filename, width = 10.8, height = 6) {
  for (extension in c("png", "pdf")) {
    arguments <- list(
      filename = file.path(output_dir, paste0(filename, ".", extension)),
      plot = plot, width = width, height = height, units = "in", bg = "white"
    )
    if (extension == "png") arguments$dpi <- 220 else arguments$device <- grDevices::cairo_pdf
    do.call(ggsave, arguments)
  }
}

# Step 2: eight patients spread across the benefit distribution, shown in
# data order (not sorted), each with risks predicted without and with treatment.
picks <- patients[patients$rank %in% round(nrow(patients) * c(.08, .25, .40, .52, .64, .75, .86, .95)), ]
picks <- picks[order(picks$id), ]
picks$label <- factor(paste("Patient", seq_len(nrow(picks))),
                      levels = rev(paste("Patient", seq_len(nrow(picks)))))
two_risks <- rbind(
  data.frame(label = picks$label, risk = picks$risk_observation, arm = "Without chemotherapy"),
  data.frame(label = picks$label, risk = picks$risk_chemotherapy, arm = "With chemotherapy")
)
two_risks$arm <- factor(two_risks$arm, levels = c("Without chemotherapy", "With chemotherapy"))
gap_label <- sprintf("%+.0f pp", 100 * picks$benefit)
predictions <- ggplot() +
  geom_segment(data = picks, aes(x = 100 * risk_observation, xend = 100 * risk_chemotherapy,
                                 y = label, yend = label),
               colour = "#C9BED3", linewidth = 2.2) +
  geom_point(data = two_risks, aes(100 * risk, label, colour = arm), size = 5) +
  geom_text(data = picks, aes(x = 103, y = label, label = gap_label),
            hjust = 0, size = 6.2, colour = ink, family = "DejaVu Sans") +
  annotate("text", x = 103, y = nrow(picks) + .75, label = "Benefit", hjust = 0,
           size = 6.2, fontface = "bold", colour = ink, family = "DejaVu Sans") +
  scale_colour_manual(values = c("Without chemotherapy" = grey, "With chemotherapy" = purple)) +
  scale_x_continuous(limits = c(0, 118), breaks = seq(0, 100, 20),
                     labels = function(x) paste0(x, "%"), expand = expansion(mult = 0)) +
  scale_y_discrete(expand = expansion(add = c(.6, 1.2))) +
  labs(x = "Predicted risk of death within three years", y = NULL) +
  slide_theme() +
  theme(panel.grid.major.y = element_blank())
save_figure(predictions, "patient-predictions", height = 6.2)

# Step 3: all 593 estimated benefits, sorted; the 10% at each end are marked.
patients$group <- factor(c(low = "10% least benefit", middle = "Middle 80%",
                           high = "10% most benefit")[patients$tail],
                         levels = c("10% least benefit", "Middle 80%", "10% most benefit"))
average <- 100 * mean(benefit)
sorted <- ggplot(patients, aes(100 * percentile, 100 * benefit, colour = group)) +
  annotate("rect", xmin = 0, xmax = 10, ymin = -Inf, ymax = Inf, fill = orange, alpha = .07) +
  annotate("rect", xmin = 90, xmax = 100, ymin = -Inf, ymax = Inf, fill = purple, alpha = .07) +
  geom_hline(yintercept = 0, colour = "#7C8190", linewidth = .5) +
  geom_hline(yintercept = average, colour = purple, linetype = "dashed", linewidth = .7) +
  geom_point(size = 1.9) +
  annotate("text", x = 30, y = average + 5, label = sprintf("Average: %.1f pp", average),
           colour = purple, size = 6, hjust = 0, family = "DejaVu Sans") +
  scale_colour_manual(values = c("10% least benefit" = orange, "Middle 80%" = "#8F79A3",
                                 "10% most benefit" = purple)) +
  scale_x_continuous(limits = c(0, 100), breaks = c(0, 10, 25, 50, 75, 90, 100),
                     labels = function(x) paste0(x, "%"), expand = expansion(mult = .01)) +
  scale_y_continuous(breaks = seq(-40, 60, 20)) +
  labs(x = "Patients, sorted from least to most estimated benefit",
       y = "Estimated benefit (pp)") +
  guides(colour = guide_legend(override.aes = list(size = 4))) +
  slide_theme()
save_figure(sorted, "sorted-patients", height = 6.2)

cat(sprintf("Reproduced saved SPE/APE (< 1e-10); %d patients, average %.2f pp, %d%% below zero.\n",
            nrow(patients), average, round(100 * mean(benefit < 0))))
print(picks[, c("label", "risk_observation", "risk_chemotherapy", "benefit", "rank")],
      row.names = FALSE, digits = 3)
