*! test_sparkta2_nces.do
*! NCES EDGE district-level demo for sparkta2.
*! Loads NCES_EDGE_Texas_District_Map.dta (1,018 Texas school districts) from
*! the _datashare and renders the data on the bundled texas_districts.geojson
*! polygon boundaries (built from NCES EDGE SY2024-25 shapefile, simplified).
*!
*! 20 dashboard examples + 2 v0.7.x chart-type additions (donut over sdtyp,
*! native bar2 of top-15 districts).

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

local out "`c(pwd)'/sparkta2_nces_out"
capture mkdir "`out'"

capture which sparkta
if _rc display as text "Note: sparkta not installed; chart pass-throughs will be skipped."

*-----------------------------------------------------------------------------
* Load NCES EDGE Texas district data from _datashare
*-----------------------------------------------------------------------------
if "${driveuse}" == "" {
    global driveuse "/Users/`c(username)'/Library/CloudStorage/GoogleDrive-eric.booth@texas2036.org/Shared drives/Data and Research Team/"
}
local dta "${driveuse}/_datashare/NCES_EDGE/02_cleaned/NCES_EDGE_Texas_District_Map.dta"
capture confirm file "`dta'"
if _rc {
    display as error "NCES_EDGE_Texas_District_Map.dta not found at:"
    display as error "  `dta'"
    exit 601
}

use "`dta'", clear

* Coordinates ship as strings in District_Map.dta -- destring for points/hexbin
capture destring intptlat intptlon, replace force

* District type label
generate str40 sdtyp_label = "Unknown"
replace sdtyp_label = "Unified"               if sdtyp == "1"
replace sdtyp_label = "Elementary only"       if sdtyp == "2"
replace sdtyp_label = "Secondary only"        if sdtyp == "3"
replace sdtyp_label = "Service agency"        if sdtyp == "5"
replace sdtyp_label = "School-wide / Other"   if sdtyp == "A"
label variable sdtyp_label "District type"

* Convenience labels
label variable school_count   "Schools per district"
label variable student_count  "Total students"
label variable teacher_fte    "Teacher FTEs"
label variable frpl_pct       "% eligible for free/reduced-price lunch"
label variable lunch_eligible "FRPL count"
label variable students_per_teacher "Students per teacher"

* Region grouping: bucket by first two digits of the 7-digit leaid (state=48)
* and then by the next-digit prefix → 8 synthetic regions for filter demos.
generate int region_bucket = mod(real(substr(leaid, 3, 2)), 8)
label define rbL 0 "R0" 1 "R1" 2 "R2" 3 "R3" 4 "R4" 5 "R5" 6 "R6" 7 "R7"
label values region_bucket rbL
label variable region_bucket "Region bucket (synthetic, by leaid)"

* Numeric `frpl_pct' as 0-1 fraction; convert to percent for display
generate float frpl_pct100 = frpl_pct * 100
label variable frpl_pct100 "FRPL eligibility (%)"

* Cap a few extreme small-district stat values for cleaner ranges
generate float spt = students_per_teacher
replace spt = . if spt < 1 | spt > 30
label variable spt "Students per teacher (winsorised 1-30)"

* Big-8 Texas metropolitan ISDs (Houston, Dallas, Austin, San Antonio, Fort Worth, El Paso, Cy-Fair, Northside)
local big8_leaid "4823640 4819170 4806240 4815910 4816050 4807260 4808790 4815240"

* DFW core ISDs
local dfw_leaid "4819170 4816050 4845330 4816140 4843230"

tempfile nces_data
save "`nces_data'", replace

*=============================================================================
* (1) Bivariate choropleth -- FRPL % vs students-per-teacher, full UI
*=============================================================================
sparkta2 frpl_pct100 spt,                                       ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(rdbu) bins(3)                         ///
    modes(bivariate|x|y|diff|ratio)                              ///
    filters(sdtyp_label region_bucket)                           ///
    sliders(frpl_pct100 spt student_count)                       ///
    tooltipvars(student_count teacher_fte school_count)          ///
    swapbutton download search                                   ///
    title("1. Texas school districts -- FRPL% vs S/T ratio")     ///
    subtitle("1,018 NCES EDGE districts; full UI")               ///
    xlabel("FRPL eligibility (%)") ylabel("Students per teacher") ///
    offline noopen export("`out'/01_districts_bivariate.html")

