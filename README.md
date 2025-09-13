# Climate change impacts on physical inactivity: A panel data study of global warming across 156 countries from 2000 to 2022

Reproducible Stata code to generate the **manuscript Table 1** and **Supplementary Tables S3–S10** for the study on climate change and physical inactivity (2000–2022).

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
│   │   ├── manuscript/               
│   │   └── supplementary/            
│   └── derived/
│       └── coefficients/             # Coefficients for figures (optional)
└── scripts/
    ├── 00_config.do
    ├── 01_table1.do
    ├── 02_table_S2.do
    ├── 03_tables_S3_S5.do
    ├── 04_table_S6.do
    ├── 05_table_S7.do
    ├── 06_table_S8.do
    ├── 07_tables_S9_S10.do
```

## Requirements
- Stata 15+ 
- SSC package `estout` (for `eststo/esttab`)

## How to run
1. Open Stata in the **repo root** folder (where this README is).
2. Place your processed dataset at `data/processed/processed_data.csv`.
3. Run:
   ```stata
   do "scripts/00_config.do"
   do "scripts/01_table1.do"
   do "scripts/01_table_S2.do"
   do "scripts/01_tables_S3_S5.do"
   do "scripts/01_table_S6.do"
   do "scripts/01_table_S7.do"
   do "scripts/01_table_S8.do"
   do "scripts/02_tables_S9_S10.do"
   ```

Outputs will appear in `outputs/tables/`.

## Notes
- Standard errors are clustered by `objectid` (country-level).
- Country fixed-effects and country-specific linear trends are included where specified.
- If your data has `año_by_country`, `00_config.do` auto-renames it to `year_by_country`.
