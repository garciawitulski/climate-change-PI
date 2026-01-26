*******************************************************
* 08_table_S10.do — Temperature effects stratified by median age
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/tables/supplementary/Table_S10a_medageStrata_PI0.tex (Both sexes)
*   - outputs/tables/supplementary/Table_S10b_medageStrata_PI1.tex (Men)
*   - outputs/tables/supplementary/Table_S10c_medageStrata_PI2.tex (Women)
*
* Description:
*   Estimates temperature-physical inactivity relationship stratified by
*   terciles of country-level median age (2000-2022 average).
*   Includes formal test of difference in Bin 5 effect between T3 (oldest)
*   and T1 (youngest) countries using pooled interaction model.
*******************************************************
version 15.0
clear all
set more off

* ========== 0) Setup and load data ==========
local OUTDIR_TAB "outputs/tables/supplementary"

* Ensure output directories exist
cap mkdir "outputs"
cap mkdir "outputs/tables"
cap mkdir "`OUTDIR_TAB'"

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

* Detect median age variable
local med_candidates "Median_age median_age MedianAge medianage Median_age__merged Median_age_ Median age"
local medvar ""
foreach v of local med_candidates {
    capture confirm variable `v'
    if !_rc {
        local medvar "`v'"
        continue, break
    }
}
if "`medvar'"=="" {
    di as error "Median age variable not found. Tried: `med_candidates'"
    exit 198
}
di as text "Using median age variable: `medvar'"

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

* ========== 2) Define variable lists ==========
local outcomes "pi0 pi1 pi2"   // Both sexes, men, women
local bins     "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socio    "`gdpvar' deathr lnpm25"

* ========== 3) Create median age terciles ==========
* Compute country-level mean of median age across all years (2000-2022)
bys objectid: egen medage_mean = mean(`medvar')

* Create terciles (1 = youngest, 2 = middle, 3 = oldest countries)
xtile medage_terc = medage_mean, nq(3)
label define medage3 1 "T1 (Low)" 2 "T2 (Middle)" 3 "T3 (High)", replace
label values medage_terc medage3

* Summary statistics of terciles
di as text _n "=== Median Age Tercile Distribution ===" _n
tabstat medage_mean, by(medage_terc) stat(n mean min max) nototal

