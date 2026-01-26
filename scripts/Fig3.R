# scripts/Fig3.R
# Purpose: Generate mortality attributable to physical inactivity by climate scenario
# Panel A: Regional median mortality by SSP scenario (heatstrip)
# Panel B: Country-level mortality by SSP scenario (heatmap, ordered within region)
# Inputs:
#   data/processed/mortality_costs.csv (country mortality estimates by SSP)
# Outputs:
#   outputs/figures/Fig3_mortality_PI_combined.tiff (publication quality)
#   outputs/figures/Fig3_mortality_PI_combined.pdf (vector format)

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(scales)
  library(RColorBrewer)
  library(patchwork)
  library(forcats)
})

# ---- helper: ensure output dir exists ----
ensure_dir <- function(path) {
  d <- dirname(path)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ---- inputs & outputs (repo-relative) ----
input_csv  <- file.path("data", "processed", "mortality_costs.csv")
output_dir <- file.path("outputs", "figures")
output_tiff <- file.path(output_dir, "Fig3_mortality_PI_combined.tiff")
output_pdf  <- file.path(output_dir, "Fig3_mortality_PI_combined.pdf")

# ---- check inputs ----
if (!file.exists(input_csv)) {
  stop(sprintf("Input file not found: %s\n  Please ensure mortality costs CSV is available.", input_csv))
}

# ---- configuration ----
# Show numeric values inside cells
show_vals_region  <- TRUE   # Panel A (regional medians)
show_vals_country <- TRUE   # Panel B (country values)

# Font sizes
size_title_panel  <- 7
axis_region_size  <- 7
axis_country_size <- 2.8
region_text_size  <- 2.0
country_text_size <- 1.0
legend_title_size <- 7
legend_text_size  <- 6

# ---- load data ----
message("Loading mortality costs data...")
df <- read.csv(input_csv, stringsAsFactors = FALSE)

# Validate required columns
required_cols <- c("country_standard", "region_wb", "ssp", "deathsPI", "pop_est")
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")))
}

# ---- prepare country-level data ----
message("Preparing country-level data...")
df_plot <- df %>%
  rename(scenario = ssp) %>%
  mutate(
    mortality_rate = (deathsPI / pop_est) * 100000,
    scenario = factor(scenario, levels = c("ssp126", "ssp245", "ssp585"))
  ) %>%
  group_by(scenario) %>%
  arrange(region_wb, desc(mortality_rate), .by_group = TRUE) %>%
  mutate(
    order_in_scenario = row_number(),
    region_change     = region_wb != lag(region_wb, default = ""),
    country_label     = country_standard
  ) %>%
  group_by(scenario, region_wb) %>%
  mutate(region_mid = mean(order_in_scenario)) %>%
  ungroup()

# Identify last scenario (ssp585)
last_scenario <- levels(df_plot$scenario)[nlevels(df_plot$scenario)]

# ---- regional aggregates (Panel A) ----
message("Computing regional medians...")
df_reg_raw <- df_plot %>%
  group_by(region_wb, scenario) %>%
  summarise(
    median_mort = median(mortality_rate, na.rm = TRUE),
    .groups = "drop"
  )

# Order regions by median in last scenario
reg_order <- df_reg_raw %>%
  filter(scenario == last_scenario) %>%
  arrange(desc(median_mort)) %>%
  pull(region_wb)

df_reg <- df_reg_raw %>%
  mutate(region_wb = factor(region_wb, levels = reg_order))

if (show_vals_region) {
  df_reg <- df_reg %>%
    mutate(label_txt = sprintf("%.1f", median_mort))
}

# ---- shared palette & scale ----
heatmap_palette <- c("#313695", "#4575b4", "#74add1", "#abd9e9",
                     "#fdae61", "#f46d43", "#d73027")
fill_breaks <- c(0, 1, 5, 20, 50, 100)
fill_labels <- c("0", "1", "5", "20", "50", "100+")

