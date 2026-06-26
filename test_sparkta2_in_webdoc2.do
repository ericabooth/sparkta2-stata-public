*! test_sparkta2_in_webdoc2.do
*!
*!   INVOKE VIA  webdoc do  (NOT plain do):
*!     . webdoc do test_sparkta2_in_webdoc2.do, replace
*!
*!   This do-file (1) writes 3 sparkta2 maps and (2) builds a webdoc2 report
*!   that embeds them via wdiframe. The report and the 3 maps land in
*!   cwd/sparkta2_webdoc2_out/ next to each other (same-origin rule).

version 17.0
set more off

local outdir "`c(pwd)'/sparkta2_webdoc2_out"
shell mkdir -p "`outdir'"
cd "`outdir'"

* Build the demo data once
findfile texas_county_demo.csv
import delimited using "`r(fn)'", varnames(1) clear stringcols(2)
destring fips poverty_rate uninsured_rate, replace force
generate int region_n = mod(fips - 48000, 5)
label define regL 0 "North" 1 "East" 2 "South" 3 "West" 4 "Central"
label values region_n regL
label variable region_n "Region"

* Three sparkta2 maps written into the report's directory
sparkta2 poverty_rate uninsured_rate, id(fips) name(county) ///
    type(bivariate) scheme(rdbu) modes(bivariate|x|y|diff|ratio) ///
    comparable filters(region_n) sliders(poverty_rate uninsured_rate) ///
    swapbutton download search offline noopen tx2036style ///
    title("Texas counties: poverty vs uninsured") ///
    export("map_bivariate.html")

sparkta2 poverty_rate, id(fips) name(county) ///
    type(hexbin) scheme(viridis) hexradius(22) hexstat(mean) ///
    download offline noopen tx2036style ///
    title("Hexbin -- mean poverty rate per hex") ///
    export("map_hexbin.html")

sparkta2 poverty_rate uninsured_rate, id(fips) name(county) ///
    type(bivariate) scheme(rdbu) basemap modes(bivariate|x|y|diff|ratio) ///
    comparable offline noopen tx2036style ///
    title("Bivariate + US-state basemap") ///
    export("map_basemap.html")

* Now switch the webdoc2 report's target to live next to those maps
wdinit sparkta2_in_webdoc2, replace

wput Each sparkta2 map writes a fully offline HTML file with d3, topojson-client, d3-hexbin, the engine, and the data all inlined. An iframe (via wdiframe) gives a self-contained widget that does not compete with the parent report for global CSS, DOM ids, or D3 instances.

wputh2 Map 1: bivariate full UI
wdiframe map_bivariate.html, height(820px)

wputh2 Map 2: hexbin
wdiframe map_hexbin.html, height(720px)

wputh2 Map 3: bivariate with state basemap
wdiframe map_basemap.html, height(820px)

wputh2 Tripwires
wput See WEBDOC2_EMBEDDING.md for the full list. The four important ones:
wdlist
    wditem Parent report and all iframe targets must share a folder (file:// same-origin per directory).
    wditem Pass bare filenames to wdiframe, not absolute paths.
    wditem Each map is 0.9 to 2 MB offline. Five maps on one page is roughly 10 MB.
    wditem Iframe height around 820px clears the controls panel; 720 cuts it off.
wdlistend

* v0.7.0 native chart types embed via the same wdiframe pattern as maps.
preserve
clear
input str30 sector long enroll
"Public 4-year" 644000
"Public 2-year" 714000
"Independent"   162000
"Career schools" 86000
"Health-related" 19000
end
sparkta2 enroll, name(sector) type(donut) scheme(tx2036) download datatable tx2036style downloadpos(below) ///
    offline noopen title("v0.7.0 donut: enrollment by sector")               ///
    export("chart_donut.html")
restore

wputh2 v0.7.0 native chart types
wput The new D3 chart engine (donut, bar, line, divbar, barrace) emits the same offline HTML shape as the maps; wdiframe handles them identically.

wdiframe chart_donut.html, height(620px)

wdclose
