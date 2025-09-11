# Climate–PI Tables

Reproducible Stata code to generate the **manuscript Table 1** and **Supplementary Tables S3–S5** for the study on climate change and physical inactivity (2000–2022).

## Structure
```
climate-PI-tables/
├── data/
│   ├── raw/
│   └── processed/
│       └── processed_data.csv        # << Place your processed dataset here
├── outputs/
│   ├── logs/
│   ├── tables/
│   │   ├── manuscript/               # Table1.tex
│   │   └── supplementary/            # Table_S3.tex, Table_S4.tex, Table_S5.tex
│   └── derived/
│       └── coefficients/             # Coefficients for figures (optional)
└── scripts/
    ├── 00_config.do
    ├── 01_tables_S3_S5.do
    └── 02_table1_manuscript.do
```

## Requirements
- Stata 16+ (tested with 17/18)
- SSC package `estout` (for `eststo/esttab`)

## How to run
1. Open Stata in the **repo root** folder (where this README is).
2. Place your processed dataset at `data/processed/processed_data.csv`.
3. Run:
   ```stata
   do scripts/00_config.do
   do scripts/01_tables_S3_S5.do
   do scripts/02_table1_manuscript.do
   ```

Outputs will appear in `outputs/tables/`.

## Notes
- Standard errors are clustered by `objectid` (country-level).
- Country fixed-effects and country-specific linear trends are included where specified.
- If your data has `año_by_country`, `00_config.do` auto-renames it to `year_by_country`.
