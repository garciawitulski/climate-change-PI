*****************************************************
* 07_table_S2.do  —  Descriptive statistics (2000–2022)
* Outputs:
*   - outputs/tables/supplementary/Table_S2.tex
*   - outputs/derived/descriptives_summary.csv
*****************************************************

version 15.0
clear all
set more off

* ---------- Paths ----------
* If you already source paths from scripts/00_config.do, this will pick them up.
capture noisily do "scripts/00_config.do"

* Fallbacks if globals are not defined in 00_config.do
capture confirm file "${DATA_PROCESSED}"
if _rc {
    local DATA_PROCESSED "data/processed/processed_data.csv"
}
else {
    local DATA_PROCESSED "${DATA_PROCESSED}"
}

* Ensure output dirs exist
capture mkdir "outputs"
capture mkdir "outputs/derived"
capture mkdir "outputs/tables"
capture mkdir "outputs/tables/supplementary"

* ---------- Load data ----------
import delimited "`DATA_PROCESSED'", clear varn(1) encoding(UTF-8)

* ---------- Variable mapping (edit here if your names differ) ----------
* Outcomes (age-standardized PI prevalence, percentage points)
local var_PI_both   "PI0"
local var_PI_men    "PI1"
local var_PI_women  "PI2"

* Temperature: annual pop-weighted mean (°C) and monthly bin counts (months per year)
local var_tmean     "tmean_weighted"
local bin2          "total_bin_2_tmean"
local bin3          "total_bin_3_tmean"
local bin4          "total_bin_4_tmean"
local bin5          "total_bin_5_tmean"
* Bin 1 is the residual (12 months - other bins)
capture drop bin1_tmean
gen bin1_tmean = 12 - ( `bin2' + `bin3' + `bin4' + `bin5' )

* Climate confounders (population-weighted)
local var_precip    "precipitation_weighted"   // mm/year
local var_cloud     "cld_weighted"             // %
local var_frost     "frs_weighted"             // days/year
local var_vap       "vap_weighted"             // hPa
local var_wet       "wet_weighted"             // days/year

* PM2.5 (µg/m3): prefer raw PM2.5 if present; otherwise back out from ln(pm2.5)
local var_pm25 ""
capture confirm variable pm25_weighted
if !_rc local var_pm25 "pm25_weighted"
if "`var_pm25'"=="" {
    capture confirm variable pm25
    if !_rc local var_pm25 "pm25"
}
if "`var_pm25'"=="" {
    capture confirm variable lnpm25
    if !_rc {
        gen pm25 = exp(lnpm25)
        local var_pm25 "pm25"
        label var pm25 "PM2.5 (µg/m3) [from exp(lnpm25)]"
    }
}
assert "`var_pm25'" != "" // stop if neither pm25 nor lnpm25 available

* Socioeconomic & health
local var_deathr   "deathr"         // per 1,000 population
local var_gdppc    ""
capture confirm variable GDPpc
if !_rc local var_gdppc "GDPpc"
if "`var_gdppc'"=="" {
    capture confirm variable gdppc
    if !_rc local var_gdppc "gdppc"
}
if "`var_gdppc'"=="" {
    capture confirm variable lnGDPpc
    if !_rc {
        gen GDPpc = exp(lnGDPpc)     // constant 2015 US$ assumed in source
        local var_gdppc "GDPpc"
        label var GDPpc "GDP per capita (constant 2015 US$)"
    }
}
assert "`var_gdppc'" != "" // stop if neither GDPpc nor lnGDPpc available

* ---------- Build labels for the table ----------
label var `var_PI_both'  "Both"
label var `var_PI_men'   "Men"
label var `var_PI_women' "Women"

label var `var_tmean' "Mean Temperature (°C)"
label var bin1_tmean  "Bin 1 (<4.2°C) [months]"
label var `bin2'      "Bin 2 [4.2–13.4°C) [months]"
label var `bin3'      "Bin 3 [13.4–21.8°C) [months]"
label var `bin4'      "Bin 4 [21.8–27.8°C) [months]"
label var `bin5'      "Bin 5 (>27.8°C) [months]"

label var `var_precip' "Precipitations (mm/year)"
label var `var_cloud'  "Cloud Cover (%)"
label var `var_frost'  "Frost Days (days/year)"
label var `var_vap'    "Vapor Pressure (hPa)"
label var `var_wet'    "Wet days (days/year)"
label var `var_pm25'   "PM2.5 (µg/m3)"