* ========== 4) Run stratified regressions and create tables ==========
foreach dep of local outcomes {

    di as text _n "========== Estimating models for `dep' =========="

    eststo clear

    * --- T1: Countries with low median age (youngest) ---
    di as text "  - Tercile 1 (youngest countries)..."
    quietly areg `dep' `bins' `controls' `socio' `trendvar' if medage_terc==1, ///
        absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE"
    estadd local  trend "Year × Country"
    estadd local  group "T1 (Low)"
    eststo T1

    * --- T2: Countries with middle median age ---
    di as text "  - Tercile 2 (middle-aged countries)..."
    quietly areg `dep' `bins' `controls' `socio' `trendvar' if medage_terc==2, ///
        absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE"
    estadd local  trend "Year × Country"
    estadd local  group "T2 (Middle)"
    eststo T2

    * --- T3: Countries with high median age (oldest) ---
    di as text "  - Tercile 3 (oldest countries)..."
    quietly areg `dep' `bins' `controls' `socio' `trendvar' if medage_terc==3, ///
        absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local  fe    "Country FE"
    estadd local  trend "Year × Country"
    estadd local  group "T3 (High)"
    eststo T3

    * ========== 5) Formal test: T3 - T1 difference in Bin 5 effect ==========
    di as text "  - Running pooled interaction model for difference test..."

    * Pooled model with tercile × Bin 5 interaction
    quietly areg `dep' ///
        i.medage_terc##i.total_bin_5_tmean ///
        total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean ///
        `controls' `socio' `trendvar', ///
        absorb(objectid) vce(cluster objectid)

    * Test: Bin 5 effect in T3 - Bin 5 effect in T1
    quietly lincom 3.medage_terc#1.total_bin_5_tmean - 1.medage_terc#1.total_bin_5_tmean

    scalar diff_b  = r(estimate)
    scalar diff_p  = r(p)
    scalar diff_lb = r(lb)
    scalar diff_ub = r(ub)

    di as text "    Difference (T3 - T1) for Bin 5: " as result %9.3f diff_b ///
        as text " (95% CI: [" as result %9.3f diff_lb as text ", " as result %9.3f diff_ub ///
        as text "], p = " as result %9.4f diff_p as text ")"

    * Inject test results into all model estimates
    foreach m in T1 T2 T3 {
        estimates restore `m'
        estadd scalar bin5_diff_b  = diff_b
        estadd scalar bin5_diff_p  = diff_p
        estadd scalar bin5_diff_lb = diff_lb
        estadd scalar bin5_diff_ub = diff_ub
        eststo `m'
    }

    * ========== 6) Export LaTeX table ==========

    * Determine outcome label and filename
    local out_label = cond("`dep'"=="pi0", "Both sexes", ///
                      cond("`dep'"=="pi1", "Men", "Women"))
    local fname = cond("`dep'"=="pi0", "Table_S10a_medageStrata_PI0.tex", ///
                  cond("`dep'"=="pi1", "Table_S10b_medageStrata_PI1.tex", ///
                       "Table_S10c_medageStrata_PI2.tex"))

    * Variable order in table
    local roworder `bins' `controls' `gdpvar' deathr lnpm25

    * Coefficient labels
    local cl_bins ///
        total_bin_2_tmean "Bin 2 [4.2–13.4°C)" ///
        total_bin_3_tmean "Bin 3 [13.4–21.8°C)" ///
        total_bin_4_tmean "Bin 4 [21.8–27.8°C)" ///
        total_bin_5_tmean "Bin 5 (>27.8°C)"

    local cl_others ///
        `gdpvar' "ln(GDP per capita)" ///
        deathr "Death Rate" ///
        lnpm25 "ln(PM2.5)" ///
        precipitation_weighted "Precipitation" ///
        cld_weighted "Cloud Cover" ///
        frs_weighted "Frost Days" ///
        vap_weighted "Vapor Pressure" ///
        wet_weighted "Wet Days"

    * Column titles
    local col1 "T1 (Low)"
    local col2 "T2 (Middle)"
    local col3 "T3 (High)"

    * Export table
    di as text "  - Exporting table: `fname'"
    esttab T1 T2 T3 using "`OUTDIR_TAB'/`fname'", replace ///
        label booktabs fragment collabels(none) nogaps ///
        order(`roworder') ///
        coeflabels(`cl_bins' `cl_others') ///
        refcat(total_bin_2_tmean "{\it Reference: Bin 1 (<4.2°C)}", nolabel) ///
        mtitles("`col1'" "`col2'" "`col3'") ///
        cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        stats(group fe trend ///
              bin5_diff_b bin5_diff_p ///
              r2adj nobs, ///
              labels("\textbf{Age Stratum}" "\textbf{Fixed Effects}" "\textbf{Trend}" ///
                     "\textbf{Bin 5: T3$-$T1 (pp)}" "\textbf{Bin 5: T3$-$T1 $p$-value}" ///
                     "\textbf{Adjusted $R^2$}" "\textbf{Observations}") ///
              fmt(%s %s %s %9.3f %9.4f %9.2f %9.0f)) ///
        prehead("\begin{table}[H]" _n "\centering" _n ///
                "\caption{Temperature bins stratified by country median age terciles — `out_label' (2000–2022)}" _n ///
                "\label{tab:S11_`dep'}" _n ///
                "\begin{tabular}{lccc}" _n "\toprule" _n ///
                " & \multicolumn{3}{c}{`out_label'} \\\\" _n ///
                "\cmidrule(lr){2-4}" _n ///
                " & `col1' & `col2' & `col3' \\\\") ///
        prefoot("\midrule") ///
        postfoot("\bottomrule" _n "\end{tabular}" _n ///
                 "\begin{minipage}{0.95\textwidth}" _n ///
                 "\footnotesize\textit{Notes:} Stratification by terciles of country-level mean median age (2000–2022). " ///
                 "T1 = youngest countries; T3 = oldest countries. " ///
                 "All models include country fixed effects and country-specific linear time trends (Year$\times$Country). " ///
                 "Standard errors clustered at the country level. " ///
                 "Reference category: Bin 1 (<4.2°C). " ///
                 "Bottom rows report the difference in Bin 5 coefficient between T3 and T1 (in percentage points) " ///
                 "and its $p$-value from a pooled model with tercile$\times$Bin 5 interactions. " ///
                 "Significance: * $p<0.10$, ** $p<0.05$, *** $p<0.01$." _n ///
                 "\end{minipage}" _n "\end{table}")
}

di as result _n "=== All tables successfully generated ===" _n
di as text "Output files:"
di as text "  - Table_S10a_medageStrata_PI0.tex (Both sexes)"
di as text "  - Table_S10b_medageStrata_PI1.tex (Men)"
di as text "  - Table_S10c_medageStrata_PI2.tex (Women)"
di as text "Location: `OUTDIR_TAB'/"
*******************************************************
