*! test_sparkta2_barlabels.do
*! Battery for directlabels on the native bar types (v0.8.0).
*!
*! Covers the six bar layouts the engine renders separately -- single,
*! grouped, and stacked, each horizontal and vertical -- plus donut and
*! divbar, which had direct labels before.  Until v0.8.0 the directlabels
*! flag reached the engine for bars but only donut and divbar acted on it,
*! so every bar variant is checked here to keep that from regressing.
*!
*! Run:   stata-mp -b do test_sparkta2_barlabels.do
*! then:  grep -E "r\([0-9]+\);" test_sparkta2_barlabels.log   (expect no hits)
*!        grep "ALL BARLABEL TESTS PASSED" test_sparkta2_barlabels.log
*!
*! Outputs land in `c(pwd)'/sparkta2_barlabels_out/ (gitignored via *_out/).
*! When run from a clone, put the clone on the adopath first:
*!   adopath ++ "<path-to-clone>"

version 17.0
clear all
set more off

* adopath ++ "<path-to-your-clone>"

capture which sparkta2
if _rc {
    display as error "sparkta2 not found on adopath"
    exit 199
}

local out "`c(pwd)'/sparkta2_barlabels_out"
capture mkdir "`out'"

* HTML holds double quotes, so build needles with char(34) and test the file
* contents inline; a whole HTML file does not survive a local-macro round trip.
local q = char(34)
local DL1 "`q'directlabels`q':1"
local DL0 "`q'directlabels`q':0"
local NRM "`q'normalize`q':1"

* Two categorical dimensions so grouped and stacked layouts both have data,
* and one value with a wide range so some segments are too narrow to label.
clear
input str12 cat str10 grp double val
"Elementary"   "Growth"      52.4
"Elementary"   "Relative"    18.7
"Elementary"   "Achievement" 21.7
"Elementary"   "None"         7.2
"Middle"       "Growth"      19.1
"Middle"       "Relative"    45.8
"Middle"       "Achievement" 35.1
"Middle"       "None"         0.4
"High"         "Growth"       2.8
"High"         "Relative"    39.0
"High"         "Achievement" 58.2
"High"         "None"         0.2
end
tempfile bardata
save `bardata'

*-----------------------------------------------------------------------------
* (1) All six bar layouts build with directlabels and carry the flag through
*     to the emitted meta JSON.
*-----------------------------------------------------------------------------
local n_built = 0

* single series: one row per category
preserve
collapse (sum) val, by(cat)
foreach orient in horizontal "" {
    local tag = cond("`orient'" == "", "vert", "horiz")
    sparkta2 val, name(cat) type(bar2) `orient' directlabels          ///
        title("single `tag'") export("`out'/bar_single_`tag'.html")   ///
        offline noopen
    confirm file "`out'/bar_single_`tag'.html"
    assert strpos(fileread("`out'/bar_single_`tag'.html"), "`DL1'") > 0
    local n_built = `n_built' + 1
}
restore

* grouped and stacked: two dimensions
foreach layout in "" stacked {
    foreach orient in horizontal "" {
        local ltag = cond("`layout'" == "", "grouped", "stacked")
        local otag = cond("`orient'" == "", "vert", "horiz")
        sparkta2 val, name(cat) over(grp) type(bar2) `layout' `orient'    ///
            directlabels title("`ltag' `otag'")                           ///
            export("`out'/bar_`ltag'_`otag'.html") offline noopen
        confirm file "`out'/bar_`ltag'_`otag'.html"
        assert strpos(fileread("`out'/bar_`ltag'_`otag'.html"), "`DL1'") > 0
        local n_built = `n_built' + 1
    }
}
assert `n_built' == 6
display as result "TEST 1 OK: all 6 bar layouts build with directlabels"

*-----------------------------------------------------------------------------
* (2) The engine actually ships bar-label code, not just the flag.  The
*     single/grouped paths label with a text.dlab join; the stacked paths
*     append per-segment labels guarded by a minimum segment width.
*-----------------------------------------------------------------------------
assert strpos(fileread("`out'/bar_single_horiz.html"), "text.dlab") > 0
assert strpos(fileread("`out'/bar_single_horiz.html"), "labelFill") > 0
display as result "TEST 2 OK: embedded engine carries the bar direct-label code"

*-----------------------------------------------------------------------------
* (3) normalize + stacked (the 100% layout) still labels, and the flag is
*     off by default so existing do-files render unchanged.
*-----------------------------------------------------------------------------
sparkta2 val, name(cat) over(grp) type(bar2) horizontal stacked normalize ///
    directlabels title("stacked 100%")                                    ///
    export("`out'/bar_stacked100.html") offline noopen
assert strpos(fileread("`out'/bar_stacked100.html"), "`DL1'") > 0
assert strpos(fileread("`out'/bar_stacked100.html"), "`NRM'") > 0

sparkta2 val, name(cat) over(grp) type(bar2) horizontal stacked ///
    title("no labels") export("`out'/bar_nolabels.html") offline noopen
assert strpos(fileread("`out'/bar_nolabels.html"), "`DL0'") > 0
display as result "TEST 3 OK: normalize labels; directlabels stays off by default"

*-----------------------------------------------------------------------------
* (4) The types that already had direct labels keep them.
*-----------------------------------------------------------------------------
preserve
collapse (sum) val, by(cat)
sparkta2 val, name(cat) type(donut) directlabels ///
    title("donut") export("`out'/donut.html") offline noopen
assert strpos(fileread("`out'/donut.html"), "`DL1'") > 0
restore

* divbar takes long form (item x level x share) and defaults directlabels on
sparkta2 val, name(cat) level(grp) type(divbar)         ///
    levelorder("Growth|Relative|Achievement|None")      ///
    centerlevel("Achievement") title("divbar")          ///
    export("`out'/divbar.html") offline noopen
assert strpos(fileread("`out'/divbar.html"), "`DL1'") > 0
display as result "TEST 4 OK: donut and divbar direct labels unchanged"

display as result _n "ALL BARLABEL TESTS PASSED"
