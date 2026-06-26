*! test_sparkta2_in_webdoc2.do  v0.7.6
*!
*!   Comprehensive single-page demo embedding many sparkta2 outputs via
*!   webdoc2.  Uses webdoc2's NATIVE theme (Bootstrap 5.3 navbar + Inter
*!   font + Texas 2036 navy/orange tokens injected automatically by wdinit)
*!   instead of a hand-rolled CSS, so the styling matches the other
*!   webdoc2 sites in _datashare/_documentation/.
*!
*!   INVOKE VIA  webdoc do  (NOT plain do):
*!     webdoc do test_sparkta2_in_webdoc2.do, replace
*!
*!   Output:
*!     <cwd>/sparkta2_webdoc2_out/index.html      <-- open this in your browser
*!     <cwd>/sparkta2_webdoc2_out/s1_*.html ... s12_*.html
*!
*!   Sections (12 total):
*!     1.  Bivariate choropleth (full UI)
*!     2.  Univariate choropleth -- Texas-tuned projection
*!     3.  Hexbin map
*!     4.  Bivariate + US-state basemap
*!     5.  Donut chart
*!     6.  Native bar2 (horizontal)
*!     7.  Native line2 (multi-series, 2018-2024)
*!     8.  Diverging stacked bar (Pew-style Likert)
*!     9.  Bar chart race -- Texas top counties 2010-2024
*!         (2010-2018 are synthetic random-walk; 2019-2024 are real PEP)
*!    10.  Same bar2 with wraplabel(off) + gutterwidth(140)
*!    11.  sparkta scatter (Chart.js) -- pass-through
*!    12.  sparkta bar (Chart.js)     -- pass-through

version 17.0
set more off

* All paths are absolute to dodge a long-standing footgun: when sparkta2
* forwards to sparkta (Chart.js), relative export() paths resolve against
* the Stata install bundle rather than cwd.
local outdir "`c(pwd)'/sparkta2_webdoc2_out"
shell mkdir -p "`outdir'"

* ============================================================================
* 1. DATA SETUP
* ============================================================================
findfile texas_county_demo.csv
import delimited using "`r(fn)'", varnames(1) clear stringcols(2)
destring fips poverty_rate uninsured_rate, replace force

generate int region_n = mod(fips - 48000, 5)
label define regL 0 "North" 1 "East" 2 "South" 3 "West" 4 "Central"
label values region_n regL
label variable region_n "Region (synthetic)"

generate byte urban = (poverty_rate < 18 & uninsured_rate < 18)
label define urbanL 0 "Rural" 1 "Urban"
label values urban urbanL
label variable urban "Urban / Rural (demo)"

set seed 20260626
generate float pop_thou      = round(20 + 60*runiform() + 0.3*poverty_rate^2, 1)
generate float median_income = round(35000 + 800*runiform()*(100-poverty_rate) + 200*uninsured_rate, 100)
generate float life_expect   = round(73 + 6*(1 - poverty_rate/40) + runiform()*1.5, 0.1)
label variable pop_thou      "Population (thousands, synthetic)"
label variable median_income "Median household income ($)"
label variable life_expect   "Life expectancy (years)"

tempfile county
save "`county'", replace

* ============================================================================
* 2. WRITE EACH SECTION'S OUTPUT INTO `outdir' (absolute paths, no cd)
* ============================================================================

* ----- (S1) Bivariate map, full UI -----
sparkta2 poverty_rate uninsured_rate, id(fips) name(county) type(bivariate)   ///
    scheme(rdbu) modes(bivariate|x|y|diff|ratio) comparable                    ///
    filters(region_n urban) sliders(poverty_rate uninsured_rate)               ///
    tooltipvars(median_income life_expect pop_thou)                            ///
    swapbutton download datatable search tx2036style                           ///
    title("Texas counties -- poverty vs uninsured")                            ///
    subtitle("Bivariate choropleth, full interactive UI")                      ///
    offline noopen export("`outdir'/s1_bivariate_full.html")

* ----- (S2) Choropleth map, Texas-tuned projection -----
sparkta2 poverty_rate, id(fips) name(county) type(choropleth) scheme(blues)   ///
    download datatable tx2036style                                             ///
    title("Texas counties -- poverty rate (Texas-tuned Albers)")               ///
    offline noopen export("`outdir'/s2_choropleth_texas.html")

