*******************************************************
* 05_table_S6.do — Results by income group
* Outcome: pi0 (both sexes)
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/tables/supplementary/Table_S6.tex
*******************************************************
version 15.0
clear all
set more off

* 0) Load processed data (repo-relative path)
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

rename año_by_country year_by_country

* 1) Detect trend variable (year × country)
local trendvar ""
capture confirm variable year_by_country
if !_rc local trendvar "year_by_country"
capture confirm variable año_by_country
if (`"`trendvar'"'=="") & !_rc local trendvar "año_by_country"
if "`trendvar'"=="" {
    di as error "Trend variable not found: expected year_by_country or año_by_country."
    * exit 198
}

* Optional panel declaration
capture confirm variable año
if !_rc {
    xtset objectid año
}
else {
    capture confirm variable year
    if !_rc xtset objectid year
}

* 2) Income groups (robusto a tipo/etiquetas)
capture confirm variable income_grp
if _rc {
    di as error "Variable income_grp not found. Please adjust to your income variable."
    * exit 198
}

* Crear versión string (si income_grp es numérica etiquetada)
capture confirm string variable income_grp
if _rc {
    tempvar _incstr
    decode income_grp, gen(`_incstr')
}
else {
    local _incstr income_grp
}

* Definir condiciones:
* HIC: "High income: OECD" o "High income: nonOECD"
* LMIC: "Upper middle income", "Lower middle income", "Low income"
local hic_cond  inlist(`_incstr', "1. High income: OECD", "2. High income: nonOECD")
local lmic_cond inlist(`_incstr', "3. Upper middle income", "4. Lower middle income", "5. Low income")

* 2b) Asegurar variable para FE/cluster sea numérica
capture confirm numeric variable objectid
if _rc {
    encode objectid, gen(objectid_num)
    local absorb_var objectid_num
}
else {
    local absorb_var objectid
}

* 3) Regressors
local bins      "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls  "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socioecon "lngdppc deathr lnpm25"

* 4) Estimate fully-adjusted models by income group
eststo clear

quietly areg pi0 `bins' `controls' `socioecon' `trendvar' if `lmic_cond', ///
    absorb(`absorb_var') vce(cluster `absorb_var')
estadd scalar r2adj = e(r2_a)
estadd scalar nobs  = e(N)
estadd local  fe    "Country FE + trends"
eststo m_lmic

quietly areg pi0 `bins' `controls' `socioecon' `trendvar' if `hic_cond', ///
    absorb(`absorb_var') vce(cluster `absorb_var')
estadd scalar r2adj = e(r2_a)
estadd scalar nobs  = e(N)
estadd local  fe    "Country FE + trends"
eststo m_hic

* 5) Export LaTeX table
esttab m_lmic m_hic using "outputs/tables/supplementary/Table_S6.tex", replace ///
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
        lngdppc "ln(GDP per capita)" ///
        deathr "Death Rate" ///
        lnpm25 "ln(PM2.5)" ///
    ) ///
    refcat(total_bin_2_tmean "Bin 1 (<4.2°C) (ref.)", nolabel) ///
    mtitles("Low- and middle-income (LMICs)" "High-income (HICs)") ///
    cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(fe r2adj nobs, ///
          labels("\textbf{Fixed Effects}" "\textbf{Adjusted $R^2$}" "\textbf{Observations}") ///
          fmt(%s %9.2f %9.0f)) ///
    prehead("\begin{table}[H]\n\centering\n\caption{Results by income group — Outcome: Age-standardized physical inactivity (pi0), 2000–2022}\n\begin{tabular}{lcc}\n\toprule") ///
    prefoot("\midrule") ///
    postfoot("\bottomrule\n\\end{tabular}\n\\begin{minipage}{0.95\\textwidth}\n\\footnotesize\\textit{Notes:} Fully adjusted country fixed-effects models with country-specific linear trends; standard errors clustered by country. LMICs include lower-middle, upper-middle, and low-income categories; HICs include high-income (OECD and nonOECD). Significance: * p<0.10, ** p<0.05, *** p<0.01.\n\\end{minipage}\n\\end{table}")