label var `var_gdppc'  "GDP per capita (constant 2015 US$)"
label var `var_deathr' "Death rate (per 1,000 population)"

* ---------- Summary stats helper ----------
tempname S
tempfile tmpcsv
postfile `S' str60 variable double mean sd p25 p50 p75 using "`tmpcsv'", replace

quietly foreach v in ///
    `var_PI_both' `var_PI_men' `var_PI_women' ///
    `var_tmean' bin1_tmean `bin2' `bin3' `bin4' `bin5' ///
    `var_precip' `var_cloud' `var_frost' `var_vap' `var_wet' `var_pm25' ///
    `var_gdppc' `var_deathr' {
    summarize `v', detail
    local L: var label `v'
    post `S' ("`L'") (r(mean)) (r(sd)) (r(p25)) (r(p50)) (r(p75))
}
postclose `S'

import delimited using "`tmpcsv'", clear
rename (v1 v2 v3 v4 v5 v6) (variable mean sd p25 p50 p75)

* Save machine-readable CSV
export delimited using "outputs/derived/descriptives_summary.csv", replace

* ---------- Export LaTeX (four panels) ----------
* We’ll use estpost/esttab to format nicely with booktabs.
cap which estpost
if _rc ssc install estout, replace

* Panel A
estpost tabstat ///
    `var_PI_both' `var_PI_men' `var_PI_women', ///
    statistics(mean sd p25 p50 p75) columns(statistics)

esttab using "outputs/tables/supplementary/Table_S2.tex", replace ///
    booktabs fragment nomtitle noobs label nonote ///
    collabels("Mean" "Std. Dev." "Pctl.25" "Pctl.50" "Pctl.75") ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") ///
    varwidth(38) ///
    prehead("\documentclass{article}
\usepackage{booktabs}
\usepackage[margin=2.5cm]{geometry}
\begin{document}
\begin{table}[htbp]
\centering
\caption{Descriptive Statistics (2000--2022)}
\begin{tabular}{lccccc}
\toprule
& Mean & Std. Dev. & Pctl.25 & Pctl.50 & Pctl.75 \\
\midrule
\multicolumn{6}{l}{\textbf{Panel A. Age-Standardized PI Prevalence (\%)}}\\") ///
    postfoot("")

* Panel B
estpost tabstat ///
    `var_tmean' bin1_tmean `bin2' `bin3' `bin4' `bin5', ///
    statistics(mean sd p25 p50 p75) columns(statistics)

esttab using "outputs/tables/supplementary/Table_S2.tex", append ///
    booktabs fragment nomtitle noobs label nonote ///
    collabels(none) ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") ///
    varwidth(38) ///
    prehead("\addlinespace
\multicolumn{6}{l}{\textbf{Panel B. Population-Weighted Monthly Mean Temp.}}\\") ///
    postfoot("")

* Panel C
estpost tabstat ///
    `var_precip' `var_cloud' `var_frost' `var_vap' `var_wet' `var_pm25', ///
    statistics(mean sd p25 p50 p75) columns(statistics)

esttab using "outputs/tables/supplementary/Table_S2.tex", append ///
    booktabs fragment nomtitle noobs label nonote ///
    collabels(none) ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") ///
    varwidth(38) ///
    prehead("\addlinespace
\multicolumn{6}{l}{\textbf{Panel C. Population-Weighted Climate Confounders}}\\") ///
    postfoot("")

* Panel D
estpost tabstat ///
    `var_gdppc' `var_deathr', ///
    statistics(mean sd p25 p50 p75) columns(statistics)

esttab using "outputs/tables/supplementary/Table_S2.tex", append ///
    booktabs fragment nomtitle noobs label nonote ///
    collabels(none) ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f))") ///
    varwidth(38) ///
    prehead("\addlinespace
\multicolumn{6}{l}{\textbf{Panel D. Socioeconomic and Health Confounders}}\\") ///
    postfoot("\midrule
\multicolumn{6}{l}{\footnotesize Notes: For each bin the reported mean is the average number of months/year in that interval.} \\
\bottomrule
\end{tabular}
\end{table}
\end{document}")

display as result "Done: outputs/tables/supplementary/Table_S2.tex"
*****************************************************

