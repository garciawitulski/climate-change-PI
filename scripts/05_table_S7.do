*******************************************************
* 04_table_S7.do — Leave-one-region-out robustness
* Outcome: PI0 (both sexes)
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/tables/supplementary/Table_S7.tex
*   - outputs/derived/coefficients/coefficients_for_figures_regions.csv
*******************************************************
version 15.0
clear all
set more off

* 0) Load processed data (repo-relative)
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

* 1) Trend variable detection (year × country)
local trendvar ""
capture confirm variable year_by_country
if !_rc local trendvar "year_by_country"
capture confirm variable año_by_country
if (`"`trendvar'"'=="") & !_rc local trendvar "año_by_country"
if "`trendvar'"=="" {
    di as error "Trend variable not found: expected year_by_country or año_by_country."
    * exit 198
}

* Optional panel declaration (if you want)
capture confirm variable año
if !_rc {
    xtset objectid año
}
else {
    capture confirm variable year
    if !_rc xtset objectid year
}

* 2) Locals: regressors
local bins      "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls  "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socioecon "lngdppc deathr lnpm25"

* 3) Region variable → create dummies
* EDIT if your region variable has another name
capture confirm variable region_un
if _rc {
    di as error "Variable region_un not found. Please adjust the script to your region variable."
    * exit 198
}

tabulate region_un, generate(reg_)   // creates reg_1 ... reg_K for K regions
quietly count if reg_1==. & reg_2==.
if r(N) > 0 {
    di as txt "Note: some observations may have missing region."
}

* 4) Human-readable column titles (edit if your labels differ)
local reg_names "Africa Americas Asia Europe Oceania"
local mt1 "Excl. Africa"
local mt2 "Excl. Americas"
local mt3 "Excl. Asia"
local mt4 "Excl. Europe"
local mt5 "Excl. Oceania"

* If you DO have correct value labels for region_un and exactly 5 regions,
* you can try to build titles dynamically as follows (optional):
* local lblname : value label region_un
* if "`lblname'" != "" {
*     forvalues r=1/5 {
*         local nm : label `lblname' `r'
*         if "`nm'"=="" local nm "Region `r'"
*         local mt`r' "Excl. `nm'"
*     }
* }

* 5) Estimate fully adjusted model excluding one region at a time
eststo clear
forvalues r = 1/5 {
    quietly areg pi0 `bins' `controls' `socioecon' `trendvar' ///
        if reg_`r' != 1, absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE + trends"
    eststo m`r'
}

* 6) Export LaTeX table
esttab m1 m2 m3 m4 m5 using "outputs/tables/supplementary/Table_S7.tex", replace ///
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
    ) ///
    refcat(total_bin_2_tmean "Bin 1 (<4.2°C) (ref.)", nolabel) ///
    mtitles("`mt1'" "`mt2'" "`mt3'" "`mt4'" "`mt5'") ///
    cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(fe r2adj nobs, ///
          labels("\textbf{Fixed Effects}" "\textbf{Adjusted $R^2$}" "\textbf{Observations}") ///
          fmt(%s %9.2f %9.0f)) ///
    prehead("\begin{table}[H]\n\centering\n\caption{Leave-one-region-out robustness — Outcome: Age-standardized physical inactivity (PI0), 2000–2022}\n\begin{tabular}{lccccc}\n\toprule") ///
    prefoot("\midrule") ///
    postfoot("\bottomrule\n\\end{tabular}\n\\begin{minipage}{0.95\\textwidth}\n\\footnotesize\\textit{Notes:} Fully adjusted country fixed-effects models with country-specific linear trends; standard errors clustered by country. Each column excludes one region from the sample. Significance: * p<0.10, ** p<0.05, *** p<0.01.\n\\end{minipage}\n\\end{table}")


