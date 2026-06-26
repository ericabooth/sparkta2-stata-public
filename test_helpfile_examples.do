*! test_helpfile_examples.do
*! Runs every code block that appears in `help sparkta2', in order.
*! Acts as a smoke test for the help file: if one of these fails,
*! the help file is out of sync with the package.
*!
*! Produces 10 HTML files in `c(pwd)/sparkta2_helpfile_out/`.

version 17.0
clear all
set more off

* sparkta2 ships in _codeshare which is already on the Stata adopath
* (set by the Texas 2036 profile.do). To run from a local clone instead,
* uncomment the two lines below and point sparkta2_home at your clone:
*   local sparkta2_home "<path-to-your-sparkta2/ado>"
*   adopath ++ "`sparkta2_home'"

* Confirm sparkta2 is reachable
capture which sparkta2
if _rc {
    display as error "sparkta2 not found on adopath; check _codeshare or your local clone."
    exit 199
}

local out "`c(pwd)'/sparkta2_helpfile_out"
capture mkdir "`out'"

*-----------------------------------------------------------------------------
* Texas county demo dataset (used by examples 1-5, 10)
* findfile picks it up from _codeshare top level (or any adopath dir)
*-----------------------------------------------------------------------------
findfile texas_county_demo.csv
local demo_csv "`r(fn)'"
import delimited using "`demo_csv'", varnames(1) clear stringcols(2)
destring fips poverty_rate uninsured_rate, replace force
label variable fips           "5-digit county FIPS"
label variable county         "County name"
label variable poverty_rate   "Poverty rate (%)"
label variable uninsured_rate "Uninsured rate (%)"

generate int region_n = mod(fips - 48000, 5)
label define regL 0 "North" 1 "East" 2 "South" 3 "West" 4 "Central"
label values region_n regL
label variable region_n "Region (synthetic)"

generate byte urban = (poverty_rate < 18 & uninsured_rate < 18)
label define urbanL 0 "Rural" 1 "Urban"
label values urban urbanL
label variable urban "Urban / Rural (demo)"

set seed 20260620
generate float pop_thou       = round(20 + 60*runiform() + 0.3*poverty_rate^2, 1)
generate float median_income  = round(35000 + 800*runiform()*(100-poverty_rate) + 200*uninsured_rate, 100)
generate float life_expect    = round(73 + 6*(1 - poverty_rate/40) + runiform()*1.5, 0.1)
label variable pop_thou       "Population (thousands, synthetic)"
label variable median_income  "Median household income ($)"
label variable life_expect    "Life expectancy (years)"

tempfile county_data
save "`county_data'", replace

*-----------------------------------------------------------------------------
* Example 1: bivariate full UI
*-----------------------------------------------------------------------------
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate) scheme(rdbu)         ///
    modes(bivariate|x|y|diff|ratio) comparable                 ///
    filters(region_n urban) sliders(poverty_rate uninsured_rate) ///
    tooltipvars(median_income life_expect)                     ///
    swapbutton download search offline noopen                  ///
    title("Texas counties: poverty vs uninsured")              ///
    export("`out'/01_bivariate.html")

*-----------------------------------------------------------------------------
* Example 2: small-multiples
*-----------------------------------------------------------------------------
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate)                      ///
    modes(bivariate|diff|ratio) multiples comparable           ///
    filters(region_n) width(1300) height(620) offline noopen   ///
    export("`out'/02_multiples.html")

*-----------------------------------------------------------------------------
* Example 3: counties() subset + zoomto
*-----------------------------------------------------------------------------
local big8 "48201 48029 48113 48439 48453 48141 48215 48085"
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate)                      ///
    counties("`big8'") zoomto("`big8'")                         ///
    tooltipvars(median_income pop_thou)                        ///
    download offline noopen                                    ///
    export("`out'/03_big8.html")

*-----------------------------------------------------------------------------
* Example 4: hexbin TX
*-----------------------------------------------------------------------------
sparkta2 poverty_rate,                                         ///
    id(fips) name(county) type(hexbin) scheme(viridis)         ///
    hexradius(22) hexstat(mean) download offline noopen        ///
    title("Mean poverty rate per hex")                         ///
    export("`out'/04_hexbin.html")

*-----------------------------------------------------------------------------
* Example 5: basemap
*-----------------------------------------------------------------------------
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate) basemap              ///
    modes(bivariate|x|y|diff|ratio) comparable offline noopen  ///
    export("`out'/05_basemap.html")

