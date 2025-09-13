*******************************************************
* 06_tables_S9_S10.do — Global & country-level SSP combinations
* Data: data/processed/processed_data.csv
* Outputs:
*   - outputs/derived/linear_combinations_global.csv         (S9 data)
*   - outputs/tables/supplementary/Table_S9.tex              (S9 LaTeX)
*   - outputs/derived/estimates_by_country.csv               (S10 data)
*   - outputs/tables/supplementary/Table_S10.tex             (S10 LaTeX summary)
*******************************************************
version 15.0
clear all
set more off

* ========== 0) Load data and detect trend variable ==========
import delimited "data/processed/processed_data.csv", clear varn(1) encoding(UTF-8)

local trendvar ""
capture confirm variable year_by_country
if !_rc local trendvar "year_by_country"
capture confirm variable año_by_country
if ("`trendvar'"=="") & !_rc local trendvar "año_by_country"
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

* ========== 1) Locals and checks ==========
local outcomes  "PI0 PI1 PI2"   // both sexes, men, women
local bins      "total_bin_2_tmean total_bin_3_tmean total_bin_4_tmean total_bin_5_tmean"
local controls  "precipitation_weighted cld_weighted frs_weighted vap_weighted wet_weighted"
local socioecon "lnGDPpc deathr lnpm25"
local ssp_list  "ssp126 ssp245 ssp585"

* Check SSP indicator variables exist (D2..D5 for each SSP)
foreach ssp of local ssp_list {
    foreach d in 2 3 4 5 {
        capture confirm variable D`d'_`ssp'
        if _rc {
            di as error "Missing variable: D`d'_`ssp'. Please ensure SSP indicators exist."
            * exit 198
        }
    }
}

* ========== 2) TABLE S9 — Global linear combinations ==========
tempfile comb_results
tempname H
postfile `H' str6 dep str6 ssp double(b se t) using "`comb_results'", replace

foreach dep of local outcomes {
    di as text "Running global FE model for `dep'..."
    quietly areg `dep' `bins' `controls' `trendvar' `socioecon', absorb(objectid) vce(cluster objectid)

    * Compute global means of D2..D5 for each SSP and the weighted linear combo
    foreach ssp of local ssp_list {
        quietly summarize D2_`ssp'
        local w2 = r(mean)
        quietly summarize D3_`ssp'
        local w3 = r(mean)
        quietly summarize D4_`ssp'
        local w4 = r(mean)
        quietly summarize D5_`ssp'
        local w5 = r(mean)

        * Weighted combination of bin coefficients (post so we can read e(b), e(V) if needed)
        quietly lincom `w2'*total_bin_2_tmean + `w3'*total_bin_3_tmean + ///
                        `w4'*total_bin_4_tmean + `w5'*total_bin_5_tmean, post
        local b   = _b[lincom]
        local se  = _se[lincom]
        local t   = abs(`b')/`se'

        post `H' ("`dep'") ("`ssp'") (`b') (`se') (`t')
    }
}
postclose `H'

use "`comb_results'", clear

* Significance stars (two-sided normal approximations)
gen star = ""
replace star = "***" if t > 2.58
replace star = "**"  if t <= 2.58 & t > 1.96
replace star = "*"   if t <= 1.96 & t > 1.64

gen ci_low  = b - 1.96*se
gen ci_high = b + 1.96*se

* Save CSV for reproducibility (S9 data)
export delimited using "outputs/derived/linear_combinations_global.csv", replace

* Build compact LaTeX (rows = outcomes; cols = SSPs; show b[ci] + stars)
preserve
keep dep ssp b se ci_low ci_high star
gen cell = string(b, "%9.3f") + star + " \, [" + string(ci_low, "%9.3f") + ", " + string(ci_high, "%9.3f") + "]"
reshape wide cell, i(dep) j(ssp) string
tempname fh
file open `fh' using "outputs/tables/supplementary/Table_S9.tex", write replace
file write `fh' "\begin{table}[H]" _n "\centering" _n
file write `fh' "\caption{Global combined effect of extreme temperatures by SSP scenario (Age-standardized physical inactivity, 2000--2022)}" _n
file write `fh' "\begin{tabular}{lccc}" _n "\toprule" _n
file write `fh' " & SSP1-2.6 & SSP2-4.5 & SSP5-8.5 \\" _n "\midrule" _n

levelsof dep, local(deps)
foreach d of local deps {
    file write `fh' "`d' & " ///
        =cellssp126[dep=="`d'"] " & " ///
        =cellssp245[dep=="`d'"] " & " ///
        =cellssp585[dep=="`d'"] " \\" _n
}

file write `fh' "\bottomrule" _n "\end{tabular}" _n
file write `fh' "\begin{minipage}{0.95\textwidth}\footnotesize\textit{Notes:} Fully adjusted country fixed-effects model with country-specific linear trends; standard errors clustered by country. Entries are linear combinations of bin coefficients weighted by the sample means of $D2$--$D5$ for each SSP. Significance: * $p<0.10$, ** $p<0.05$, *** $p<0.01$." _n
file write `fh' "\end{minipage}" _n "\end{table}" _n
file close `fh'
restore

