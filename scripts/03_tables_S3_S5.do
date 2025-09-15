*************************************************************
* 01_tables_S3_S5.do — Supplementary Tables S3–S5			*
* Data: data/processed/processed_data.csv					*
* Outputs: outputs/tables/supplementary/Table_S3.tex ... S5 *
************************************************************* 
version 15.0
clear all
set more off

* Load processed data
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

* EXPECTED VARIABLES:
* - Outcomes: pi0 (both sexes), pi1 (men), pi2 (women)
* - Exposure bins: total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean
* - Controls: precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted
* - Socioecon/health: lnGDPpc deathr lnpm25
* - FE id: objectid
* - Trend: year_by_country  (auto-rename from "año_by_country" in 00_config)

rename año_by_country year_by_country
* Locals
local bins     "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socio    "lngdppc deathr lnpm25"

* Map outcomes to table file names and pretty labels
* pi0 = both sexes -> S3 ; pi1 = men -> S4 ; pi2 = women -> S5
foreach y in pi0 pi1 pi2 {
    eststo clear

    * Model 1: Unadjusted (OLS)
    qui reg `y' `bins', vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local fe "No"
    eststo m1

    * Model 2: Country FE (areg)
    qui areg `y' `bins', absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local fe "Country FE"
    eststo m2

    * Model 3: + Environmental controls
    qui areg `y' `bins' `controls', absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local fe "Country FE"
    eststo m3

    * Model 4: + Environmental + Socioeconomic/Health
    qui areg `y' `bins' `controls' `socio', absorb(objectid) vce(cluster objectid)
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local fe "Country FE"
    eststo m4

    * Model 5: + Country-specific linear trends
    capture confirm variable year_by_country
    if _rc {
        di as error "Variable year_by_country not found. Please create it before running Model 5."
        qui areg `y' `bins' `controls' `socio', absorb(objectid) vce(cluster objectid)
        estadd local trend "—"
    }
    else {
        qui areg `y' `bins' `controls' year_by_country `socio', absorb(objectid) vce(cluster objectid)
        estadd local trend "Year × Country"
    }
    estadd scalar r2adj = e(r2_a)
    estadd scalar nobs  = e(N)
    estadd local fe "Country FE"
    eststo m5

    * Labels per outcome
    local out_label = cond("`y'"=="pi0","Both sexes", cond("`y'"=="pi1","Men","Women"))
    local fname = cond("`y'"=="pi0","Table_S3.tex", cond("`y'"=="pi1","Table_S4.tex","Table_S5.tex"))

    esttab m1 m2 m3 m4 m5 using "outputs/tables/supplementary/`fname'", replace ///
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
        mtitles("Model 1" "Model 2" "Model 3" "Model 4" "Model 5") ///
        cells(b(fmt(%9.3f) star) ci(par fmt(%9.3f))) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        stats(fe r2adj nobs, ///
              labels("\textbf{Fixed Effects}" "\textbf{Adjusted $R^2$}" "\textbf{Observations}") ///
              fmt(%s %9.2f %9.0f)) ///
        prehead("\begin{table}[H]\n\centering\n\caption{Association Between Extreme Temperatures and Age-Standardized Physical Inactivity Prevalence — `out_label' (2000–2022)}\n\begin{tabular}{lccccc}\n\toprule\n & \multicolumn{5}{c}{`out_label'} \\\\ \n\cmidrule(lr){2-6}\n & Model 1 & Model 2 & Model 3 & Model 4 & Model 5 \\\\") ///
        prefoot("\midrule") ///
        postfoot("\bottomrule\n\\end{tabular}\n\\begin{minipage}{0.95\\textwidth}\n\\footnotesize\\textit{Notes:} Model 1 = Unadjusted; Model 2 = Country fixed effects; Model 3 = + environmental controls; Model 4 = + socioeconomic/health controls; Model 5 = + country-specific linear trends. Standard errors clustered by country. Significance: * p<0.10, ** p<0.05, *** p<0.01.\n\\end{minipage}\n\\end{table}")

}

* Optional: export coefficients for figures (Model 5)
foreach y in pi0 pi1 pi2 {
    capture noisily areg `y' `bins' `controls' year_by_country `socio', absorb(objectid) vce(cluster objectid)
    if _rc continue
    matrix b = e(b)
    matrix V = e(V)

    clear
    set obs 5
    gen bin      = _n
    gen coef     = 0
    gen ci_lower = .
    gen ci_upper = .
    gen model    = 5
    gen outcome  = "`y'"

    forvalues j = 2/5 {
        replace coef     = b[1, `=`j'-1']                             if bin==`j'
        replace ci_lower = b[1, `=`j'-1'] - 1.96*sqrt(V[`=`j'-1',`=`j'-1']) if bin==`j'
        replace ci_upper = b[1, `=`j'-1'] + 1.96*sqrt(V[`=`j'-1',`=`j'-1']) if bin==`j'
    }

    export delimited using "outputs/derived/coefficients/coefficients_for_figures_`y'.csv", replace
}
*******************************************************
