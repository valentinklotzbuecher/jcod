#!/usr/bin/env Rscript
# Figures for the exploratory colon report; no models are fitted here.
# Run after scripts/analyze-colon.R finishes writing its native inference outputs.
stopifnot(requireNamespace("ggplot2", quietly = TRUE))
library(ggplot2)

input_dir <- "results/colon"
output_dir <- file.path(input_dir, "figures")
required <- c("model-summary.csv", "constant-spe.csv", "constant-ape.csv",
              "interaction-spe.csv", "interaction-ape.csv", "classification-native.csv")
if (!all(file.exists(file.path(input_dir, required)))) {
  stop("Run scripts/analyze-colon.R to completion before plotting.")
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
read_result <- function(filename) {
  utils::read.csv(file.path(input_dir, filename), stringsAsFactors = FALSE)
}
purple <- "#5A317E"
orange <- "#A34E2A"
ink <- "#252438"
muted <- "#687080"
source_note <- "Public survival::colon data · Complete-baseline cohort: 593 patients · See report for source and selection"
report_theme <- function(base_size = 13) {
  theme_minimal(base_size = base_size, base_family = "DejaVu Sans") +
    theme(
      text = element_text(colour = ink),
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "#FCFBFD", colour = NA),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E9E5EC", linewidth = 0.35),
      plot.title = element_text(face = "bold", size = base_size * 1.45,
                                margin = margin(b = 8)),
      plot.subtitle = element_text(colour = muted, size = base_size * 0.94,
                                   margin = margin(b = 15)),
      plot.caption = element_text(colour = muted, size = base_size * 0.75,
                                  hjust = 0, lineheight = 1.3,
                                  margin = margin(t = 14)),
      axis.title = element_text(size = base_size * 0.94),
      axis.text = element_text(colour = ink, size = base_size * 0.84),
      strip.text = element_text(face = "bold", colour = ink,
                                margin = margin(t = 9, b = 9)),
      strip.background = element_rect(fill = "#F0EBF4", colour = NA),
      legend.position = "bottom", legend.title = element_blank(),
      plot.margin = margin(18, 20, 16, 18)
    )
}
save_figure <- function(plot, filename, width, height) {
  for (extension in c("png", "pdf")) {
    arguments <- list(
      filename = file.path(output_dir, paste0(filename, ".", extension)),
      plot = plot, width = width, height = height, units = "in", bg = "white"
    )
    if (extension == "png") arguments$dpi <- 200 else arguments$device <- grDevices::cairo_pdf
    do.call(ggsave, arguments)
  }
}

# Native bands are calibrated separately within each specified model.
model_names <- c(constant = "Constant treatment odds ratio",
                 interaction = "Six treatment interactions")
spe <- rbind(read_result("constant-spe.csv"), read_result("interaction-spe.csv"))
ape <- rbind(read_result("constant-ape.csv"), read_result("interaction-ape.csv"))
summary <- read_result("model-summary.csv")
stopifnot(setequal(spe$model, names(model_names)),
          setequal(ape$model, names(model_names)),
          all(is.finite(as.matrix(spe[, c("estimate", "lower_uniform", "upper_uniform")]))),
          all(spe$lower_uniform <= spe$upper_uniform))
for (model in names(model_names)) {
  row <- ape[ape$model == model, ]
  stopifnot(nrow(row) == 1L,
            abs(row$estimate - summary$average[summary$model == model]) < 1e-10)
}
spe$panel <- factor(spe$model, levels = names(model_names), labels = model_names)
ape$panel <- factor(ape$model, levels = names(model_names), labels = model_names)
ape$label <- sprintf("Average %.2f pp", 100 * ape$estimate)
spe_plot <- ggplot(spe, aes(percentile, 100 * estimate)) +
  geom_hline(yintercept = 0, colour = "#938B9C", linewidth = 0.55) +
  geom_ribbon(aes(ymin = 100 * lower_uniform, ymax = 100 * upper_uniform,
                  fill = model), alpha = 0.15) +
  geom_hline(data = ape, aes(yintercept = 100 * estimate, colour = model),
             linetype = "dashed", linewidth = 0.7) +
  geom_line(aes(colour = model), linewidth = 1.2) +
  geom_label(data = ape, aes(x = 0.12, y = 100 * estimate, label = label,
                             colour = model), inherit.aes = FALSE,
              hjust = 0, vjust = -0.6, size = 3.3,
              label.size = 0, fill = "white", label.padding = grid::unit(0.15, "lines")) +
  facet_wrap(~ panel, nrow = 1) +
  scale_colour_manual(values = c(constant = orange, interaction = purple)) +
  scale_fill_manual(values = c(constant = orange, interaction = purple)) +
  scale_x_continuous(breaks = c(.10, .25, .50, .75, .90),
                     labels = function(x) paste0(round(100 * x), "%")) +
  scale_y_continuous(breaks = function(x) pretty(x, n = 6)) +
  labs(
    title = "Colon chemotherapy: two fitted effect distributions",
    subtitle = "Three-year mortality · Observation versus levamisole + fluorouracil · Dashed lines show averages",
    x = "Percentile of estimated risk reduction",
    y = "Observation risk − chemotherapy risk (percentage points)",
    caption = paste(
      "Shading: native 95% uniform bands over the 10th–90th percentile grid, separately for each model.",
      "Each band covers one model. Exploratory fitted benefits for observed profiles; validation is shown separately.",
      source_note, sep = "\n"
    )
  ) + report_theme() + theme(legend.position = "none", panel.spacing = grid::unit(1.5, "lines"))
