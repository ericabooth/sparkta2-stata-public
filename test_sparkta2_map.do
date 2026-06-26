*! test_sparkta2_map.do
*! Companion driver for sparkta2 v0.7.1 -- exercises 20 dashboard examples plus
*! 8 v0.6.x / v0.7.x additions (Export menu, datatable, animate, Texas-tuned
*! projection, donut, bar2, divbar, barrace).
*!
*!  1. Bivariate -- full UI (toggle, filters, sliders, swap, download, zoom, search)
*!  2. Univariate Blues (1 filter, 1 slider)
*!  3. Univariate Viridis (2 filters, custom dimensions)
*!  4. Bivariate BuPu static (no toggle)
*!  5. Small multiples -- bivariate + diff + ratio
*!  6. Small multiples -- X + Y univariate
*!  7. Diff-only (comparable -> value diff)
*!  8. Rank-diff (units mismatched -> rank fallback)
*!  9. County subset via counties() (Big-8 Texas metros)
*! 10. `if' qualifier subset (rural only) + zoomto South TX
*! 11. Tooltipvars data table (5 extra fields)
*! 12. Auto-zoom to DFW metroplex on load
*! 13. Pan/zoom disabled (nozoom) for slide export
*! 14. Prominent search box (no filter clutter)
*! 15. Chart pass-through -- bar by region (sparkta)
*! 16. Chart pass-through -- scatter + lfit + CI (sparkta)
*! 17. Hexbin of TX counties (centroid aggregation)
*! 18. Bivariate + basemap (faded US-state outline behind TX)
*! 19. BONUS -- US 50-state choropleth (layer=states, idwidth=2)
*! 20. BONUS -- US 50-state hexbin (same data, hexagonal density)
*!
*! Finally builds a single scrollable dashboard.html.

version 17.0
clear all
set more off

* sparkta2 ships in _codeshare which is already on the Stata adopath
* (set by the Texas 2036 profile.do). To run from a local clone instead,
* uncomment the two lines below and point sparkta2_home at your clone:
*   local sparkta2_home "<path-to-your-sparkta2/ado>"
*   adopath ++ "`sparkta2_home'"

capture which sparkta2
if _rc {
    display as error "sparkta2 not found on adopath; check _codeshare or your local clone."
    exit 199
}

local out "`c(pwd)'/sparkta2_demo_out"
capture mkdir "`out'"

capture which sparkta
if _rc display as text "Note: sparkta not installed; chart pass-throughs will be skipped."

*-----------------------------------------------------------------------------
* Load demo county data + synthetic auxiliary vars
* findfile picks up texas_county_demo.csv from _codeshare top level
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
generate float pop_thou = round(20 + 60 * runiform() + 0.3 * poverty_rate^2, 1)
label variable pop_thou "Population (thousands, synthetic)"

generate float median_income = round(35000 + 800 * runiform() * (100 - poverty_rate) + 200 * uninsured_rate, 100)
label variable median_income "Median household income ($)"

generate float life_expect = round(73 + 6 * (1 - poverty_rate/40) + runiform() * 1.5, 0.1)
label variable life_expect "Life expectancy (years)"

* Approximate county centroid lat/lon for hexbin/points alt path -- here we
* leave it to the engine (it falls back to feature centroids when lat/lon
* aren't passed).

local big8 "48201 48029 48113 48439 48453 48141 48215 48085"
local dfw  "48113 48439 48085 48121 48397 48257 48139 48251"
local south_fips "48047 48131 48249 48273 48355"

* Save the county dataset so we can return to it after the US-state section
tempfile county_data
save "`county_data'", replace

*=============================================================================
* (1) Bivariate -- full UI
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu) bins(3)                        ///
    mode(bivariate) modes(bivariate|x|y|diff|ratio)             ///
    filters(region_n urban)                                     ///
    sliders(poverty_rate uninsured_rate pop_thou)               ///
    tooltipvars(median_income life_expect pop_thou)             ///
    comparable swapbutton download search                       ///
    title("1. Bivariate -- full UI")                            ///
    subtitle("Toggle modes, filter, slide, search, swap, zoom, export") ///
    xlabel("Poverty rate (%)") ylabel("Uninsured rate (%)")     ///
    note("Click a county to zoom; double-click to reset.")      ///
    offline noopen export("`out'/01_bivariate_full.html")

