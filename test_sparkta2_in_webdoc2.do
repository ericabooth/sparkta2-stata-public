*! test_sparkta2_in_webdoc2.do  v0.7.7
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
*!    11.  sparkta scatter (Chart.js) -- pass-through (KEEPS native scrollbar
*!         via data-skip-resize -- intentional contrast with the auto-resized
*!         sparkta2-native iframes above)
*!    12.  sparkta bar (Chart.js)     -- pass-through

version 17.0
set more off

* All paths are absolute to dodge a long-standing footgun: when sparkta2
* forwards to sparkta (Chart.js), relative export() paths resolve against
* the Stata install bundle rather than cwd.
*
* Recursion guard: this do-file later `cd's into outdir so wdinit names the
* report  outdir/index.html.  If the user re-runs in the same Stata session
* (or webdoc2 leaves Stata cwd inside outdir), the next c(pwd) would already
* end in "/sparkta2_webdoc2_out" and we'd nest recursively to
* sparkta2_webdoc2_out/sparkta2_webdoc2_out/...  Detect that and cd up one
* level before computing outdir.  Also save the pre-run cwd so we cd back
* at the end (wdclose) and subsequent runs start clean.
local _start_cwd "`c(pwd)'"
if regexm("`c(pwd)'", "/sparkta2_webdoc2_out/?$") qui cd ..

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
*   Real Census PEP estimates for 2019-2024 (8 counties).  2010-2018 are a
*   synthetic backward random-walk anchored at each county's 2019 value so
*   the race has 15 frames to animate over.  ~1% YoY rms drift, seed
*   1029384 for reproducibility.  Treat early years as illustrative only.
*
*   Implementation: single preserve scope; build synthetic via plain Stata
*   commands into a tempfile, then append onto the real PEP rows.
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
tempfile pep_real pep_synth
save "`pep_real'", replace

* Anchor table: each county's 2019 value
keep if yr == 2019
keep name v
rename v anchor_2019
tempfile anchors
save "`anchors'", replace

* Cross-join anchors x (years 2010..2018) and backward random-walk per county.
clear
local nyrs = 9   /* 2010..2018 */
expand `nyrs', generate(_dup)   /* error: no data; switch to set obs */
quietly use "`anchors'", clear
expand `nyrs'
bysort name: gen byte _k = _n      /* 1..9 within each county */
gen long yr = 2019 - _k             /* 2018, 2017, ... 2010 */
set seed 1029384
gen double _step = exp(-(rnormal() * 0.012 + 0.010))
sort name yr  /* yr now ascending: 2010 (k=9) first... */
* Iterate backward in time per county to apply cumulative drift.
bysort name (yr): gen double v = .
bysort name (yr): replace v = anchor_2019 if _n == _N + 1   /* never triggers */
* Apply random-walk: 2018 = anchor * step18; 2017 = 2018 * step17; ...
* Easier: iterate from 2018 (closest to anchor) backward.
gsort name -yr
bysort name (yr): gen double _runv = .
bysort name: replace _runv = anchor_2019 * _step if yr == 2018
bysort name: replace _runv = _runv[_n-1] * _step if missing(_runv)
replace v = round(_runv)
keep yr name v
save "`pep_synth'", replace