*=============================================================================
* (2) Univariate choropleth -- FRPL %, Blues
*=============================================================================
sparkta2 frpl_pct100,                                           ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(choropleth) scheme(blues)                               ///
    filters(sdtyp_label) sliders(frpl_pct100) download           ///
    title("2. FRPL eligibility by district")                     ///
    xlabel("FRPL (%)")                                           ///
    offline noopen export("`out'/02_districts_frpl_blues.html")

*=============================================================================
* (3) Univariate choropleth -- viridis on student count
*=============================================================================
sparkta2 student_count,                                          ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(choropleth) scheme(viridis)                             ///
    filters(region_bucket) sliders(student_count)                ///
    title("3. Student count by district (Viridis)")              ///
    width(1080) height(760) offline noopen                       ///
    export("`out'/03_districts_students_viridis.html")

*=============================================================================
* (4) Bivariate static, BuPu
*=============================================================================
sparkta2 frpl_pct100 spt,                                        ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(bupu) bins(3) modes(bivariate)        ///
    filters(region_bucket)                                       ///
    title("4. Bivariate -- BuPu static")                         ///
    offline noopen export("`out'/04_districts_bivariate_bupu.html")

*=============================================================================
* (5) Small multiples -- bivariate + diff + ratio
*=============================================================================
sparkta2 frpl_pct100 spt,                                        ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(rdbu) modes(bivariate|diff|ratio)     ///
    multiples comparable                                         ///
    filters(sdtyp_label) sliders(frpl_pct100)                    ///
    title("5. Small multiples -- bivariate, diff, ratio")        ///
    width(1300) height(620) offline noopen                       ///
    export("`out'/05_districts_multiples.html")

*=============================================================================
* (6) Small multiples -- X + Y univariate
*=============================================================================
sparkta2 frpl_pct100 spt,                                        ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(blues) modes(x|y) multiples           ///
    filters(region_bucket)                                       ///
    title("6. Small multiples -- FRPL% and S/T side-by-side")    ///
    width(1280) height(560) offline noopen                       ///
    export("`out'/06_districts_multiples_xy.html")

*=============================================================================
* (7) Diff-only -- rank fallback (units differ)
*=============================================================================
sparkta2 frpl_pct100 student_count,                              ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(puor) mode(diff) modes(diff)          ///
    filters(sdtyp_label)                                         ///
    title("7. Rank-diff -- FRPL% vs student count")              ///
    note("Units differ -> percentile-rank difference.")          ///
    offline noopen export("`out'/07_districts_rankdiff.html")

*=============================================================================
* (8) HEXBIN -- aggregate district centroids into hex grid
*=============================================================================
sparkta2 frpl_pct100,                                            ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(hexbin) scheme(viridis)                                 ///
    hexradius(22) hexstat(mean) download                         ///
    tooltipvars(student_count teacher_fte school_count)          ///
    title("8. Hexbin -- mean FRPL% per hex (district centroids)") ///
    offline noopen export("`out'/08_districts_hexbin.html")

*=============================================================================
* (9) HEXBIN with explicit lat/lon centroids
*=============================================================================
sparkta2 frpl_pct100,                                            ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(hexbin) lat(intptlat) lon(intptlon)                     ///
    hexradius(20) hexstat(mean) scheme(plasma)                   ///
    title("9. Hexbin -- using intptlat/intptlon directly")       ///
    offline noopen export("`out'/09_districts_hexbin_latlon.html")

*=============================================================================
* (10) Hexbin -- count per hex (density)
*=============================================================================
sparkta2 student_count,                                          ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(hexbin) lat(intptlat) lon(intptlon)                     ///
    hexradius(18) hexstat(count) scheme(reds)                    ///
    title("10. Hexbin -- # of districts per hex")                ///
    offline noopen export("`out'/10_districts_hexbin_count.html")

*=============================================================================
* (11) Points -- district centroids as circles, colored by S/T ratio
*=============================================================================
sparkta2 spt,                                                    ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(points) lat(intptlat) lon(intptlon)                     ///
    pointsize(3) scheme(viridis)                                 ///
    filters(sdtyp_label) sliders(spt)                            ///
    tooltipvars(student_count teacher_fte school_count)          ///
    download search                                              ///
    title("11. District centroids -- circles by S/T ratio")      ///
    offline noopen export("`out'/11_districts_points.html")