*=============================================================================
* (2) Univariate Blues
*=============================================================================
sparkta2 poverty_rate,                                          ///
    id(fips) name(county) geo(texas)                            ///
    type(choropleth) scheme(blues)                              ///
    filters(region_n) sliders(poverty_rate) download            ///
    title("2. Poverty rate -- sequential Blues")                ///
    xlabel("Poverty rate (%)")                                  ///
    offline noopen export("`out'/02_choropleth_blues.html")

*=============================================================================
* (3) Univariate Viridis
*=============================================================================
sparkta2 uninsured_rate,                                        ///
    id(fips) name(county) geo(texas)                            ///
    type(choropleth) scheme(viridis)                            ///
    filters(urban region_n) sliders(uninsured_rate)             ///
    title("3. Uninsured rate -- viridis colormap")              ///
    width(1080) height(760) offline noopen                      ///
    export("`out'/03_choropleth_viridis.html")

*=============================================================================
* (4) Bivariate BuPu static
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(bupu) bins(3) modes(bivariate)       ///
    filters(region_n)                                           ///
    title("4. Bivariate -- BuPu (static)")                      ///
    xlabel("Poverty rate (%)") ylabel("Uninsured rate (%)")     ///
    offline noopen export("`out'/04_bivariate_bupu.html")

*=============================================================================
* (5) Small multiples -- bivariate + diff + ratio
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu) modes(bivariate|diff|ratio)    ///
    multiples comparable                                        ///
    filters(region_n) sliders(poverty_rate uninsured_rate)      ///
    title("5. Small multiples -- bivariate, diff, ratio")       ///
    width(1300) height(620) offline noopen                      ///
    export("`out'/05_multiples_3panel.html")

*=============================================================================
* (6) Small multiples -- X + Y univariate
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(blues) modes(x|y) multiples          ///
    filters(region_n)                                           ///
    title("6. Small multiples -- X and Y univariate")           ///
    width(1280) height(560) offline noopen                      ///
    export("`out'/06_multiples_xy.html")

*=============================================================================
* (7) Diff-only (value diff)
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu) mode(diff) modes(diff)         ///
    comparable filters(region_n)                                ///
    title("7. Diff-only -- uninsured minus poverty")            ///
    offline noopen export("`out'/07_diff_only.html")

*=============================================================================
* (8) Rank-diff fallback
*=============================================================================
sparkta2 poverty_rate pop_thou,                                ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(puor) mode(diff) modes(diff)         ///
    filters(urban)                                              ///
    title("8. Rank-diff -- poverty vs population")              ///
    note("`comparable' omitted -> percentile-rank difference.") ///
    offline noopen export("`out'/08_rankdiff.html")

*=============================================================================
* (9) counties() -- Big-8 metros
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu)                                ///
    counties("`big8'") zoomto("`big8'")                         ///
    tooltipvars(median_income pop_thou)                         ///
    download                                                    ///
    title("9. Big-8 metros only (counties + zoomto)")           ///
    subtitle("Harris, Bexar, Dallas, Tarrant, Travis, El Paso, Hidalgo, Collin") ///
    offline noopen export("`out'/09_counties_big8.html")

*=============================================================================
* (10) [if] qualifier -- rural + south-TX zoom
*=============================================================================
sparkta2 poverty_rate uninsured_rate if urban == 0,            ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(gnbu)                                ///
    filters(region_n) sliders(poverty_rate)                     ///
    zoomto("`south_fips'")                                      ///
    title("10. Rural counties (if urban==0) + South-TX zoom")   ///
    offline noopen export("`out'/10_if_rural.html")

*=============================================================================
* (11) Tooltip data table
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu)                                ///
    tooltipvars(region_n urban median_income pop_thou life_expect) ///
    title("11. Tooltip data table")                             ///
    subtitle("Hover any county -- tooltip shows 5 extra fields") ///
    offline noopen export("`out'/11_tooltip_table.html")

*=============================================================================
* (12) zoomto() DFW
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu)                                ///
    zoomto("`dfw'") tooltipvars(median_income)                  ///
    title("12. Auto-zoom to DFW metroplex")                     ///
    offline noopen export("`out'/12_zoomto_dfw.html")

