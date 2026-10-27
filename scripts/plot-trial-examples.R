#!/usr/bin/env Rscript
# Closing slide figure: sorted effects in the three trial pilots, drawn from
# their saved native SortedEffects 1.7.0 results. No models or resamples are
# fitted. Colon is the worked example; the IST and ACTG 175 pilots follow their
# own plans (docs/ist-analysis-plan.md, docs/actg175-pilot.md).
# Run from the repository root under a UTF-8 locale (labels use "·" and "³"):
#   LC_ALL=C.UTF-8 Rscript scripts/plot-trial-examples.R
stopifnot(requireNamespace("ggplot2", quietly = TRUE))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run under a UTF-8 locale, e.g. LC_ALL=C.UTF-8.")
library(ggplot2)

output_dir <- "results/trials"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
read_result <- function(path) utils::read.csv(path, stringsAsFactors = FALSE)

# Benefit is positive when the treatment is better: control minus treated risk
# for colon and IST (shown in percentage points), treated minus control CD4
# count for ACTG 175. Each band is calibrated within its own model only.
spe_rows <- function(trial, path, keep, model, scale) {
  d <- read_result(path)
  d <- d[d$model == keep, ]
  stopifnot(nrow(d) == 81L, isTRUE(all.equal(d$percentile, seq(.10, .90, .01))),
            all(d$lower_uniform <= d$estimate), all(d$estimate <= d$upper_uniform))
  data.frame(trial = trial, model = model, percentile = d$percentile,
             estimate = scale * d$estimate, lower = scale * d$lower_uniform,
             upper = scale * d$upper_uniform)
}
spe <- rbind(
  spe_rows("colon", "results/colon/constant-spe.csv", "constant", "without", 100),
  spe_rows("colon", "results/colon/interaction-spe.csv", "interaction", "with", 100),
  spe_rows("ist", "results/ist/constant-spe.csv", "constant", "without", 100),
  spe_rows("ist", "results/ist/interaction-spe.csv", "interaction", "with", 100),
  spe_rows("actg175", "results/actg175/spe.csv", "main", "without", 1),
  spe_rows("actg175", "results/actg175/spe.csv", "interaction", "with", 1)
)
actg_ape <- read_result("results/actg175/ape.csv")
ape <- data.frame(
  trial = c("colon", "ist", "actg175"),
  estimate = c(100 * read_result("results/colon/interaction-ape.csv")$estimate,
               100 * read_result("results/ist/interaction-ape.csv")$estimate,
               actg_ape$estimate[actg_ape$model == "interaction"]),
  unit = c(" pp", " pp", "")
)
stopifnot(nrow(ape) == 3L, all(is.finite(ape$estimate)))
ape$label <- paste0("Average: ", ifelse(ape$unit == "", sprintf("%.0f", ape$estimate),
                                        sprintf("%.1f", ape$estimate)), ape$unit)

panels <- c(colon = "Colon cancer (n = 593)", ist = "Stroke, IST (n = 19,285)",
            actg175 = "HIV, ACTG 175 (n = 1,054)")
outcomes <- data.frame(trial = names(panels), label = c(
  "Chemotherapy vs observation:\nfewer deaths by 3 years (pp)",
  "Aspirin vs none: less death\nor dependence at 6 months (pp)",
  "Adding didanosine: higher\nCD4 at 20 weeks (cells/mm³)"))
for (name in c("spe", "ape", "outcomes")) {
  d <- get(name)
  d$trial <- factor(d$trial, levels = names(panels), labels = panels)
  assign(name, d)
}

purple <- "#5A317E"
orange <- "#A34E2A"
ink <- "#252438"
muted <- "#687080"
model_labels <- c(with = "With treatment interactions (shaded: 95% uniform band)",
                  without = "Without interactions")
figure <- ggplot(spe, aes(percentile, estimate)) +
  geom_ribbon(data = spe[spe$model == "with", ], aes(ymin = lower, ymax = upper),
              fill = purple, alpha = .17) +
  geom_hline(yintercept = 0, colour = "#938B9C", linewidth = .55) +
  geom_hline(data = ape, aes(yintercept = estimate), colour = purple,
             linetype = "dashed", linewidth = .7) +
  geom_line(aes(colour = model), linewidth = 1.35) +
  geom_text(data = ape, aes(x = .12, y = estimate, label = label), inherit.aes = FALSE,
            hjust = 0, vjust = -.6, size = 4.6, colour = purple, family = "DejaVu Sans") +
  geom_text(data = outcomes, aes(x = .1, y = Inf, label = label), inherit.aes = FALSE,
            hjust = 0, vjust = 1.25, size = 4.1, lineheight = .95, colour = muted,
            family = "DejaVu Sans") +
  facet_wrap(~ trial, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = c(with = purple, without = orange), labels = model_labels,
                      breaks = c("with", "without")) +
  scale_x_continuous(limits = c(.1, .9), breaks = c(.1, .5, .9),
                     labels = function(x) paste0(round(100 * x), "%"),
                     expand = expansion(mult = .04)) +
  scale_y_continuous(expand = expansion(mult = c(.05, .3))) +
  labs(x = "Patients, sorted by estimated benefit", y = "Estimated benefit") +
  theme_minimal(base_size = 17, base_family = "DejaVu Sans") +
  theme(
    text = element_text(colour = ink),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "#FCFBFD", colour = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "#E9E5EC", linewidth = 0.4),
    panel.spacing = grid::unit(1.6, "lines"),
    axis.text = element_text(colour = ink, size = 17 * 0.88),
    axis.title = element_text(size = 17, margin = margin(t = 10, r = 10)),
    strip.text = element_text(face = "bold", size = 17 * 0.86, margin = margin(t = 9, b = 9)),
    strip.background = element_rect(fill = "#F0EBF4", colour = NA),
    legend.position = "bottom", legend.title = element_blank(),
    legend.text = element_text(size = 17 * 0.9),
    legend.key.width = grid::unit(1.4, "cm"),
    plot.margin = margin(10, 16, 8, 10)
  )
for (extension in c("png", "pdf")) {
  arguments <- list(filename = file.path(output_dir, paste0("three-trials.", extension)),
                    plot = figure, width = 12.4, height = 5.5, units = "in", bg = "white")
  if (extension == "png") arguments$dpi <- 220 else arguments$device <- grDevices::cairo_pdf
  do.call(ggsave, arguments)
}
cat("Saved results/trials/three-trials.{png,pdf} from saved SPE/APE results.\n")
