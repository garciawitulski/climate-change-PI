*******************************************************
* 05_table_S6.do — Results by income group
* Outcome: PI0 (both sexes)
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/tables/supplementary/Table_S6.tex
*   - outputs/derived/coefficients/coefficients_for_figures_income.csv
*******************************************************
version 15.0
clear all
set more off

* 0) Load processed data (repo-relative path)
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

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

* 2) Income groups
* Expect income_grp (World Bank coding). Generate dummies inc_1 ... inc_K
capture confirm variable income_grp
if _rc {
    di as error "Variable income_grp not found. Please adjust to your income variable."
    * exit 198
}
tabulate income_grp, generate(inc_)   // inc_1, inc_2, inc_3, inc_4, (inc_5 if present)

* Define groups:
* High-income (HIC): categories 1 or 2
* Low- and middle-income (LMIC): categories 3, 4, (and 5 if present)
local hic_cond   "(inc_1==1 | inc_2==1)"
local lmic_cond  "(inc_3==1 | inc_4==1 | (c(rc)!=0 ? 0 : 0))"
* If inc_5 exists, include it in LMICs
capture confirm variable inc_5
if !_rc local lmic_cond "(inc_3==1 | inc_4==1 | inc_5==1)"

* 3) Regressors
local bins      "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls  "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socioecon "lnGDPpc deathr lnpm25"

* 4) Estimate fully-adjusted models by income group
eststo clear

quietly areg PI0 `bins' `controls' `socioecon' `trendvar' if `lmic_cond', absorb(objectid) vce(cluster objectid)
estadd scalar r2adj = e(r2_a)
estadd scalar nobs  = e(N)
estadd local  fe    "Country FE + trends"
eststo m_lmic

quietly areg PI0 `bins' `controls' `socioecon' `trendvar' if `hic_cond', absorb(objectid) vce(cluster objectid)
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
        lnGDPpc "ln(GDP per capita)" ///
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
    prehead("\begin{table}[H]\n\centering\n\caption{Results by income group — Outcome: Age-standardized physical inactivity (PI0), 2000–2022}\n\begin{tabular}{lcc}\n\toprule") ///
    prefoot("\midrule") ///
    postfoot("\bottomrule\n\\end{tabular}\n\\begin{minipage}{0.95\\textwidth}\n\\footnotesize\\textit{Notes:} Fully adjusted country fixed-effects models with country-specific linear trends; standard errors clustered by country. LMICs include lower-middle, upper-middle, and low-income categories (and unclassified if applicable); HICs include high-income categories. Significance: * p<0.10, ** p<0.05, *** p<0.01.\n\\end{minipage}\n\\end{table}")

* 6) Export coefficients for figures (one CSV: LMICs vs HICs)
tempfile coef_all
preserve
clear
set obs 0
gen bin      = .
gen coef     = .
gen ci_lower = .
gen ci_upper = .
gen group    = ""   // "LMICs" / "HICs"
gen outcome  = "PI0"
save `coef_all', replace
restore

program define _append_coef, rclass
    * args: group_label (LMICs/HICs)  cond_expr
    args glabel gcond

    quietly areg PI0 `bins' `controls' `socioecon' `trendvar' if `gcond', absorb(objectid) vce(cluster objectid)
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    preserve
    clear
    set obs 5
    gen bin      = _n
    gen coef     = 0
    gen ci_lower = .
    gen ci_upper = .
    gen group    = "`glabel'"
    gen outcome  = "PI0"

    foreach vv in total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean {
        local k = substr("`vv'", -1, 1)  // 2..5
        local p = colnumb(`b', "`vv'")
        if `p' < . {
            replace coef     = `b'[1, `p']                                 if bin==`k'
            replace ci_lower = `b'[1, `p'] - 1.96*sqrt(`V'[`p', `p'])      if bin==`k'
            replace ci_upper = `b'[1, `p'] + 1.96*sqrt(`V'[`p', `p'])      if bin==`k'
        }
    }

    tempfile tmp
    save `tmp'
    use `coef_all', clear
    append using `tmp'
    save `coef_all', replace
    restore
end

_append_coef "LMICs" `lmic_cond'
_append_coef "HICs"  `hic_cond'

use `coef_all', clear
export delimited using "outputs/derived/coefficients/coefficients_for_figures_income.csv", replace
*******************************************************