* ----- (S3) Hexbin map with Export menu -----
sparkta2 poverty_rate, id(fips) name(county) type(hexbin) scheme(viridis)     ///
    hexradius(22) hexstat(mean) download datatable animate tx2036style         ///
    title("Texas counties -- hexbin of poverty rate")                          ///
    offline noopen export("`outdir'/s3_hexbin.html")

* ----- (S4) Bivariate with US-state basemap -----
sparkta2 poverty_rate uninsured_rate, id(fips) name(county) type(bivariate)   ///
    scheme(rdbu) basemap modes(bivariate|x|y|diff|ratio) comparable            ///
    download datatable tx2036style                                             ///
    title("Bivariate + US-state basemap")                                      ///
    offline noopen export("`outdir'/s4_basemap.html")

* ----- (S5) Donut chart -----
preserve
clear
input str30 sector long enroll
"Public 4-year"  644000
"Public 2-year"  714000
"Independent"    162000
"Career schools"  86000
"Health-related"  19000
end
sparkta2 enroll, name(sector) type(donut) scheme(tx2036)                       ///
    download datatable animate offline noopen                                  ///
    tx2036style downloadpos(below)                                             ///
    title("Texas postsecondary enrollment by sector (donut)")                  ///
    export("`outdir'/s5_donut.html")
restore

* ----- (S6) Native bar2, horizontal, mean poverty by region -----
preserve
collapse (mean) poverty_rate uninsured_rate, by(region_n)
sparkta2 poverty_rate, name(region_n) type(bar2) horizontal scheme(blues)      ///
    tooltipvars(uninsured_rate)                                                 ///
    download datatable animate offline noopen                                  ///
    tx2036style downloadpos(below)                                             ///
    title("Mean poverty rate by region (sparkta2-native bar2)")                ///
    export("`outdir'/s6_bar2_horizontal.html")
restore

* ----- (S7) Native line2 multi-series -----
preserve
clear
input double yr str20 series double y
2018 "Texas"           42.0
2019 "Texas"           43.1
2020 "Texas"           41.5
2021 "Texas"           42.8
2022 "Texas"           43.9
2023 "Texas"           44.5
2024 "Texas"           45.2
2018 "ESC 13 (Austin)" 46.5
2019 "ESC 13 (Austin)" 47.0
2020 "ESC 13 (Austin)" 46.1
2021 "ESC 13 (Austin)" 47.2
2022 "ESC 13 (Austin)" 48.0
2023 "ESC 13 (Austin)" 48.6
2024 "ESC 13 (Austin)" 49.3
2018 "ESC 4 (Houston)" 39.0
2019 "ESC 4 (Houston)" 40.4
2020 "ESC 4 (Houston)" 38.5
2021 "ESC 4 (Houston)" 39.1
2022 "ESC 4 (Houston)" 40.0
2023 "ESC 4 (Houston)" 40.6
2024 "ESC 4 (Houston)" 41.2
end
sparkta2 y yr, over(series) type(line2) scheme(tx2036)                         ///
    download datatable animate offline noopen                                  ///
    tx2036style downloadpos(below)                                             ///
    title("Time trend, 2018-2024 (sparkta2-native line2)")                     ///
    xlabel("Year") ylabel("% meeting")                                          ///
    export("`outdir'/s7_line2_multi_series.html")
restore