save_figure(spe_plot, "sorted-comparison", width = 12.5, height = 6.7)

# A line connects two descriptive means. No endpoint confidence interval is drawn.
classification <- read_result("classification-native.csv")
stopifnot(nrow(classification) == 12L,
          all(is.finite(as.matrix(classification[, c("low_mean", "high_mean", "multiplier")]))))
classification$panel <- vapply(classification$label, function(label) {
  paste(strwrap(label, width = 28), collapse = "\n")
}, character(1))
classification$panel <- factor(classification$panel, levels = classification$panel)
low <- transform(classification, tail = "Bottom 10%", value = low_mean * multiplier)
high <- transform(classification, tail = "Top 10%", value = high_mean * multiplier)
endpoints <- rbind(low, high)
endpoints$tail <- factor(endpoints$tail, levels = c("Bottom 10%", "Top 10%"))
endpoints$label <- sprintf("%.1f", endpoints$value)
endpoints$label_y <- ifelse(endpoints$tail == "Bottom 10%", 0.20, -0.20)
bounds <- do.call(rbind, lapply(seq_len(nrow(classification)), function(i) {
  limits <- switch(classification$variable[i], age = c(18, 85), nodes = c(0, 27),
                   c(0, 100))
  data.frame(panel = classification$panel[i], value = limits)
}))
counts <- unique(classification[, c("n_low", "n_high")])
stopifnot(nrow(counts) == 1L)
classification_plot <- ggplot() +
  geom_blank(data = bounds, aes(value, 0)) +
  geom_segment(data = classification,
                aes(x = low_mean * multiplier, xend = high_mean * multiplier,
                    y = 0, yend = 0), colour = "#C5BACF", linewidth = 1.2) +
  geom_point(data = endpoints, aes(value, 0, colour = tail, shape = tail), size = 3.4) +
  geom_text(data = endpoints, aes(value, label_y, label = label, colour = tail),
             size = 3.5, fontface = "bold", show.legend = FALSE) +
  facet_wrap(~ panel, scales = "free_x", ncol = 3) +
  scale_colour_manual(values = c("Bottom 10%" = orange, "Top 10%" = purple)) +
  scale_shape_manual(values = c("Bottom 10%" = 16, "Top 10%" = 17)) +
  scale_x_continuous(breaks = function(x) pretty(x, n = 4),
                     expand = expansion(mult = 0.09)) +
  scale_y_continuous(limits = c(-0.42, 0.42), breaks = NULL) +
  labs(
    title = "Baseline characteristics of the fitted effect tails",
    subtitle = sprintf(
      "Interaction model · Bottom 10%%: %s profiles; top 10%%: %s profiles · Groups defined by estimated risk reduction",
      format(counts$n_low, big.mark = ","), format(counts$n_high, big.mark = ",")
    ),
    x = "Mean age or positive-node count; percentage for indicator characteristics", y = NULL,
    caption = paste(
      "Each panel uses its own original units. Endpoints are descriptive means; connecting lines are not confidence intervals.",
      "Tails describe the fitted interaction model. Statistical uncertainty and validation are discussed in the report.",
      source_note, sep = "\n"
    )
  ) + report_theme(base_size = 12) +
  theme(panel.grid.major.y = element_blank(),
        strip.text = element_text(size = 10, lineheight = 1.05, face = "bold"),
        panel.spacing = grid::unit(1.4, "lines"),
        legend.text = element_text(size = 11),
        legend.margin = margin(t = 8),
        plot.subtitle = element_text(size = 10.6, colour = muted))
save_figure(classification_plot, "classification-dumbbells", width = 12.5, height = 10.5)
message("Saved colon report plots to ", output_dir)
