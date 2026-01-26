# scripts/Fig4.R
# Purpose: Generate Sankey diagram showing economic costs of physical inactivity
#          by World Bank region, income group, and climate scenario
# Inputs:
#   data/processed/mortality_costs.csv (country-level costs with region/income/scenario)
# Outputs:
#   outputs/figures/Fig4_Sankey_region_income_scenario.pdf

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(ggalluvial)
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
output_pdf <- file.path(output_dir, "Fig4_Sankey_region_income_scenario.pdf")

# ---- check inputs ----
if (!file.exists(input_csv)) {
  stop(sprintf("Input file not found: %s\n  Please ensure mortality costs CSV is available.", input_csv))
}

# ---- load data ----
message("Loading mortality costs data...")
df <- read.csv(input_csv, stringsAsFactors = FALSE)

# Validate required columns
required_cols <- c("region_wb", "income_grp", "ssp", "ecosts")
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")))
}

# ---- prepare data ----
message("Preparing flow data...")

# Recode income groups to 3 categories
df_plot <- df %>%
  rename(scenario = ssp) %>%
  mutate(
    income_recoded = case_when(
      income_grp %in% c("1. High income: OECD", "2. High income: nonOECD") ~ "High Income",
      income_grp == "3. Upper middle income"                                ~ "Middle Income",
      income_grp %in% c("4. Lower middle income", "5. Low income")          ~ "Low Income",
      TRUE ~ NA_character_
    )
  )

# Create flow dataset: aggregate by Region x Income x Scenario
flows <- df_plot %>%
  mutate(val = abs(ecosts)) %>%
  filter(
    !is.na(region_wb),
    !is.na(scenario),
    !is.na(income_recoded),
    is.finite(val)
  ) %>%
  group_by(region_wb, income_recoded, scenario) %>%
  summarise(value = sum(val, na.rm = TRUE), .groups = "drop")

# ---- order factors logically ----
ssp_levels <- c("ssp126", "ssp245", "ssp585")

flows <- flows %>%
  mutate(
    region_wb = fct_reorder(region_wb, value, .fun = sum),
    income_recoded = factor(income_recoded,
                           levels = c("High Income", "Middle Income", "Low Income")),
    scenario = factor(
      scenario,
      levels = ssp_levels[ssp_levels %in% unique(scenario)]
    )
  )

# ---- create Sankey diagram ----
message("Creating Sankey diagram...")

gg_sankey <- ggplot(
  flows,
  aes(axis1 = region_wb,
      axis2 = income_recoded,
      axis3 = scenario,
      y     = value)
) +
  # Flows in gray
  geom_alluvium(fill = "grey70", color = "grey60", alpha = 0.9,
                width = 0.25, knot.pos = 0.4) +
  # Nodes (strata) with labels
  geom_stratum(width = 0.25, color = "grey20", fill = "white") +
  geom_text(stat = "stratum",
            aes(label = after_stat(stratum)),
            size = 3) +
  # Axis titles (the "columns" of the Sankey)
  scale_x_discrete(
    limits = c("World Bank region", "Income group", "Scenario"),
    expand = c(.05, .05)
  ) +
  # Y scale
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.05))) +
  theme_minimal(base_size = 11) +
  theme(
    axis.title.y  = element_blank(),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    panel.grid    = element_blank(),
    axis.text.x   = element_text(face = "bold"),
    plot.title    = element_text(hjust = 0.5, face = "bold")
  ) +
  labs(
    title = "Economic costs of physical inactivity by region, income group, and scenario",
    x     = NULL
  )

# ---- save output ----
ensure_dir(output_pdf)

message(sprintf("Saving PDF output to: %s", output_pdf))
ggsave(
  filename = output_pdf,
  plot     = gg_sankey,
  width    = 8,
  height   = 5,
  units    = "in",
  device   = cairo_pdf
)

message("Done. Figure written to: ", output_dir)
