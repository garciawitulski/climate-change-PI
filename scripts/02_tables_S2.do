*****************************************************
* 02_tables_S2.do — Descriptive stats table         *
* Data: data/processed/processed_data.csv           *
* Outputs: outputs/tables/supplementary/Table_S2.tex*

version 15.0
clear all
set more off

* ---------- Paths (edit if needed) ----------
* You can source paths from scripts/00_config.do; otherwise these fallbacks are used.
capture noisily do "scripts/00_config.do"

* Fallbacks (only used if not set in 00_config.do)
capture confirm global INFILE
if _rc global INFILE "data/processed/processed_data.csv"
capture confirm global OUT_TEX
if _rc global OUT_TEX "outputs/tables/supplementary/Table_S2.tex"
capture confirm global OUT_CSV
if _rc global OUT_CSV "outputs/derived/descriptives_summary.csv"

* Ensure output folders exist (silently skip if they don't)
cap mkdir "outputs"
cap mkdir "outputs/derived"
cap mkdir "outputs/tables"
cap mkdir "outputs/tables/supplementary"

* ---------- Import CSV ----------
import delimited using "${INFILE}", varnames(1) encoding("UTF-8") clear

* Harmonize year variable name (covers common encoding variants)
capture confirm variable year
if _rc {
    capture confirm variable año
    if !_rc rename año year
    else {
        capture confirm variable an~o
        if !_rc rename an~o year
        capture confirm variable a_o
        if !_rc rename a_o year
        capture confirm variable a?o
        if !_rc rename a?o year
    }
}

* ---------- Map variables from the CSV ----------
* Physical inactivity prevalence (%)
local var_PI_both   pi0
local var_PI_men    pi1
local var_PI_women  pi2

* Temperature and bins (months per year in each bin)
local var_tmean     tmean_weighted
local bin1          total_bin_1_tmean
local bin2          total_bin_2_tmean
local bin3          total_bin_3_tmean
local bin4          total_bin_4_tmean
local bin5          total_bin_5_tmean

* Weather & air pollution
local var_precip    precipitation_weighted
local var_cloud     cld_weighted
local var_frost     frs_weighted
local var_vap       vap_weighted
local var_wet       wet_weighted
local var_pm25      pm25

* Socio‑economic / health
local var_gdppc     gdppc
local var_deathr    deathr

* ---------- Check the key variables exist ----------
foreach v in `var_PI_both' `var_PI_men' `var_PI_women' `var_tmean' `bin1' `bin2' `bin3' `bin4' `bin5' ///
             `var_precip' `var_cloud' `var_frost' `var_vap' `var_wet' `var_pm25' `var_gdppc' `var_deathr' {
    capture confirm variable `v'
    if _rc {
        di as error "Variable `v' not found. Please verify the CSV column names."
        error 111
    }
}

* ---------- Variable labels (used as row names in the table) ----------
label var `var_PI_both'  "Physical inactivity (%), both"
label var `var_PI_men'   "Physical inactivity (%), men"
label var `var_PI_women' "Physical inactivity (%), women"

label var `var_tmean'    "Mean temperature (°C)"
label var `bin1'         "Bin 1 (<4.2°C) [months]"
label var `bin2'         "Bin 2 [4.2–13.4°C) [months]"
label var `bin3'         "Bin 3 [13.4–21.8°C) [months]"
label var `bin4'         "Bin 4 [21.8–27.8°C) [months]"
label var `bin5'         "Bin 5 (>27.8°C) [months]"

label var `var_precip'   "Precipitation (mm/year)"
label var `var_cloud'    "Cloud cover (%)"
label var `var_frost'    "Frost days (days/year)"
label var `var_vap'      "Vapor pressure (hPa)"
label var `var_wet'      "Wet days (days/year)"
label var `var_pm25'     "PM2.5 (µg/m³)"

label var `var_gdppc'    "GDP per capita (2015 US$)"
label var `var_deathr'   "Crude death rate (per 1,000)"

* ---------- Build summary stats via postfile ----------
tempname S
tempfile statsdta
postfile `S' str60 variable double mean sd p25 p50 p75 using "`statsdta'", replace

local varlist `var_PI_both' `var_PI_men' `var_PI_women' ///
              `var_tmean' `bin1' `bin2' `bin3' `bin4' `bin5' ///
              `var_precip' `var_cloud' `var_frost' `var_vap' `var_wet' `var_pm25' ///
              `var_gdppc' `var_deathr'

quietly foreach v of local varlist {
    summarize `v', detail
    local L : variable label `v'
    if "`L'" == "" local L "`v'"
    post `S' ("`L'") (r(mean)) (r(sd)) (r(p25)) (r(p50)) (r(p75))
}
postclose `S'

* IMPORTANT: postfile creates a .dta — use it (do NOT import delimited)
use "`statsdta'", clear

* ---------- Export CSV ----------
export delimited using "${OUT_CSV}", replace

* ---------- (Optional) Minimal LaTeX table ----------
tempname fh
file open `fh' using "${OUT_TEX}", write replace text

file write `fh' _n "\begin{table}[H]" _n "\centering" _n "\caption{Descriptive statistics (2000–2022)}" _n ///
                "\begin{tabular}{lrrrrr}" _n "\toprule" _n ///
                "Variable & Mean & SD & p25 & p50 & p75 \\\\" _n "\midrule" _n

forvalues i = 1/`=_N' {
    local r1 = subinstr(variable[`i'], "&", "\&", .)
    file write `fh' "`r1' & " %9.2f (mean[`i']) " & " %9.2f (sd[`i']) " & " %9.2f (p25[`i']) " & " %9.2f (p50[`i']) " & " %9.2f (p75[`i']) " \\\\" _n
}

file write `fh' "\bottomrule" _n ///
                "\end{tabular}" _n ///
                "\end{table}" _n

file close `fh'


display "Tabla LaTeX guardada en: ${OUT_TEX}"