* ----- (S8) Diverging stacked bar (Pew-style Likert) -----
preserve
clear
input str120 q str22 response double share
"Texas is on the right track when it comes to investing in K-12 public education"          "Strongly disagree"   18
"Texas is on the right track when it comes to investing in K-12 public education"          "Disagree"            22
"Texas is on the right track when it comes to investing in K-12 public education"          "Neutral"             14
"Texas is on the right track when it comes to investing in K-12 public education"          "Agree"               29
"Texas is on the right track when it comes to investing in K-12 public education"          "Strongly agree"      17
"My local school district uses its funding effectively"                                     "Strongly disagree"    9
"My local school district uses its funding effectively"                                     "Disagree"            18
"My local school district uses its funding effectively"                                     "Neutral"             21
"My local school district uses its funding effectively"                                     "Agree"               39
"My local school district uses its funding effectively"                                     "Strongly agree"      13
"State leaders should expand school choice through publicly funded programs"               "Strongly disagree"   24
"State leaders should expand school choice through publicly funded programs"               "Disagree"            18
"State leaders should expand school choice through publicly funded programs"               "Neutral"             12
"State leaders should expand school choice through publicly funded programs"               "Agree"               26
"State leaders should expand school choice through publicly funded programs"               "Strongly agree"      20
"Higher education in Texas is affordable for most families"                                "Strongly disagree"   29
"Higher education in Texas is affordable for most families"                                "Disagree"            33
"Higher education in Texas is affordable for most families"                                "Neutral"             14
"Higher education in Texas is affordable for most families"                                "Agree"               18
"Higher education in Texas is affordable for most families"                                "Strongly agree"       6
"Texas should invest more in early childhood education before kindergarten"                "Strongly disagree"    7
"Texas should invest more in early childhood education before kindergarten"                "Disagree"            13
"Texas should invest more in early childhood education before kindergarten"                "Neutral"             18
"Texas should invest more in early childhood education before kindergarten"                "Agree"               36
"Texas should invest more in early childhood education before kindergarten"                "Strongly agree"      26
end
sparkta2 share, name(q) level(response) type(divbar)                            ///
    levelorder("Strongly disagree|Disagree|Neutral|Agree|Strongly agree")       ///
    centerlevel(Neutral)                                                        ///
    tx2036style downloadpos(below) download datatable                            ///
    title("Pew-style divbar: 5 Texas policy items, full Likert distribution")   ///
    width(1100) height(560)                                                      ///
    offline noopen export("`outdir'/s8_divbar.html")
restore

* ----- (S9) Bar chart race -- Texas top counties 2010-2024 -----
*   Real Census PEP estimates for 2019-2024 (8 counties).  Then a backward
*   random-walk to fabricate 2010-2018 anchored at each county's 2019 value
*   so the race has 15 frames to animate over.  ~1% YoY rms drift, seed
*   1029384 for reproducibility.  Treat early years as illustrative only.
preserve
clear
input long yr str22 name double v
2019 "Harris"   4729310
2019 "Dallas"   2635516
2019 "Tarrant"  2102515
2019 "Bexar"    2010260
2019 "Travis"   1273954
2019 "Collin"   1034730
2019 "Hidalgo"   868707
2019 "El Paso"   839238
2020 "Harris"   4731145
2020 "Dallas"   2613539
2020 "Tarrant"  2110640
2020 "Bexar"    2009324
2020 "Travis"   1290188
2020 "Collin"   1064465
2020 "Hidalgo"   870781
2020 "El Paso"   865657
2021 "Harris"   4738253
2021 "Dallas"   2599883
2021 "Tarrant"  2126477
2021 "Bexar"    2028340
2021 "Travis"   1305057
2021 "Collin"   1109463
2021 "Hidalgo"   875892
2021 "El Paso"   864621
2022 "Harris"   4780913
2022 "Dallas"   2613539
2022 "Tarrant"  2154595
2022 "Bexar"    2061226
2022 "Travis"   1330411
2022 "Collin"   1158696
2022 "Hidalgo"   880356
2022 "El Paso"   863943
2023 "Harris"   4835125
2023 "Dallas"   2606358
2023 "Tarrant"  2182947
2023 "Bexar"    2092984
2023 "Travis"   1351019
2023 "Collin"   1195359
2023 "Hidalgo"   888367
2023 "El Paso"   869100
2024 "Harris"   4894753
2024 "Dallas"   2604722
2024 "Tarrant"  2211232
2024 "Bexar"    2126810
2024 "Travis"   1378260
2024 "Collin"   1235598
2024 "Hidalgo"   898507
2024 "El Paso"   870168
end

* Build synthetic 2010-2018 rows via a backward random-walk anchored at each
* county's 2019 value.  Each step shrinks v by ~1% (positive drift backwards
* in time = population growth forwards) plus normal noise.
preserve
keep if yr == 2019
gen double anchor = v
keep name anchor
tempfile anchors
save "`anchors'", replace
restore

