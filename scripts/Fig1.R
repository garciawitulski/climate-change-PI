# scripts/plot_coefficients_figures.R
# Purpose: Build figures (Fig1, FigS1, FigS2) from coefficients CSVs
# Inputs:
#   outputs/derived/coefficients/coefficients_for_figures_PI0.csv
#   outputs/derived/coefficients/coefficients_for_figures_PI1.csv
#   outputs/derived/coefficients/coefficients_for_figures_PI2.csv
# Outputs:
#   outputs/figures/Fig1.tex
#   outputs/figures/FigS1.tex
#   outputs/figures/FigS2.tex

suppressPackageStartupMessages({
  library(ggplot2)
  library(cowplot)
  library(scales)
  library(tikzDevice)
})

# ---- helper: ensure output dir exists ----
ensure_dir <- function(path) {
  d <- dirname(path)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ---- inputs & outputs (repo-relative) ----
input_dir  <- file.path("outputs", "derived", "coefficients")
output_dir <- file.path("outputs", "figures")

file_list <- file.path(input_dir, c(
  "coefficients_for_figures_PI0.csv",
  "coefficients_for_figures_PI1.csv",
  "coefficients_for_figures_PI2.csv"
))

output_names <- file.path(output_dir, c("Fig1.tex", "FigS1.tex", "FigS2.tex"))

# ---- plotting function ----
plot_model <- function(data, model_num, y_limits=NULL) {
  filtered_data <- subset(data, model == model_num)

  # determine y-limits if not provided
  if (is.null(y_limits)) {
    y_min <- floor(min(filtered_data$ci_lower, na.rm = TRUE) * 10) / 10
    y_max <- ceiling(max(filtered_data$ci_upper, na.rm = TRUE) * 10) / 10
    y_limits <- c(y_min, y_max)
  }

  ggplot(filtered_data) +
    geom_errorbar(aes(x = bin, ymin = ci_lower, ymax = ci_upper, color = bin),
                  width = 0.2, size = 0.8, alpha = 0.8) +
    geom_point(aes(x = bin, y = coef, color = bin), size = 2.8, shape = 16) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", size = 0.3) +
    scale_x_continuous(limits = c(0.8, 5.2),
                       breaks = 1:5,
                       labels = c("Bin 1\n($<$4.2\\,\\textdegree C)",
                                  "Bin 2\n[4.2--13.4\\,\\textdegree C)",
                                  "Bin 3\n[13.4--21.8\\,\\textdegree C)",
                                  "Bin 4\n[21.8--27.8\\,\\textdegree C)",
                                  "Bin 5\n($>$27.8\\,\\textdegree C)"),
                       expand = c(0.02, 0.02)) +
    scale_y_continuous(limits = y_limits,
                       breaks = pretty(y_limits, n = 8),
                       labels = label_number(accuracy = 0.1),
                       expand = c(0.02, 0.02)) +
    scale_color_gradient2(low = "#00008B", mid = "#808080", high = "#FF0000", midpoint = 3,
                          name = "Temperature\nIntervals") +
    theme_minimal(base_size = 10) +
    theme(
      axis.title = element_text(size = 10),
      axis.text  = element_text(size = 9, colour = "black"),
      axis.title.x = element_text(margin = margin(t = 10)),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.margin = margin(20, 20, 20, 20),
      legend.position = "none"
    ) +
    labs(x = "Temperature Intervals", y = "Physical inactivity (95 CI)")
}

# ---- main loop ----
ensure_dir(output_names[1])

for (i in seq_along(file_list)) {
  file_name <- file_list[i]
  if (!file.exists(file_name)) {
    warning(sprintf("File not found: %s (skipping)", file_name))
    next
  }
  base <- read.csv(file_name)

  # basic checks
  needed_cols <- c("bin","coef","ci_lower","ci_upper","model")
  miss <- setdiff(needed_cols, names(base))
  if (length(miss) > 0) stop(sprintf("Missing columns in %s: %s", file_name, paste(miss, collapse=", ")))

  # consistent ordering / numeric
  base$bin <- as.numeric(base$bin)
  base$model <- as.integer(base$model)

  descriptions <- c(
    "Model 1: Unadjusted",
    "Model 2: + Country FE",
    "Model 3: + FE & environmental covariates",
    "Model 4: + FE, environmental & socioeconomic",
    "Model 5: Fully adjusted"
  )

  # y-range harmonised across the 5 panels for this outcome
  y_min <- floor(min(base$ci_lower, na.rm = TRUE) * 10) / 10
  y_max <- ceiling(max(base$ci_upper, na.rm = TRUE) * 10) / 10
  y_limits <- c(y_min, y_max)

  plots <- lapply(1:5, function(m) {
    p <- plot_model(base, m, y_limits)
    p + ggtitle(descriptions[m]) +
      theme(plot.title = element_text(size = 10, hjust = 0.5, face = "bold"))
  })

  # legend (kept for future use)
  legend <- cowplot::get_legend(
    ggplot(base) +
      geom_point(aes(x = bin, y = coef, color = bin)) +
      scale_color_gradient2(low = "#00008B", mid = "#808080", high = "#FF0000", midpoint = 3,
                            name = "Temperature\nIntervals") +
      theme_minimal() +
      theme(legend.position = "bottom")
  )

  combined_plots <- cowplot::plot_grid(
    cowplot::plot_grid(plotlist = plots, ncol = 2, labels = NULL),
    legend,
    ncol = 1,
    rel_heights = c(1, 0.12)
  )

  out_tex <- output_names[i]
  ensure_dir(out_tex)
  tikz(out_tex, width = 9, height = 10, standAlone = TRUE, sanitize = TRUE)
  print(combined_plots)
  dev.off()
}

message("Done. LaTeX figures written to: ", output_dir)

