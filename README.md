# Effects of climate change on physical inactivity: A panel study across 156 countries from 2000 to 2022
Authors: Christian García-Witulski, PhD, Mariano Rabassa, PhD, Oscar Melo, PhD, Juliana Helo Sarmiento, PhD


Reproducible code to generate **manuscript tables and figures** for the study on climate change and physical inactivity (2000–2022).

This repository contains:
- **Stata scripts** for generating Tables 1–12 (manuscript and supplementary)
- **R scripts** for generating Figures 1–4

## Repository Structure
```
climate-change-PI/
├── data/
│   ├── raw/
│   │   └── shapefiles/
│   │       └── WB_countries_Admin0_10m/    # World Bank country shapefile 
│   └── processed/
│       ├── processed_data.csv              # Main panel dataset (156 countries, 2000-2022)
│       ├── mortality_costs.csv             # Mortality and economic cost estimates
├── outputs/
│   ├── logs/                               # Stata log files
│   ├── tables/
│   │   ├── manuscript/                     # Main tables (Table 1, etc.)
│   │   └── supplementary/                  # Supplementary tables (S2-S12)
│   ├── derived/
│   │   └── coefficients/                   # Coefficient CSVs for figures
│   │       ├── coefficients_for_figures_PI0.csv
│   │       ├── coefficients_for_figures_PI1.csv
│   │       └── coefficients_for_figures_PI2.csv
└── scripts/
    ├── 00_config.do                        # Stata configuration
    ├── 01_table_1.do                       # Table 1: Main results
    ├── 02_tables_S2.do                     # Table S2
    ├── 03_tables_S3_S5.do                  # Tables S3-S5
    ├── 04_table_S6.do                      # Table S6
    ├── 05_table_S7.do                      # Table S7
    ├── 06_table_S8.do                      # Table S8
    ├── 07_table_S9.do                      # Table S9
    ├── 08_table_S10.do                     # Table S10
    ├── 09_tables_S11_S12.do                # Tables S11-S12
    ├── Fig1.R                              # Figure 1: Temperature-PI coefficient plots
    ├── Fig2.R                              # Figure 2: Global PI change maps by SSP scenario
    ├── Fig3.R                              # Figure 3: Mortality attributable to PI
    └── Fig4.R                              # Figure 4: Economic costs Sankey diagram
```

## Requirements

### For Tables (Stata)
- **Stata 15+**
- SSC package `estout` (for `eststo/esttab`)
  ```stata
  ssc install estout
  ```

### For Figures (R)
- **R 4.0+**
- Required packages:
  ```r
  install.packages(c(
    "ggplot2", "dplyr", "cowplot", "scales", "tikzDevice",  # Fig1
    "sf", "readr", "RColorBrewer",                          # Fig2
    "patchwork", "forcats",                                 # Fig3
    "ggalluvial"                                            # Fig4
  ))
  ```

## How to Run

### Tables (Stata)
1. Open Stata in the **repo root** folder (where this README is).
2. Ensure `data/processed/processed_data.csv` exists.
3. Run all table scripts:
   ```stata
   do "scripts/00_config.do"
   do "scripts/01_table_1.do"
   do "scripts/02_tables_S2.do"
   do "scripts/03_tables_S3_S5.do"
   do "scripts/04_table_S6.do"
   do "scripts/05_table_S7.do"
   do "scripts/06_table_S8.do"
   do "scripts/07_table_S9.do"
   do "scripts/08_table_S10.do"
   do "scripts/09_tables_S11_S12.do"
   ```

Outputs appear in `outputs/tables/`.

### Figures (R)
1. Ensure required data files exist:
   - `data/processed/mortality_costs.csv` (for Fig3, Fig4)
   - `data/processed/estimates_by_country.csv` (for Fig2)
   - `outputs/derived/coefficients/*.csv` (for Fig1)
   - `data/raw/shapefiles/WB_countries_Admin0_10m/*.shp` (for Fig2)

2. Run individual figure scripts from repo root:
   ```r
   source("scripts/Fig1.R")  # Temperature-PI coefficients
   source("scripts/Fig2.R")  # Global PI change maps
   source("scripts/Fig3.R")  # Mortality heatmaps
   source("scripts/Fig4.R")  # Economic costs Sankey
   ```

Outputs appear in `outputs/figures/`.

## Figure Descriptions

| Figure | Description | Outputs |
|--------|-------------|---------|
| **Fig1** | Temperature-PI coefficient plots (5 models, 3 outcomes) | `Fig1.tex`, `FigS1.tex`, `FigS2.tex` |
| **Fig2** | Global physical inactivity change maps by SSP scenario | `Fig2_Global_PI_change_by_CC.pdf`, `.jpg` |
| **Fig3** | Mortality attributable to PI by region and scenario | `Fig3_mortality_PI_combined.tiff`, `.pdf` |
| **Fig4** | Economic costs Sankey: region → income → scenario | `Fig4_Sankey_region_income_scenario.pdf` |

## Data Notes

### Required Data Files
- **processed_data.csv**: Main panel dataset with 156 countries (2000-2022)
  - Columns: `objectid`, `year`, `PI`, `tavg`, `region_wb`, `income_grp`, etc.
- **mortality_costs.csv**: Mortality and economic cost estimates
  - Columns: `country_standard`, `region_wb`, `ssp`, `deathsPI`, `pop_est`, `ecosts`, etc.
- **estimates_by_country.csv**: Country-level PI change estimates by SSP
  - Columns: `objectid`, `ssp`, `b` (coefficient)
- **World Bank shapefile**: in `data/raw/shapefiles/WB_countries_Admin0_10m/`

### Model Notes
- Standard errors are clustered by `objectid` (country-level)
- Country fixed-effects and country-specific linear trends included where specified



