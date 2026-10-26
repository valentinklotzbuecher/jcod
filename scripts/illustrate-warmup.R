#!/usr/bin/env Rscript
# Constructed conditional-average risks for the two-slide warm-up.
# These are population quantities, not sampled outcomes or fitted estimates.
library(ggplot2)

output_dir <- "results/warmup"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
scenario_names <- c("Constant benefit", "Heterogeneous benefit")
truth <- data.frame(
  scenario = rep(scenario_names, each = 3),
  profile = rep(c("A", "B", "C"), 2),
  population_weight = rep(1 / 3, 6),
  risk_control = rep(.40, 6),
  risk_treated = c(.30, .30, .30, .50, .30, .10)
)
truth$benefit <- truth$risk_control - truth$risk_treated
summary <- do.call(rbind, lapply(scenario_names, function(name) {
  d <- truth[truth$scenario == name, ]
  data.frame(
    scenario = name,
    risk_control = sum(d$population_weight * d$risk_control),
    risk_treated = sum(d$population_weight * d$risk_treated),
    mean_benefit = sum(d$population_weight * d$benefit)
  )
}))

# Check the population construction independently of the plot.
stopifnot(all(truth$risk_control >= 0 & truth$risk_control <= 1),
          all(truth$risk_treated >= 0 & truth$risk_treated <= 1),
          all(abs(tapply(truth$population_weight, truth$scenario, sum) - 1) < 1e-12),
          max(abs(summary$risk_control - .40)) < 1e-12,
          max(abs(summary$risk_treated - .30)) < 1e-12,
          max(abs(summary$mean_benefit - .10)) < 1e-12,
          max(abs(truth$benefit - c(.10, .10, .10, -.10, .10, .30))) < 1e-12)

# Population inverse-CDF quantile: at a jump boundary, take the lower step.
population_quantile <- function(u, d) {
  d <- d[order(d$benefit), ]
  cumulative <- cumsum(d$population_weight)
  vapply(u, function(p) d$benefit[which(cumulative >= p)[1]], numeric(1))
}
u <- c(.10, 1 / 3, .50, 2 / 3, .90)
stopifnot(max(abs(population_quantile(u, truth[4:6, ]) -
                     c(-.10, -.10, .10, .10, .30))) < 1e-12)

# Exact horizontal quantile segments, with open starts and closed ends at
# jumps. No smoothing, sampling uncertainty or package inference is implied.
segments <- data.frame(
  scenario = c(scenario_names[1], rep(scenario_names[2], 3)),
  lower_percentile = c(0, 0, 100 / 3, 200 / 3),
  upper_percentile = c(100, 100 / 3, 200 / 3, 100),
  benefit_pp = c(10, -10, 10, 30)
)
segments$scenario <- factor(segments$scenario, levels = scenario_names)
jump_start <- segments[segments$scenario == scenario_names[2] &
                         segments$lower_percentile > 0, ]
jump_end <- segments[segments$scenario == scenario_names[2] &
                       segments$upper_percentile < 100, ]

figure <- ggplot(segments) +
  geom_hline(yintercept = 0, colour = "#9A929F", linewidth = .5) +
  geom_segment(aes(x = lower_percentile, xend = upper_percentile,
                   y = benefit_pp, yend = benefit_pp),
               colour = "#5A317E", linewidth = 1.7, lineend = "butt") +
  geom_point(data = jump_start, aes(lower_percentile, benefit_pp),
             shape = 21, fill = "white", colour = "#5A317E", stroke = 1.2, size = 3.7) +
  geom_point(data = jump_end, aes(upper_percentile, benefit_pp),
             colour = "#5A317E", size = 3.7) +
  facet_wrap(~ scenario, nrow = 1) +
  scale_x_continuous(breaks = c(0, 100 / 3, 200 / 3, 100),
                     labels = c("0", "33⅓", "66⅔", "100"),
                     limits = c(0, 100), expand = expansion(mult = .04)) +
  scale_y_continuous(breaks = seq(-10, 30, by = 10), limits = c(-16, 36),
                     expand = expansion(mult = 0)) +
  labs(x = "Percentile of true benefit", y = "Risk reduction (percentage points)") +
  theme_minimal(base_size = 20, base_family = "DejaVu Sans") +
  theme(
    text = element_text(colour = "#252438"),
    axis.text = element_text(colour = "#252438", size = 17),
    axis.title = element_text(margin = margin(t = 10, r = 10)),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "#E9E5EC", linewidth = .4),
    strip.text = element_text(face = "bold", size = 19,
                              margin = margin(t = 10, b = 10)),
    strip.background = element_rect(fill = "#F0EBF4", colour = NA),
    panel.spacing = grid::unit(1.3, "lines"),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "#FCFBFD", colour = NA),
    plot.margin = margin(12, 16, 12, 12)
  )

write.csv(truth, file.path(output_dir, "population-risks.csv"), row.names = FALSE)
write.csv(summary, file.path(output_dir, "population-means.csv"), row.names = FALSE)
write.csv(segments, file.path(output_dir, "quantile-segments.csv"), row.names = FALSE)
ggsave(file.path(output_dir, "effect-distributions.png"), figure,
       width = 12, height = 6.2, dpi = 220, bg = "white")
ggsave(file.path(output_dir, "effect-distributions.pdf"), figure,
       width = 12, height = 6.2, device = grDevices::cairo_pdf, bg = "white")
cat("Verified equal 10 pp population means, valid risks and exact quantile steps.\n")
