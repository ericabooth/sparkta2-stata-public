*! test_sparkta2_geojson.do
*! Regression battery for GeoJSON geographies (v0.8.13).
*!   stata-mp -b do test_sparkta2_geojson.do      (from the repository folder)
*!
*! Before v0.8.13, overlays() drew nothing on a GeoJSON map and said
*! nothing, and every geography except geo(texas) used the national
*! projection, which tilts Texas.  Stata cannot look at the drawn page, so
*! these checks read what is written into the HTML file: the overlay
*! specification and data, the projection request, and the engine code that
*! handles each case.  Open the pages in sparkta2_geojson_out to check the drawing.

version 17.0
clear all
set more off

local repo "`c(pwd)'"
capture confirm file "`repo'/texas_districts.geojson"
if _rc {
    display as error "run this file from the sparkta2 repository folder"
    exit 601
}
local out "`repo'/sparkta2_geojson_out"
capture mkdir "`out'"
local q = char(34)
local nfail 0
local ntest 0

* does the file contain the text?  (a whole page does not fit in a macro)
capture program drop _gj_has
program define _gj_has, rclass
    * the text to look for is in the global GJN: it holds double quotes,
    * which do not survive being passed as a program argument
    args file
    mata: st_numscalar("r(hit)", strpos(_gj_slurp(st_local("file")), st_global("GJN")) > 0)
    return scalar hit = r(hit)
end
mata:
string scalar _gj_slurp(string scalar f)
{
    real scalar fh
    string scalar s, b
    fh = fopen(f, "r"); s = ""
    while ((b = fread(fh, 1048576)) != J(0, 0, "")) s = s + b
    fclose(fh)
    return(s)
}
end

* data: one row per district in the bundled GeoJSON, ids read from the file
tempfile ids
mata:
s = _gj_slurp("texas_districts.geojson")
ids = J(0, 1, "")
p = 1
tag = char(34) + "geoid" + char(34) + ":" + char(34)
while ((k = strpos(substr(s, p, .), tag)) > 0) {
    ids = ids \ substr(s, p + k - 1 + strlen(tag), 7)
    p = p + k + strlen(tag) + 6
}
st_local("nid", strofreal(rows(ids)))
(void) st_addobs(rows(ids))
(void) st_addvar("str7", "leaid")
st_sstore(., "leaid", ids)
end
local ++ntest
if `nid' != 1016 {
    display as error "FAIL setup: expected 1016 district ids, read `nid'"
    local ++nfail
}
gen value = mod(_n, 17)
gen region = cond(mod(_n, 3) == 0, "A", cond(mod(_n, 3) == 1, "B", "C"))
label variable region "Regions"
gen name = "District " + leaid

*--- 1. group-variable overlay on a GeoJSON geography ------------------------*
sparkta2 value, id(leaid) name(name) geo(texas_districts) idwidth(7)   ///
    type(choropleth) overlays(region) offline noopen                    ///
    export("`out'/01_overlay_groupvar.html")
local ++ntest
global GJN "`q'kind`q':`q'groupvar`q'"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 1: page lacks $GJN"
    local ++nfail
}
local ++ntest
global GJN "`q'o__region`q'"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 1: page lacks $GJN"
    local ++nfail
}
local ++ntest
global GJN "__undissolved"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 1: page lacks $GJN"
    local ++nfail
}
local ++ntest
global GJN "sparkta2-engine 0.8.13"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 1: page lacks $GJN"
    local ++nfail
}

*--- 2. a layer token on GeoJSON still builds (a note is printed) ------------*
local ++ntest
capture noisily sparkta2 value, id(leaid) name(name) geo(texas_districts) ///
    idwidth(7) type(choropleth) overlays(region states) offline noopen     ///
    export("`out'/02_overlay_object.html")
if _rc {
    display as error "FAIL 2: rc=" _rc
    local ++nfail
}

*--- 3. no projection() given: the page asks for none, the engine decides ----*
local ++ntest
global GJN "`q'projection`q':`q'`q'"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 3 (empty projection): page lacks $GJN"
    local ++nfail
}
local ++ntest
global GJN "(texas|tx)[_-]"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 3: page lacks $GJN"
    local ++nfail
}
local ++ntest
global GJN "d3.geoBounds(fitFC)"
_gj_has "`out'/01_overlay_groupvar.html"
if r(hit) != 1 {
    display as error "FAIL 3: page lacks $GJN"
    local ++nfail
}

*--- 4. an explicit projection() is passed through unchanged -----------------*
sparkta2 value, id(leaid) name(name) geo(texas_districts) idwidth(7)   ///
    type(choropleth) projection(albers_usa) offline noopen              ///
    export("`out'/04_explicit_projection.html")
local ++ntest
global GJN "`q'projection`q':`q'albers_usa`q'"
_gj_has "`out'/04_explicit_projection.html"
if r(hit) != 1 {
    display as error "FAIL 4: page lacks $GJN"
    local ++nfail
}

*--- 5. county (TopoJSON) overlays are untouched -----------------------------*
import delimited using "`repo'/texas_county_demo.csv", varnames(1) clear
gen half = cond(mod(fips, 2), "odd", "even")
sparkta2 poverty_rate, id(fips) name(county) type(choropleth)          ///
    overlays(half states) offline noopen export("`out'/05_county_overlays.html")
local ++ntest
global GJN "`q'kind`q':`q'groupvar`q'"
_gj_has "`out'/05_county_overlays.html"
if r(hit) != 1 {
    display as error "FAIL 5: page lacks $GJN"
    local ++nfail
}
local ++ntest
global GJN "`q'kind`q':`q'object`q'"
_gj_has "`out'/05_county_overlays.html"
if r(hit) != 1 {
    display as error "FAIL 5: page lacks $GJN"
    local ++nfail
}

display as text _n "geojson: `ntest' checks, `nfail' failed"
if `nfail' exit 9
display as result "GEOJSON_OK"
