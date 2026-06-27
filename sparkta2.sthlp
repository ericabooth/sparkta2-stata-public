{smcl}
{* *! version 0.7.8  26jun2026}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] sparkta" "help sparkta"}{...}
{vieweralsosee "[R] spmap" "help spmap"}{...}
{title:Title}

{phang}
{bf:sparkta2} {hline 2} Interactive choropleth, bivariate, hexbin, and point
maps from Stata, with chart pass-through to sparkta.


{title:Description}

{pstd}
{cmd:sparkta2} is a thin dispatcher around three engines (v0.7.8):

{phang2}o  A bundled D3 v7 {bf:map engine} that handles {cmd:type(bivariate)},
{cmd:type(choropleth)}, {cmd:type(hexbin)}, and {cmd:type(points)}.{p_end}

{phang2}o  A bundled D3 v7 {bf:chart engine} that handles native non-map
chart types: {cmd:type(donut)}, {cmd:type(bar2)}, {cmd:type(line2)},
{cmd:type(divbar)} (Pew-style diverging stacked bar for Likert / survey
items), and {cmd:type(barrace)} (animated bar chart race).  These all
inherit the v0.6.0 Export menu, the {cmd:datatable} option, and the
{cmd:animate} option.{p_end}

{phang2}o  Fahad Mirza's
{browse "https://github.com/fahad-mirza/sparkta_stata":{bf:sparkta}}
chart package, called verbatim for every other {cmd:type()} value
({cmd:bar}, {cmd:line}, {cmd:scatter}, {cmd:pie}, {cmd:violin},
{cmd:histogram}, CI bar, CI line, area, bubble, and the stacked variants).
Install {cmd:sparkta} separately if you intend to use those chart types.{p_end}

{pstd}
{bf:Note on}{cmd: bar }{bf:vs}{cmd: bar2}{bf:.}  v0.7.1 keeps {cmd:type(bar)}
and {cmd:type(line)} forwarding to sparkta unchanged -- every pre-0.7.0
do-file using sparkta's bar/line syntax (multi-var, {cmd:stat()},
{cmd:fit()}, {cmd:over()} with stat=mean, ...) still works without edits.
The new D3-native versions are exposed as {cmd:type(bar2)} and
{cmd:type(line2)}, which inherit the Export menu, {cmd:datatable}, and
{cmd:animate} but take simpler input (one numeric var with {cmd:name()},
optional {cmd:over()} for grouping/stacking).

{pstd}
Map design borrows from Mike Bostock's Observable notebooks
({browse "https://observablehq.com/@d3/bivariate-choropleth":bivariate-choropleth},
{browse "https://observablehq.com/@mbostock/methods-of-comparison-compared":methods-of-comparison-compared},
{browse "https://observablehq.com/@d3/zoom-to-bounding-box":zoom-to-bounding-box}),
and from the D3 Graph Gallery
({browse "https://d3-graph-gallery.com/graph/hexbinmap_geo_label.html":hexbin map},
{browse "https://d3-graph-gallery.com/graph/backgroundmap_country.html":background map}).
{cmd:d3-hexbin} v0.2.2 is bundled for the hexbin renderer (MIT,
© Mike Bostock).


{title:Syntax}

{p 8 16 2}
Maps (handled by sparkta2 directly):
{p_end}
{p 8 16 2}
{cmd:sparkta2} {it:yvar} [{it:xvar}] {ifin} {cmd:,} {cmd:id(}{it:idvar}{cmd:)}
{cmd:type(}{it:maptype}{cmd:)} [{it:map_options}]
{p_end}

{p 8 16 2}
Native charts (handled by sparkta2 directly, v0.7.0+):
{p_end}
{p 8 16 2}
{cmd:sparkta2} {it:xvar} [{it:yvar}] {ifin} {cmd:,}
{cmd:type(}donut{c |}bar2{c |}line2{c |}divbar{c |}barrace{cmd:)}
[ {cmd:name(}{it:catvar}{cmd:)} {cmd:over(}{it:groupvar}{cmd:)}
{cmd:level(}{it:lvlvar}{cmd:)} {cmd:time(}{it:tvar}{cmd:)} {it:chart_options} ]
{p_end}

{p 8 16 2}
Other charts (forwarded verbatim to sparkta):
{p_end}
{p 8 16 2}
{cmd:sparkta2} {it:varlist} {cmd:,} {cmd:type(}{it:charttype}{cmd:)} [{it:sparkta_options}]
{p_end}

{p 8 16 2}
Combined dashboard:
{p_end}
{p 8 16 2}
{cmd:sparkta2_dashboard,} {cmd:files(}{it:list}{cmd:)} {cmd:export(}{it:path}{cmd:)}
[{cmd:titles(}{it:pipelist}{cmd:)} {it:other}]
{p_end}

{phang}
Map {cmd:type()} values:

{phang2}{bf:bivariate}  - two-variable joint NxN choropleth (default 3x3){p_end}
{phang2}{bf:choropleth} - one-variable sequential or diverging choropleth{p_end}
{phang2}{bf:hexbin}     - hexagonal aggregation of feature centroids or lat/lon points{p_end}
{phang2}{bf:points}     - circles at lat/lon (ZIP centroids, addresses){p_end}
{phang2}{bf:map}        - auto-pick: bivariate if two vars, choropleth if one{p_end}


{title:Options}

