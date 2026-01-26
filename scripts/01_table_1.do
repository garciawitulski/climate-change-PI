*******************************************************
* 01_table1.do — Manuscript Table 1
* Input : data/processed/mortality_costs.csv
* Output: outputs/tables/manuscript/Table1.tex
*         outputs/derived/table1_values.csv
*******************************************************
version 15.0
clear all
set more off

* --- Paths (relative to repo) ---
local INFILE  "data/processed/mortality_costs.csv"
local OUT_TEX "outputs/tables/manuscript/Table1.tex"
local OUT_CSV "outputs/derived/table1_values.csv"

capture mkdir "outputs"
capture mkdir "outputs/tables"
capture mkdir "outputs/tables/manuscript"
capture mkdir "outputs/derived"

* --- Load dataset ---
import delimited "`INFILE'", clear varnames(1) encoding("UTF-8")

* Basic checks
capture confirm variable ssp
if _rc {
    di as error "Variable 'ssp' not found (expected: ssp126/ssp245/ssp585)."
    exit 111
}
foreach v in gdp country_standard totdeathspi totecost {
    capture confirm variable `v'
    if _rc {
        di as error "Variable '`v'' not found in dataset."
        exit 111
    }
}


* --- Totals by scenario ---

collapse (first) totdeathspi totecost, by(ssp)

* Canonical order
gen ord = .
replace ord = 1 if ssp=="ssp126"
replace ord = 2 if ssp=="ssp245"
replace ord = 3 if ssp=="ssp585"
sort ord

* Derived calculations
gen losses_bil = totecost/1e9


* Benchmarks (manuscript constants)
scalar BASE_DEATHS_2008 = 5.3e6
scalar BASE_LOSS_2013   = 13.7e9
scalar BASE_GGHED       = 5.65e12

gen deaths_vs2008 = 100 * totdeathspi / BASE_DEATHS_2008
gen loss_vs2013   = 100 * totecost   / BASE_LOSS_2013
gen loss_vsGGHED   = 100 * totecost   / BASE_GGHED

* Readable labels
gen ssp_label = cond(ssp=="ssp126","SSP1-2.6", cond(ssp=="ssp245","SSP2-4.5","SSP5-8.5"))

* Export auxiliary CSV
order ssp ssp_label totdeathspi losses_bil loss_vsGGHED deaths_vs2008 loss_vs2013 
export delimited using "`OUT_CSV'", replace

quietly summarize totdeathspi if ord==1, meanonly
local D1 : display %12.0fc r(mean)
quietly summarize totdeathspi if ord==2, meanonly
local D2 : display %12.0fc r(mean)
quietly summarize totdeathspi if ord==3, meanonly
local D3 : display %12.0fc r(mean)

quietly summarize losses_bil if ord==1, meanonly
local L1 : display %4.2f r(mean)
quietly summarize losses_bil if ord==2, meanonly
local L2 : display %4.2f r(mean)
quietly summarize losses_bil if ord==3, meanonly
local L3 : display %4.2f r(mean)

quietly summarize loss_vsGGHED if ord==1, meanonly
local G1 : display %7.4f r(mean)
quietly summarize loss_vsGGHED if ord==2, meanonly
local G2 : display %7.4f r(mean)
quietly summarize loss_vsGGHED if ord==3, meanonly
local G3 : display %7.4f r(mean)

quietly summarize deaths_vs2008 if ord==1, meanonly
local R1 : display %4.1f r(mean)
quietly summarize deaths_vs2008 if ord==2, meanonly
local R2 : display %4.1f r(mean)
quietly summarize deaths_vs2008 if ord==3, meanonly
local R3 : display %4.1f r(mean)

quietly summarize loss_vs2013 if ord==1, meanonly
local P1 : display %4.1f r(mean)
quietly summarize loss_vs2013 if ord==2, meanonly
local P2 : display %4.1f r(mean)
quietly summarize loss_vs2013 if ord==3, meanonly
local P3 : display %4.1f r(mean)

* --- Write LaTeX with file write 
tempname fh
file open `fh' using "`OUT_TEX'", write replace
file write `fh' "\begin{table}[htbp]" _n
file write `fh' "\centering" _n
file write `fh' "\caption{Forecast of the additional global health and economic burden attributable to climate-change-induced physical inactivity by 2050}" _n
file write `fh' "\begin{tabular}{lccc}" _n "\toprule" _n
file write `fh' " & SSP1--2.6 & SSP2--4.5 & SSP5--8.5 \\" _n "\midrule" _n
* Fila 1
file write `fh' "Projected deaths (persons) & `D1' & `D2' & `D3' \\" _n
* Fila 2
file write `fh' "Projected economic losses (USD, billions) & `L1' & `L2' & `L3' \\" _n
* Fila 3
file write `fh' "Projected economic losses (vs. global GGHE-D, \%) & `G1' & `G2' & `G3' \\" _n
file write `fh' "\addlinespace \multicolumn{4}{l}{\textit{Benchmark comparisons}} \\" _n
* Fila 4
file write `fh' "Projected deaths vs. 2008 premature deaths (\%) & `R1' & `R2' & `R3' \\" _n
* Fila 5
file write `fh' "Projected economic losses vs. 2013 productivity losses (\%) & `P1' & `P2' & `P3' \\" _n
file write `fh' "\bottomrule" _n "\end{tabular}" _n
file write `fh' "\begin{minipage}{0.95\textwidth}\footnotesize\textit{Notes:} Totals sum across countries. Economic losses valued under a friction-cost approach. Percent of GGHE-D computed as losses divided by the sum of Domestic General Government Health Expenditure (GGHE-D). Benchmarks: 5.3 million PI-attributable deaths (2008) and US\$13.7 billion productivity losses (2013). \end{minipage}" _n
file write `fh' "\end{table}" _n
file close `fh'

di as result "Table1.tex and table1_values.csv generated."
*******************************************************









