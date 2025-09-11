*******************************************************
* 02_table1_manuscript.do — Manuscript Table 1
* Goal: Fully adjusted FE model (+ optional Temperature Range)
*******************************************************
version 16.0
clear all
set more off

import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

local bins     "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socio    "lnGDPpc deathr lnpm25"

* Optional variable name for temperature range (edit if needed)
local trvar "t_range_weighted"

capture confirm variable year_by_country
if _rc {
    di as error "Variable year_by_country not found. Please create it before running."
}

* Both sexes as default
local y "PI0"

eststo clear
qui areg `y' `bins' `controls' year_by_country `socio', absorb(objectid) vce(cluster objectid)
estadd local fe "Country FE + trends"
if !_rc {
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
}

* Try adding temperature range if present
capture confirm variable `trvar'
if !_rc {
    qui areg `y' `bins' `controls' `trvar' year_by_country `socio', absorb(objectid) vce(cluster objectid)
    eststo m_fe
    estadd local fe "Country FE + trends"
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
}
else {
    eststo m_fe
}

esttab m_fe using "outputs/tables/manuscript/Table1.tex", replace ///
    label booktabs fragment collabels(none) ///
    coeflabels( ///
        total_bin_2_tmean "Bin 2 [4.2–13.4°C)" ///
        total_bin_3_tmean "Bin 3 [13.4–21.8°C)" ///
        total_bin_4_tmean "Bin 4 [21.8–27.8°C)" ///
        total_bin_5_tmean "Bin 5 (>27.8°C)" ///
        precipitation_weighted "Precipitation" ///
        cld_weighted "Cloud Cover" ///
        frs_weighted "Frost Days" ///
        vap_weighted "Vapor Pressure" ///
        wet_weighted "Wet Days" ///
        lnGDPpc "ln(GDP per capita)" ///
        deathr "Death Rate" ///
        lnpm25 "ln(PM2.5)" ///
        `trvar' "Temperature Range" ///
    ) ///
    refcat(total_bin_2_tmean "Bin 1 (<4.2°C) (ref.)", nolabel) ///
    cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(fe r2adj nobs, labels("\textbf{Fixed Effects}" "\textbf{Adjusted $R^2$}" "\textbf{Observations}") fmt(%s %9.2f %9.0f)) ///
    prehead("\begin{table}[H]\n\centering\n\caption{Fully adjusted fixed-effects model — Both sexes}\n\begin{tabular}{lc}\n\toprule\n & (1) \\\\") ///
    prefoot("\midrule") ///
    postfoot("\bottomrule\n\\end{tabular}\n\\begin{minipage}{0.95\\textwidth}\n\\footnotesize\\textit{Notes:} Country fixed effects and country-specific linear trends; SEs clustered by country. Significance: * p<0.10, ** p<0.05, *** p<0.01.\n\\end{minipage}\n\\end{table}")
*******************************************************
