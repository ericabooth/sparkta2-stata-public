*! test_sparkta2_v080.do
*! Battery for the v0.8.0 features: dashtab() higher-order tabs (incl.
*! per-tab geographies), overlays() checkbox layers (object mesh + dissolve
*! by data variable), maplabels, rasterimage(), sparkta2_dashboard tabs,
*! chart-side dashtab(), and the error paths.
*!
*! Run:   stata-mp -b do test_sparkta2_v080.do
*! then:  grep -E "r\([0-9]+\);" test_sparkta2_v080.log   (expect no hits)
*!        grep "ALL V080 TESTS PASSED" test_sparkta2_v080.log
*!
*! Outputs land in `c(pwd)'/sparkta2_v080_out/ (gitignored via *_out/).
*! When run from a clone, the clone directory itself must be on the adopath:
*!   adopath ++ "<path-to-clone>"   (uncomment + edit below if needed)

version 17.0
clear all
set more off

* adopath ++ "<path-to-your-clone>"

capture which sparkta2
if _rc {
    display as error "sparkta2 not found on adopath"
    exit 199
}

local out "`c(pwd)'/sparkta2_v080_out"
capture mkdir "`out'"

*-----------------------------------------------------------------------------
* Data: county demo + a synthetic 4-way region grouping (self-contained --
* no external crosswalk needed; any county->group mapping exercises the
* dissolve identically)
*-----------------------------------------------------------------------------
findfile texas_county_demo.csv
import delimited using "`r(fn)'", varnames(1) stringcols(2) clear
destring fips poverty_rate uninsured_rate, replace force
label variable poverty_rate   "Poverty rate (%)"
label variable uninsured_rate "Uninsured rate (%)"
generate int region4 = 1 + mod(floor((fips - 48001) / 2), 4)
label define reg4L 1 "Panhandle-Plains" 2 "Central Corridor" 3 "Gulf-Border" 4 "Piney-Metro"
label values region4 reg4L
label variable region4 "Synthetic region"
tempfile counties
save `counties'

*-----------------------------------------------------------------------------
* 1. Regression guard: plain choropleth (single-tab path)
*-----------------------------------------------------------------------------
sparkta2 poverty_rate, id(fips) name(county) type(choropleth) ///
    title("v080-1 plain choropleth") export("`out'/v080_01_plain.html") offline noopen
assert r(n_tabs) == 1
assert r(n_rows) == 254

*-----------------------------------------------------------------------------
* 2. overlays(): dissolve-by-variable + topo-object mesh + maplabels,
*    plus a SPARSE highlight variable (empty for most rows -> only the
*    flagged counties get dissolved outlines; label sits on largest part)
*-----------------------------------------------------------------------------
generate str28 keyc = ""
replace keyc = "Key study counties (demo)" ///
    if inlist(fips, 48201, 48113, 48439, 48029, 48453)
label variable keyc "Key study counties (demo)"
sparkta2 poverty_rate, id(fips) name(county) type(choropleth) ///
    overlays(region4 states keyc) maplabels labelsize(7) download datatable ///
    title("v080-2 overlays + labels") export("`out'/v080_02_overlays.html") offline noopen

*-----------------------------------------------------------------------------
* 3. dashtab(), same geography on both tabs + an overlay riding along
*-----------------------------------------------------------------------------
generate byte half = fips >= 48250
label define halfL 0 "West half" 1 "East half"
label values half halfL
sparkta2 poverty_rate, id(fips) name(county) type(choropleth) dashtab(half) ///
    overlays(region4) dashtabstyle(buttons) ///
    title("v080-3 dashtab buttons") export("`out'/v080_03_dashtab.html") offline noopen
assert r(n_tabs) == 2
assert r(n_rows) == 254

*-----------------------------------------------------------------------------
* 4. dashtab() across DIFFERENT geographies: counties tab + districts tab
*-----------------------------------------------------------------------------
use `counties', clear
keep fips county poverty_rate
generate str9 geoid = string(fips)
rename county name
drop fips
generate int level = 1
tempfile ctylong
save `ctylong'

