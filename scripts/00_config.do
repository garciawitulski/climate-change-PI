*******************************************************
* 00_config.do — project setup (portable paths)
*******************************************************
version 15.0
clear all
set more off

* Root = current working directory (open Stata here)
local ROOT : pwd
display as text "Project root: `ROOT'"

* Create output dirs if missing
cap mkdir "outputs"
cap mkdir "outputs/logs"
cap mkdir "outputs/tables"
cap mkdir "outputs/tables/manuscript"
cap mkdir "outputs/tables/supplementary"
cap mkdir "outputs/derived"
cap mkdir "outputs/derived/coefficients"

* Check & install required packages
cap which esttab
if _rc ssc install estout, replace

* Optional: log
log using "outputs/logs/run_`c(current_date)'_`c(current_time)'.smcl", replace

* Harmonize variable names if needed (Spanish → English)
capture confirm variable año_by_country
if !_rc {
    rename año_by_country year_by_country
}

* NOTE: all scripts assume you run Stata from repo root
*******************************************************
