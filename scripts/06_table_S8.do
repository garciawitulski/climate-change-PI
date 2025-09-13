*******************************************************
* 03_table_S8.do — Robustness to binning schemes
* Goal: Compare percentile, equal-width, and SD bins (outcome: PI0)
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/tables/supplementary/Table_S8.tex
*   - outputs/derived/coefficients/coefficients_for_figures_bins.csv
*******************************************************
version 15.0
clear all
set more off

* 0) Load processed data (repo-relative path)
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

* 1) Detect trend variable (year × country) and panel time var (optional)
local trendvar ""
capture confirm variable year_by_country
if !_rc local trendvar "year_by_country"
capture confirm variable año_by_country
if (_rc==0) & ("`trendvar'"=="") local trendvar "año_by_country"

if "`trendvar'"=="" {
    di as error "Trend variable not found. Expected year_by_country or año_by_country."
    * You can exit here if it's required:
    * exit 198
}

* Optional xtset (robust to Spanish/English 'year')
capture confirm variable año
if !_rc {
    xtset objectid año
}
else {
    capture confirm variable year
    if !_rc xtset objectid year
}

* 2) Controls and covariates
local controls   "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socioecon  "lnGDPpc deathr lnpm25"

* 3) Check bin variables exist (percentile / equal-width / SD)
* Percentile bins
foreach v in total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean {
    capture confirm variable `v'
    if _rc {
        di as error "Missing percentile-bin variable: `v'"
        * exit 198
    }
}
* Equal-width bins
foreach v in total_eq_tmean_bin_2 total_eq_tmean_bin_3 total_eq_tmean_bin_4 total_eq_tmean_bin_5 {
    capture confirm variable `v'
    if _rc {
        di as error "Missing equal-width-bin variable: `v'"
        * exit 198
    }
}
* SD bins
foreach v in total_sd_tmean_bin_2 total_sd_tmean_bin_3 total_sd_tmean_bin_4 total_sd_tmean_bin_5 {
    capture confirm variable `v'
    if _rc {
        di as error "Missing SD-bin variable: `v'"
        * exit 198
    }
}

* 4) Helper to standardize coefficient names across models
capture drop BIN_2 BIN_3 BIN_4 BIN_5

program define _make_bins, rclass
    * args: scheme = pct | eq | sd
    args scheme

    * Clean previous clones if any
    capture drop BIN_2 BIN_3 BIN_4 BIN_5

    if "`scheme'"=="pct" {
        clonevar BIN_2 = total_bin_2_tmean
        clonevar BIN_3 = total_bin_3_tmean
        clonevar BIN_4 = total_bin_4_tmean
        clonevar BIN_5 = total_bin_5_tmean
    }
    else if "`scheme'"=="eq" {
        clonevar BIN_2 = total_eq_tmean_bin_2
        clonevar BIN_3 = total_eq_tmean_bin_3
        clonevar BIN_4 = total_eq_tmean_bin_4
        clonevar BIN_5 = total_eq_tmean_bin_5
    }
    else if "`scheme'"=="sd" {
        clonevar BIN_2 = total_sd_tmean_bin_2
        clonevar BIN_3 = total_sd_tmean_bin_3
        clonevar BIN_4 = total_sd_tmean_bin_4
        clonevar BIN_5 = total_sd_tmean_bin_5
    }
    else {
        di as error "Unknown scheme: `scheme'"
        exit 198
    }
end

* 5) Estimate fully adjusted models for each binning scheme (PI0)
eststo clear

* Percentile bins (column 1)
_make_bins pct
quietly areg PI0 BIN_2 BIN_3 BIN_4 BIN_5 `controls' `socioecon' `trendvar', absorb(objectid) vce(cluster objectid)
estadd scalar r2adj = e(r2_a)
estadd scalar nobs  = e(N)
estadd local  fe "Country FE + trends"
eststo m_pct

* Equal-width bins (column 2)
_make_bins eq
quietly areg PI0 BIN_2 BIN_3 BIN_4 BIN_5 `controls' `socioecon' `trendvar', absorb(objectid) vce(cluster objectid)
estadd scalar r2adj = e(r2_a)
estadd scalar nobs  = e(N)
estadd local  fe "Country FE + trends"
eststo m_eq