# ---- Panel A: Regional heatstrip ----
message("Creating Panel A (regional medians)...")
p_reg <- ggplot(df_reg, aes(x = scenario, y = region_wb, fill = median_mort)) +
  geom_tile(color = "white", linewidth = 0.25) +
  scale_fill_gradientn(
    colours = heatmap_palette,
    trans   = "pseudo_log",
    breaks  = fill_breaks,
    labels  = fill_labels,
    name    = "Mortality per 100,000 population (median)",
    guide   = guide_colorbar(
      title.position = "top",
      title.hjust    = 0.5,
      barwidth       = 20,
      barheight      = 0.5,
      direction      = "horizontal"
    )
  ) +
  labs(title = "A. Regional median mortality attributable to physical inactivity",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 8) +
  theme(
    plot.title    = element_text(face = "bold", size = size_title_panel, margin = margin(b = 2)),
    axis.text.x   = element_text(face = "bold", size = 6),
    axis.text.y   = element_text(face = "bold", size = axis_region_size),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(size = legend_title_size),
    legend.text  = element_text(size = legend_text_size),
    panel.grid    = element_blank()
  )

if (show_vals_region) {
  p_reg <- p_reg +
    geom_text(aes(label = label_txt),
              size = region_text_size,
              lineheight = 0.9,
              color = "black")
}

# ---- reorder countries within region by last scenario ----
message("Ordering countries within regions...")
df_last <- df_plot %>%
  filter(scenario == last_scenario) %>%
  select(country_standard, region_wb, mort_last = mortality_rate)

df_plot_ord <- df_plot %>%
  left_join(df_last, by = c("country_standard", "region_wb")) %>%
  mutate(region_wb = factor(region_wb, levels = reg_order)) %>%
  group_by(region_wb) %>%
  arrange(desc(mort_last), .by_group = TRUE) %>%
  mutate(country_ord = dense_rank(desc(mort_last))) %>%
  ungroup() %>%
  arrange(region_wb, country_ord) %>%
  mutate(country_f = factor(country_standard, levels = unique(country_standard)))

if (show_vals_country) {
  df_plot_ord <- df_plot_ord %>%
    mutate(label_txt = sprintf("%.2f", mortality_rate))
}

# ---- Panel B: Country heatmap ----
message("Creating Panel B (country-level heatmap)...")
p_heatmap <- ggplot(df_plot_ord,
                    aes(x = scenario, y = country_f, fill = mortality_rate)) +
  geom_tile() +
  facet_grid(region_wb ~ ., scales = "free_y", space = "free_y") +
  scale_fill_gradientn(
    colours = heatmap_palette,
    trans   = "pseudo_log",
    breaks  = fill_breaks,
    labels  = fill_labels,
    name    = "Mortality per 100,000 population",
    guide   = guide_colorbar(
      title.position = "top",
      title.hjust    = 0.5,
      barwidth       = 20,
      barheight      = 0.5,
      direction      = "horizontal"
    )
  ) +
  labs(title = "B. Country-level mortality attributable to physical inactivity",
       x = "SSP scenario", y = "Country") +
  theme_minimal() +
  theme(
    plot.title      = element_text(face = "bold", size = size_title_panel, margin = margin(b = 2)),
    axis.text.y     = element_text(size = axis_country_size),
    axis.text.x     = element_text(face = "bold", size = 6),
    axis.title.x    = element_text(size = 7, margin = margin(t = 2)),
    axis.title.y    = element_text(size = 7, margin = margin(r = 2)),
    strip.text.y    = element_text(size = 7, face = "bold", angle = 0),
    strip.background = element_blank(),
    panel.spacing.y  = unit(0.4, "lines"),
    legend.position  = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(size = legend_title_size),
    legend.text  = element_text(size = legend_text_size),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    panel.background  = element_blank()
  )

if (show_vals_country) {
  p_heatmap <- p_heatmap +
    geom_text(aes(label = label_txt),
              size  = country_text_size,
              color = "black")
}

# ---- combine panels ----
message("Combining panels...")
fig_combined <- p_reg / p_heatmap +
  plot_layout(guides = "keep", heights = c(1, 4)) &
  theme(
    legend.position = "bottom",
    legend.box = "vertical",
    legend.direction = "vertical",
    legend.title = element_text(size = legend_title_size),
    legend.text  = element_text(size = legend_text_size)
  )

# ---- save outputs ----
ensure_dir(output_tiff)

message(sprintf("Saving TIFF output to: %s", output_tiff))
ggsave(output_tiff, fig_combined,
       width = 7.5, height = 10, units = "in",
       dpi = 600, compression = "lzw")

message(sprintf("Saving PDF output to: %s", output_pdf))
ggsave(output_pdf, fig_combined,
       width = 7.5, height = 10, units = "in")

message("Done. Figures written to: ", output_dir)