*=============================================================================
* (12) Subset to Big-8 metro ISDs + auto-zoom
*=============================================================================
sparkta2 frpl_pct100 spt,                                        ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(rdbu)                                 ///
    counties("`big8_leaid'") zoomto("`big8_leaid'")              ///
    tooltipvars(student_count teacher_fte school_count)          ///
    download                                                     ///
    title("12. Big-8 metro ISDs only")                           ///
    subtitle("Houston, Dallas, Austin, San Antonio, Fort Worth, El Paso, Cy-Fair, Northside") ///
    offline noopen export("`out'/12_districts_big8.html")

*=============================================================================
* (13) `if' qualifier -- districts with > 5,000 students
*=============================================================================
sparkta2 frpl_pct100 spt if student_count > 5000,                ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(gnbu)                                 ///
    filters(sdtyp_label) sliders(student_count)                  ///
    title("13. Districts with > 5,000 students")                 ///
    offline noopen export("`out'/13_districts_if_large.html")

*=============================================================================
* (14) Tooltipvars data table -- 6 extra fields
*=============================================================================
sparkta2 frpl_pct100,                                            ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(choropleth) scheme(blues)                               ///
    tooltipvars(sdtyp_label student_count school_count teacher_fte spt lunch_eligible) ///
    title("14. Tooltip data table -- 6 fields per district")     ///
    offline noopen export("`out'/14_districts_tooltip_table.html")

*=============================================================================
* (15) zoomto DFW core
*=============================================================================
sparkta2 frpl_pct100 spt,                                        ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(rdbu)                                 ///
    zoomto("`dfw_leaid'") tooltipvars(student_count school_count) ///
    title("15. Auto-zoom to DFW core ISDs")                      ///
    offline noopen export("`out'/15_districts_zoomto_dfw.html")

*=============================================================================
* (16) nozoom static export
*=============================================================================
sparkta2 frpl_pct100 spt,                                        ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(bivariate) scheme(rdbu) nozoom download                 ///
    title("16. Static district map (no zoom)")                   ///
    offline noopen export("`out'/16_districts_nozoom.html")

*=============================================================================
* (17) Search by district name
*=============================================================================
sparkta2 frpl_pct100,                                            ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)         ///
    type(choropleth) scheme(viridis) search                      ///
    title("17. Search districts by name")                        ///
    subtitle("Try 'Houston' or 'Dallas' in the search box")      ///
    offline noopen export("`out'/17_districts_search.html")

*=============================================================================
* (18) Roll up to county level via leaid -> county mapping (synthetic)
*     Maps each district to a county by parsing leaid; simple demo of a
*     district-level dataset rendered on the county topojson.
*=============================================================================
preserve
    quietly findfile texas_county_demo.csv
    quietly import delimited using "`r(fn)'", varnames(1) clear stringcols(2)
    quietly destring fips, replace force
    quietly sort fips
    quietly gen long _idx = _n
    tempfile county_list
    quietly save "`county_list'"
restore
preserve
    * Synthetic district-to-county mapping for demonstration purposes.
    quietly generate long _idx = mod(real(leaid), 254) + 1
    quietly merge m:1 _idx using "`county_list'", keepusing(fips) nogen keep(match)
    quietly collapse (mean) frpl_pct100 (sum) student_count, by(fips)
    quietly label variable frpl_pct100 "Mean district FRPL (%)"
    sparkta2 frpl_pct100,                                        ///
        id(fips) geo(texas)                                       ///
        type(choropleth) scheme(blues) download                   ///
        tooltipvars(student_count)                                ///
        title("18. District data rolled up to TX counties (demo)") ///
        offline noopen export("`out'/18_districts_to_county.html")
restore