findfile texas_districts.geojson
local djson "`r(fn)'"
clear
python:
import json
from sfi import Data, Macro
g = json.load(open(Macro.getLocal("djson")))
ids = [f["properties"]["geoid"] for f in g["features"]]
nms = [f["properties"]["name"] for f in g["features"]]
Data.setObsTotal(len(ids))
Data.addVarStr("geoid", 9)
Data.addVarStr("name", 244)
Data.store("geoid", None, [[i] for i in ids])
Data.store("name", None, [[n] for n in nms])
end
generate double poverty_rate = 5 + mod(real(geoid), 47) * 0.55
generate int level = 2
append using `ctylong'
label define lvlL 1 "Counties" 2 "School districts"
label values level lvlL
label variable poverty_rate "Poverty rate (%)"

sparkta2 poverty_rate, id(geoid) name(name) type(choropleth) ///
    dashtab(level) dashtabgeo(texas|texas_districts) dashtabidwidth(5 7) ///
    title("v080-4 counties vs districts") export("`out'/v080_04_multigeo.html") offline noopen
assert r(n_tabs) == 2

*-----------------------------------------------------------------------------
* 5. rasterimage(): generate a tiny PNG in python, then embed under mercator
*-----------------------------------------------------------------------------
local rpng "`out'/v080_test_raster.png"
python:
import zlib, struct
from sfi import Macro
W, H = 120, 80
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
rows = b""
for y in range(H):
    row = b"\x00"
    for x in range(W):
        row += bytes((214, 69, 0, 120)) if (x//10 + y//10) % 2 == 0 else bytes((27, 45, 85, 80))
    rows += row
# NOTE: keep this a single line -- Stata's python console treats the line
# after a multi-line parenthesized expression as a continuation, silently
# swallowing it (the open() would never run).
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
open(Macro.getLocal("rpng"), "wb").write(png)
end
use `counties', clear
sparkta2 poverty_rate, id(fips) name(county) type(choropleth) projection(mercator) ///
    rasterimage("`rpng'") rasterbounds(-104 28 -96 34) rasteropacity(0.6) ///
    rasterlabel("Checker test") ///
    title("v080-5 raster") export("`out'/v080_05_raster.html") offline noopen

*-----------------------------------------------------------------------------
* 6. Chart-side dashtab(): bar2 and donut across two aggregation levels
*-----------------------------------------------------------------------------
clear
input str24 name double val int level
"Austin ISD"      74  1
"Dallas ISD"      69  1
"Houston ISD"     71  1
"Fort Worth ISD"  66  1
"El Paso ISD"     72  1
"Central region"  70  2
"North region"    68  2
"Gulf region"     73  2
end
label define clvl 1 "Districts" 2 "Regions"
label values level clvl
label variable val "Share meeting standard (%)"

sparkta2 val, name(name) type(bar2) horizontal dashtab(level) ///
    title("v080-6 chart dashtab bar2") export("`out'/v080_06_chart_dashtab.html") offline noopen
assert r(n_tabs) == 2

sparkta2 val, name(name) type(donut) dashtab(level) dashtabstyle(buttons) ///
    title("v080-7 chart dashtab donut") export("`out'/v080_07_chart_donut.html") offline noopen

*-----------------------------------------------------------------------------
* 7. sparkta2_dashboard, tabs
*-----------------------------------------------------------------------------
sparkta2_dashboard, files("v080_01_plain.html v080_02_overlays.html v080_05_raster.html") ///
    titles("Plain|Overlays|Raster") tabs noopen ///
    title("v080 tabbed dashboard") export("`out'/v080_08_dashboard_tabs.html")
assert "`r(layout)'" == "tabs"

*-----------------------------------------------------------------------------
* 8. Error paths (must fail cleanly with r(198))
*-----------------------------------------------------------------------------
use `counties', clear
generate byte onelvl = 1
capture sparkta2 poverty_rate, id(fips) type(choropleth) dashtab(onelvl) ///
    export("`out'/should_not_exist_1.html") offline noopen
assert _rc == 198

capture sparkta2 poverty_rate, id(fips) type(choropleth) dashtab(region4) ///
    counties(48201|48113) export("`out'/should_not_exist_2.html") offline noopen
assert _rc == 198

capture sparkta2 poverty_rate, id(fips) type(choropleth) ///
    rasterimage("no_such_file_xyz.png") rasterbounds(-104 28 -96 34) ///
    export("`out'/should_not_exist_3.html") offline noopen
assert _rc == 601

* dashtab on a sparkta pass-through type must be rejected by the dispatcher
capture sparkta2 poverty_rate, type(bar) dashtab(region4) export("`out'/x.html")
assert _rc == 198

*-----------------------------------------------------------------------------
* Payload sanity: every output contains the tabs payload and bootstrap
*-----------------------------------------------------------------------------
foreach f in v080_01_plain v080_02_overlays v080_03_dashtab v080_04_multigeo v080_05_raster {
    quietly checksum "`out'/`f'.html"
    assert r(filelen) > 300000
}

display as result _n "ALL V080 TESTS PASSED"
