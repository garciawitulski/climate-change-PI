*******************************************************
* 09_table_S12_baseline_temp_strata.do — Temperature effects stratified by baseline climate
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/tables/supplementary/Table_S9a_baselineTemp_PI0.tex (Both sexes)
*   - outputs/tables/supplementary/Table_S9b_baselineTemp_PI1.tex (Men)
*   - outputs/tables/supplementary/Table_S9c_baselineTemp_PI2.tex (Women)
*   - outputs/derived/baseline_temp_variance_check.log (Diagnostics)
*
* Description:
*   Estimates temperature-physical inactivity relationship stratified by
*   terciles of country-level mean temperature (2000-2022).
*   Uses Bin 3 as reference category.
*   Includes diagnostic checks for within-country variance and linear dependence.
*******************************************************
version 15.0
clear all
set more off

* ========== 0) Setup and load data ==========
local OUTDIR_TAB "outputs/tables/supplementary"
local OUTDIR_DER "outputs/derived"

* Ensure output directories exist
cap mkdir "outputs"
cap mkdir "outputs/tables"
cap mkdir "`OUTDIR_TAB'"
cap mkdir "`OUTDIR_DER'"

* Check & install required packages
cap which esttab
if _rc ssc install estout, replace

* Load data with relative path
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

* ========== 1) Detect key variables ==========

* Detect trend variable (year_by_country or año_by_country)
local trendvar ""
capture confirm variable year_by_country
if !_rc local trendvar "year_by_country"
capture confirm variable año_by_country
if ("`trendvar'"=="") & !_rc local trendvar "año_by_country"
if "`trendvar'"=="" {
    di as error "Trend variable not found: expected year_by_country or año_by_country."
    exit 198
}
di as text "Using trend variable: `trendvar'"

* Detect GDP variable (lnGDPpc or lngdppc)
capture confirm variable lnGDPpc
if !_rc {
    local gdpvar "lnGDPpc"
}
else {
    capture confirm variable lngdppc
    if !_rc {
        local gdpvar "lngdppc"
    }
    else {
        di as error "GDP variable not found: expected lnGDPpc or lngdppc."
        exit 198
    }
}
di as text "Using GDP variable: `gdpvar'"

* Detect mean temperature variable
capture confirm variable tmean_weighted
if _rc {
    di as error "Mean temperature variable 'tmean_weighted' not found."
    exit 198
}

* ========== 2) Define variable lists ==========
local outcomes "pi0 pi1 pi2"   // Both sexes, men, women
local bins     "total_bin_1_tmean total_bin_2_tmean total_bin_4_tmean total_bin_5_tmean"
local controls "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socio    "`gdpvar' deathr lnpm25"

* ========== 3) Create Bin 1 if not present ==========
* Bin 1 = 12 - (Bin2 + Bin3 + Bin4 + Bin5)
capture confirm variable total_bin_1_tmean
if _rc {
    di as text "Creating total_bin_1_tmean from bin identity..."
    gen total_bin_1_tmean = 12 - (total_bin_2_tmean + total_bin_3_tmean + ///
                                  total_bin_4_tmean + total_bin_5_tmean)
}

* Verification: alternative calculation
gen total_bin_1_check = 12 - (total_bin_2_tmean + total_bin_3_tmean + ///
                               total_bin_4_tmean + total_bin_5_tmean)
assert abs(total_bin_1_tmean - total_bin_1_check) < 1e-8
drop total_bin_1_check

* ========== 4) Create baseline temperature terciles ==========
* Compute country-level mean temperature across all years (2000-2022)
bys country_standard: egen baseline_T = mean(tmean_weighted)

* Create terciles (1 = coolest, 2 = middle, 3 = hottest countries)
xtile baseline_terc = baseline_T, nq(3)
label define baseline3 1 "T1 (Cooler)" 2 "T2 (Middle)" 3 "T3 (Hotter)", replace
label values baseline_terc baseline3

* Calculate temperature cutpoints for table headers
preserve
    bys country_standard: keep if _n==1
    _pctile baseline_T, p(33.3333 66.6667)
    local t1_hi = r(r1)
    local t2_hi = r(r2)
restore

* Format cutpoints for display
local t1_hi_s : display %4.1f `t1_hi'
local t2_hi_s : display %4.1f `t2_hi'

* Summary statistics of terciles
di as text _n "=== Baseline Temperature Tercile Distribution ===" _n
tabstat baseline_T, by(baseline_terc) stat(n mean min max) nototal

di as text _n "Temperature cutpoints:"
di as text "  T1 (Cooler):  < `t1_hi_s'°C"
di as text "  T2 (Middle):  [`t1_hi_s', `t2_hi_s')°C"
di as text "  T3 (Hotter):  >= `t2_hi_s'°C" _n