*=============================================================================
* (19) Scatter -- students vs teachers, colored by district type
*     Two highly correlated metrics (student_count, teacher_fte) crossed by
*     a third (district type via over()), with an interactive region filter.
*=============================================================================
capture which sparkta
if !_rc {
    capture noisily sparkta2 student_count teacher_fte,          ///
        type(scatter) fit(lfit) over(sdtyp_label)                ///
        filters(region_bucket)                                   ///
        title("19. Students vs teachers by district type")       ///
        subtitle("Filter the region dropdown to see how districts cluster") ///
        xtitle("Total students") ytitle("Teacher FTEs")          ///
        offline export("`out'/19_districts_scatter.html")
}

*=============================================================================
* (20) Bar -- three district metrics by type, with region filter
*     student_count, teacher_fte, school_count averaged per district type.
*     One filter (region_bucket) lets the viewer crosstab by region.
*=============================================================================
capture which sparkta
if !_rc {
    capture noisily sparkta2 student_count teacher_fte school_count, ///
        type(bar) over(sdtyp_label) stat(mean)                   ///
        filters(region_bucket)                                   ///
        title("20. Mean students, teachers, schools by district type") ///
        subtitle("Three crosstabable metrics + a region filter")  ///
        offline export("`out'/20_districts_bar.html")
}

*=============================================================================
* v0.7.0 ADDITIONS (district-level chart types; smoke tests, not in dashboard)
*   21  Donut: enrollment share by district rating
*   22  Native horizontal bar with v0.6.0 Export menu + animate:
*       top-15 districts by enrollment
*   23  Native line chart: median FRPL eligibility over panel years (synthetic)
*=============================================================================

* 21: Donut over rating categories (count of districts by sdtyp)
preserve
capture confirm variable sdtyp
if !_rc {
    drop if missing(sdtyp)
    gen byte one = 1
    collapse (sum) n_districts = one, by(sdtyp)
    rename sdtyp rating
    sparkta2 n_districts, name(rating) type(donut) scheme(tx2036)            ///
        download datatable animate offline noopen                             ///
        title("v0.7.0 -- Districts by sdtyp")                                 ///
        export("`out'/21_districts_donut.html")
}
restore

* 22: Native horizontal bar of top-15 districts by student count
preserve
capture confirm variable student_count
if !_rc {
    keep if !missing(student_count)
    gsort -student_count
    keep in 1/15
    sparkta2 student_count, name(name) type(bar2) horizontal                 ///
        scheme(blues) download datatable animate offline noopen              ///
        title("v0.7.1 -- Top-15 districts by student count (bar2)")          ///
        export("`out'/22_districts_top15_bar.html")
}
restore

*=============================================================================
* DASHBOARD -- combine all into one scrollable page
*=============================================================================
local _all_files  "01_districts_bivariate.html 02_districts_frpl_blues.html 03_districts_students_viridis.html 04_districts_bivariate_bupu.html 05_districts_multiples.html 06_districts_multiples_xy.html 07_districts_rankdiff.html 08_districts_hexbin.html 09_districts_hexbin_latlon.html 10_districts_hexbin_count.html 11_districts_points.html 12_districts_big8.html 13_districts_if_large.html 14_districts_tooltip_table.html 15_districts_zoomto_dfw.html 16_districts_nozoom.html 17_districts_search.html 18_districts_to_county.html 19_districts_scatter.html 20_districts_bar.html"
local _all_titles "Bivariate full UI|Univariate FRPL Blues|Student count Viridis|Bivariate BuPu (static)|Small multiples (3 panels)|Small multiples (X and Y)|Rank-diff|Hexbin (centroids)|Hexbin (lat/lon direct)|Hexbin -- density count|Points -- centroids|Big-8 metro ISDs|Districts > 5K students|Tooltip data table|Auto-zoom to DFW|Static (no zoom)|Search by district name|Rolled up to counties|Sparkta scatter pass-through|Sparkta bar pass-through"

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
    title("sparkta2 v0.7.1 -- Texas school district demo gallery")           ///
    subtitle("20 examples using NCES EDGE Texas District Map data (1,018 districts) on simplified district polygons (SY2024-25 NCES EDGE shapefile). Two v0.7.x chart-type additions (donut over sdtyp; native bar2 of top-15 districts) are written next to this dashboard but not embedded here.") ///
    export("`out'/00_dashboard.html") noopen

display as result _n "NCES district demo files written to:"
display as result "  `out'"
display as result _n "Dashboard (start here): `out'/00_dashboard.html"