set seed 1029384
tempfile synth
quietly {
    clear
    set obs 72   /* 8 counties x 9 backward years */
    gen str22 name = ""
    gen long  yr   = .
    gen double v   = .
    local i = 1
    use "`anchors'", clear
    levelsof name, local(_county_list) clean
    use "`anchors'", clear
    local row = 1
    tempname mh
    file open `mh' using "`synth'", write text replace
    foreach c of local _county_list {
        quietly summarize anchor if name == "`c'", meanonly
        local cur = r(mean)
        forvalues y = 2018(-1)2010 {
            * Backward drift: walking from a higher 2019 back to a lower 2010.
            local step = exp(-(rnormal() * 0.012 + 0.010))
            local cur  = `cur' * `step'
            local cur_r : display %12.0f `cur'
            local cur_r = strtrim("`cur_r'")
            file write `mh' `"`y' "`c'" `cur_r'"' _n
        }
    }
    file close `mh'
}

* Load the real 2019-2024 data + append the synthetic 2010-2018 rows.
restore
preserve
* Real data, again (we restored back to nothing useful above):
clear
input long yr str22 name double v
2019 "Harris"   4729310
2019 "Dallas"   2635516
2019 "Tarrant"  2102515
2019 "Bexar"    2010260
2019 "Travis"   1273954
2019 "Collin"   1034730
2019 "Hidalgo"   868707
2019 "El Paso"   839238
2020 "Harris"   4731145
2020 "Dallas"   2613539
2020 "Tarrant"  2110640
2020 "Bexar"    2009324
2020 "Travis"   1290188
2020 "Collin"   1064465
2020 "Hidalgo"   870781
2020 "El Paso"   865657
2021 "Harris"   4738253
2021 "Dallas"   2599883
2021 "Tarrant"  2126477
2021 "Bexar"    2028340
2021 "Travis"   1305057
2021 "Collin"   1109463
2021 "Hidalgo"   875892
2021 "El Paso"   864621
2022 "Harris"   4780913
2022 "Dallas"   2613539
2022 "Tarrant"  2154595
2022 "Bexar"    2061226
2022 "Travis"   1330411
2022 "Collin"   1158696
2022 "Hidalgo"   880356
2022 "El Paso"   863943
2023 "Harris"   4835125
2023 "Dallas"   2606358
2023 "Tarrant"  2182947
2023 "Bexar"    2092984
2023 "Travis"   1351019
2023 "Collin"   1195359
2023 "Hidalgo"   888367
2023 "El Paso"   869100
2024 "Harris"   4894753
2024 "Dallas"   2604722
2024 "Tarrant"  2211232
2024 "Bexar"    2126810
2024 "Travis"   1378260
2024 "Collin"   1235598
2024 "Hidalgo"   898507
2024 "El Paso"   870168
end
tempfile real_pep
save "`real_pep'", replace

import delimited using "`synth'", clear delimiter(" ") varnames(none)
rename (v1 v2 v3) (yr name v)
* Strip quotes from name (left by file write)
replace name = subinstr(name, char(34), "", .)
append using "`real_pep'"
sort yr name

sparkta2 v, name(name) time(yr) type(barrace) top(8) duration(20)              ///
    scheme(tx2036) download datatable                                          ///
    tx2036style downloadpos(below)                                             ///
    title("Bar chart race -- Texas top counties, 2010-2024")                   ///
    subtitle("2019-2024 = Census PEP; 2010-2018 = synthetic backward random-walk (illustrative only)") ///
    offline noopen export("`outdir'/s9_barrace.html")
restore

* ----- (S10) labelwrap(off) demo on the bar2 -----
preserve
use "`county'", clear
collapse (mean) poverty_rate, by(region_n)
sparkta2 poverty_rate, name(region_n) type(bar2) horizontal scheme(blues)       ///
    wraplabel(off) gutterwidth(140)                                              ///
    download datatable offline noopen tx2036style downloadpos(below)             ///
    title("Same bar2 with wraplabel(off) + gutterwidth(140)")                   ///
    export("`outdir'/s10_bar2_truncate.html")
restore

* ----- (S11) sparkta pass-through: scatter with lfit + CI -----
*   Absolute path required: sparkta resolves relative export() against the
*   Stata install bundle, not cwd.  Same for (S12) below.
capture which sparkta
if !_rc capture noisily sparkta2 poverty_rate uninsured_rate, type(scatter) fit(lfit) fitci offline title("Poverty vs uninsured (sparkta scatter + lfit + CI)") export("`outdir'/s11_sparkta_scatter.html")

* ----- (S12) sparkta pass-through: bar by region (Chart.js, stat(mean)) -----
capture which sparkta
if !_rc capture noisily sparkta2 poverty_rate uninsured_rate, type(bar) over(region_n) stat(mean) offline title("Mean rates by region (sparkta Chart.js bar, pass-through)") export("`outdir'/s12_sparkta_bar.html")

* ============================================================================
* 3. EMIT THE auto-resize listener as a sibling JS file in `outdir'.
* ============================================================================
tempname jsf
file open `jsf' using "`outdir'/sparkta2_resize.js", write text replace
file write `jsf' "window.addEventListener('message', function(e){" _n
file write `jsf' "  if(!e.data||e.data.type!=='sparkta2-resize') return;" _n
file write `jsf' "  var ifrs=document.querySelectorAll('iframe');" _n
file write `jsf' "  for(var i=0;i<ifrs.length;i++){" _n
file write `jsf' "    if(ifrs[i].contentWindow===e.source){" _n
file write `jsf' "      ifrs[i].style.height=(e.data.height+12)+'px';" _n
file write `jsf' "      ifrs[i].setAttribute('scrolling','no');" _n
file write `jsf' "      break;" _n
file write `jsf' "    }" _n
file write `jsf' "  }" _n
file write `jsf' "});" _n
file close `jsf'

* ============================================================================
* 4. ASSEMBLE THE WEBDOC2 REPORT
*    cd into the output dir so wdinit names the report  outdir/index.html
*    and the wdiframe references use bare filenames (file:// same-origin).
* ============================================================================
cd "`outdir'"

* wdinit re-points webdoc2 to `index' (overrides the test_*.html stub that
* `webdoc do' creates at the cwd of invocation).  webdoc2's default theme
* (Bootstrap 5.3 + Inter font + TX2036 brand tokens) is injected
* automatically into the <head>.
wdinit index, replace

* ----- Bootstrap navbar (matches the data_centers webdoc2 site convention) ----
wput <nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-3">
wput <div class="container-fluid">
wput <a class="navbar-brand" href="#" title="sparkta2 v0.7.6 demo">SPARKTA2 v0.7.6 demo</a>
wput <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#mainNavbar" aria-controls="mainNavbar" aria-expanded="false" aria-label="Toggle navigation"><span class="navbar-toggler-icon"></span></button>
wput <div class="collapse navbar-collapse" id="mainNavbar">
wput <ul class="navbar-nav me-auto mb-2 mb-lg-0">
wput <li class="nav-item"><a class="nav-link active" href="#top">Home</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s1">Bivariate</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s2">Choropleth</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s3">Hexbin</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s5">Donut</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s6">Bar2</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s7">Line2</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s8">Divbar</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s9">Race</a></li>
wput <li class="nav-item"><a class="nav-link" href="#s11">sparkta</a></li>
wput </ul>
wput </div></div></nav>

wput <a id="top"></a>
wputh1 sparkta2 demo -- maps, native D3 charts, sparkta pass-through
wput <p class="lead">One long page that embeds twelve sparkta2 outputs via &lt;iframe&gt;: five maps, five sparkta2-native chart types (donut, bar2, line2, divbar, barrace), one label-wrap demo, and two sparkta (Chart.js) pass-through charts.  Each iframe auto-resizes to its content so no section gets clipped behind a scrollbar.</p>

* ---------- (S1) ----------
wputh2 1. Bivariate choropleth -- full interactive UI
wput <p>Two-variable joint quantile map of poverty rate (x) and uninsured rate (y) for Texas counties.  Mode toggle, filters, sliders, search, swap-axes, and the Export dropdown.  Hover for tooltips with three extra variables.</p>
wput <p class="text-muted small">Source: <code>s1_bivariate_full.html</code></p>
wdiframe s1_bivariate_full.html, height(900px)

* ---------- (S2) ----------
wputh2 2. Univariate choropleth -- Texas-tuned projection
wput <p>Single-variable map of poverty rate.  v0.6.1 switched the default projection for <code>geo(texas)</code> from <code>d3.geoAlbersUsa()</code> to a Texas-tuned <code>d3.geoAlbers()</code>, dropping the panhandle's lean from ~3 degrees to ~1 degree.</p>
wput <p class="text-muted small">Source: <code>s2_choropleth_texas.html</code></p>
wdiframe s2_choropleth_texas.html, height(900px)

* ---------- (S3) ----------
wputh2 3. Hexbin -- spatial aggregation of county centroids
wput <p>Hexagonal binning over 254 county centroids, mean poverty rate per hex (radius 22).  Animates in via IntersectionObserver as the section scrolls into view.</p>
wput <p class="text-muted small">Source: <code>s3_hexbin.html</code></p>
wdiframe s3_hexbin.html, height(900px)

* ---------- (S4) ----------
wputh2 4. Bivariate + faded US-state basemap
wput <p>Same bivariate as section 1, with a faded 50-state outline drawn behind the focused Texas layer.</p>
wput <p class="text-muted small">Source: <code>s4_basemap.html</code></p>
wdiframe s4_basemap.html, height(900px)

* ---------- (S5) ----------
wputh2 5. Donut chart -- sparkta2-native (v0.7.0)
wput <p>Five-slice ring chart of synthetic postsecondary enrollment by sector, in the Texas 2036 palette.  Centre label shows the total automatically.  Export menu offers PNG / SVG / Print to PDF / Download CSV / View data table.</p>
wput <p class="text-muted small">Source: <code>s5_donut.html</code></p>
wdiframe s5_donut.html, height(820px)

* ---------- (S6) ----------
wputh2 6. Native horizontal bar2 -- with v0.6.0 features
wput <p>Mean poverty rate by region, sparkta2-native bar2.  Inherits the v0.6.0 Export menu, the <code>datatable</code> option, and <code>animate</code>.  Hover a bar for the per-region uninsured rate as a tooltip extra.</p>
wput <p class="text-muted small">Source: <code>s6_bar2_horizontal.html</code></p>
wdiframe s6_bar2_horizontal.html, height(820px)

* ---------- (S7) ----------
wputh2 7. Native line2 -- three series, 2018-2024
wput <p>Multi-series line via <code>over()</code>.  Three synthetic series (statewide, ESC 4, ESC 13) over a six-year span; monotone-X curve, dot tooltips per point.</p>
wput <p class="text-muted small">Source: <code>s7_line2_multi_series.html</code></p>
wdiframe s7_line2_multi_series.html, height(820px)

* ---------- (S8) ----------
wputh2 8. Diverging stacked bar -- Pew-style Likert (v0.7.0)
wput <p>Five long survey items rendered Pew-style: wrapped item text in the left margin, central zero baseline, direct % labels inside each segment, net favourability column on the right, no bottom axis.</p>
wput <p class="text-muted small">Source: <code>s8_divbar.html</code></p>
wdiframe s8_divbar.html, height(820px)

* ---------- (S9) ----------
wputh2 9. Bar chart race -- Texas top counties, 2010-2024
wput <p>Animated race across 15 frames.  <strong>2019-2024 values are real Census PEP estimates</strong>; <strong>2010-2018 are synthetic random-walk backwards</strong> from each county's 2019 value (~1% YoY drift, set seed 1029384) so the race has enough movement to be interesting.  Don't read the early years as facts.</p>
wput <p class="text-muted small">Source: <code>s9_barrace.html</code></p>
wdiframe s9_barrace.html, height(820px)

* ---------- (S10) ----------
wputh2 10. Same bar2 -- wraplabel(off) + gutterwidth(140)
wput <p>Identical input to section 6, but with v0.7.3 label-wrap controls: force single-line labels and shrink the left gutter to 140 px.  Labels that would overflow get truncated with an ellipsis.  Useful for narrow grid embeds.</p>
wput <p class="text-muted small">Source: <code>s10_bar2_truncate.html</code></p>
wdiframe s10_bar2_truncate.html, height(820px)

* ---------- (S11) ----------
wputh2 11. sparkta pass-through -- scatter + lfit + CI
wput <p>Non-map types fall through to Fahad Mirza's sparkta package (Chart.js).  Same dataset rendered as a scatter plot with a linear-fit line and CI band.</p>
wput <p class="text-muted small">Source: <code>s11_sparkta_scatter.html</code></p>
wdiframe s11_sparkta_scatter.html, height(640px)

* ---------- (S12) ----------
wputh2 12. sparkta pass-through -- bar over region, stat(mean)
wput <p>Same call shape used in existing _datashare do-files: <code>type(bar) over(varname) stat(mean)</code> with multiple y-variables.  v0.7.1 keeps this path unchanged; opt in to sparkta2's D3-native bar by changing <code>type(bar)</code> to <code>type(bar2)</code>.</p>
wput <p class="text-muted small">Source: <code>s12_sparkta_bar.html</code></p>
wdiframe s12_sparkta_bar.html, height(640px)

wput <hr><p class="text-muted small">Built with sparkta2 v0.7.6 + webdoc2.  Each iframe is independent; auto-resize via the postMessage listener loaded below.</p>
wput <script src="sparkta2_resize.js"></script>

wdclose