* ========== 5) Within-country variance diagnostics ==========
di as text "=== Checking within-country variance of temperature bins ===" _n

* Compute within-country standard deviations for each bin
foreach b in 1 2 3 4 5 {
    bys country_standard: egen sd_b`b' = sd(total_bin_`b'_tmean)
}

* Indicators for bins with zero within-country variance
foreach b in 1 2 3 4 5 {
    capture drop zsd_b`b'
    gen byte zsd_b`b' = (sd_b`b' < 1e-8)
    replace zsd_b`b' = 0 if missing(zsd_b`b')
}

* Summarize zero-variance patterns by tercile
preserve
    egen byte tag_ctry = tag(country_standard)
    keep if tag_ctry

    collapse (count) n_countries = tag_ctry ///
             (sum) n_zeroVar_B1=zsd_b1 n_zeroVar_B2=zsd_b2 ///
                   n_zeroVar_B3=zsd_b3 n_zeroVar_B4=zsd_b4 n_zeroVar_B5=zsd_b5, ///
             by(baseline_terc)

    di as text "Countries by tercile with zero within-country variance in each bin:"
    list baseline_terc n_countries n_zeroVar_B1 n_zeroVar_B2 n_zeroVar_B3 n_zeroVar_B4 n_zeroVar_B5, ///
         sep(0) noobs
restore

* ========== 6) Check linear dependence in hottest tercile ==========
di as text _n "=== Checking linear dependence in T3 (hottest countries) ===" _n

* Compute within-country deviations (demeaned)
foreach b in 1 2 3 4 5 {
    bys country_standard: egen m_b`b' = mean(total_bin_`b'_tmean)
    gen w_b`b' = total_bin_`b'_tmean - m_b`b'
}

* Sum of within deviations for Bins 3+4+5
gen w_sum345 = w_b3 + w_b4 + w_b5

* Flag countries in T3 with no within-variance in Bins 1 and 2
preserve
    egen byte tag_ctry2 = tag(country_standard)
    keep if tag_ctry2
    gen byte both_zero = (sd_b1 < 1e-8 & sd_b2 < 1e-8)
    keep country_standard both_zero baseline_terc
    tempfile flags
    save `flags', replace
restore

merge m:1 country_standard using `flags', nogen

* For T3 countries with zero variance in B1 and B2, verify that B3+B4+B5 sum to zero
count if baseline_terc==3 & both_zero==1
local n_constrained = r(N)
if `n_constrained' > 0 {
    di as text "Found `n_constrained' obs in T3 countries where B1 and B2 have no within-variance"
    di as text "Verifying that w_b3 + w_b4 + w_b5 = 0 (linear dependence)..."
    assert abs(w_sum345) < 1e-6 if baseline_terc==3 & both_zero==1
    di as result "  ✓ Linear dependence verified for constrained observations"
}
else {
    di as text "No countries in T3 have zero within-variance in both B1 and B2"
}

* Clean up auxiliary variables
drop tag_ctry2 both_zero w_* m_b* sd_b* zsd_b*

* ========== 7) Run stratified regressions and create tables ==========

