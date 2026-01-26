# scripts/Fig2.R
# Purpose: Generate global physical inactivity change maps by climate change scenario
# Inputs:
#   data/processed/estimates_by_country.csv (country-level PI estimates by SSP scenario)
#   data/raw/shapefiles/WB_countries_Admin0_10m.shp (World Bank country shapefile)
# Outputs:
#   outputs/figures/Fig2_Global_PI_change_by_CC.jpg (raster for preview)
#   outputs/figures/Fig2_Global_PI_change_by_CC.pdf (vector for publication)

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(cowplot)
  library(readr)
  library(RColorBrewer)
})

# ---- helper: ensure output dir exists ----
ensure_dir <- function(path) {
  d <- dirname(path)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ---- inputs & outputs (repo-relative) ----
# Data directories
shp_path <- file.path("data", "raw", "shapefiles", "WB_countries_Admin0_10m",
                      "WB_countries_Admin0_10m.shp")
estimates_path <- file.path("data", "processed", "estimates_by_country.csv")

# Output directory
output_dir <- file.path("outputs", "figures")
output_jpg <- file.path(output_dir, "Fig2_Global_PI_change_by_CC.jpg")
output_pdf <- file.path(output_dir, "Fig2_Global_PI_change_by_CC.pdf")

# ---- check inputs ----
if (!file.exists(shp_path)) {
  stop(sprintf("Shapefile not found: %s\n  Please download World Bank country shapefile to data/raw/shapefiles/", shp_path))
}

if (!file.exists(estimates_path)) {
  stop(sprintf("Estimates file not found: %s\n  Please ensure country estimates CSV is available.", estimates_path))
}

# ---- load data ----
message("Loading shapefile...")
world <- st_read(shp_path, quiet = TRUE)

message("Loading country estimates...")
estimates <- read_csv(estimates_path, show_col_types = FALSE) %>%
  rename(OBJECTID = objectid)

# ---- merge data ----
message("Merging spatial and estimate data...")
merged_data <- world %>%
  left_join(estimates, by = "OBJECTID")

# ---- calculate common limits for color scale ----
limit_lower <- min(merged_data$b, na.rm = TRUE)
limit_upper <- max(merged_data$b, na.rm = TRUE)

message(sprintf("Value range for Physical Inactivity change: %.2f to %.2f",
                limit_lower, limit_upper))

# ---- function to generate map for specific scenario (no legend) ----
map_by_scenario <- function(ssp_val) {
  # Filter data for the scenario
  subset_data <- merged_data %>% filter(ssp == ssp_val)

  # Assign global estimate according to scenario
  global_est <- switch(ssp_val,
                       "ssp126" = "0.98, p<0.01",
                       "ssp245" = "1.22, p<0.01",
                       "ssp585" = "1.75, p<0.01")

  ggplot() +
    # Background: all countries in light gray
    geom_sf(data = merged_data, fill = "grey90", color = "white", size = 0.1) +
    # Overlay countries with estimates for filtered scenario, colored by "b"
    geom_sf(data = subset_data, aes(fill = b), color = "white", size = 0.1) +
    scale_fill_gradientn(
      colors = brewer.pal(9, "YlOrRd"),
      name = "Physical Inactivity Change (%)",
      limits = c(limit_lower, limit_upper),
      na.value = "lightgray"
    ) +
    coord_sf(clip = "off") +
    theme_void() +
    theme(
      plot.margin = margin(1, 1, 1, 1),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      legend.position = "none",
      plot.background = element_rect(fill = "white", color = NA)
    ) +
    # Convert title to uppercase to display "SSP126", "SSP245", etc.
    labs(title = toupper(ssp_val)) +
    # Add notation in lower right corner: title above estimate
    annotate("text", x = Inf, y = -Inf, hjust = 1, vjust = 0,
             label = paste0("Global PI change (%)\n", global_est),
             size = 3.5, color = "black", fontface = "bold")
}

# ---- create example map with legend to extract it ----
message("Generating maps for each scenario...")
map_with_legend <- map_by_scenario("ssp126") + theme(legend.position = "bottom")
common_legend <- get_legend(map_with_legend)

# ---- generate maps for each scenario (without legend) ----
scenarios <- c("ssp126", "ssp245", "ssp585")
maps <- lapply(scenarios, map_by_scenario)

# ---- combine three maps in column and add common legend below ----
# Assign panel labels A, B, C in upper left corner of each plot
combined_maps <- plot_grid(plotlist = maps, ncol = 1,
                          labels = c("A", "B", "C"),
                          label_size = 16)

final_plot <- plot_grid(combined_maps, common_legend,
                       ncol = 1,
                       rel_heights = c(1, 0.1))

# ---- save outputs ----
ensure_dir(output_jpg)

message(sprintf("Saving JPEG output to: %s", output_jpg))
ggsave(output_jpg, final_plot,
       width = 8, height = 12,
       device = "jpeg",
       dpi = 300)

message(sprintf("Saving PDF output to: %s", output_pdf))
ggsave(output_pdf, final_plot,
       width = 8, height = 12,
       units = "in",
       device = cairo_pdf)  # Vector PDF, editable in Illustrator/Inkscape

message("Done. Figures written to: ", output_dir)