{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Identification + geometry}
{synopt :{cmd:id(}{it:varname}{cmd:)}}id variable. 5-digit county FIPS, 5-digit ZIP, 2-digit state FIPS, 11-digit tract GEOID, etc. Numeric ids are zero-padded to {cmd:idwidth()}; string ids are left as-is and only padded when shorter than {cmd:idwidth()}.{p_end}
{synopt :{cmd:name(}{it:varname}{cmd:)}}display name for tooltips and the search box{p_end}
{synopt :{cmd:geo(}{it:string}{cmd:)}}geography label; chooses {it:<geo>_counties.topojson}. Default {bf:texas}{p_end}
{synopt :{cmd:layer(}{it:string}{cmd:)}}topojson object to render: {bf:counties} (default), {bf:states}, {bf:nation}, {bf:zctas}, {bf:tracts}, {bf:auto}{p_end}
{synopt :{cmd:idwidth(}{it:#}{cmd:)}}zero-pad width for short {cmd:id()} values; default 5. Ids longer than this width are written verbatim — no truncation.{p_end}
{synopt :{cmd:lat(}{it:varname}{cmd:)}}numeric latitude (required for {cmd:type(points)}; optional for {cmd:type(hexbin)}){p_end}
{synopt :{cmd:lon(}{it:varname}{cmd:)}}numeric longitude{p_end}

{syntab :Rendering style}
{synopt :{cmd:type(}{it:string}{cmd:)}}{bf:bivariate} | {bf:choropleth} | {bf:hexbin} | {bf:points} | {bf:map}{p_end}
{synopt :{cmd:scheme(}{it:string}{cmd:)}}bivariate: {bf:rdbu|bupu|gnbu|puor}; sequential: {bf:blues|reds|greens|oranges|purples|viridis|magma|inferno|plasma|cividis}{p_end}
{synopt :{cmd:bins(}{it:#}{cmd:)}}quantile bins per axis (bivariate); 2-5, default 3{p_end}
{synopt :{cmd:basemap}}draw a faded states/nation outline behind the focused features (background-map style){p_end}
{synopt :{cmd:hexradius(}{it:#}{cmd:)}}hexagon radius in SVG units; default 18{p_end}
{synopt :{cmd:hexstat(}{it:string}{cmd:)}}hexbin aggregate: {bf:mean} (default) | {bf:sum} | {bf:median} | {bf:count} | {bf:min} | {bf:max}{p_end}
{synopt :{cmd:pointsize(}{it:#}{cmd:)}}circle radius for {cmd:type(points)}; default 4{p_end}

{syntab :Comparison-mode toggle}
{synopt :{cmd:mode(}{it:string}{cmd:)}}initial mode: {bf:bivariate|x|y|diff|ratio}{p_end}
{synopt :{cmd:modes(}{it:string}{cmd:)}}allowed modes in toggle (pipe-sep), e.g. {bf:bivariate|diff|ratio}{p_end}
{synopt :{cmd:comparable}}declare x/y on the same scale (enables value diff/ratio){p_end}
{synopt :{cmd:multiples}}small-multiples: one panel per mode in a responsive grid{p_end}

{syntab :Interactivity}
{synopt :{cmd:filters(}{it:varlist}{cmd:)}}categorical filter dropdowns; one per variable{p_end}
{synopt :{cmd:sliders(}{it:varlist}{cmd:)}}dual-handle range sliders (numeric); one per variable{p_end}
{synopt :{cmd:tooltipvars(}{it:varlist}{cmd:)}}extra fields rendered as a data table inside the tooltip{p_end}
{synopt :{cmd:search}}in-browser name-search box (filters by {cmd:name()}){p_end}
{synopt :{cmd:counties(}{it:idlist}{cmd:)}}restrict the map to a pipe- or space-separated list of {cmd:id()} values{p_end}
{synopt :{cmd:zoomto(}{it:idlist}{cmd:)}}auto-zoom to the bounding box of these ids on load{p_end}
{synopt :{cmd:nozoom}}disable pan, zoom, and click-to-zoom{p_end}
{synopt :{cmd:swapbutton}}include a "Swap axes" button (bivariate / diff / ratio){p_end}
{synopt :{cmd:download}}include an "Export {c -(}" menu (PNG, SVG, Print to PDF){p_end}
{synopt :{cmd:downloadpos(}{it:string}{cmd:)}}{cmd:side}|{cmd:below}|{cmd:none} -- Export menu placement (v0.7.2){p_end}
{synopt :{cmd:datatable}}add "Download CSV" + "View data table" to the Export menu{p_end}
{synopt :{cmd:animate}}fade map features in when the chart scrolls into view{p_end}
{synopt :{cmd:tx2036style}}Texas 2036 brand + Montserrat font (v0.7.2; requires online for Google Fonts){p_end}
{synopt :{cmd:wraplabel(}{it:string}{cmd:)}}{cmd:auto}|{cmd:on}|{cmd:off} -- category-label wrap policy (v0.7.3; for {cmd:bar2}/{cmd:divbar}){p_end}
{synopt :{cmd:gutterwidth(}{it:#}{cmd:)}}explicit left-margin width in px for horizontal category labels (v0.7.3){p_end}
{synopt :{cmd:projection(}{it:string}{cmd:)}}{cmd:albers_usa}|{cmd:albers_tx}|{cmd:albers}|{cmd:mercator}; default is auto by {cmd:geo()}{p_end}
{synopt :{cmd:rotate(}{it:lambda} [{it:phi}]{cmd:)}}override projection rotation in degrees{p_end}
{synopt :{cmd:parallels(}{it:p1 p2}{cmd:)}}override Albers standard parallels in degrees{p_end}
{synopt :{cmd:center(}{it:lon lat}{cmd:)}}override projection center in degrees{p_end}

{syntab :Output}
{synopt :{cmd:title(}{it:string}{cmd:)}}{p_end}
{synopt :{cmd:subtitle(}{it:string}{cmd:)}}{p_end}
{synopt :{cmd:note(}{it:string}{cmd:)}}{p_end}
{synopt :{cmd:xlabel(}{it:string}{cmd:)}}{p_end}
{synopt :{cmd:ylabel(}{it:string}{cmd:)}}{p_end}
{synopt :{cmd:export(}{it:path}{cmd:)}}output HTML path{p_end}
{synopt :{cmd:offline}}embed D3 + topojson-client + d3-hexbin inline (no CDN at runtime){p_end}
{synopt :{cmd:noopen}}do not auto-open the result in the default browser{p_end}
{synopt :{cmd:width(}{it:#}{cmd:)}}svg viewBox width; default 980{p_end}
{synopt :{cmd:height(}{it:#}{cmd:)}}svg viewBox height; default 720{p_end}
{synoptline}

{phang}
{cmd:[if] [in]} qualifiers are honored: excluded rows are not embedded
in the map at all (the corresponding feature renders as dim grey).


{title:Browser interactions and the Stata options that produce them}

{pstd}
Every interactive control in the rendered HTML is enabled by a specific
Stata option. The table below maps the option to the in-browser behavior.

{synoptset 32 tabbed}{...}
{synopthdr:Browser control / behavior}
{synoptline}
{synopt :{cmd:mode(...) modes(...)}}A row of buttons appears at the top of the controls panel. Clicking switches the colour palette among bivariate / x-only / y-only / y - x (diff) / y/x (ratio). Only one panel is shown at a time.{p_end}
{synopt :{cmd:multiples}}Suppresses the mode toggle and instead lays out every mode in {cmd:modes()} side-by-side in a responsive grid. Filters and sliders update all panels simultaneously.{p_end}
{synopt :{cmd:comparable}}Switches the diff palette from rank-difference (default) to value-difference. Only set when x and y share units.{p_end}
{synopt :{cmd:filters(varlist)}}Each variable becomes a dropdown. Selecting a value dims every county whose value differs (it keeps its outline but goes to light grey).{p_end}
{synopt :{cmd:sliders(varlist)}}Each variable becomes a dual-handle range slider. Dragging the handles dims counties whose value lies outside the range.{p_end}
{synopt :{cmd:search}}Adds a text input. Typing dims counties whose {cmd:name()} doesn't contain the typed substring (case-insensitive).{p_end}
{synopt :{cmd:counties(fips_list)}}Counties not in the list are not embedded at all — they don't render, even as grey.{p_end}
{synopt :{cmd:[if] [in]}}Same effect as {cmd:counties()} but expressed as a Stata logical condition. Excluded rows don't ship.{p_end}
{synopt :{cmd:zoomto(fips_list)}}On page load, the projection is auto-zoomed to the bounding box of the listed features.{p_end}
{synopt :{i:default (no} {cmd:nozoom}{i:)}}Mouse wheel zooms in/out. Drag pans. {bf:Clicking a feature} zooms the map to that feature's bounding box. {bf:Double-clicking} the map resets to the initial view. A {bf:Reset zoom} button appears in the controls panel.{p_end}
{synopt :{cmd:nozoom}}All of the above are disabled — the map renders statically. Use for slide exports.{p_end}
{synopt :{cmd:swapbutton}}A "Swap axes (X ⇄ Y)" button appears. Clicking flips the variable assignment for bivariate/diff/ratio.{p_end}
{synopt :{cmd:download}}An "Export {c -(}" dropdown appears with {bf:Download PNG} (full SVG rasterised, all panels at 2x), {bf:Download SVG} (live SVG with inlined CSS), and {bf:Print to PDF{c 133}} (opens the browser print dialog with a print-only stylesheet that hides the controls panel and tooltip).{p_end}
{synopt :{cmd:datatable}}Extends the Export menu with {bf:Download CSV} (every row currently embedded, including {cmd:tooltipvars()}, with the original Stata variable names) and {bf:View data table} (a collapsible scrollable HTML table beneath the chart showing the rows that pass the active filters/sliders/search; capped at 500 visible rows for performance — use CSV for the full set).{p_end}
{synopt :{cmd:animate}}On first paint, the map is invisible; an IntersectionObserver fires when the chart scrolls into view and the features fade in over ~450ms with a small per-feature stagger. One-shot — does not re-trigger on subsequent scrolls.{p_end}
{synopt :{cmd:downloadpos()}}Places the Export menu either in the side controls panel ({cmd:side}, default), in a right-aligned footer below the chart ({cmd:below}), or hides it entirely ({cmd:none}).  When set to {cmd:below} and there are no other controls (no filters, sliders, modes, search), the side panel collapses entirely so the page doesn't reserve the 240px sidebar.{p_end}
{synopt :{cmd:tx2036style}}Loads Montserrat from Google Fonts as the HTML body font and tightens typography (heavy h1 weight, kerning).  SVG text deliberately stays on the system stack so {cmd:getComputedTextLength} measurements (used by divbar wrap, donut label suppression) stay stable across the async font load.  Falls back to system sans-serif if offline.  Use with {cmd:scheme(tx2036)} for the full brand look.{p_end}
{synopt :{cmd:wraplabel()}}Controls how long category labels render on {cmd:type(bar2)} (horizontal) and {cmd:type(divbar)}.  {cmd:auto} (default for bar2) wraps when the longest label exceeds ~28 characters.  {cmd:on} (default for divbar; aliased {cmd:wrap}) always wraps to a multi-line block.  {cmd:off} (aliased {cmd:truncate}) renders a single line and truncates with a Unicode ellipsis (...) when a label exceeds the gutter width.  No effect on the other chart types or on vertical bars.{p_end}
{synopt :{cmd:gutterwidth()}}Override the left-margin width in pixels for the category-label gutter on horizontal {cmd:bar2} and on {cmd:divbar}.  Default depends on context: 160 (bar2 no-wrap), 300 (bar2 wrap), 300 (divbar).  Useful for tight grid embeds where you want to trade wrap fidelity for a narrower chart.{p_end}
{synopt :{cmd:projection()}}Picks the d3 projection.  Default is auto: {cmd:geo(texas)} -> {bf:albers_tx} (Texas-tuned d3.geoAlbers, v0.7.8: rotate=[101.5,0], center=[0,31.5], parallels=[27.5,36.5]); {cmd:geo(us)} or {cmd:layer(states|nation)} -> {bf:albers_usa} (the d3.geoAlbersUsa composite with AK/HI insets); other geos default to {bf:albers_usa}.  Explicit values: {bf:albers_usa}, {bf:albers_tx}, {bf:albers} (generic Albers — use with {cmd:rotate()}/{cmd:parallels()}/{cmd:center()} to tune), {bf:mercator}.  {bf:Note:} v0.7.8 retunes the {bf:albers_tx} preset so the panhandle's top edge renders horizontally flat (central meridian at the panhandle's longitudinal midpoint -101.5{c 176}; upper standard parallel at the panhandle latitude 36.5{c 176}).  The original v0.6.1 fix (rotate=[99,0], parallels=[27.5,35.5]) reduced the {bf:albers_usa} ~3.3{c 176} lean to ~1.3{c 176}; v0.7.8 takes it to ~0{c 176}.  Pass {cmd:projection(albers_usa)} to restore the pre-0.6.1 composite look exactly, or {cmd:rotate(99) parallels(27.5 35.5)} on top of {cmd:projection(albers_tx)} to recover the v0.6.1 look.{p_end}
{synopt :{cmd:rotate() parallels() center()}}Numeric overrides applied on top of the chosen preset.  {cmd:rotate(}{it:lambda}{cmd:)} or {cmd:rotate(}{it:lambda phi}{cmd:)} sets the projection rotation in degrees.  {cmd:parallels(}{it:p1 p2}{cmd:)} sets the two Albers standard parallels in degrees.  {cmd:center(}{it:lon lat}{cmd:)} sets the projection center in degrees.  These have no effect under {cmd:projection(albers_usa)} because the composite projection does not expose them.{p_end}
{synopt :{cmd:tooltipvars(varlist)}}Each listed variable becomes a labelled row in the tooltip table when hovering over a county/ZIP/state. Labels use {cmd:variable label} when present.{p_end}
{synopt :{cmd:basemap}}A faded {bf:states} (or {bf:nation}) outline is drawn behind the focused features and remains visible at every zoom level.{p_end}
{synopt :{cmd:hexradius() hexstat()}}Active only for {cmd:type(hexbin)}. Hovering a hex shows its aggregate value and a sample of the points it contains.{p_end}
{synopt :{cmd:pointsize()}}Active only for {cmd:type(points)}. Hovering a circle shows the underlying ZIP/feature record.{p_end}
{synopt :Mode toggle (auto)}If two or more modes are allowed, a button row appears.  Click a button to switch the active mode.  Disabled when {cmd:multiples} is on.{p_end}
{synoptline}


{title:Data prep — getting your data into the right shape}

{pstd}
{bf:Three columns are always required:} an {cmd:id} (county FIPS, ZIP, state
FIPS, …), at least one numeric measure to color by, and — if you want
readable hover text — a {cmd:name} variable.  Beyond that, prep needs differ
by map type:

{phang}
{bf:choropleth / bivariate (polygon types)}{break}
{cmd:id()} must match the topojson's feature ids exactly after zero-padding
to {cmd:idwidth()}. For Texas counties that means 5-digit FIPS; pad to 5
with {cmd:tostring fips, replace force format("%05.0f")} or pass the
numeric var and let sparkta2 do it.  Pre-aggregate to one row per feature
({cmd:collapse (mean) value, by(fips)}) — duplicate rows overwrite each
other silently in the embedded data array.  Missing values render as
{bf:no data} (grey); use {cmd:[if] !missing(value)} if you want to drop
them entirely.

{phang}
{bf:points (graduated symbols at lat/lon)}{break}
You need {cmd:lat()} and {cmd:lon()} (decimal degrees, WGS84) and they must
both be non-missing on every row you want to plot. Drop missing-coord rows
first: {cmd:drop if missing(lat) | missing(lon)}.  {cmd:id()} can be ZIP,
parcel id, or anything unique; the topojson is still used for the underlying
geography (county outline shows beneath the points).

{phang}
{bf:hexbin}{break}
Two modes. If you pass {cmd:lat()} and {cmd:lon()}, each row is one point
and the hex aggregation runs over the lat/lon set (used for ZIP-level data
in the bundled demo).  If you don't pass lat/lon, the engine falls back to
the feature centroids of {cmd:layer()} and aggregates the value bound to
each feature (used for county-level hexagons).  {cmd:hexstat()} chooses the
aggregator; default {bf:mean}.

{phang}
{bf:Categorical filters and labelled numerics}{break}
{cmd:filters(varlist)} understands two shapes: a string variable, or a
numeric variable with a value label.  Pass {cmd:label define} + {cmd:label
values} on your numeric region/category codes BEFORE calling sparkta2 —
the dropdown shows the value label, not the raw number.  Without a value
label, numeric codes are displayed as raw numbers.  Multi-word string
values like {bf:"Middle / Jr. High"} are preserved as single dropdown
entries (no whitespace tokenization).

{phang}
{bf:Sliders}{break}
{cmd:sliders(varlist)} require numeric variables only.  The slider range is
auto-set from the {cmd:summarize, meanonly} min/max; the data shouldn't
have a single repeated value (span 0 collapses the slider).  If the
variable is fully missing on the active rows, the slider is skipped with a
warning rather than emitting invalid JSON.

{phang}
{bf:Tooltipvars}{break}
{cmd:tooltipvars(varlist)} accepts any mix of string, labelled numeric, and
unlabelled numeric.  String and labelled-numeric values render verbatim;
plain numerics get formatted with {cmd:%,.2f} (or {cmd:%,.0f} when abs ≥
1000).  Set a {cmd:variable label} on each var so the tooltip row gets a
readable left column.

{phang}
{bf:Sanity checks before plotting}{break}
{cmd:assert !missing(fips)}; {cmd:isid fips} (one row per feature);
{cmd:tab region_n, missing} (verify your filter categories aren't all
missing); {cmd:summarize lat lon} (decimal degrees, not radians, not
degrees-minutes).


{title:Working outside Texas}

{pstd}
{cmd:sparkta2} ships Texas-centric assets, but the engine itself is
geography-agnostic.  Two paths to map something other than Texas counties:

{phang}
{bf:Reuse the bundled topojson at a different layer.}{break}
{cmd:texas_counties.topojson} actually contains three layers: {bf:counties}
(254 TX, 5-digit FIPS), {bf:states} (56 US states + DC + territories,
2-digit FIPS), and {bf:nation} (one US outline). To draw an all-US state
choropleth, supply 2-digit state FIPS in {cmd:id()} and pass {cmd:layer(states)
idwidth(2)}. The same data drives {cmd:type(hexbin)} for a state-level
hexbin variant.

{phang}
{bf:Add a new geography.}{break}
Drop a {bf:<geo>_counties.topojson} file next to the ado files and pass
{cmd:geo(<geo>)}.  The file should be a TopoJSON (not GeoJSON) with at
least one object — the engine picks the first one unless you specify
{cmd:layer()}. Pipeline:

{phang2}1.  Download a shapefile (US Census TIGER for US geographies; Natural
Earth or GADM for international).{p_end}
{phang2}2.  Convert to TopoJSON with
{browse "https://mapshaper.org":mapshaper} or
{browse "https://github.com/topojson/topojson-server":topojson-server}.
Mapshaper has a GUI: drop the shapefile, "Export" as TopoJSON, pick a
quantization (1e5 is a good default).{p_end}
{phang2}3.  In mapshaper, set the {bf:id} attribute to whatever you'll
pass in {cmd:id()} (e.g. {cmd:GEOID} for US Census features); pad it to
the width you'll use with {cmd:idwidth()}.{p_end}
{phang2}4.  Save the file as
{it:<geo>_counties.topojson} next to {cmd:sparkta2_engine.js}, and
re-run {cmd:adopath ++ "<that dir>"}.{p_end}

{pstd}
If you want a custom backdrop (e.g. an Asia-Pacific map), include a
{bf:states} (regions/admin1) and {bf:nation} (country outline) object in
the same topojson; {cmd:basemap} will pick them up automatically.

{pstd}
For US-wide work outside Texas, the bundled topojson is sufficient via the
{cmd:layer(states)} trick — see the bonus examples below.


{title:Projection tuning -- Texas-tuned Albers and how to override it}

{pstd}
sparkta2 ships with three projection presets and an unspecified-Albers
escape hatch:

{phang}1. {bf:albers_usa} -- the d3.geoAlbersUsa composite with AK/HI insets.
Default for {cmd:geo(us)} and for any {cmd:layer(states|nation)} call.
Optimized for CONUS; centers near Kansas with parallels (29.5{c 176}, 45.5{c 176}).{p_end}

{phang}2. {bf:albers_tx} -- a Texas-tuned d3.geoAlbers preset.  Default for
{cmd:geo(texas)}.  Currently (v0.7.8): {bf:rotate=[101.5,0]},
{bf:parallels=[27.5,36.5]}, {bf:center=[0,31.5]}.{p_end}

{phang}3. {bf:mercator} -- d3.geoMercator.  Useful for web-tile interop.
Produces a noticeable upward bulge in Texas because Mercator's polar
distortion grows quickly above ~30{c 176} N.{p_end}

{phang}4. {bf:albers} -- a generic d3.geoAlbers with default settings.  Pair
with {cmd:rotate()}/{cmd:parallels()}/{cmd:center()} for arbitrary tuning.{p_end}

{pstd}
{bf:Why the v0.7.8 retuning.}  d3.geoAlbersUsa was used for every layer
including {cmd:geo(texas)} prior to v0.6.1, producing a ~3.3{c 176} downward
lean on the panhandle's top edge.  v0.6.1 introduced {bf:albers_tx} with
{bf:rotate=[99,0]}, {bf:parallels=[27.5,35.5]} -- this cut the lean to ~1.3{c 176}
but didn't eliminate it.  v0.7.8 retunes to {bf:rotate=[101.5,0]},
{bf:parallels=[27.5,36.5]} -- the lean is now 0.0{c 176} (panhandle top edge
renders perfectly horizontal).

{pstd}
{bf:The geometry.}  In Albers conic, lines of constant latitude render as
{bf:circular arcs} centered on the cone apex.  Two settings control how
any one latitude line slopes on the rendered map:

{phang}- The {bf:central meridian} (set by {cmd:rotate(}{it:lambda}{cmd:)})
determines where the arc {it:peaks}.  For the arc between two endpoints
to render as a horizontal chord, the central meridian must be at the
{bf:longitudinal midpoint} of those endpoints.{p_end}

{phang}- The {bf:standard parallels} (set by {cmd:parallels(}{it:phi1 phi2}{cmd:)})
mark where the projection is conformal (zero N-S distortion).  Placing
one parallel exactly at the latitude you want to render flat makes that
latitude line conformal.{p_end}

{pstd}
The Texas panhandle's top edge runs from -103{c 176} W to -100{c 176} W at 36.5{c 176} N.
Midpoint: {bf:-101.5{c 176} W}.  Latitude: {bf:36.5{c 176} N}.  Those are the
v0.7.8 albers_tx values exactly.

{pstd}
{bf:Trade-off.}  Shifting the central meridian 2.5{c 176} west of the state's
longitudinal centroid (-99.5{c 176}) means {bf:East Texas} longitude lines
tilt slightly more from vertical -- Sabine Pass (-93.5{c 176} W) sits 8{c 176} east
of CM instead of the 5.5{c 176} it sat at under v0.6.1.  At Texas scale this
is visually negligible, but a close compare against an albers_usa
rendering of the same data will show East Texas counties subtly rotated.

{pstd}
{bf:Common overrides.}

{phang}{cmd}* Restore the v0.6.1 tuning (panhandle ~1.3 deg lean, less East Texas shear):{p_end}
{phang}{cmd}sparkta2 ..., geo(texas) projection(albers_tx) rotate(99) parallels(27.5 35.5){p_end}

{phang}{cmd}* Restore the pre-v0.6.1 composite look (panhandle ~3.3 deg lean, AK/HI compatible):{p_end}
{phang}{cmd}sparkta2 ..., geo(texas) projection(albers_usa){p_end}

{phang}{cmd}* Use plain Albers conic with custom parameters (no Texas-specific tuning):{p_end}
{phang}{cmd}sparkta2 ..., projection(albers) rotate(99) parallels(27.5 35.5) center(0 31.5){p_end}

{phang}{cmd}* Use Mercator (web-tile interop; Texas gets a slight upward bulge):{p_end}
{phang}{cmd}sparkta2 ..., projection(mercator){p_end}

{pstd}
{bf:Why your map might look tilted differently from this gallery.}
If your map's panhandle top is not flat (or is tilted more than expected),
check, in order:

{phang}1. The {cmd:geo()} value.  {cmd:geo(texas)} defaults to albers_tx;
{cmd:geo(us)} defaults to albers_usa; other geos default to albers_usa.
Different defaults render the same data with different lean.{p_end}

{phang}2. The {cmd:layer()} value.  {cmd:layer(states|nation)} forces
albers_usa regardless of {cmd:geo()} -- so a {cmd:geo(texas) layer(states)}
call uses albers_usa, not albers_tx.{p_end}

{phang}3. Any explicit {cmd:projection() / rotate() / parallels() / center()}
overrides you've passed.  These take precedence over the preset defaults.{p_end}

{phang}4. The sparkta2 version installed.  v0.5.x and earlier used
albers_usa for everything; v0.6.1 introduced albers_tx with a ~1.3 deg
residual lean; v0.7.8 retunes albers_tx to zero lean.  Run any sparkta2
map call and the dispatcher banner at the top of the Stata Results window
prints the running version.{p_end}


{title:Examples}

{pstd}
A runnable do-file containing every example below sits at
{bf:examples/test_helpfile_examples.do} in the package; both the
Texas-county and ZIP datasets are bundled (the ZIP path is the Texas 2036
{bf:_datashare/Zipcode_Crosswalks/02_cleaned/TX_ZIP_Crosswalk.dta}).


{dlgtab:1. County bivariate choropleth — full UI}

{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    id(fips) name(county) type(bivariate) scheme(rdbu)         ///{p_end}
{phang}{cmd}    modes(bivariate|x|y|diff|ratio) comparable                 ///{p_end}
{phang}{cmd}    filters(region_n urban) sliders(poverty_rate uninsured_rate) ///{p_end}
{phang}{cmd}    tooltipvars(median_income life_expect)                     ///{p_end}
{phang}{cmd}    swapbutton download search offline                         ///{p_end}
{phang}{cmd}    title("Texas counties: poverty vs uninsured")              ///{p_end}
{phang}{cmd}    export("01_bivariate.html"){p_end}


{dlgtab:2. Small-multiples — three modes side by side}

{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    id(fips) name(county) type(bivariate)                      ///{p_end}
{phang}{cmd}    modes(bivariate|diff|ratio) multiples comparable           ///{p_end}
{phang}{cmd}    filters(region_n) width(1300) height(620) offline          ///{p_end}
{phang}{cmd}    export("02_multiples.html"){p_end}


{dlgtab:3. Subset to specific counties + auto-zoom}

{phang}{cmd}local big8 "48201 48029 48113 48439 48453 48141 48215 48085"{p_end}
{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    id(fips) name(county) type(bivariate)                      ///{p_end}
{phang}{cmd}    counties("`big8'") zoomto("`big8'")                         ///{p_end}
{phang}{cmd}    tooltipvars(median_income pop_thou)                        ///{p_end}
{phang}{cmd}    download offline                                           ///{p_end}
{phang}{cmd}    export("03_big8.html"){p_end}


{dlgtab:4. Hexbin — aggregate county centroids}

{phang}{cmd}sparkta2 poverty_rate,                                         ///{p_end}
{phang}{cmd}    id(fips) name(county) type(hexbin) scheme(viridis)         ///{p_end}
{phang}{cmd}    hexradius(22) hexstat(mean) download offline               ///{p_end}
{phang}{cmd}    title("Mean poverty rate per hex")                         ///{p_end}
{phang}{cmd}    export("04_hexbin.html"){p_end}


{dlgtab:5. Basemap — faded US-state backdrop}

{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    id(fips) name(county) type(bivariate) basemap              ///{p_end}
{phang}{cmd}    modes(bivariate|x|y|diff|ratio) comparable offline         ///{p_end}
{phang}{cmd}    export("05_basemap.html"){p_end}


{dlgtab:6. US 50-state choropleth — works outside Texas}

{phang}{cmd}* user data: 2-digit string state_fips + numeric value pop_mil{p_end}
{phang}{cmd}sparkta2 pop_mil,                                              ///{p_end}
{phang}{cmd}    id(state_fips) name(state_name) geo(texas)                 ///{p_end}
{phang}{cmd}    layer(states) idwidth(2)                                   ///{p_end}
{phang}{cmd}    type(choropleth) scheme(blues) download                    ///{p_end}
{phang}{cmd}    tooltipvars(gdp_thou)                                      ///{p_end}
{phang}{cmd}    title("US state population")                               ///{p_end}
{phang}{cmd}    width(1200) height(720) offline                            ///{p_end}
{phang}{cmd}    export("06_us_states.html"){p_end}


{dlgtab:7. US 50-state bivariate — works outside Texas}

{phang}{it:Note:} hexbin assumes a dense point cloud; with only 50 state
centroids the bins are sparse and align oddly. Use {cmd:type(bivariate)} or
{cmd:type(choropleth)} for state-level data instead.{p_end}

{phang}{cmd}sparkta2 pop_mil gdp_thou,                                     ///{p_end}
{phang}{cmd}    id(state_fips) name(state_name) geo(texas)                 ///{p_end}
{phang}{cmd}    layer(states) idwidth(2)                                   ///{p_end}
{phang}{cmd}    type(bivariate) scheme(rdbu)                                ///{p_end}
{phang}{cmd}    modes(bivariate|x|y|diff|ratio) swapbutton download         ///{p_end}
{phang}{cmd}    width(1200) height(720) offline                            ///{p_end}
{phang}{cmd}    export("07_us_states_bivariate.html"){p_end}


{dlgtab:8. School-district choropleth (bundled NCES boundaries)}

{phang}{cmd}use "NCES_EDGE_Texas_District_Map.dta", clear{p_end}
{phang}{cmd}destring intptlat intptlon, replace force{p_end}
{phang}{cmd}generate float frpl_pct100 = frpl_pct * 100{p_end}
{phang}{cmd}sparkta2 frpl_pct100 students_per_teacher,                    ///{p_end}
{phang}{cmd}    id(leaid) name(name) geo(texas_districts) idwidth(7)      ///{p_end}
{phang}{cmd}    type(bivariate) scheme(rdbu)                              ///{p_end}
{phang}{cmd}    filters(sdtyp) sliders(frpl_pct100 student_count)         ///{p_end}
{phang}{cmd}    tooltipvars(student_count teacher_fte school_count)       ///{p_end}
{phang}{cmd}    download search offline                                   ///{p_end}
{phang}{cmd}    export("08_districts.html"){p_end}


{dlgtab:9. District hexbin (centroids from `intptlat'/`intptlon')}

{phang}{cmd}sparkta2 frpl_pct100,                                         ///{p_end}
{phang}{cmd}    id(leaid) name(name) geo(texas_districts) idwidth(7)      ///{p_end}
{phang}{cmd}    type(hexbin) lat(intptlat) lon(intptlon)                  ///{p_end}
{phang}{cmd}    hexradius(20) hexstat(mean) scheme(viridis) offline       ///{p_end}
{phang}{cmd}    export("09_districts_hexbin.html"){p_end}


{dlgtab:9a. Export menu with data download (v0.6.0)}

{phang}{it:Use the new}{cmd: datatable} {it:option together with}{cmd: download} {it:so the Export menu offers PNG, SVG, Print to PDF, Download CSV, and View data table.}{p_end}

{phang}{cmd}sparkta2 poverty_rate,                                         ///{p_end}
{phang}{cmd}    id(fips) name(county) type(choropleth) scheme(blues)       ///{p_end}
{phang}{cmd}    tooltipvars(median_income pop_thou)                        ///{p_end}
{phang}{cmd}    download datatable offline                                 ///{p_end}
{phang}{cmd}    title("Texas poverty by county")                           ///{p_end}
{phang}{cmd}    export("09a_export_menu.html"){p_end}


{dlgtab:9b. Animate features on scroll into view (v0.6.0)}

{phang}{it:When the chart enters the viewport, the regions fade in over ~450ms.}
{it:Useful for one-pagers embedded mid-document so the reader sees motion exactly when they reach the figure.}{p_end}

{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    id(fips) name(county) type(bivariate) scheme(rdbu)         ///{p_end}
{phang}{cmd}    modes(bivariate|x|y|diff|ratio) comparable                 ///{p_end}
{phang}{cmd}    download datatable animate offline                         ///{p_end}
{phang}{cmd}    export("09b_animate.html"){p_end}


{dlgtab:9d. Projection control (v0.6.1)}

{phang}{it:Default behavior is automatic.}{cmd: geo(texas)} {it:now uses a Texas-tuned Albers projection that drops the panhandle's tilt from ~3.3 degrees down to ~1.3 degrees.}{p_end}

{phang}{it:Restore the pre-0.6.1 tilted look exactly:}{p_end}
{phang}{cmd}sparkta2 poverty_rate,                                         ///{p_end}
{phang}{cmd}    id(fips) name(county) type(choropleth)                     ///{p_end}
{phang}{cmd}    projection(albers_usa)                                     ///{p_end}
{phang}{cmd}    export("legacy_look.html"){p_end}

{phang}{it:Roll your own Texas projection (the four lines below are identical to the new default):}{p_end}
{phang}{cmd}sparkta2 poverty_rate,                                         ///{p_end}
{phang}{cmd}    id(fips) name(county) type(choropleth)                     ///{p_end}
{phang}{cmd}    projection(albers) rotate(99) parallels(27.5 35.5)         ///{p_end}
{phang}{cmd}    center(0 31.5)                                             ///{p_end}
{phang}{cmd}    export("custom_albers.html"){p_end}

{phang}{it:Web Mercator for international or partial-state work:}{p_end}
{phang}{cmd}sparkta2 some_metric,                                          ///{p_end}
{phang}{cmd}    id(border_county) name(county) type(choropleth)            ///{p_end}
{phang}{cmd}    projection(mercator)                                       ///{p_end}
{phang}{cmd}    export("mercator.html"){p_end}


{dlgtab:9c. Points map with all v0.6.0 features}

{phang}{cmd}sparkta2 enrollment,                                           ///{p_end}
{phang}{cmd}    id(campus_id) name(campus_name) type(points)               ///{p_end}
{phang}{cmd}    lat(latitude) lon(longitude)                               ///{p_end}
{phang}{cmd}    geo(texas) idwidth(9)                                      ///{p_end}
{phang}{cmd}    scheme(viridis) pointsize(5)                               ///{p_end}
{phang}{cmd}    download datatable animate                                 ///{p_end}
{phang}{cmd}    tooltipvars(district_name esc_region rating)               ///{p_end}
{phang}{cmd}    title("Texas campuses by enrollment")                      ///{p_end}
{phang}{cmd}    export("09c_points_all.html"){p_end}


{dlgtab:9e. Donut chart -- enrollment by sector (v0.7.0)}

{phang}{it:One slice per row.}{cmd: name(category)} {it:supplies the slice label and}{cmd: <xvar>} {it:supplies the slice value.  Center label shows the total automatically.}{p_end}

{phang}{cmd}sparkta2 enrollment,                                            ///{p_end}
{phang}{cmd}    name(sector) type(donut) scheme(tx2036)                     ///{p_end}
{phang}{cmd}    download datatable animate                                  ///{p_end}
{phang}{cmd}    title("Texas postsecondary enrollment by sector")           ///{p_end}
{phang}{cmd}    export("09e_donut.html"){p_end}


{dlgtab:9f. Native bar2 / line2 (v0.7.1; with v0.6.0 export menu + animate)}

{phang}{bf:Why bar2 / line2 (not bar / line).}  sparkta (Fahad Mirza) already
implements {cmd:type(bar)} and {cmd:type(line)} via Chart.js with its own
multi-variable / {cmd:stat()} / {cmd:fit()} syntax.  v0.7.1 keeps {cmd:bar}
and {cmd:line} forwarding to sparkta so pre-existing do-files don't break.
The new D3-native versions are exposed as {cmd:bar2} and {cmd:line2}.{p_end}

{phang}{it:Simple horizontal bar (no}{cmd: over()}{it:, value var =}{cmd: poverty_pct}{it:):}{p_end}
{phang}{cmd}sparkta2 poverty_pct, name(region) type(bar2) horizontal        ///{p_end}
{phang}{cmd}    scheme(blues) download datatable animate                    ///{p_end}
{phang}{cmd}    title("Estimated poverty rate by Comptroller region")       ///{p_end}
{phang}{cmd}    export("09f_bar_simple.html"){p_end}

{phang}{it:Stacked + normalised to 100% (long input:}{cmd: yr } x{cmd: sector } x{cmd: share}{it:):}{p_end}
{phang}{cmd}sparkta2 share, name(yr) over(sector) type(bar2) stacked normalize ///{p_end}
{phang}{cmd}    scheme(tx2036) download datatable                           ///{p_end}
{phang}{cmd}    title("Enrollment share by sector, 2020-2024")              ///{p_end}
{phang}{cmd}    export("09f_bar_stacked.html"){p_end}

{phang}{it:Multi-series line.  Two-var input}{cmd: y x }{it: with}{cmd: over(series)}{it:.}{p_end}
{phang}{cmd}sparkta2 metric yr, over(region) type(line2) scheme(tx2036)     ///{p_end}
{phang}{cmd}    download datatable animate                                  ///{p_end}
{phang}{cmd}    title("Trend, 2018-2024") xlabel("Year") ylabel("Value")    ///{p_end}
{phang}{cmd}    export("09f_line.html"){p_end}


{dlgtab:9g. Diverging stacked bar (Pew-style) for Likert items (v0.7.0)}

{phang}{bf:Why this chart.}  Pew Research Center has popularised the
"diverging stacked bar" for showing Likert-scale survey items: agree /
disagree responses spread to the right and left of a central zero line, with
percentages labelled inside each segment and no distracting bottom axis.
The result is a single panel that lets a reader scan many items by net
favourability while still reading each item's full breakdown.{p_end}

{phang}{bf:What's bundled by default.}  Setting {cmd:type(divbar)} turns on
four Pew-style behaviours automatically:{p_end}
{phang2}o  {bf:Horizontal bars} with {bf:wrapping} on long item text in the
left margin.  Survey questions can be a sentence long -- sparkta2 wraps to
multiple lines and vertically-centres the block on its bar.{p_end}
{phang2}o  {bf:Central zero baseline} ({bf:.zero}): a vertical line drawn at
the centring response level.  Negative segments (e.g. {it:Disagree},
{it:Strongly disagree}) extend to the left; positive to the right.{p_end}
{phang2}o  {bf:Direct labels} inside each segment showing the percentage
({cmd:directlabels} is on by default for divbar).  Suppressed automatically
for segments too narrow to host the label.{p_end}
{phang2}o  {bf:No bottom axis} ({cmd:suppressaxis} on by default).  The
direct labels do the job a bottom axis would otherwise do; the axis would
just add clutter.{p_end}

{phang}{bf:Data shape.}  Long form: one row per (item, response level, share).
{cmd:name()} is the item identifier (a string of any length -- it wraps),
{cmd:level()} is the response category, and {it:xvar} is the share (numeric
percent).  {cmd:levelorder()} lets you fix the response order via a
pipe-separated string; {cmd:centerlevel()} declares which level the bars
center on (if odd-numbered, defaults to the middle level; if you have a
"Don't know" level the convention is to drop it before plotting).{p_end}

{phang}{bf:Bonus annotation.}  A {bf:Net (+/-)} column appears at the right
edge showing each item's net favourability (positive total minus negative
total).  Blue means net-positive, red means net-negative.{p_end}

{phang}{cmd}* Long-form Likert data: (item q, response, % share){p_end}
{phang}{cmd}sparkta2 share, name(q) level(response) type(divbar)            ///{p_end}
{phang}{cmd}    levelorder("Strongly disagree|Disagree|Neutral|Agree|Strongly agree") ///{p_end}
{phang}{cmd}    centerlevel(Neutral)                                        ///{p_end}
{phang}{cmd}    download datatable                                          ///{p_end}
{phang}{cmd}    title("Texans on K-12 and higher-ed policy")                ///{p_end}
{phang}{cmd}    subtitle("Pew-style diverging stacked bar")                 ///{p_end}
{phang}{cmd}    width(1100) height(560)                                     ///{p_end}
{phang}{cmd}    export("09g_divbar.html"){p_end}

{phang}{it:Style notes for reproducible Pew-style output:}{p_end}
{phang2}o  Always pass {cmd:levelorder()} explicitly so the legend and the
within-bar stacking match.  Don't rely on input row order.{p_end}
{phang2}o  Hand off the cleaned long file to a separate reproducible step
that computes {cmd:share} per item -- so the chart itself stays a thin
visualisation layer.{p_end}
{phang2}o  Use {cmd:tooltipvars(n)} to show the per-item sample size on
hover when you have it; the chart itself does not bake n into the labels
because Pew's house style omits it from in-bar labels.{p_end}


{dlgtab:9i. Likert "three ways" comparison -- 9 items (v0.7.2)}

{phang}{bf:Pattern:}  the same 9 Likert items rendered three different ways
on a single dashboard page so the viewer can scan trade-offs at a glance --
(A) divbar full distribution, (B) sparkta2-native bar2 % Agree summary,
(C) sparkta2-native bar2 net favourability with an RdBu diverging palette
and animate-on-scroll.  All three iframes embed via
{help sparkta2_dashboard}.  Each panel deliberately uses horizontal labels
so the eye doesn't have to read angled text.{p_end}

{phang}{bf:Sort discipline:}  compute net favourability per item
({it:%Agree + %Strongly agree minus %Strongly disagree - %Disagree}) and pin
the row order to that sort across all three charts so the eye can track each
item down the page.{p_end}

{phang}{cmd}* Long-form input: q | response | share (a 9-item version sits in{p_end}
{phang}{cmd}* test_helpfile_examples.do, block 9i).  Compute the row order once:{p_end}
{phang}{cmd}preserve{p_end}
{phang}{cmd}gen byte _sign = -1 if inlist(response, "Strongly disagree", "Disagree"){p_end}
{phang}{cmd}replace  _sign =  1 if inlist(response, "Agree", "Strongly agree"){p_end}
{phang}{cmd}replace  _sign =  0 if response == "Neutral"{p_end}
{phang}{cmd}gen double _signed = share * _sign{p_end}
{phang}{cmd}collapse (sum) net_fav = _signed, by(q){p_end}
{phang}{cmd}gsort -net_fav{p_end}
{phang}{cmd}gen int item_order = _n{p_end}
{phang}{cmd}tempfile order; save "`order'", replace{p_end}
{phang}{cmd}restore{p_end}
{phang}{cmd}merge m:1 q using "`order'", nogenerate{p_end}
{phang}{cmd}sort item_order response{p_end}

{phang}{cmd}* (A) Pew-style diverging stacked bar -- full Likert distribution{p_end}
{phang}{cmd}sparkta2 share, name(q) level(response) type(divbar)                       ///{p_end}
{phang}{cmd}    levelorder("Strongly disagree|Disagree|Neutral|Agree|Strongly agree")  ///{p_end}
{phang}{cmd}    centerlevel(Neutral) tx2036style downloadpos(below) download datatable ///{p_end}
{phang}{cmd}    title("A. Pew-style diverging stacked bar: full distribution")         ///{p_end}
{phang}{cmd}    width(1100) height(850) offline noopen                                  ///{p_end}
{phang}{cmd}    export("09i_A_divbar.html"){p_end}

{phang}{cmd}* (B) sparkta2-native bar2 -- % Agree (incl. Strongly agree){p_end}
{phang}{cmd}preserve{p_end}
{phang}{cmd}gen byte _pos = inlist(response, "Agree", "Strongly agree"){p_end}
{phang}{cmd}collapse (sum) pct_agree = share if _pos == 1, by(q item_order){p_end}
{phang}{cmd}gsort item_order{p_end}
{phang}{cmd}sparkta2 pct_agree, name(q) type(bar2) horizontal                          ///{p_end}
{phang}{cmd}    scheme(blues) tx2036style downloadpos(below) download datatable animate ///{p_end}
{phang}{cmd}    title("B. sparkta2-native bar2 (D3): % Agree")                          ///{p_end}
{phang}{cmd}    width(1100) height(850) offline noopen                                  ///{p_end}
{phang}{cmd}    export("09i_B_bar2.html"){p_end}
{phang}{cmd}restore{p_end}

{phang}{cmd}* (C) sparkta2-native bar2 -- net favourability with animate-on-scroll{p_end}
{phang}{cmd}preserve{p_end}
{phang}{cmd}gen byte _pos = inlist(response, "Agree", "Strongly agree"){p_end}
{phang}{cmd}gen byte _neg = inlist(response, "Strongly disagree", "Disagree"){p_end}
{phang}{cmd}gen double _signed = share * _pos - share * _neg{p_end}
{phang}{cmd}collapse (sum) net_fav_pct = _signed, by(q item_order){p_end}
{phang}{cmd}gsort item_order{p_end}
{phang}{cmd}sparkta2 net_fav_pct, name(q) type(bar2) horizontal                        ///{p_end}
{phang}{cmd}    scheme(rdbu) tx2036style downloadpos(below) download datatable animate ///{p_end}
{phang}{cmd}    title("C. sparkta2-native bar2 (D3): net favourability")               ///{p_end}
{phang}{cmd}    xlabel("Net % favourable (positive minus negative)")                   ///{p_end}
{phang}{cmd}    width(1100) height(850) offline noopen                                  ///{p_end}
{phang}{cmd}    export("09i_C_bar2_netfav.html"){p_end}
{phang}{cmd}restore{p_end}

{phang}{cmd}* Combine all three on a single HTML page for the viewer:{p_end}
{phang}{cmd}sparkta2_dashboard,                                                        ///{p_end}
{phang}{cmd}    files("09i_A_divbar.html 09i_B_bar2.html 09i_C_bar2_netfav.html")     ///{p_end}
{phang}{cmd}    titles("A. Pew divbar|B. bar2 (% Agree)|C. bar2 (net favourability)") ///{p_end}
{phang}{cmd}    heights("900") tx2036style                                            ///{p_end}
{phang}{cmd}    title("Likert survey items, three ways (9-item version)")              ///{p_end}
{phang}{cmd}    export("09i_comparison.html"){p_end}


{dlgtab:9h. Bar chart race -- categories over time (v0.7.0)}

{phang}{it:Long form input:}{cmd: name(category) time(yvar)}{it: with}
{cmd: <xvar>}{it: as the bar value.  Top-N is fixed per frame via}
{cmd: top()}{it:.  A play/pause/replay button appears in the View panel.}{p_end}

{phang}{cmd}sparkta2 pop, name(county) time(yr) type(barrace) top(10)       ///{p_end}
{phang}{cmd}    duration(15) scheme(tx2036) download datatable              ///{p_end}
{phang}{cmd}    title("Top-10 Texas counties by population, 2019-2024")     ///{p_end}
{phang}{cmd}    export("09h_barrace.html"){p_end}


{dlgtab:9j. Label-wrap control on bar2 / divbar (v0.7.3)}

{phang}{bf:Two options} govern how long category labels render on horizontal
{cmd:bar2} and on {cmd:divbar}:{p_end}

{phang}{cmd:wraplabel(}{it:string}{cmd:)} -- wrap policy:{p_end}
{phang2}{cmd:auto}: default for bar2; wraps when the longest label exceeds ~28 chars.{p_end}
{phang2}{cmd:on}: always wrap (default for divbar).{p_end}
{phang2}{cmd:off}: never wrap; truncate with Unicode ellipsis if a label overflows.{p_end}

{phang}{cmd:gutterwidth(}{it:#}{cmd:)} -- left-margin width in px for the category-label gutter.  Default depends on context (160 bar2 no-wrap, 300 wrapped).{p_end}

{phang}{bf:When to override.}  The auto rule covers most policy work, but
real corner cases exist: short labels you want stacked anyway ({cmd:wraplabel(on)});
very long labels you want cleanly truncated for grid embeds
({cmd:wraplabel(off)}); narrow charts in a 2x2 panel ({cmd:gutterwidth(220)}).{p_end}

{phang}{bf:All four modes on the same 9-item Likert data:}{p_end}

{phang}{cmd}* (a) Default auto -- wrap kicks in because labels are long{p_end}
{phang}{cmd}sparkta2 pct_agree, name(q) type(bar2) horizontal                          ///{p_end}
{phang}{cmd}    tx2036style downloadpos(below) scheme(blues)                            ///{p_end}
{phang}{cmd}    title("9j-a. wraplabel(auto) -- default, wraps long items")            ///{p_end}
{phang}{cmd}    export("09j_a_auto.html"){p_end}

{phang}{cmd}* (b) Force on -- explicit wrap even when labels are short{p_end}
{phang}{cmd}sparkta2 pct_agree, name(q) type(bar2) horizontal                          ///{p_end}
{phang}{cmd}    wraplabel(on) tx2036style downloadpos(below) scheme(blues)              ///{p_end}
{phang}{cmd}    title("9j-b. wraplabel(on) -- always wrap")                            ///{p_end}
{phang}{cmd}    export("09j_b_on.html"){p_end}

{phang}{cmd}* (c) Force off -- single line, truncated with ellipsis{p_end}
{phang}{cmd}sparkta2 pct_agree, name(q) type(bar2) horizontal                          ///{p_end}
{phang}{cmd}    wraplabel(off) tx2036style downloadpos(below) scheme(blues)             ///{p_end}
{phang}{cmd}    title("9j-c. wraplabel(off) -- truncate with ellipsis")                ///{p_end}
{phang}{cmd}    export("09j_c_off.html"){p_end}

{phang}{cmd}* (d) Narrow gutter via gutterwidth -- truncates more aggressively{p_end}
{phang}{cmd}sparkta2 pct_agree, name(q) type(bar2) horizontal                          ///{p_end}
{phang}{cmd}    wraplabel(off) gutterwidth(180) tx2036style downloadpos(below)           ///{p_end}
{phang}{cmd}    scheme(blues)                                                           ///{p_end}
{phang}{cmd}    title("9j-d. gutterwidth(180) + wraplabel(off)")                        ///{p_end}
{phang}{cmd}    export("09j_d_narrow.html"){p_end}


{dlgtab:10. Chart pass-through to sparkta}

{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    type(scatter) fit(lfit) fitci offline                      ///{p_end}
{phang}{cmd}    export("10_scatter.html"){p_end}
{phang}{cmd}sparkta2 poverty_rate uninsured_rate,                          ///{p_end}
{phang}{cmd}    type(bar) over(region_n) stat(mean) offline                ///{p_end}
{phang}{cmd}    export("10_bar.html"){p_end}


{title:Returned values}

{phang}{bf:r(export)} - path of the written HTML.{p_end}
{phang}{bf:r(type)}   - resolved map type.{p_end}
{phang}{bf:r(geo)}    - {cmd:geo()} as resolved.{p_end}
{phang}{bf:r(n_rows)} - number of data rows actually written.{p_end}


{title:References}

{phang}
Bostock, M. {it:Bivariate choropleth}, {it:Methods of comparison compared},
and {it:Zoom to bounding box} — Observable notebooks at
{browse "https://observablehq.com/@d3":observablehq.com/@d3}.

{phang}
Holtz, Y. {it:D3 Graph Gallery — Hexbin map} and {it:Background map} at
{browse "https://d3-graph-gallery.com":d3-graph-gallery.com}.

{phang}
Mirza, F. {bf:sparkta} — interactive HTML charts from Stata.
{browse "https://github.com/fahad-mirza/sparkta_stata":github.com/fahad-mirza/sparkta_stata}.


{title:Embedding in webdoc2 and the iframe auto-resize protocol (v0.7.7)}

{pstd}
sparkta2 maps and charts embed in webdoc2 reports via {cmd:wdiframe}, the same way
sparkta dashboards do. Write the map / chart .html into the same folder as the
parent report (file:// enforces same-origin per directory), then:

{phang}{cmd}sparkta2 ..., offline noopen export("mymap.html"){p_end}
{phang}{cmd}wdiframe mymap.html, height(820px){p_end}

{pstd}
The do-file must be invoked via {cmd:webdoc do mydoc.do, replace} (not
plain {cmd:do}) for {cmd:wdinit}/{cmd:webdoc put}/{cmd:wdiframe} to
register. A runnable proof-of-concept lives at
{bf:examples/test_sparkta2_in_webdoc2.do} (12-section comprehensive demo).

{pstd}
{bf:Auto-resize protocol (v0.7.7).}  Every sparkta2-native HTML page embeds
a small inline {cmd:<script>} that calls
{cmd}window.parent.postMessage({type:'sparkta2-resize', height: H}, '*'){txt}
on load / window resize / DOM mutation, where H is the rendered content
height in pixels.  Parent pages ({cmd:sparkta2_dashboard} wrappers and the
companion webdoc2 demo) ship a listener that grows each iframe to fit its
content and sets {cmd:scrolling="no"}, so embedded outputs never get
clipped behind a scrollbar.

{pstd}
{bf:Per-iframe escape hatch.}  Mark a single {cmd:<iframe>} with HTML
attribute {cmd:data-skip-resize="1"} and the parent listener will leave
its height and scrolling untouched.  Use this for sparkta / Chart.js
pass-throughs (which don't emit the {cmd:sparkta2-resize} postMessage):
without the escape hatch, those iframes get silently clipped at the
declared height; with it, they get a native scrollbar.  Section 11 of
{bf:test_sparkta2_in_webdoc2.do} is the canonical example.


{title:See also}

{phang}{help sparkta} — Fahad Mirza's chart engine that this command wraps.{p_end}
{phang}{help spmap} — Maurizio Pisati's static Stata mapping package.{p_end}
{phang}{help webdoc2} — Texas 2036 webdoc2 wrapper around Ben Jann's {cmd:webdoc}.{p_end}


{title:Author}

{pstd}
Eric Booth, Texas 2036.{break}
eric.booth@texas2036.org

{pstd}
Map renderer, dispatcher, dashboard helper, and all sparkta2-specific
plumbing.  When called with a non-map {cmd:type()}, {cmd:sparkta2}
forwards to {help sparkta} — credit for those chart types belongs entirely
to Fahad Mirza.