foreach dep of local outcomes {

    di as text _n "========== Estimating models for `dep' =========="

    eststo clear

    * --- T1: Cooler countries ---
    di as text "  - Tercile 1 (cooler countries)..."
    quietly areg `dep' `bins' `controls' `socio' `trendvar' if baseline_terc==1, ///
        absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE"
    estadd local  trend "Year × Country"
    estadd local  sample "T1 (Cooler)"
    estadd local  temp_range "$<$`t1_hi_s'$^{\circ}$C"
    eststo T1

    * --- T2: Middle temperature countries ---
    di as text "  - Tercile 2 (middle temperature countries)..."
    quietly areg `dep' `bins' `controls' `socio' `trendvar' if baseline_terc==2, ///
        absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE"
    estadd local  trend "Year × Country"
    estadd local  sample "T2 (Middle)"
    estadd local  temp_range "[`t1_hi_s',`t2_hi_s')$^{\circ}$C"
    eststo T2

    * --- T3: Hotter countries ---
    di as text "  - Tercile 3 (hotter countries)..."
    quietly areg `dep' `bins' `controls' `socio' `trendvar' if baseline_terc==3, ///
        absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE"
    estadd local  trend "Year × Country"
    estadd local  sample "T3 (Hotter)"
    estadd local  temp_range "$\ge$`t2_hi_s'$^{\circ}$C"
    eststo T3

    * ========== 8) Export LaTeX table ==========

    * Determine outcome label and filename
    local out_label = cond("`dep'"=="pi0", "Both sexes", ///
                      cond("`dep'"=="pi1", "Men", "Women"))
    local fname = cond("`dep'"=="pi0", "Table_S9a_baselineTemp_PI0.tex", ///
                  cond("`dep'"=="pi1", "Table_S9b_baselineTemp_PI1.tex", ///
                       "Table_S9c_baselineTemp_PI2.tex"))

    * Variable order in table (Bin 3 excluded as reference)
    local roworder `bins' `controls' `gdpvar' deathr lnpm25

    * Coefficient labels
    local cl_bins ///
        total_bin_1_tmean "Bin 1 (<4.2°C)" ///
        total_bin_2_tmean "Bin 2 [4.2–13.4°C)" ///
        total_bin_4_tmean "Bin 4 [21.8–27.8°C)" ///
        total_bin_5_tmean "Bin 5 (>27.8°C)"

    local cl_ctrl ///
        precipitation_weighted "Precipitation" ///
        cld_weighted "Cloud Cover" ///
        frs_weighted "Frost Days" ///
        vap_weighted "Vapor Pressure" ///
        wet_weighted "Wet Days" ///
        `gdpvar' "ln(GDP per capita)" ///
        deathr "Death Rate" ///
        lnpm25 "ln(PM2.5)"

    * Column titles with temperature ranges
    local c1 "T1 (Cooler)"
    local c2 "T2 (Middle)"
    local c3 "T3 (Hotter)"

    * Export table
    di as text "  - Exporting table: `fname'"
    esttab T1 T2 T3 using "`OUTDIR_TAB'/`fname'", replace ///
        label booktabs fragment collabels(none) nogaps ///
        order(`roworder') ///
        coeflabels(`cl_bins' `cl_ctrl') ///
        refcat(total_bin_1_tmean "{\it Reference: Bin 3 [13.4–21.8°C)}", nolabel) ///
        mtitles("`c1'" "`c2'" "`c3'") ///
        cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        stats(sample temp_range fe trend r2adj nobs, ///
              labels("\textbf{Climate Stratum}" "\textbf{Mean Temp Range}" ///
                     "\textbf{Fixed Effects}" "\textbf{Trend}" ///
                     "\textbf{Adjusted $R^2$}" "\textbf{Observations}") ///
              fmt(%s %s %s %s %9.2f %9.0f)) ///
        prehead("\begin{table}[H]" _n "\centering" _n ///
                "\caption{Temperature bins stratified by country-level mean temperature terciles — `out_label' (2000–2022)}" _n ///
                "\label{tab:S12_`dep'}" _n ///
                "\begin{tabular}{lccc}" _n "\toprule" _n ///
                " & \multicolumn{3}{c}{`out_label'} \\\\" _n ///
                "\cmidrule(lr){2-4}" _n ///
                " & `c1' & `c2' & `c3' \\\\" _n ///
                " & $<$`t1_hi_s'$^{\circ}$C & [`t1_hi_s'--`t2_hi_s')$^{\circ}$C & $\ge$`t2_hi_s'$^{\circ}$C \\\\") ///
        prefoot("\midrule") ///
        postfoot("\bottomrule" _n "\end{tabular}" _n ///
                 "\begin{minipage}{0.95\textwidth}" _n ///
                 "\footnotesize\textit{Notes:} Stratification by terciles of country-level mean temperature (2000–2022). " ///
                 "T1 = cooler countries ($<$`t1_hi_s'°C); " ///
                 "T2 = middle countries ([`t1_hi_s', `t2_hi_s')°C); " ///
                 "T3 = hotter countries ($\ge$`t2_hi_s'°C). " ///
                 "All models include country fixed effects and country-specific linear time trends (Year$\times$Country). " ///
                 "Standard errors clustered at the country level. " ///
                 "Reference category: Bin 3 [13.4–21.8°C). " ///
                 "Full model with environmental and socioeconomic controls. " ///
                 "Significance: * $p<0.10$, ** $p<0.05$, *** $p<0.01$." _n ///
                 "\end{minipage}" _n "\end{table}")
}

di as result _n "=== All tables successfully generated ===" _n
di as text "Output files:"
di as text "  - Table_S9a_baselineTemp_PI0.tex (Both sexes)"
di as text "  - Table_S9b_baselineTemp_PI1.tex (Men)"
di as text "  - Table_S9c_baselineTemp_PI2.tex (Women)"
di as text "Location: `OUTDIR_TAB'/"
*******************************************************