*=============================================================================
* (13) nozoom -- static export
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu) nozoom download                ///
    title("13. Static map (no zoom)")                           ///
    offline noopen export("`out'/13_nozoom.html")

*=============================================================================
* (14) Search box
*=============================================================================
sparkta2 poverty_rate,                                          ///
    id(fips) name(county) geo(texas)                            ///
    type(choropleth) scheme(viridis) search                     ///
    title("14. Search by county name")                          ///
    offline noopen export("`out'/14_search.html")

*=============================================================================
* (15-16) Chart pass-through (skipped if sparkta absent)
*=============================================================================
capture which sparkta
if !_rc {
    capture noisily sparkta2 poverty_rate uninsured_rate,       ///
        type(bar) over(region_n) stat(mean)                     ///
        title("15. Mean rates by region (sparkta pass-through)") ///
        offline export("`out'/15_bar_pass.html")

    capture noisily sparkta2 poverty_rate uninsured_rate,       ///
        type(scatter) fit(lfit) fitci                           ///
        title("16. Poverty vs uninsured (sparkta scatter)")     ///
        offline export("`out'/16_scatter_pass.html")
}
else {
    display as text _n "(Skipping bar + scatter pass-through.)"
}

*=============================================================================
* (17) HEXBIN -- TX counties aggregated to hex grid
*=============================================================================
sparkta2 poverty_rate,                                          ///
    id(fips) name(county) geo(texas)                            ///
    type(hexbin) scheme(viridis)                                ///
    hexradius(22) hexstat(mean) download                        ///
    tooltipvars(uninsured_rate pop_thou)                        ///
    title("17. Hexbin -- mean poverty rate per hex")            ///
    subtitle("County centroids aggregated into hexagons (d3-hexbin)") ///
    xlabel("Mean poverty rate (%)")                             ///
    note("Inspired by d3-graph-gallery hexbinmap_geo_label.")   ///
    offline noopen export("`out'/17_hexbin_tx.html")

*=============================================================================
* (18) BASEMAP -- bivariate TX with faded US-state backdrop
*=============================================================================
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) geo(texas)                            ///
    type(bivariate) scheme(rdbu) basemap                        ///
    modes(bivariate|x|y|diff|ratio) comparable                  ///
    filters(region_n) sliders(poverty_rate)                     ///
    title("18. Bivariate with US-state basemap")                ///
    subtitle("Faded states/Mexico outline as geographic context") ///
    xlabel("Poverty rate (%)") ylabel("Uninsured rate (%)")     ///
    note("Inspired by d3-graph-gallery backgroundmap_country.") ///
    offline noopen export("`out'/18_basemap.html")

*=============================================================================
* US-STATE BONUS EXAMPLES (19, 20)
* Generate synthetic 50-state + DC + territories data, then plot at state level.
*=============================================================================
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
    * use a simple deterministic seed offset to produce stable synthetic values
    replace pop_mil  = round(0.5 + 35 * runiform() , 0.1) in `i'
    replace gdp_thou = round(20  + 80 * runiform() + 30 * pop_mil[`i'], 1) in `i'
    local ++i
}
* Name labels (just a placeholder identifier)
replace state_name = "State " + state_fips
destring state_fips, gen(state_fips_n) force

label variable pop_mil  "Population (millions)"
label variable gdp_thou "GDP per capita (synthetic, $K)"
label variable state_fips "State FIPS (2-digit)"

*=============================================================================
* (19) US 50-state choropleth -- layer(states) idwidth(2)
*=============================================================================
sparkta2 pop_mil,                                              ///
    id(state_fips) name(state_name) geo(texas)                  ///
    layer(states) idwidth(2)                                    ///
    type(choropleth) scheme(blues) download                     ///
    tooltipvars(gdp_thou)                                       ///
    title("19. US state population (bonus -- not Texas-only)")  ///
    subtitle("Same topojson, layer(states) + idwidth(2) selects the 56-feature US states layer") ///
    xlabel("Population (millions)")                             ///
    note("Synthetic state-level values; demonstrates the engine works outside Texas.") ///
    width(1200) height(720) offline noopen                      ///
    export("`out'/19_us_states_choropleth.html")