* ========== 3) TABLE S10 — Country-level combinations (PI0) ==========
* Re-use current data in memory. Run single global model for PI0:
quietly areg PI0 `bins' `controls' `trendvar' `socioecon', absorb(objectid) vce(cluster objectid)
matrix b = e(b)
matrix V = e(V)

* Country list and country names
preserve
keep objectid año country_standard
bysort objectid: keep if _n==1
keep objectid country_standard
tempfile countries
save `countries', replace
restore

tempfile byctry
tempname H2
postfile `H2' str6 ssp double(objectid) double(b se t) using "`byctry'", replace

levelsof objectid, local(ids)
foreach c of local ids {
    foreach ssp of local ssp_list {
        quietly summarize D2_`ssp' if objectid==`c'
        local w2 = r(mean)
        quietly summarize D3_`ssp' if objectid==`c'
        local w3 = r(mean)
        quietly summarize D4_`ssp' if objectid==`c'
        local w4 = r(mean)
        quietly summarize D5_`ssp' if objectid==`c'
        local w5 = r(mean)

        * lincom using the currently active e(b), e(V)
        quietly lincom `w2'*total_bin_2_tmean + `w3'*total_bin_3_tmean + ///
                        `w4'*total_bin_4_tmean + `w5'*total_bin_5_tmean, post
        local cb = _b[lincom]
        local cs = _se[lincom]
        local ct = abs(`cb')/`cs'
        post `H2' ("`ssp'") (`c') (`cb') (`cs') (`ct')
    }
}
postclose `H2'

use "`byctry'", clear
gen star = ""
replace star = "***" if t > 2.58
replace star = "**"  if t <= 2.58 & t > 1.96
replace star = "*"   if t <= 1.96 & t > 1.64
gen ci_low  = b - 1.96*se
gen ci_high = b + 1.96*se

* Attach country names
joinby objectid using `countries', unmatched(master)
order country_standard objectid ssp b se t star ci_low ci_high
sort country_standard ssp

* Save full CSV (S10 data)
export delimited using "outputs/derived/estimates_by_country.csv", replace

* Build S10 summary LaTeX: distribution of effects by SSP (min, p25, median, p75, max, % sig +/-)
preserve
collapse ///
    (count) N = b ///
    (min)   min = b ///
    (p25)   p25 = b ///
    (p50)   p50 = b ///
    (p75)   p75 = b ///
    (max)   max = b, by(ssp)

* Compute significance shares
tempfile full
save `full', replace
restore

preserve
gen sigpos = (star!="" & b>0)
gen signeg = (star!="" & b<0)
collapse (mean) share_sigpos = sigpos share_signeg = signeg, by(ssp)
tempfile sigs
save `sigs', replace
restore

use `full', clear
merge 1:1 ssp using `sigs', nogenerate

* Write LaTeX
tempname fh2
file open `fh2' using "outputs/tables/supplementary/Table_S10.tex", write replace
file write `fh2' "\begin{table}[H]" _n "\centering" _n
file write `fh2' "\caption{Country-level combined effects by SSP (Outcome: PI0). Distribution across countries.}" _n
file write `fh2' "\begin{tabular}{lrrrrrrcc}" _n "\toprule" _n
file write `fh2' " & Min & P25 & Median & P75 & Max & N & \% Sig. + & \% Sig. - \\" _n "\midrule" _n
levelsof ssp, local(ssps)
foreach s of local ssps {
    local lab = cond("`s'"=="ssp126","SSP1-2.6", cond("`s'"=="ssp245","SSP2-4.5","SSP5-8.5"))
    file write `fh2' "`lab' & " ///
        =string(min,    "%9.3f") " & " ///
        =string(p25,    "%9.3f") " & " ///
        =string(p50,    "%9.3f") " & " ///
        =string(p75,    "%9.3f") " & " ///
        =string(max,    "%9.3f") " & " ///
        =string(N,      "%9.0f") " & " ///
        =string(100*share_sigpos, "%9.1f") "\% & " ///
        =string(100*share_signeg, "%9.1f") "\% \\" _n if ssp=="`s'"
}
file write `fh2' "\bottomrule" _n "\end{tabular}" _n
file write `fh2' "\begin{minipage}{0.95\textwidth}\footnotesize\textit{Notes:} Effects computed as linear combinations of bin coefficients (from a fully-adjusted FE model) weighted by SSP-specific means of $D2$--$D5$. Standard errors from the linear combination delta method; significance uses normal critical values. The full country-by-country table is provided as CSV in the repository." _n
file write `fh2' "\end{minipage}" _n "\end{table}" _n
file close `fh2'
restore

di as result "Done: Table_S9.tex, Table_S10.tex, and the two CSVs were written to outputs/."
*******************************************************

