# sparkta2

**Interactive D3 maps + native non-map chart types from Stata, with chart pass-through to `sparkta` for anything else.**

`sparkta2` is a thin Stata dispatcher around three engines:

- A bundled **D3 v7 map engine** for `type(bivariate | choropleth | hexbin | points)`.
- A bundled **D3 v7 chart engine** (new in v0.7.0) for `type(donut | bar2 | line2 | divbar | barrace)`.
- Forwarding to **`sparkta`** by Fahad Mirza ([fahad-mirza/sparkta_stata](https://github.com/fahad-mirza/sparkta_stata)) for every other chart type (`bar`, `line`, `scatter`, `pie`, `violin`, `histogram`, ...). Install `sparkta` separately if you intend to use those.

> **Why `bar2` / `line2` and not `bar` / `line`?** sparkta already implements `type(bar)` and `type(line)` via Chart.js with its own multi-variable / `stat()` / `fit()` syntax. v0.7.1 keeps `bar` and `line` forwarding to sparkta so every pre-existing do-file works unchanged. The new D3-native versions are exposed as `bar2` and `line2`, which inherit the v0.6.0 Export menu, `datatable`, and `animate` but take simpler input (one numeric var with `name()`, optional `over()` for grouping/stacking).

Map design borrows from Mike Bostock's Observable notebooks ([d3/bivariate-choropleth](https://observablehq.com/@d3/bivariate-choropleth), [mbostock/methods-of-comparison-compared](https://observablehq.com/@mbostock/methods-of-comparison-compared), [d3/zoom-to-bounding-box](https://observablehq.com/@d3/zoom-to-bounding-box)) and the D3 Graph Gallery ([hexbin map](https://d3-graph-gallery.com/graph/hexbinmap_geo_label.html), [background map](https://d3-graph-gallery.com/graph/backgroundmap_country.html)). `d3-hexbin` v0.2.2 is bundled (MIT, © Mike Bostock).

## Status

Live version demo gallery here: https://ericabooth.github.io/Sparkta2_Example_Site/

**v0.7.8** (2026-06-26). Texas-tuned Albers retuned to make the panhandle top edge perfectly horizontal: central meridian moved from `–99°` to `–101.5°` (the panhandle's longitudinal midpoint) and upper standard parallel from `35.5°` to `36.5°` (the panhandle's latitude). The v0.6.1 fix had reduced the original `albers_usa` ~3.3° lean to ~1.3°; v0.7.8 takes it to 0.0°. See [Projection: Texas-tuned Albers and how to override it](#projection-texas-tuned-albers-and-how-to-override-it) below for the geometry, trade-offs, and escape hatches.

**v0.7.7** (2026-06-26). Iframe auto-resize protocol: every sparkta2-native HTML output now posts its rendered content height to its parent page on load / resize / DOM mutation, and parent pages (sparkta2_dashboard wrappers + the webdoc2 demos) grow each iframe to fit + set `scrolling="no"`, so embeds never get clipped behind a scrollbar. Opt out per-iframe with the `data-skip-resize="1"` HTML attribute (used for sparkta / Chart.js pass-throughs that don't speak the resize protocol).

**v0.7.3** (2026-06-26). Chart label policy: `wraplabel(auto | on | off)` (synonyms `wrap`, `truncate`) + `gutterwidth(N)` left-margin override. `auto` keeps long labels on one line when they fit, wraps to two lines otherwise, and truncates with an ellipsis if even two lines don't fit. Useful for divbar/bar2/line2 with long category names.

**v0.7.2** (2026-06-26). `tx2036style` option (Texas 2036 brand + Montserrat font from Google Fonts) and `downloadpos(side|below|none)` option to move the Export menu under the chart (collapses the 240px side panel when no other controls live there).

**v0.7.1** (2026-06-26). Backward-compat rename: native bar / line are now `type(bar2)` / `type(line2)`, so sparkta's `type(bar)` / `type(line)` continue to forward unchanged. Existing do-files that called sparkta for bars or lines keep working without edits.

**v0.7.0** (2026-06-26). Native D3 chart types beyond maps: donut, bar2, line2, diverging stacked bar (Pew-style for Likert/survey items), and bar chart race. All inherit the v0.6.0 Export menu, animate-on-view, and CSV data download.

Two bundled Texas geographies: 254 counties (with 56 US states + nation as backdrop layers) and 1,018 NCES EDGE SY2024-25 school districts. The engine also accepts any TopoJSON or GeoJSON FeatureCollection you drop next to the ado files.

<img width="1081" height="721" alt="image" src="https://github.com/user-attachments/assets/cd9ea4ec-1747-4eae-b852-522007036d29" />


### What's new in v0.7.7 (2026-06-26)

- **Iframe auto-resize protocol.** Each sparkta2-native HTML page now embeds a tiny inline `<script>` that calls `window.parent.postMessage({type:'sparkta2-resize', height: H}, '*')` whenever the rendered content height changes (load, window resize, ResizeObserver, MutationObserver). Both `sparkta2_dashboard` wrappers and the webdoc2 demos ship a parent-side listener that grows each iframe to fit and sets `scrolling="no"`, so embedded outputs never get clipped behind a scrollbar.
- **`data-skip-resize="1"` escape hatch.** Mark a single `<iframe>` with that HTML attribute and the parent listener will leave its height + scrolling untouched. Use this for sparkta / Chart.js pass-throughs whose pages do not emit the `sparkta2-resize` message — without the escape hatch, those iframes would be silently clipped at the wrapper's declared height; with it, they get a native scrollbar.
- **Comprehensive single-page demo do-file:** [`examples/test_sparkta2_in_webdoc2.do`](examples/test_sparkta2_in_webdoc2.do) now builds a 12-section webdoc2 page covering every sparkta2-native type (5 maps + 5 charts + 1 label-wrap demo) plus 2 sparkta (Chart.js) pass-throughs. Section 11 deliberately keeps its scrollbar (via `data-skip-resize`) to demonstrate the escape hatch.

### What's new in v0.7.3 (2026-06-26)

- **Chart label policy.** New `wraplabel(auto | on | off)` option (synonyms `wrap` and `truncate`) plus `gutterwidth(N)` to override the left-margin gutter width. `auto` keeps long category names on one line when they fit, wraps to two lines otherwise, and truncates with an ellipsis if even two lines still overflow. Targets divbar / bar2 / line2 with long item text where the default gutter was clipping labels.

### What's new in v0.7.2 (2026-06-26)

- **`tx2036style` option.** Loads Montserrat (400/500/600/700 weights) from Google Fonts and tightens typography to a Texas 2036 brand look — heavy h1 weight, kerning, navy body text. SVG text deliberately stays on the system stack so `getComputedTextLength` measurements (used by divbar wrap, donut label suppression) stay stable across the async font load. Falls back to system sans-serif if offline.
- **`downloadpos(side | below | none)` option.** Moves the Export menu out of the side controls panel into a right-aligned footer under the chart, or hides it entirely. When `below` and no other controls live in the side panel, the layout collapses to a single column so the page no longer reserves the 240px sidebar — useful for narrow embeds and one-off figures.
- **New helpfile example 9g+:** "Likert survey items, three ways" comparison — the same 9 Likert items rendered as Pew-style divbar (full distribution), sparkta2-native bar2 (% Agree summary), and sparkta-forwarded bar (Chart.js, % Agree), all combined onto a single dashboard page via `sparkta2_dashboard`.

### What's new in v0.7.1 (2026-06-26)

- **Backward-compat rename.** sparkta2-native bar / line are now exposed as `type(bar2)` and `type(line2)`. `type(bar)` and `type(line)` continue to forward to `sparkta` unchanged so every pre-0.7.0 do-file using sparkta's bar/line syntax (multi-var, `stat()`, `fit()`, `over()` with stat=mean, ...) still works without edits.
- Opt in to the D3-native versions (Export menu, `animate`, `datatable`, CSV download) by changing `type(bar)` to `type(bar2)` (and likewise `line` → `line2`). The native versions take simpler input — one numeric var with `name()`, optional `over()` for grouping/stacking.
- `donut`, `divbar`, `barrace` keep their original names — there's no name collision with sparkta for those.

### What's new in v0.7.0 (2026-06-26)

- **Five new sparkta2-native non-map chart types.** All D3 v7, rendered by a new `sparkta2_chart_engine.js` and dispatched by `sparkta2_chart.ado`.
  - `type(donut)` — ring chart, one slice per row. Center label shows the total.
  - `type(bar2)` (v0.7.1 rename; was `bar` in v0.7.0) — vertical / horizontal bars; optional `over()` for grouped or `stacked` (+ `normalize`) variants.
  - `type(line2)` (v0.7.1 rename; was `line` in v0.7.0) — multi-series line via `over(series)`; `y x` input; monotone-X curve.
  - `type(divbar)` — **Pew-style diverging stacked bar** for Likert/survey items. Horizontal bars, wrapping long item text in the left margin, central zero baseline, direct % labels inside segments, net favourability column on the right, no bottom axis by default. Long-form input: `name(item) level(response) <share>`, with `levelorder()` to fix the level ordering.
  - `type(barrace)` — animated bar chart race over `time()`, with play/pause/replay button.

### What's new in v0.6.1 (2026-06-26)

- **Texas projection tilt fixed.** `d3.geoAlbersUsa()` was used for every layer including `geo(texas)`, but its CONUS-wide standard parallels (29.5°N / 45.5°N) and –96° rotation centre the projection near Kansas. Texas, south and west of that centre, rendered with a ~3.3° downward lean on the panhandle's top edge. Now:
  - `geo(texas)` defaults to a Texas-tuned `d3.geoAlbers()` (`rotate=[99,0], center=[0,31.5], parallels=[27.5,35.5]`), dropping the lean to ~1.3°.
  - `geo(us)` and `layer(states|nation)` keep `d3.geoAlbersUsa()` (unchanged).
- **New options:** `projection(albers_usa | albers_tx | albers | mercator)` for presets, plus `rotate()`, `parallels()`, and `center()` numeric overrides on any non-composite projection.
- Backward-compat escape hatch: pass `projection(albers_usa)` to restore the pre-0.6.1 look exactly.

### What's new in v0.6.0 (2026-06-23)

- **Export menu** replaces the single "Download PNG" button. Setting `download` now opens a small dropdown with **PNG**, **SVG**, and **Print to PDF…** (browser print dialog with a print-only stylesheet that hides the controls panel and tooltip).
- **`datatable` option.** Extends the Export menu with **Download CSV** (every embedded row with original Stata variable names, including `tooltipvars()`) and **View data table** (collapsible scrollable HTML table beneath the chart showing rows that pass the active filters/sliders/search).
- **`animate` option.** IntersectionObserver-gated entry animation: features fade in over ~450ms with a small per-feature stagger when the chart enters the viewport. One-shot; doesn't re-trigger on subsequent scrolls.

### What's new in v0.5.0

- **Hexbin renderer fix.** v0.4.0's hexbin produced zero bins — d3-hexbin defaults to array-indexing the input but the engine pushes object points. Engine now sets explicit x/y accessors. All hexbin examples now render.
- **Basemap projection fix.** Previously the projection was fit to the basemap layer (all 50 US states), so Texas-only maps appeared tiny in the corner and "reset zoom" exposed the whole US. The projection now always fits the focused layer; the basemap is drawn beneath at whatever extent.
- **GeoJSON FeatureCollection support.** Engine accepts either a TopoJSON (with `objects`) or a GeoJSON `FeatureCollection` (with `features`). Drop a `<geo>.geojson` next to the ado and pass `geo(<name>)`.
- **`texas_districts.geojson` bundled.** 1,018 Texas school district polygons built from the NCES EDGE SY2024-25 shapefile, simplified via Douglas-Peucker to 1.4 MB. Use `geo(texas_districts) idwidth(7)` with 7-digit LEAID ids.
- **NCES districts demo do-file.** New [`examples/test_sparkta2_nces.do`](examples/test_sparkta2_nces.do) loads `NCES_EDGE_Texas_District_Map.dta` from the _datashare and exercises sparkta2 on real district-level data (replaces the v0.4.0 ZIP demo, which couldn't use polygon boundaries because no ZCTA boundaries were in the _datashare).

## Install

```stata
net install sparkta2, from("https://raw.githubusercontent.com/ericabooth/sparkta2-stata/master/ado/") replace force
which sparkta2
help sparkta2
```

Note that Stata's `net install` only copies `.ado`, `.sthlp`, and `.jar` files; the bundled D3 / TopoJSON / d3-hexbin assets need to land next to the ado files for `findfile` to pick them up.  The package handles this automatically: on first map call, `sparkta2_findfile` checks `adopath` for the assets and, if any are missing, downloads them from the same GitHub mirror into `sysdir PLUS/s/sparkta2/`.  Subsequent calls reuse the cached copies. Override the source with `global sparkta2_remote_base "<your URL>"` before the first call.

### For chart pass-through, also install `sparkta`

```stata
net install sparkta, from("https://raw.githubusercontent.com/fahad-mirza/sparkta_stata/master/ado") replace
```

Without `sparkta`, only the map types (`bivariate`, `choropleth`, `hexbin`, `points`, `map`) work; non-map types raise an informative error pointing to the install command. Credit: `sparkta` is by [Fahad Mirza](https://github.com/fahad-mirza/sparkta_stata) — `sparkta2` extends and builds on it.

### Verify

```stata
which sparkta2
help sparkta2
do https://raw.githubusercontent.com/ericabooth/sparkta2-stata/main/examples/test_helpfile_examples.do
```

The third command runs all 10 examples that appear in `help sparkta2` and writes the HTML output to `sparkta2_helpfile_out/` in your cwd.

## Quick start

```stata
import delimited using "examples/texas_county_demo.csv", varnames(1) clear stringcols(2)
destring fips poverty_rate uninsured_rate, replace force

* Bivariate choropleth with the full UI
sparkta2 poverty_rate uninsured_rate,                       ///
    id(fips) name(county) type(bivariate) scheme(rdbu)      ///
    modes(bivariate|x|y|diff|ratio) comparable              ///
    filters(region_n urban) sliders(poverty_rate uninsured_rate) ///
    tooltipvars(median_income life_expect)                  ///
    swapbutton download search offline                      ///
    title("Texas counties: poverty vs uninsured")           ///
    export("texas_bivariate.html")
```

Four drivers in [`examples/`](examples/) exercise every option:

- [`test_sparkta2_map.do`](examples/test_sparkta2_map.do) — 20 county-level examples + dashboard (Texas data + 2 US-state bonus)
- [`test_sparkta2_nces.do`](examples/test_sparkta2_nces.do) — 20 NCES EDGE Texas school-district examples + dashboard (loads `NCES_EDGE_Texas_District_Map.dta` from the _datashare; renders on the bundled `texas_districts.geojson` polygons)
- [`test_helpfile_examples.do`](examples/test_helpfile_examples.do) — the 10 examples that appear in `help sparkta2`, verbatim, runnable as a smoke test
- [`test_sparkta2_in_webdoc2.do`](examples/test_sparkta2_in_webdoc2.do) — comprehensive 12-section webdoc2 demo: 5 maps + 5 sparkta2-native charts (donut, bar2, line2, divbar, barrace) + 1 label-wrap demo + 2 sparkta (Chart.js) pass-throughs. Exercises the v0.7.7 iframe auto-resize protocol + the `data-skip-resize` escape hatch.

## Browser interactions — how each control maps back to Stata options

| In the browser | Stata option that produced it | What happens |
|---|---|---|
| Row of buttons at the top of the controls panel | `mode() modes()` | Click to switch the active mode among `bivariate / x / y / y - x (diff) / y / x (ratio)`. Only the active mode renders. |
| Multiple panels in a grid | `multiples` + `modes(…)` | Mode toggle is replaced by one SVG per allowed mode. Filters/sliders update all panels together. |
| Diverging diff palette | `comparable` (paired with `mode(diff)` or `modes(…|diff|…)`) | Switches diff from rank-difference (default) to value-difference. Only set when x and y share units. |
| Dropdown(s) on the side panel | `filters(varlist)` | Each variable becomes a dropdown. Selecting a value dims (greys out) every county whose value differs. |
| Dual-handle slider(s) on the side panel | `sliders(varlist)` (numeric) | Each variable becomes a slider. Drag handles to dim counties whose value is outside the range. |
| Text input "Filter by name…" | `search` | Typing dims counties whose `name()` doesn't contain the substring (case-insensitive). |
| Map shows only a chosen set; everything else hidden | `counties(fips_list)` **or** `[if] [in]` | Excluded counties aren't embedded — they don't even render in grey. |
| Map auto-zooms to a region on load | `zoomto(fips_list)` | Auto-fits the projection to the bounding box of the listed features. |
| Drag to pan, wheel to zoom, click-a-county zooms in, dblclick resets | *default (no `nozoom`)* | All four are wired up; a "Reset zoom" button also appears in the controls panel. |
| All zoom/pan disabled | `nozoom` | Useful for static slide exports. |
| "Swap axes (X ⇄ Y)" button | `swapbutton` | Flips X and Y in the bivariate / diff / ratio palettes (single-panel mode only). |
| "Download PNG" button | `download` | Rasterises the full SVG (all panels in multiples mode) at 2x. |
| Tooltip shows a labelled table of extra fields | `tooltipvars(varlist)` | Each listed variable becomes a row in the tooltip table; uses `variable label` if set. |
| Faded states/nation outline behind the focused features | `basemap` | Drawn underneath and stays visible at every zoom level. |
| Hex polygons over the map | `type(hexbin) hexradius() hexstat()` | Aggregates feature centroids or lat/lon points into hexagons; hover shows the bin's contents. |
| Circle marks at lat/lon | `type(points) lat() lon() pointsize()` | Each row becomes one circle. Used for ZIP centroids, addresses, or any point-level data. |

## Data prep — getting your data into the right shape

Three columns are always required: an `id`, at least one numeric measure to color by, and (for readable tooltips) a `name` variable. Beyond that, prep needs differ by map type.

### Choropleth / bivariate (polygon types)

- `id()` must match the topojson's feature ids exactly after zero-padding to `idwidth()`. For Texas counties that's 5-digit FIPS; pass the numeric var and sparkta2 zero-pads, or pre-format with `tostring fips, replace force format("%05.0f")`.
- One row per feature. Duplicate ids overwrite silently in the embedded JSON. Pre-aggregate with `collapse (mean) value, by(fips)`.
- Missing values render as grey (no data). Use `[if] !missing(value)` to drop them.

### Points (graduated symbols at lat/lon)

- `lat()` and `lon()` are required, in decimal degrees (WGS84). Drop missing-coord rows first: `drop if missing(lat) | missing(lon)`.
- `id()` can be ZIP, parcel id, or anything unique — it labels tooltips and powers the search box.
- The chosen `layer()` (default `counties`) still renders underneath as a faded outline so points sit on top of a recognisable backdrop.

### Hexbin

Two modes:

- **With** `lat()` / `lon()` — each row is one point and the hex aggregation runs over the lat/lon set. Used for ZIP-level data.
- **Without** `lat()` / `lon()` — the engine uses the centroid of each `layer()` feature, joined to the data row by `id()`. Used for county-level hex maps.

`hexstat()` chooses the aggregator: `mean` (default), `sum`, `median`, `count`, `min`, `max`. `count` is useful for pure-density maps.

### Categorical filters and labelled numerics

`filters(varlist)` understands two shapes: a string variable, or a numeric variable with a value label. Apply `label define` + `label values` to your category codes BEFORE calling sparkta2 — the dropdown displays the value label, not the raw number. Unlabelled numerics show as raw integers.

### Sliders

`sliders(varlist)` requires numeric variables. Range is auto-set from the variable's min/max. Constant variables (span 0) produce a single-point slider; cap and clip beforehand if needed.

### Tooltipvars

`tooltipvars(varlist)` accepts string, labelled-numeric, or plain numeric. Set a `variable label` on each var so the tooltip row gets a readable left column. Plain numerics are auto-formatted as comma-separated with 2 decimal places (or 0 decimals when abs ≥ 1000).

### Sanity checks before plotting

```stata
assert !missing(fips)            // every row has an id
isid fips                        // one row per feature for choropleth/bivariate
tab region_n, missing            // verify filter categories aren't all missing
summarize lat lon                // decimal degrees, not radians
```

## Working outside Texas

`sparkta2` is Texas-centric in defaults, but the engine is geography-agnostic. Two paths:

### 1. Use the bundled topojson at a different layer

`texas_counties.topojson` actually contains three layers:

| `layer()` | Features | Id format | `idwidth()` |
|---|---|---|---|
| `counties` (default) | 254 Texas counties | 5-digit FIPS | 5 |
| `states` | 56 US states + DC + territories | 2-digit FIPS | 2 |
| `nation` | 1 US outline (no data attached) | — | — |

So an all-US 50-state choropleth needs **no new data file** — just supply 2-digit state FIPS in `id()` and pass `layer(states) idwidth(2)`. Examples 6 and 7 in the help file (and #19, #20 in `test_sparkta2_map.do`) do exactly this.

### 2. Add a new geography

Drop a `<geo>_counties.topojson` next to the ado files and pass `geo(<geo>)`. The file should be a TopoJSON (not GeoJSON) with at least one object. Standard pipeline:

1. Source a shapefile (US Census TIGER for US geographies; [Natural Earth](https://www.naturalearthdata.com/) or [GADM](https://gadm.org/) for international).
2. Convert to TopoJSON with [mapshaper](https://mapshaper.org) (has a GUI: drop the shapefile, "Export" as TopoJSON, pick quantization 1e5) or [topojson-server](https://github.com/topojson/topojson-server).
3. In mapshaper, set the **id** attribute on each feature to whatever you'll pass in `id()` (e.g., `GEOID` for US Census features). Pre-pad it to the width you'll use with `idwidth()`.
4. Save as `<geo>_counties.topojson` next to `sparkta2_engine.js`, then re-run `adopath ++ "<that dir>"`.

If you want a custom basemap, include `states` (admin1/regions) and `nation` (country outline) objects in the same topojson; `basemap` will pick them up automatically.

## Projection: Texas-tuned Albers and how to override it

sparkta2 picks one of three projection presets by default and exposes the full d3 projection tunables (`rotate`, `parallels`, `center`) for fine control. The defaults are calibrated for a flat Texas panhandle — but readers running the same code may see slightly different tilt depending on their `geo()`, `layer()`, and sparkta2 version. This section explains why and what to do about it.

### Defaults and what they look like

| `geo()` / `layer()` | preset | rotate | parallels | center |
|---|---|---|---|---|
| `geo(texas)` (counties / districts / hexbin / points) | **albers_tx** | `[101.5, 0]` | `[27.5, 36.5]` | `[0, 31.5]` |
| `geo(us)` *or any* `layer(states\|nation)` | **albers_usa** | composite (AK/HI insets) | composite | composite |
| any other `geo()` | **albers_usa** | composite | composite | composite |

`albers_tx` is a Texas-tuned d3.geoAlbers — a single non-composite Albers conic with parameters chosen so the panhandle top edge renders horizontally flat. `albers_usa` is d3's composite that ships AK and HI as insets and centers CONUS near Kansas; it's the right call for multi-state maps but renders Texas-only viewports with a noticeable downward lean on the panhandle's top edge.

### Why the v0.7.8 retuning

| Version | preset | rotate | parallels | Panhandle top lean |
|---|---|---|---|---|
| ≤ v0.6.0 (`geo(texas)` was using `albers_usa`) | composite | `[-96, 0]` (CONUS-tuned) | `[29.5, 45.5]` | ~3.3° |
| v0.6.1 – v0.7.7 (`albers_tx` first cut) | `albers_tx` | `[99, 0]` | `[27.5, 35.5]` | ~1.3° |
| **v0.7.8** (`albers_tx` retune) | `albers_tx` | **`[101.5, 0]`** | **`[27.5, 36.5]`** | **0.0°** |

### The geometry

In an Albers conic, lines of constant latitude render as **circular arcs centered on the cone apex** — not as straight horizontal lines. Two settings control whether any given latitude line slopes on the rendered map:

1. The **central meridian** (set by `rotate(λ)`) determines where the arc peaks. For the arc between two endpoints to render as a horizontal chord, the central meridian must sit at the **longitudinal midpoint** of those endpoints.
2. The **standard parallels** (set by `parallels(φ1 φ2)`) mark where the projection is conformal (zero N-S distortion). Placing a parallel exactly at the latitude you want to render flat makes that latitude line conformal.

The Texas panhandle's top edge runs from `–103°W` to `–100°W` at `36.5°N`. Midpoint: **`–101.5°W`**. Latitude: **`36.5°N`**. Those are the v0.7.8 `albers_tx` values exactly — that's where the flat panhandle comes from.

### Trade-off

Shifting the central meridian 2.5° west of the state's longitudinal centroid (`–99.5°W`) means **East Texas** longitude lines tilt slightly more from vertical — Sabine Pass (`–93.5°W`) now sits 8° east of the central meridian instead of the 5.5° it sat at under the v0.6.1 tuning. At Texas scale this is visually negligible, but if you place an `albers_usa` Texas render alongside the v0.7.8 `albers_tx` one you'll see East Texas counties subtly rotated.

If a flat panhandle isn't important to your use case — you want minimal shear across the whole state, or you're matching another atlas — use one of the escape hatches.

### Escape hatches

```stata
* Restore the v0.6.1 tuning (panhandle ~1.3° lean, less East Texas shear):
sparkta2 ..., geo(texas) projection(albers_tx) rotate(99) parallels(27.5 35.5)

* Restore the pre-v0.6.1 composite look (panhandle ~3.3° lean, AK/HI compatible):
sparkta2 ..., geo(texas) projection(albers_usa)

* Use plain Albers with your own tuning (no Texas-specific defaults):
sparkta2 ..., projection(albers) rotate(99) parallels(27.5 35.5) center(0 31.5)

* Use Mercator (web-tile interop; Texas gets a slight upward bulge above ~30°N):
sparkta2 ..., projection(mercator)
```

### Why your map might look tilted differently

If your panhandle top is not flat, or is tilted differently from what's shown here, check in order:

1. **`geo()` value.** `geo(texas)` picks `albers_tx`; `geo(us)` picks `albers_usa`; other geos pick `albers_usa`. Different defaults render the same data with different lean.
2. **`layer()` value.** `layer(states|nation)` overrides the geo default and forces `albers_usa` — so `geo(texas) layer(states)` is using the composite, not the Texas-tuned preset.
3. **Explicit `projection() / rotate() / parallels() / center()`** you've passed. These take precedence over the preset defaults.
4. **Installed version.** v0.5.x and earlier used `albers_usa` for every map; v0.6.1 introduced `albers_tx` with a ~1.3° residual lean; v0.7.8 retunes `albers_tx` to zero lean. Every sparkta2 map call prints a dispatcher banner like `[sparkta2 v0.7.8]` in the Stata Results window — that's the running version.

## Worked examples

These all live in [`examples/test_helpfile_examples.do`](examples/test_helpfile_examples.do) and are tested in CI-style smoke tests before each release.

### County bivariate, full UI

```stata
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate) scheme(rdbu)         ///
    modes(bivariate|x|y|diff|ratio) comparable                 ///
    filters(region_n urban) sliders(poverty_rate uninsured_rate) ///
    tooltipvars(median_income life_expect)                     ///
    swapbutton download search offline                         ///
    title("Texas counties: poverty vs uninsured")              ///
    export("01_bivariate.html")
```

### Small-multiples — three modes side by side

```stata
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate)                      ///
    modes(bivariate|diff|ratio) multiples comparable           ///
    filters(region_n) width(1300) height(620) offline          ///
    export("02_multiples.html")
```

### Subset to specific counties + auto-zoom

```stata
local big8 "48201 48029 48113 48439 48453 48141 48215 48085"
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate)                      ///
    counties("`big8'") zoomto("`big8'")                         ///
    tooltipvars(median_income pop_thou) download offline       ///
    export("03_big8.html")
```

### Hexbin

```stata
sparkta2 poverty_rate,                                         ///
    id(fips) name(county) type(hexbin) scheme(viridis)         ///
    hexradius(22) hexstat(mean) download offline               ///
    title("Mean poverty rate per hex")                         ///
    export("04_hexbin.html")
```

### Basemap

```stata
sparkta2 poverty_rate uninsured_rate,                          ///
    id(fips) name(county) type(bivariate) basemap              ///
    modes(bivariate|x|y|diff|ratio) comparable offline         ///
    export("05_basemap.html")
```

### US 50-state choropleth (works outside Texas)

```stata
* user data: 2-digit string state_fips + numeric value pop_mil
sparkta2 pop_mil,                                              ///
    id(state_fips) name(state_name) geo(texas)                 ///
    layer(states) idwidth(2)                                   ///
    type(choropleth) scheme(blues) download                    ///
    tooltipvars(gdp_thou)                                      ///
    title("US state population")                               ///
    width(1200) height(720) offline                            ///
    export("06_us_states.html")
```

### US 50-state hexbin (same data, hex variant)

```stata
sparkta2 pop_mil,                                              ///
    id(state_fips) name(state_name) geo(texas)                 ///
    layer(states) idwidth(2)                                   ///
    type(hexbin) scheme(magma) hexradius(28) hexstat(mean)     ///
    width(1200) height(720) offline                            ///
    export("07_us_states_hex.html")
```

### District choropleth on the bundled NCES boundaries

```stata
use "NCES_EDGE_Texas_District_Map.dta", clear
destring intptlat intptlon, replace force
sparkta2 frpl_pct100 students_per_teacher,                     ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)       ///
    type(bivariate) scheme(rdbu)                                ///
    filters(sdtyp_label) sliders(frpl_pct100 student_count)    ///
    tooltipvars(student_count teacher_fte school_count)        ///
    download search offline                                     ///
    export("08_districts_bivariate.html")
```

### District hexbin (centroids from `intptlat` / `intptlon`)

```stata
sparkta2 frpl_pct100,                                          ///
    id(leaid) name(name) geo(texas_districts) idwidth(7)       ///
    type(hexbin) lat(intptlat) lon(intptlon)                   ///
    hexradius(20) hexstat(mean) scheme(viridis) offline        ///
    export("09_districts_hexbin.html")
```

### Chart pass-through to sparkta

```stata
sparkta2 poverty_rate uninsured_rate, type(scatter) fit(lfit) fitci
sparkta2 poverty_rate uninsured_rate, type(bar) over(region_n) stat(mean)
```

## Folder layout

```
sparkta2/
├── ado/
│   ├── sparkta2.ado                  # dispatcher (forwards non-map/non-chart types to sparkta)
│   ├── sparkta2_map.ado              # map command
│   ├── sparkta2_chart.ado            # native chart command (donut, bar2, line2, divbar, barrace)
│   ├── sparkta2_dashboard.ado        # combine maps + charts -> one scrollable page
│   ├── sparkta2_findfile.ado         # locate engine + map assets
│   ├── sparkta2_writehtml.ado        # map HTML assembler (emits sparkta2-resize postMessage)
│   ├── sparkta2_chart_writehtml.ado  # chart HTML assembler (emits sparkta2-resize postMessage)
│   ├── sparkta2_embedjs.ado          # <script>…</script> wrapper
│   ├── sparkta2_appendfile.ado       # shell-based file embedder
│   ├── sparkta2_streamfile.ado       # line-by-line file stream
│   ├── sparkta2_open.ado             # cross-platform browser open
│   ├── sparkta2_engine.js            # D3 map engine
│   ├── sparkta2_chart_engine.js      # D3 chart engine
│   ├── sparkta2.sthlp                # Stata help
│   ├── sparkta2.pkg                  # net install manifest
│   ├── stata.toc
│   ├── d3.min.js
│   ├── topojson-client.min.js
│   ├── d3-hexbin.min.js
│   ├── texas_counties.topojson       # 254 TX counties + 56 US states + nation
│   └── texas_districts.geojson       # 1,018 NCES EDGE SY24-25 school districts
├── examples/
│   ├── test_sparkta2_map.do          # 20 county-level + 2 US-state bonus examples
│   ├── test_sparkta2_nces.do         # 20 NCES school-district examples
│   ├── test_helpfile_examples.do     # mirrors `help sparkta2` examples 1:1
│   ├── test_sparkta2_in_webdoc2.do   # 12-section webdoc2 demo (maps + charts + sparkta forwards)
│   └── texas_county_demo.csv
└── README.md
```

## Returned values

- `r(export)` — path of the written HTML
- `r(type)` — resolved map type
- `r(geo)` — resolved `geo()`
- `r(n_rows)` — number of data rows actually written

## License

MIT for `sparkta2`. `sparkta` is MIT-licensed by Fahad Mirza (refer to that repo for the canonical license). `d3-hexbin` is MIT-licensed by Mike Bostock.


<img width="1077" height="744" alt="Screenshot 2026-06-20 at 11 29 46 AM" src="https://github.com/user-attachments/assets/c73828e6-4053-424b-acf6-dd94cdec75e4" />

## See also

- [`sparkta`](https://github.com/fahad-mirza/sparkta_stata) — the chart engine this command wraps (Fahad Mirza)
- [`spmap`](https://www.stata-journal.com/article.html?article=gr0008) — Maurizio Pisati's static Stata mapping package
- [`geo2xy`](https://www.stata-journal.com/article.html?article=gr0067), [`shp2dta`](https://www.stata-journal.com/article.html?article=dm0094) — companion utilities for prepping geographic data in Stata
- Eric's other Stata packages: [github.com/ericabooth](https://github.com/ericabooth)

## Author

Eric A. Booth, Sr Researcher, Texas2036.org (eric.a.booth@gmail.com).

Mapping renderer, dispatcher, dashboard helper, and all sparkta2-specific plumbing. When called with a non-map `type()`, `sparkta2` forwards to `sparkta` — credit for those chart types belongs entirely to Fahad Mirza.