* Stitch synthetic + real together.
use "`pep_real'", clear
append using "`pep_synth'"
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
file write `jsf' "      if(ifrs[i].hasAttribute('data-skip-resize')) break;" _n
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
wput <a class="navbar-brand" href="#" title="sparkta2 v0.7.7 demo">SPARKTA2 v0.7.7 demo</a>
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
wput <p class="lead">One long page that embeds twelve sparkta2 outputs via &lt;iframe&gt;: five maps, five sparkta2-native chart types (donut, bar2, line2, divbar, barrace), one label-wrap demo, and two sparkta (Chart.js) pass-through charts.  Every sparkta2-native iframe auto-resizes to its content so it does not get clipped behind a scrollbar.  Section 11 deliberately opts out of auto-resize to demonstrate the &lt;code&gt;data-skip-resize&lt;/code&gt; escape hatch (the only example on this page with a visible iframe scrollbar).</p>

* ---------- (S1) ----------
wput <a id="s1"></a>
wputh2 1. Bivariate choropleth -- full interactive UI
wput <p>Two-variable joint quantile map of poverty rate (x) and uninsured rate (y) for Texas counties.  Mode toggle, filters, sliders, search, swap-axes, and the Export dropdown.  Hover for tooltips with three extra variables.</p>
wput <p class="text-muted small">Source: <code>s1_bivariate_full.html</code></p>
wdiframe s1_bivariate_full.html, height(900px)

* ---------- (S2) ----------
wput <a id="s2"></a>
wputh2 2. Univariate choropleth -- Texas-tuned projection
wput <p>Single-variable map of poverty rate.  v0.6.1 switched the default projection for <code>geo(texas)</code> from <code>d3.geoAlbersUsa()</code> to a Texas-tuned <code>d3.geoAlbers()</code>, dropping the panhandle's lean from ~3 degrees to ~1 degree.</p>
wput <p class="text-muted small">Source: <code>s2_choropleth_texas.html</code></p>
wdiframe s2_choropleth_texas.html, height(900px)

* ---------- (S3) ----------
wput <a id="s3"></a>
wputh2 3. Hexbin -- spatial aggregation of county centroids
wput <p>Hexagonal binning over 254 county centroids, mean poverty rate per hex (radius 22).  Animates in via IntersectionObserver as the section scrolls into view.</p>
wput <p class="text-muted small">Source: <code>s3_hexbin.html</code></p>
wdiframe s3_hexbin.html, height(900px)

* ---------- (S4) ----------
wput <a id="s4"></a>
wputh2 4. Bivariate + faded US-state basemap
wput <p>Same bivariate as section 1, with a faded 50-state outline drawn behind the focused Texas layer.</p>
wput <p class="text-muted small">Source: <code>s4_basemap.html</code></p>
wdiframe s4_basemap.html, height(900px)

* ---------- (S5) ----------
wput <a id="s5"></a>
wputh2 5. Donut chart -- sparkta2-native (v0.7.0)
wput <p>Five-slice ring chart of synthetic postsecondary enrollment by sector, in the Texas 2036 palette.  Centre label shows the total automatically.  Export menu offers PNG / SVG / Print to PDF / Download CSV / View data table.</p>
wput <p class="text-muted small">Source: <code>s5_donut.html</code></p>
wdiframe s5_donut.html, height(820px)

* ---------- (S6) ----------
wput <a id="s6"></a>
wputh2 6. Native horizontal bar2 -- with v0.6.0 features
wput <p>Mean poverty rate by region, sparkta2-native bar2.  Inherits the v0.6.0 Export menu, the <code>datatable</code> option, and <code>animate</code>.  Hover a bar for the per-region uninsured rate as a tooltip extra.</p>
wput <p class="text-muted small">Source: <code>s6_bar2_horizontal.html</code></p>
wdiframe s6_bar2_horizontal.html, height(820px)

* ---------- (S7) ----------
wput <a id="s7"></a>
wputh2 7. Native line2 -- three series, 2018-2024
wput <p>Multi-series line via <code>over()</code>.  Three synthetic series (statewide, ESC 4, ESC 13) over a six-year span; monotone-X curve, dot tooltips per point.</p>
wput <p class="text-muted small">Source: <code>s7_line2_multi_series.html</code></p>
wdiframe s7_line2_multi_series.html, height(820px)

* ---------- (S8) ----------
wput <a id="s8"></a>
wputh2 8. Diverging stacked bar -- Pew-style Likert (v0.7.0)
wput <p>Five long survey items rendered Pew-style: wrapped item text in the left margin, central zero baseline, direct % labels inside each segment, net favourability column on the right, no bottom axis.</p>
wput <p class="text-muted small">Source: <code>s8_divbar.html</code></p>
wdiframe s8_divbar.html, height(820px)

* ---------- (S9) ----------
wput <a id="s9"></a>
wputh2 9. Bar chart race -- Texas top counties, 2010-2024
wput <p>Animated race across 15 frames.  <strong>2019-2024 values are real Census PEP estimates</strong>; <strong>2010-2018 are synthetic random-walk backwards</strong> from each county's 2019 value (~1% YoY drift, set seed 1029384) so the race has enough movement to be interesting.  Don't read the early years as facts.</p>
wput <p class="text-muted small">Source: <code>s9_barrace.html</code></p>
wdiframe s9_barrace.html, height(820px)

* ---------- (S10) ----------
wput <a id="s10"></a>
wputh2 10. Same bar2 -- wraplabel(off) + gutterwidth(140)
wput <p>Identical input to section 6, but with v0.7.3 label-wrap controls: force single-line labels and shrink the left gutter to 140 px.  Labels that would overflow get truncated with an ellipsis.  Useful for narrow grid embeds.</p>
wput <p class="text-muted small">Source: <code>s10_bar2_truncate.html</code></p>
wdiframe s10_bar2_truncate.html, height(820px)

* ---------- (S11) ----------
wput <a id="s11"></a>
wputh2 11. sparkta pass-through -- scatter + lfit + CI
wput <p>Non-map types fall through to Fahad Mirza's sparkta package (Chart.js).  Same dataset rendered as a scatter plot with a linear-fit line and CI band.</p>
wput <p class="text-muted small">Source: <code>s11_sparkta_scatter.html</code></p>
webdoc put <div class="alert alert-warning small mb-2"><strong>Note: this iframe deliberately shows a scrollbar.</strong>  The sparkta (Chart.js) pass-through does not emit the <code>sparkta2-resize</code> postMessage that the parent listener uses to resize each iframe to match its content height.  Rather than silently clipping the scatter, this section opts out of auto-resize with <code>data-skip-resize="1"</code> and lets the iframe render a native scrollbar.  Every other section embeds a sparkta2-native output that speaks the resize protocol, so they fit their content with no scrollbar.</div>
webdoc put <iframe src="s11_sparkta_scatter.html" width="100%" height="500" data-skip-resize="1" style="border:none;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.06);margin:1rem 0;display:block;"></iframe>

* ---------- (S12) ----------
wput <a id="s12"></a>
wputh2 12. sparkta pass-through -- bar over region, stat(mean)
wput <p>Same call shape used in existing _datashare do-files: <code>type(bar) over(varname) stat(mean)</code> with multiple y-variables.  v0.7.1 keeps this path unchanged; opt in to sparkta2's D3-native bar by changing <code>type(bar)</code> to <code>type(bar2)</code>.</p>
wput <p class="text-muted small">Source: <code>s12_sparkta_bar.html</code></p>
* Sparkta pass-throughs don't emit the sparkta2-resize postMessage, so this
* iframe stays at its declared height.  s12's content (chart + a big stats
* panel) renders to ~1900 px, so 1920 px keeps it scrollbar-free; the only
* deliberate-scrollbar demo on this page is s11.
wdiframe s12_sparkta_bar.html, height(1920px)

wput <hr><p class="text-muted small">Built with sparkta2 v0.7.7 + webdoc2.  Each iframe is independent; the postMessage listener loaded below resizes every sparkta2-native iframe to match its content height (and sets scrolling="no"), except for iframes marked with <code>data-skip-resize="1"</code>, which keep their declared height and native scrollbar (see section 11).</p>
wput <script src="sparkta2_resize.js"></script>

wdclose

* Restore Stata's pre-run cwd so a subsequent re-run doesn't recursively
* nest into sparkta2_webdoc2_out/sparkta2_webdoc2_out/.
qui cd "`_start_cwd'"
