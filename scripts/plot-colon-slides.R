#!/usr/bin/env Rscript
# Slide figures from the existing colon results. No models or resamples are fitted.
# Run from the repository root after the colon analysis and inference audit.
stopifnot(requireNamespace("ggplot2", quietly = TRUE))
library(ggplot2)

input_dir <- "results/colon"
output_dir <- file.path(input_dir, "slides")
required <- c("constant-spe.csv", "constant-ape.csv", "interaction-spe.csv",
              "interaction-ape.csv", "classification-stabilized.csv",
              "validation-tertile.csv")
if (!all(file.exists(file.path(input_dir, required)))) {
  stop("The existing colon analysis, validation and stabilized CA results are required.")
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
read_result <- function(filename) {
  utils::read.csv(file.path(input_dir, filename), stringsAsFactors = FALSE)
}

purple <- "#5A317E"
orange <- "#A34E2A"
ink <- "#252438"
muted <- "#687080"
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
      strip.text = element_text(face = "bold", size = base_size * 0.9,
                                margin = margin(t = 10, b = 10)),
      strip.background = element_rect(fill = "#F0EBF4", colour = NA),
      legend.position = "bottom", legend.title = element_blank(),
      legend.text = element_text(size = base_size * 0.92),
      legend.key.width = grid::unit(1.4, "cm"),
      legend.margin = margin(t = 8),
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

# Keep exactly the same scales and fitted curve before and after revealing the
# native 95% uniform band. The dashed line is the existing native APE estimate.
spe <- rbind(read_result("constant-spe.csv"), read_result("interaction-spe.csv"))
ape <- rbind(read_result("constant-ape.csv"), read_result("interaction-ape.csv"))
stopifnot(setequal(spe$model, c("constant", "interaction")),
          setequal(ape$model, c("constant", "interaction")),
          all(is.finite(as.matrix(spe[, c("estimate", "lower_uniform", "upper_uniform")]))),
          all(spe$lower_uniform <= spe$upper_uniform))
interaction_spe <- spe[spe$model == "interaction", ]
interaction_ape <- ape[ape$model == "interaction", ]
spe_axes <- function(x_expand = .025) {
  list(
    scale_x_continuous(limits = c(.1, .9), breaks = c(.1, .25, .5, .75, .9),
                       labels = function(x) paste0(round(100 * x), "%"),
                       expand = expansion(mult = x_expand)),
    scale_y_continuous(limits = c(-30, 50), breaks = seq(-20, 40, 20),
                       expand = expansion(mult = 0)),
    labs(x = "Patients, sorted by estimated benefit", y = "Estimated benefit (pp)")
  )
}
interaction_plot <- function(show_band = FALSE) {
  p <- ggplot(interaction_spe, aes(percentile, 100 * estimate))
  if (show_band) {
    p <- p + geom_ribbon(aes(ymin = 100 * lower_uniform, ymax = 100 * upper_uniform),
                          fill = purple, alpha = .17)
  }
  p +
    geom_hline(yintercept = 0, colour = "#938B9C", linewidth = .6) +
    geom_hline(yintercept = 100 * interaction_ape$estimate, colour = purple,
               linetype = "dashed", linewidth = .8) +
    geom_line(colour = purple, linewidth = 1.6) +
    annotate("label", x = .12, y = 100 * interaction_ape$estimate + 5,
             label = sprintf("Average: %.1f pp", 100 * interaction_ape$estimate),
             hjust = 0, size = 5.5, colour = purple, fill = "white",
             label.size = 0, label.padding = grid::unit(.15, "lines")) +
    spe_axes() + slide_theme()
}
save_figure(interaction_plot(FALSE), "sorted-effects")
save_figure(interaction_plot(TRUE), "sorted-effects-band")

# Bands are native, calibrated separately within each model. The comparison
# uses one common vertical scale; neither model's results are changed here.
model_names <- c(constant = "Constant treatment odds ratio",
                 interaction = "Six treatment interactions")
spe$panel <- factor(spe$model, levels = names(model_names), labels = model_names)
ape$panel <- factor(ape$model, levels = names(model_names), labels = model_names)
ape$label <- sprintf("Average: %.1f pp", 100 * ape$estimate)
comparison <- ggplot(spe, aes(percentile, 100 * estimate)) +
  geom_ribbon(aes(ymin = 100 * lower_uniform, ymax = 100 * upper_uniform,
                  fill = model), alpha = .17) +
  geom_hline(yintercept = 0, colour = "#938B9C", linewidth = .6) +
  geom_hline(data = ape, aes(yintercept = 100 * estimate, colour = model),
             linetype = "dashed", linewidth = .8) +
  geom_line(aes(colour = model), linewidth = 1.4) +
  geom_label(data = ape, aes(x = .12, y = 100 * estimate + 5,
                             label = label, colour = model),
              inherit.aes = FALSE, hjust = 0, size = 4.8, label.size = 0,
              fill = "white", label.padding = grid::unit(.15, "lines")) +
  facet_wrap(~ panel, nrow = 1) +
  scale_colour_manual(values = c(constant = orange, interaction = purple)) +
  scale_fill_manual(values = c(constant = orange, interaction = purple)) +
  spe_axes(x_expand = .05) + slide_theme(base_size = 18) +
  theme(legend.position = "none", panel.spacing = grid::unit(1.8, "lines"))
save_figure(comparison, "model-comparison", width = 12, height = 6.5)

# Classification endpoints come from the audited reconstruction; they are
# descriptive means, identical to the native point estimates. No CA inference
# is drawn: each connecting line joins two means, not confidence limits.
classification <- read_result("classification-stabilized.csv")
stopifnot(nrow(classification) == 12L,
          all(is.finite(as.matrix(classification[, c("low_mean", "high_mean", "multiplier")]))),
          all(classification$n_low == 60L), all(classification$n_high == 60L))
panel_labels <- c(
  age = "Age (years)", female = "Female (%)", old_men = "Men aged 65+ (%)",
  younger_women = "Women under 55 (%)", nodes = "Positive nodes (count)",
  nodes_over4 = "More than 4 nodes (%)", poor_diff = "Poor differentiation (%)",
  extensive = "Serosa or beyond (%)", obstruct = "Bowel obstruction (%)",
  perfor = "Perforation (%)", adhere = "Tumour adherence (%)",
  surg_late = "Long surgery-to-registration\ninterval (%)"
)
classification_plot <- function(variables) {
  d <- classification[match(variables, classification$variable), ]
  stopifnot(!anyNA(d$variable))
  d$panel <- factor(d$variable, levels = variables, labels = panel_labels[variables])
  low <- transform(d, tail = "Bottom 10%", value = low_mean * multiplier,
                   point_y = .04, label_y = .22)
  high <- transform(d, tail = "Top 10%", value = high_mean * multiplier,
                    point_y = -.04, label_y = -.22)
  endpoints <- rbind(low, high)
  endpoints$tail <- factor(endpoints$tail, levels = c("Bottom 10%", "Top 10%"))
  endpoints$label <- sprintf("%.1f", endpoints$value)
  bounds <- do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    limits <- switch(d$variable[i], age = c(18, 85), nodes = c(0, 27), c(0, 100))
    data.frame(panel = d$panel[i], value = limits)
  }))
  ggplot() +
    geom_blank(data = bounds, aes(value, 0)) +
    geom_segment(data = d,
                  aes(x = low_mean * multiplier, xend = high_mean * multiplier,
                      y = .04, yend = -.04), colour = "#C5BACF", linewidth = 1.5) +
    geom_point(data = endpoints, aes(value, point_y, colour = tail, shape = tail),
                size = 4.2) +
    geom_text(data = endpoints, aes(value, label_y, label = label, colour = tail),
               size = 5, fontface = "bold", show.legend = FALSE) +
    facet_wrap(~ panel, scales = "free_x", ncol = 3) +
    scale_colour_manual(values = c("Bottom 10%" = orange, "Top 10%" = purple)) +
    scale_shape_manual(values = c("Bottom 10%" = 16, "Top 10%" = 17)) +
    scale_x_continuous(breaks = function(x) pretty(x, n = 3),
                       expand = expansion(mult = .12)) +
    scale_y_continuous(limits = c(-.42, .42), breaks = NULL) +
    labs(x = NULL, y = NULL) + slide_theme(base_size = 17) +
    theme(panel.grid.major.y = element_blank(),
          panel.spacing = grid::unit(1.15, "lines"),
          strip.text = element_text(size = 14.7, face = "bold", lineheight = 1.05,
                                    margin = margin(t = 8, b = 8)),
          axis.text.x = element_text(size = 13.5),
          plot.margin = margin(10, 16, 6, 10))
}
save_figure(classification_plot(c("age", "female", "old_men", "younger_women",
                                  "nodes", "nodes_over4")),
            "classification-demographics", width = 12, height = 6.5)