*-----------------------------------------------------------------------------
* Examples 6-7: US 50-state choropleth + hexbin
*-----------------------------------------------------------------------------
clear
local state_ids "01 02 04 05 06 08 09 10 11 12 13 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 44 45 46 47 48 49 50 51 53 54 55 56 60 66 69 72 78"
local _ns : word count `state_ids'
set obs `_ns'
generate str2 state_fips = ""
generate str40 state_name = ""
generate float pop_mil = .
generate float gdp_thou = .
set seed 48000
local i 1
foreach sid of local state_ids {
    replace state_fips = "`sid'" in `i'
    replace pop_mil  = round(0.5 + 35*runiform(), 0.1) in `i'
    replace gdp_thou = round(20 + 80*runiform() + 30*pop_mil[`i'], 1) in `i'
    local ++i
}
replace state_name = "State " + state_fips
label variable pop_mil  "Population (millions)"
label variable gdp_thou "GDP per capita (synthetic, $K)"

* (6) US choropleth
sparkta2 pop_mil,                                              ///
    id(state_fips) name(state_name) geo(texas)                 ///
    layer(states) idwidth(2)                                   ///
    type(choropleth) scheme(blues) download                    ///
    tooltipvars(gdp_thou)                                      ///
    title("US state population")                               ///
    width(1200) height(720) offline noopen                     ///
    export("`out'/06_us_states.html")

* (7) US bivariate -- pop vs GDP per capita, full UI
sparkta2 pop_mil gdp_thou,                                     ///
    id(state_fips) name(state_name) geo(texas)                 ///
    layer(states) idwidth(2)                                   ///
    type(bivariate) scheme(rdbu)                                ///
    modes(bivariate|x|y|diff|ratio) swapbutton download         ///
    width(1200) height(720) offline noopen                     ///
    export("`out'/07_us_states_bivariate.html")

*-----------------------------------------------------------------------------
* Examples 8-9: NCES districts (replace v0.4 ZIP demo)
*-----------------------------------------------------------------------------
if "${driveuse}" == "" {
    global driveuse "/Users/`c(username)'/Library/CloudStorage/GoogleDrive-eric.booth@texas2036.org/Shared drives/Data and Research Team/"
}
local nces_dta "${driveuse}/_datashare/NCES_EDGE/02_cleaned/NCES_EDGE_Texas_District_Map.dta"
capture confirm file "`nces_dta'"
if _rc {
    display as text "(Skipping examples 8 and 9: NCES_EDGE_Texas_District_Map.dta not at `nces_dta'.)"
}
else {
    use "`nces_dta'", clear
    capture destring intptlat intptlon, replace force
    generate float frpl_pct100 = frpl_pct * 100
    label variable frpl_pct100 "FRPL eligibility (%)"
    label variable student_count "Total students"

    * (8) District choropleth (polygon boundaries from the bundled GeoJSON)
    sparkta2 frpl_pct100 students_per_teacher,                 ///
        id(leaid) name(name) geo(texas_districts) idwidth(7)   ///
        type(bivariate) scheme(rdbu)                            ///
        filters(sdtyp) sliders(frpl_pct100 student_count)       ///
        tooltipvars(student_count teacher_fte school_count)    ///
        download search offline noopen                         ///
        export("`out'/08_districts_bivariate.html")

    * (9) District hexbin via centroid lat/lon
    sparkta2 frpl_pct100,                                      ///
        id(leaid) name(name) geo(texas_districts) idwidth(7)   ///
        type(hexbin) lat(intptlat) lon(intptlon)                ///
        hexradius(20) hexstat(mean) scheme(viridis) offline noopen ///
        export("`out'/09_districts_hexbin.html")
}

*-----------------------------------------------------------------------------
* Example 10: chart pass-through (requires sparkta)
*-----------------------------------------------------------------------------
use "`county_data'", clear
capture which sparkta
if !_rc {
    capture noisily sparkta2 poverty_rate uninsured_rate,      ///
        type(scatter) fit(lfit) fitci offline                  ///
        export("`out'/10_scatter.html")
    capture noisily sparkta2 poverty_rate uninsured_rate,      ///
        type(bar) over(region_n) stat(mean) offline            ///
        export("`out'/10_bar.html")
}
else {
    display as text "(Skipping example 10: sparkta not installed.)"
}

*-----------------------------------------------------------------------------
* Examples 9a-9d: v0.6.0 / v0.6.1 features on the existing county dataset.
*   9a  Export menu + datatable
*   9b  Animate on scroll into view
*   9c  Points map with all v0.6.0 features
*   9d  Projection control (Texas-tuned default, legacy override, custom)
*-----------------------------------------------------------------------------
use "`county_data'", clear

* 9a: download datatable
sparkta2 poverty_rate, id(fips) name(county) type(choropleth) scheme(blues) ///
    tooltipvars(median_income pop_thou)                                     ///
    download datatable offline noopen                                        ///
    title("v0.6.0 -- Export menu + data table")                              ///
    export("`out'/09a_export_menu.html")

* 9b: animate (IntersectionObserver fade-in)
sparkta2 poverty_rate uninsured_rate, id(fips) name(county) type(bivariate) ///
    scheme(rdbu) modes(bivariate|x|y|diff|ratio) comparable                  ///
    download datatable animate offline noopen                                ///
    title("v0.6.0 -- Animate on scroll into view")                           ///
    export("`out'/09b_animate.html")

* 9d: projection control
sparkta2 poverty_rate, id(fips) name(county) type(choropleth)               ///
    projection(albers_usa) offline noopen                                    ///
    title("v0.6.1 -- legacy projection(albers_usa) for backward-compat")     ///
    export("`out'/09d_proj_legacy.html")

sparkta2 poverty_rate, id(fips) name(county) type(choropleth)               ///
    projection(albers) rotate(99) parallels(27.5 35.5) center(0 31.5)        ///
    offline noopen                                                           ///
    title("v0.6.1 -- explicit Texas-tuned Albers overrides")                 ///
    export("`out'/09d_proj_custom.html")

*-----------------------------------------------------------------------------
* Examples 9e-9h: v0.7.0 native chart types.
*   9e  Donut
*   9f  Native bar + line (with v0.6.0 export menu + animate)
*   9g  Diverging stacked bar -- Pew-style Likert chart
*   9h  Bar chart race
*-----------------------------------------------------------------------------

* 9e: donut (THECB-like enrollment by sector)
preserve
clear
input str30 sector long enroll
"Public 4-year" 644000
"Public 2-year" 714000
"Independent" 162000
"Career schools" 86000
"Health-related" 19000
end
sparkta2 enroll, name(sector) type(donut) scheme(tx2036)                    ///
    download datatable animate offline noopen                                ///
    title("v0.7.0 -- Donut: enrollment by sector")                           ///
    export("`out'/09e_donut.html")
restore

* 9f: native bar2 -- horizontal poverty by region group
*     (v0.7.1: native bar/line are type(bar2)/type(line2) so sparkta's
*      original type(bar)/type(line) keep working unchanged.)
preserve
collapse (mean) poverty_rate, by(region_n)
sparkta2 poverty_rate, name(region_n) type(bar2) horizontal scheme(blues)   ///
    download datatable animate offline noopen                                ///
    title("v0.7.1 -- Native bar2 (horizontal) + export menu + animate")      ///
    export("`out'/09f_bar.html")
restore

* 9f': native line -- two synthetic time series via long form
preserve
clear
input double yr str20 series double y
2018 "Texas"          42
2019 "Texas"          43.1
2020 "Texas"          41.5
2021 "Texas"          42.8
2022 "Texas"          43.9
2023 "Texas"          44.5
2024 "Texas"          45.2
2018 "ESC 13"         46.5
2019 "ESC 13"         47.0
2020 "ESC 13"         46.1
2021 "ESC 13"         47.2
2022 "ESC 13"         48.0
2023 "ESC 13"         48.6
2024 "ESC 13"         49.3
end
sparkta2 y yr, over(series) type(line2) scheme(tx2036)                       ///
    download datatable animate offline noopen                                ///
    title("v0.7.1 -- Native multi-series line2")                             ///
    export("`out'/09f_line.html")
restore

* 9g: Pew-style diverging stacked bar (Likert)
preserve
clear
input str100 q str22 response double share
"Texas is on the right track investing in K-12 public education"   "Strongly disagree" 18
"Texas is on the right track investing in K-12 public education"   "Disagree"          22
"Texas is on the right track investing in K-12 public education"   "Neutral"           14
"Texas is on the right track investing in K-12 public education"   "Agree"             29
"Texas is on the right track investing in K-12 public education"   "Strongly agree"    17
"Higher education in Texas is affordable for most families"        "Strongly disagree" 29
"Higher education in Texas is affordable for most families"        "Disagree"          33
"Higher education in Texas is affordable for most families"        "Neutral"           14
"Higher education in Texas is affordable for most families"        "Agree"             18
"Higher education in Texas is affordable for most families"        "Strongly agree"    6
end
sparkta2 share, name(q) level(response) type(divbar)                         ///
    levelorder("Strongly disagree|Disagree|Neutral|Agree|Strongly agree")    ///
    centerlevel(Neutral)                                                     ///
    download datatable offline noopen                                        ///
    title("v0.7.0 -- Diverging stacked bar (Pew-style, Likert)")             ///
    width(1100) height(360)                                                  ///
    export("`out'/09g_divbar.html")
restore

* 9h: bar chart race (synthetic)
preserve
clear
input long yr str22 name double v
2020 "Harris"   4731145
2020 "Dallas"   2613539
2020 "Tarrant"  2110640
2020 "Bexar"    2009324
2020 "Travis"   1290188
2021 "Harris"   4738253
2021 "Dallas"   2599883
2021 "Tarrant"  2126477
2021 "Bexar"    2028340
2021 "Travis"   1305057
2022 "Harris"   4780913
2022 "Dallas"   2613539
2022 "Tarrant"  2154595
2022 "Bexar"    2061226
2022 "Travis"   1330411
2023 "Harris"   4835125
2023 "Dallas"   2606358
2023 "Tarrant"  2182947
2023 "Bexar"    2092984
2023 "Travis"   1351019
2024 "Harris"   4894753
2024 "Dallas"   2604722
2024 "Tarrant"  2211232
2024 "Bexar"    2126810
2024 "Travis"   1378260
end
sparkta2 v, name(name) time(yr) type(barrace) top(5) duration(10)            ///
    scheme(tx2036) download datatable offline noopen                         ///
    title("v0.7.0 -- Bar chart race (synthetic)")                            ///
    export("`out'/09h_barrace.html")
restore

display as result _n "All help-file examples written to:"
display as result "  `out'"