*=============================================================================
* (20) US 50-state BIVARIATE -- population vs GDP per capita
*     (replaces the v0.4 hexbin variant; sparse state centroids don't suit
*      hexbinning -- use type(bivariate) for state-level data instead.)
*=============================================================================
sparkta2 pop_mil gdp_thou,                                      ///
    id(state_fips) name(state_name) geo(texas)                  ///
    layer(states) idwidth(2)                                    ///
    type(bivariate) scheme(rdbu) bins(3)                        ///
    modes(bivariate|x|y|diff|ratio)                             ///
    swapbutton download                                         ///
    tooltipvars(pop_mil gdp_thou)                               ///
    title("20. US 50-state bivariate -- pop x GDP")             ///
    subtitle("Population (millions) vs synthetic GDP per capita ($K)") ///
    xlabel("Population (millions)") ylabel("GDP per capita ($K)") ///
    width(1200) height(720) offline noopen                      ///
    export("`out'/20_us_states_bivariate.html")

* Return to county dataset for any subsequent calls
use "`county_data'", clear

*=============================================================================
* v0.6.x + v0.7.0 ADDITIONS (smoke tests; not in the 20-map dashboard above)
*   21  Export menu + collapsible data table (v0.6.0 download datatable)
*   22  Animate-on-scroll into view (v0.6.0 animate)
*   23  Texas-tuned projection default (v0.6.1; visible: panhandle now level)
*   24  Legacy projection escape hatch (v0.6.1 projection(albers_usa))
*   25  Native donut chart (v0.7.0)
*   26  Native horizontal bar with Export menu + animate (v0.7.0)
*   27  Diverging stacked bar (v0.7.0 divbar, Pew-style; demonstrates wrap +
*       central zero baseline + direct labels + net favorability column)
*   28  Bar chart race (v0.7.0 barrace)
*=============================================================================

* 21
sparkta2 poverty_rate, id(fips) name(county) type(choropleth)               ///
    scheme(blues) tooltipvars(median_income pop_thou)                        ///
    download datatable offline noopen                                        ///
    title("v0.6.0 -- Export menu + data table")                              ///
    export("`out'/21_export_menu.html")

* 22
sparkta2 poverty_rate uninsured_rate, id(fips) name(county) type(bivariate) ///
    scheme(rdbu) modes(bivariate|x|y|diff|ratio) comparable                  ///
    download datatable animate offline noopen                                ///
    title("v0.6.0 -- Animate on scroll into view")                           ///
    export("`out'/22_animate.html")

* 23
sparkta2 poverty_rate, id(fips) name(county) type(choropleth)               ///
    offline noopen                                                           ///
    title("v0.6.1 -- Texas-tuned default (panhandle level)")                 ///
    export("`out'/23_proj_default.html")

* 24
sparkta2 poverty_rate, id(fips) name(county) type(choropleth)               ///
    projection(albers_usa) offline noopen                                    ///
    title("v0.6.1 -- legacy projection(albers_usa) for backward-compat")     ///
    export("`out'/24_proj_legacy.html")

* 25 (donut from a tiny synthetic frame)
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
    export("`out'/25_donut.html")
restore