save_figure(classification_plot(c("poor_diff", "extensive", "obstruct", "perfor",
                                  "adhere", "surg_late")),
            "classification-clinical", width = 12, height = 6.5)

# One prespecified split, interaction model only. Observed differences and
# their pointwise, unadjusted 95% intervals are copied from the saved CSV.
validation <- read_result("validation-tertile.csv")
validation <- validation[validation$model == "interaction", ]
stopifnot(identical(validation$tertile, 1:3),
          all(validation$n_control + validation$n_treated == 99L),
          all(validation$lower <= validation$estimate),
          all(validation$estimate <= validation$upper))
validation_plot <- ggplot(validation, aes(tertile)) +
  geom_hline(yintercept = 0, colour = "#938B9C", linewidth = .6) +
  geom_line(aes(y = 100 * mean_predicted_benefit, colour = "Predicted"),
              linewidth = 1, linetype = "dashed") +
  geom_point(aes(y = 100 * mean_predicted_benefit, colour = "Predicted",
                 shape = "Predicted"), size = 4.2) +
  geom_errorbar(aes(ymin = 100 * lower, ymax = 100 * upper, colour = "Observed"),
                 width = .12, linewidth = 1) +
  geom_point(aes(y = 100 * estimate, colour = "Observed", shape = "Observed"),
                size = 4.8) +
  scale_colour_manual(breaks = c("Observed", "Predicted"),
                       values = c(Observed = purple, Predicted = orange)) +
  scale_shape_manual(breaks = c("Observed", "Predicted"),
                      values = c(Observed = 16, Predicted = 17)) +
  guides(shape = "none", colour = guide_legend(
    override.aes = list(shape = c(16, 17), linetype = c("solid", "dashed")))) +
  scale_x_continuous(breaks = 1:3, labels = c("Lowest third\n99 patients",
                                             "Middle third\n99 patients",
                                             "Highest third\n99 patients"),
                     expand = expansion(mult = .22)) +
  scale_y_continuous(limits = c(-30, 45), breaks = seq(-20, 40, 20),
                     expand = expansion(mult = 0)) +
  labs(x = "Groups ranked by predicted benefit", y = "Benefit (pp)") +
  slide_theme() + theme(panel.grid.major.x = element_blank())
save_figure(validation_plot, "validation-tertiles")

message("Saved colon slide figures to ", output_dir)