* SD bins (column 3)
_make_bins sd
quietly areg PI0 BIN_2 BIN_3 BIN_4 BIN_5 `controls' `socioecon' `trendvar', absorb(objectid) vce(cluster objectid)
estadd scalar r2adj = e(r2_a)
estadd scalar nobs  = e(N)
estadd local  fe "Country FE + trends"
eststo m_sd

* 6) Export LaTeX table (full table env; portable path)
esttab m_pct m_eq m_sd using "outputs/tables/supplementary/Table_S8.tex", replace ///
    label booktabs collabels(none) ///
    coeflabels( ///
        BIN_2 "Bin 2" ///
        BIN_3 "Bin 3" ///
        BIN_4 "Bin 4" ///
        BIN_5 "Bin 5" ///
        precipitation_weighted "Precipitation" ///
        cld_weighted "Cloud Cover" ///
        frs_weighted "Frost Days" ///
        vap_weighted "Vapor Pressure" ///
        wet_weighted "Wet Days" ///
        lnGDPpc "ln(GDP per capita)" ///
        deathr "Death Rate" ///
        lnpm25 "ln(PM2.5)" ///
    ) ///
    refcat(BIN_2 "Bin 1 (ref.)", nolabel) ///
    mtitles("Percentile bins" "Equal-width bins" "SD bins") ///
    cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    stats(fe r2adj nobs, ///
          labels("\textbf{Fixed Effects}" "\textbf{Adjusted $R^2$}" "\textbf{Observations}") ///
          fmt(%s %9.2f %9.0f)) ///
    prehead("\begin{table}[H]\n\centering\n\caption{Robustness to temperature binning schemes — Outcome: Age-standardized physical inactivity (PI0), 2000–2022}\n\begin{tabular}{lccc}\n\toprule\n & Percentile bins & Equal-width bins & SD bins \\\\ \n\midrule") ///
    postfoot("\bottomrule\n\\end{tabular}\n\\begin{minipage}{0.95\\textwidth}\n\\footnotesize\\textit{Notes:} Fully adjusted country fixed-effects models with country-specific linear trends; standard errors clustered by country. Bin 1 is the omitted (coolest) category under each scheme. Significance: * p<0.10, ** p<0.05, *** p<0.01.\n\\end{minipage}\n\\end{table}")

* 7) Export coefficients for figures (one CSV combining the 3 schemes)
tempfile coef_all
preserve
clear
set obs 0
gen bin       = .
gen coef      = .
gen ci_lower  = .
gen ci_upper  = .
gen model     = ""     // "pct", "eq", "sd"
gen outcome   = "PI0"
save `coef_all', replace
restore

foreach S in pct eq sd {
    * Re-build BIN_* for scheme S and re-estimate to read e(b), e(V)
    _make_bins `S'
    quietly areg PI0 BIN_2 BIN_3 BIN_4 BIN_5 `controls' `socioecon' `trendvar', absorb(objectid) vce(cluster objectid)

    matrix b = e(b)
    matrix V = e(V)

    preserve
    clear
    set obs 5
    gen bin      = _n
    gen coef     = 0
    gen ci_lower = .
    gen ci_upper = .
    gen model    = "`S'"
    gen outcome  = "PI0"

    forvalues j = 2/5 {
        replace coef     = b[1, `=`j'-1'] - 0    if bin==`j'
        replace ci_lower = b[1, `=`j'-1'] - 1.96*sqrt(V[`=`j'-1', `=`j'-1']) if bin==`j'
        replace ci_upper = b[1, `=`j'-1'] + 1.96*sqrt(V[`=`j'-1', `=`j'-1']) if bin==`j'
    }

    tempfile tmp
    save `tmp'
    use `coef_all', clear
    append using `tmp'
    save `coef_all', replace
    restore
}

use `coef_all', clear
export delimited using "outputs/derived/coefficients/coefficients_for_figures_bins.csv", replace
*******************************************************