* 26 (native bar2 -- v0.7.1 rename; sparkta's type(bar) still forwards)
preserve
collapse (mean) poverty_rate, by(region_n)
sparkta2 poverty_rate, name(region_n) type(bar2) horizontal scheme(blues)   ///
    download datatable animate offline noopen                                ///
    title("v0.7.1 -- Native bar2 + Export menu + animate")                   ///
    export("`out'/26_native_bar.html")
restore

* 27 (divbar Pew-style, synthetic Likert)
preserve
clear
input str100 q str22 response double share
"Texas is on the right track investing in K-12 public education" "Strongly disagree" 18
"Texas is on the right track investing in K-12 public education" "Disagree"          22
"Texas is on the right track investing in K-12 public education" "Neutral"           14
"Texas is on the right track investing in K-12 public education" "Agree"             29
"Texas is on the right track investing in K-12 public education" "Strongly agree"    17
"Higher education in Texas is affordable for most families"      "Strongly disagree" 29
"Higher education in Texas is affordable for most families"      "Disagree"          33
"Higher education in Texas is affordable for most families"      "Neutral"           14
"Higher education in Texas is affordable for most families"      "Agree"             18
"Higher education in Texas is affordable for most families"      "Strongly agree"    6
end
sparkta2 share, name(q) level(response) type(divbar)                         ///
    levelorder("Strongly disagree|Disagree|Neutral|Agree|Strongly agree")    ///
    centerlevel(Neutral)                                                     ///
    download datatable offline noopen                                        ///
    title("v0.7.0 -- Diverging stacked bar (Pew-style)")                     ///
    width(1100) height(360)                                                  ///
    export("`out'/27_divbar.html")
restore

* 28 (barrace)
preserve
clear
input long yr str22 name double v
2020 "Harris"  4731145
2020 "Dallas"  2613539
2020 "Tarrant" 2110640
2020 "Bexar"   2009324
2020 "Travis"  1290188
2022 "Harris"  4780913
2022 "Dallas"  2613539
2022 "Tarrant" 2154595
2022 "Bexar"   2061226
2022 "Travis"  1330411
2024 "Harris"  4894753
2024 "Dallas"  2604722
2024 "Tarrant" 2211232
2024 "Bexar"   2126810
2024 "Travis"  1378260
end
sparkta2 v, name(name) time(yr) type(barrace) top(5) duration(10)            ///
    scheme(tx2036) download datatable offline noopen                         ///
    title("v0.7.0 -- Bar chart race (synthetic)")                            ///
    export("`out'/28_barrace.html")
restore

use "`county_data'", clear

*=============================================================================
* DASHBOARD -- combine all 20 maps + the 2 pass-throughs into one page
*=============================================================================
local _all_files  "01_bivariate_full.html 02_choropleth_blues.html 03_choropleth_viridis.html 04_bivariate_bupu.html 05_multiples_3panel.html 06_multiples_xy.html 07_diff_only.html 08_rankdiff.html 09_counties_big8.html 10_if_rural.html 11_tooltip_table.html 12_zoomto_dfw.html 13_nozoom.html 14_search.html 15_bar_pass.html 16_scatter_pass.html 17_hexbin_tx.html 18_basemap.html 19_us_states_choropleth.html 20_us_states_bivariate.html"
local _all_titles "Bivariate full UI|Univariate Blues|Univariate Viridis|Bivariate BuPu (static)|Small multiples (3 panels)|Small multiples (X and Y)|Diff-only (value diff)|Rank-diff fallback|Big-8 metros subset|Rural counties (if qualifier)|Tooltip data table|Auto-zoom to DFW|Static (no zoom)|Search by county name|Bar chart (sparkta pass-through)|Scatter + fit (sparkta pass-through)|Hexbin of TX counties|Bivariate + basemap|BONUS: US 50-state choropleth|BONUS: US 50-state bivariate"

local _dash_files ""
local _dash_titles ""
local _nall : word count `_all_files'
local _trest `"`_all_titles'"'
forvalues _i = 1/`_nall' {
    local _fbase : word `_i' of `_all_files'
    local _tpos = strpos(`"`_trest'"', "|")
    if `_tpos' > 0 {
        local _ftit = substr(`"`_trest'"', 1, `_tpos' - 1)
        local _trest = substr(`"`_trest'"', `_tpos' + 1, .)
    }
    else local _ftit `"`_trest'"'
    capture confirm file "`out'/`_fbase'"
    if !_rc {
        local _dash_files "`_dash_files' `_fbase'"
        if "`_dash_titles'" == "" local _dash_titles "`_ftit'"
        else                       local _dash_titles "`_dash_titles'|`_ftit'"
    }
}

sparkta2_dashboard,                                                          ///
    files("`_dash_files'") titles("`_dash_titles'") heights("920")           ///
    title("sparkta2 v0.7.1 -- Texas county + US state demo gallery")         ///
    subtitle("20 worked map examples covering bivariate, choropleth, hexbin, basemap, small multiples, subsetting, search, zoom, downloads, tooltip tables, and chart pass-through. The last two examples (US state-level) demonstrate the engine outside Texas. Eight v0.6.x / v0.7.x additions (Export menu, datatable, animate, Texas-tuned projection, donut, bar2, divbar, barrace) are written next to this dashboard but not embedded here.") ///
    export("`out'/00_dashboard.html") noopen

display as result _n "All sparkta2 demo files written to:"
display as result "  `out'"
display as result _n "Dashboard (start here): `out'/00_dashboard.html"
