*! sparkta2_map v0.8.0  2026-08-11
*! Choropleth / bivariate / hexbin / points map renderer for sparkta2.
*!
*! v0.8.0 additions:
*!   - dashtab(varname): higher-order tabs.  Where over() splits within a
*!     chart and by() makes small multiples, dashtab() renders one FULL map
*!     per level of the variable and puts a tab bar above the output.  Each
*!     tab can use its own geography via dashtabgeo() / dashtablayer() /
*!     dashtabidwidth() (pipe / space lists, one entry per level in levelsof
*!     order), so one HTML file can hold counties, school districts, and
*!     dissolved regions as separate tabs.  dashtabstyle(tabs|buttons).
*!   - overlays(list): checkbox-toggleable overlay layers drawn on top of
*!     the data layer.  Each token is either an object in the topojson
*!     (states, nation, ...) drawn as a boundary mesh, or a variable in the
*!     data: the focused features are DISSOLVED client-side by that
*!     variable's value (topojson.merge) and drawn as labelled group
*!     boundaries — regions over counties with no extra shapefile.
*!   - maplabels + labelsize(#): feature name labels at centroids with a
*!     Layers checkbox; label size counter-scales against zoom.
*!   - rasterimage(file) + rasterbounds(w s e n) + rasteropacity(#): embed a
*!     georeferenced image (base64 data URI, still fully offline) stretched
*!     between its projected corner coordinates, beneath the data layer.
*!     Exact in mercator; approximate under conic projections (see help).
*!
*! v0.7.8 fix:
*!   - Texas projection tilt iteration: the v0.6.1 settings
*!     (rotate=[99,0], parallels=[27.5,35.5]) reduced the panhandle lean
*!     from ~3.3 deg to ~1.3 deg but didn't eliminate it.  Updated to
*!     rotate=[101.5,0] and parallels=[27.5,36.5]:
*!       - Central meridian at -101.5 deg = midpoint of the panhandle's
*!         top edge (-103 deg W to -100 deg W).  In Albers conic, lines
*!         of latitude render as circular arcs symmetric around the
*!         central meridian, so centering the CM on the panhandle's
*!         longitudinal midpoint makes the two ends of the top edge
*!         (-103 deg W and -100 deg W) land at the same y -> the top
*!         renders horizontally flat.
*!       - Upper standard parallel at 36.5 deg N = panhandle top
*!         latitude.  A standard parallel is conformal (zero N-S
*!         distortion), so the 36.5 deg latitude line specifically gets
*!         the cleanest projection treatment.
*!     Tradeoff: shifting the central meridian 2.5 deg west adds a few
*!     degrees of N-S shear to East Texas (longitude lines tilt slightly
*!     more from vertical at Sabine Pass).  Negligible at this scale.
*!
*! v0.6.1 fix (superseded by v0.7.8 above):
*!   - First-pass Texas projection tilt fix.  d3.geoAlbersUsa() was used
*!     for every layer including geo(texas), but its CONUS-wide standard
*!     parallels (29.5N / 45.5N) and -96 rotation center the projection
*!     near Kansas.  Texas, south and west of that center, rendered with
*!     a ~3.3 degree downward lean of the panhandle's top edge.  v0.6.1
*!     introduced a Texas-tuned d3.geoAlbers() preset:
*!       - geo(texas) defaults to albers_tx (Texas-tuned d3.geoAlbers).
*!       - geo(us) / layer(states|nation) keeps d3.geoAlbersUsa() (unchanged).
*!       - New projection() option overrides the default:
*!           albers_usa | albers_tx | albers | mercator
*!       - New rotate(), parallels(), center() options let power users
*!         tune any projection numerically.
*!     Backward-compat: pass projection(albers_usa) to restore the
*!     pre-0.6.1 geo(texas) look exactly.
*!
*! v0.6.0 additions:
*!   - datatable     : add a collapsible "View data" table + CSV download
*!     to the Export menu beneath the chart.
*!   - animate       : fade map features in via an IntersectionObserver
*!     when the chart scrolls into view.
*!   - Export menu now offers PNG, SVG, "Print to PDF...", and (with the
*!     datatable option) CSV download + data-table toggle.  Replaces the
*!     prior single "Download PNG" button.  Backward-compat: passing
*!     `download' alone still emits a working menu (PNG/SVG/Print only).
*!
*! v0.5.3 fixes:
*!   - String id round-trip overflow: pad with explicit leading zeros instead
*!     of real()->%0Wf, which collapses 9+ digit ids into scientific notation
*!     (e.g. 199999999 -> " 2.0e+08") and breaks d3.index() in the engine.
*!   - filters() values tokenized on whitespace because levelsof was called
*!     with `clean` -- compound quotes preserved now.
*!   - sliders() emitted Stata `.` for all-missing variables, producing
*!     invalid JSON.  Missing min/max now write `null`.
program define sparkta2_map, rclass
    version 17.0

    syntax varlist(min=1 max=2 numeric) [if] [in], ID(varname) [  ///
        TYPE(string)                                       ///  map | bivariate | choropleth | hexbin | points
        NAME(varname)                                      ///  display name var
        GEO(string)                                        ///  texas (default)
        LAYer(string)                                      ///  topojson object: counties | states | nation | zctas | tracts | auto
        IDWIdth(integer 5)                                 ///  zero-pad width for id() values (5 for FIPS, 2 for state FIPS)
        BASEmap                                            ///  draw a faded outline layer behind the focused features
        LATvar(varname numeric)                            ///  latitude variable (points/hexbin)
        LONvar(varname numeric)                            ///  longitude variable (points/hexbin)
        HEXRadius(integer 18)                              ///  hexagon radius in svg units (hexbin only)
        HEXStat(string)                                    ///  hexbin aggregate: mean (default) | sum | median | count | min | max
        POINTSIze(integer 4)                               ///  circle radius for points
        SCHEME(string)                                     ///  rdbu | bupu | gnbu | puor | blues | reds | greens | viridis | ...
        TITLE(string) SUBtitle(string) NOTE(string)        ///
        XLABEL(string) YLABEL(string)                      ///
        FILTERS(varlist)                                   ///  categorical filter dropdowns
        SLIDERS(varlist numeric)                           ///  dual-handle range sliders
        TOOLTIPvars(varlist)                               ///  extra fields shown in tooltip data table
        COUNTies(string)                                   ///  pipe/space FIPS list to restrict to
        ZOOMTo(string)                                     ///  pipe/space FIPS list -- auto-zoom on load
        SEArch                                             ///  show name-search box
        NOZoom                                             ///  disable pan/zoom + click-to-zoom
        MODE(string)                                       ///  initial mode: bivariate | x | y | diff | ratio
        MODES(string)                                      ///  allowed modes in toggle (pipe-sep)
        COMParable                                         ///  declare x/y on comparable units
        SWAPbutton                                         ///  show swap-axes button
        DOWNload                                           ///  show export menu (PNG/SVG/Print)
        DOWNLOADPos(string)                                ///  side (default) | below | none -- Export menu placement
        DATATable                                          ///  add CSV download + collapsible data-table view
        ANIMate                                            ///  fade features in when chart scrolls into view
        TX2036STyle                                        ///  Texas 2036 brand + Montserrat font
        PROJection(string)                                 ///  albers_usa | albers_tx | albers | mercator
        ROtate(numlist max=2 min=1)                        ///  projection rotation, degrees: lambda [phi]
        PARallels(numlist max=2 min=2)                     ///  two Albers standard parallels, degrees
        CENter(numlist max=2 min=2)                        ///  projection center, degrees: lon lat
        MULTiples                                          ///  small-multiples: one panel per mode
        BINS(integer 3)                                    ///  quantile bins per axis for bivariate
        OVERlays(string)                                   ///  overlay layers: topo objects and/or dissolve-by variables
        MAPLABels                                          ///  feature name labels at centroids (Layers checkbox)
        LABELSize(integer 9)                               ///  label font size in svg px
        RASTERimage(string)                                ///  georeferenced image file to draw under the data layer
        RASTERBounds(numlist min=4 max=4)                  ///  west south east north, decimal degrees
        RASTEROpacity(real 0.75)                           ///  raster opacity 0-1
        RASTERLabel(string)                                ///  checkbox label for the raster layer
        DASHtab(varname)                                   ///  higher-order tabs: one full map per level of this var
        DASHTABGeo(string)                                 ///  pipe-sep geo() per tab, in levelsof order
        DASHTABLayer(string)                               ///  pipe-sep layer() per tab
        DASHTABIDWidth(numlist int >=1)                    ///  per-tab idwidth (space-sep)
        DASHTABStyle(string)                               ///  tabs (default) | buttons
        EXPORT(string) OFFLINE NOOPEN                      ///
        WIDTH(integer 980) HEIGHT(integer 828)             ///
    ]

    marksample touse, novarlist

    local nvar : word count `varlist'
    local xvar : word 1 of `varlist'
    local yvar : word 2 of `varlist'

    if "`geo'" == ""    local geo "texas"
    local geo = lower("`geo'")
    if "`type'" == "" {
        if `nvar' == 2 local type "bivariate"
        else           local type "choropleth"
    }
    local type = lower("`type'")
    if "`type'" == "map" {
        if `nvar' == 2 local type "bivariate"
        else           local type "choropleth"
    }
    if "`type'" == "univariate" local type "choropleth"

    * type validation
    local _valid_types "bivariate choropleth hexbin points"
    if !`:list type in _valid_types' {
        display as error "sparkta2: type(`type') not recognised."
        display as error "  Valid: bivariate, choropleth, hexbin, points (or `map' as an auto-pick)."
        exit 198
    }

    if "`type'" == "bivariate" & `nvar' != 2 {
        display as error "sparkta2: type(bivariate) needs two numeric variables"
        exit 198
    }
    if "`type'" == "choropleth" & `nvar' != 1 {
        display as error "sparkta2: type(choropleth) needs one numeric variable"
        exit 198
    }
    if "`type'" == "points" & ("`latvar'" == "" | "`lonvar'" == "") {
        display as error "sparkta2: type(points) requires lat() and lon() variables"
        exit 198
    }
    if "`hexstat'" != "" {
        local _hs = lower("`hexstat'")
        local _valid_hs "mean sum median count min max"
        if !`:list _hs in _valid_hs' {
            display as error "sparkta2: hexstat(`hexstat') not recognised (mean|sum|median|count|min|max)"
            exit 198
        }
        local hexstat "`_hs'"
    }
    else local hexstat "mean"

    if "`scheme'" == "" {
        if "`type'" == "bivariate" local scheme "rdbu"
        else                         local scheme "blues"
    }
    local scheme = lower("`scheme'")

    if "`mode'" == "" local mode = cond("`type'" == "bivariate", "bivariate", "x")
    local mode = lower("`mode'")

    if "`modes'" == "" {
        if "`type'" == "bivariate" {
            local modes "bivariate|x|y|diff|ratio"
        }
        else local modes "x"
    }

    local is_offline    = cond("`offline'"    != "", 1, 0)
    local is_swap       = cond("`swapbutton'" != "", 1, 0)
    local is_download   = cond("`download'"   != "", 1, 0)
    local is_datatable  = cond("`datatable'"  != "", 1, 0)
    local is_animate    = cond("`animate'"    != "", 1, 0)
    local is_tx2036st   = cond("`tx2036style'" != "", 1, 0)

    * downloadpos validation
    if "`downloadpos'" == "" local downloadpos "side"
    local downloadpos = lower("`downloadpos'")
    local _valid_dlpos "side below none"
    if !`:list downloadpos in _valid_dlpos' {
        display as error "sparkta2: downloadpos(`downloadpos') not recognised."
        display as error "  Valid: side | below | none"
        exit 198
    }

    local is_comparable = cond("`comparable'" != "", 1, 0)
    local is_multiples  = cond("`multiples'"  != "", 1, 0)
    local is_zoom       = cond("`nozoom'"     != "", 0, 1)
    local is_search     = cond("`search'"     != "", 1, 0)

    * Projection preset validation.  Empty string means "use the default,
    * which depends on geo()/layer()".  The engine knows the defaults.
    if "`projection'" != "" {
        local _proj = lower("`projection'")
        local _valid_proj "albers_usa albers_tx albers mercator"
        if !`:list _proj in _valid_proj' {
            display as error "sparkta2: projection(`projection') not recognised."
            display as error "  Valid: albers_usa | albers_tx | albers | mercator"
            exit 198
        }
        local projection "`_proj'"
    }
    * Numeric override packing: each numlist becomes a pipe-joined string so
    * the JSON writer can emit it verbatim.  Empty means "use the preset's
    * default values".
    local _rot_str ""
    if "`rotate'" != "" {
        foreach _v of numlist `rotate' {
            if "`_rot_str'" == "" local _rot_str "`_v'"
            else                  local _rot_str "`_rot_str'|`_v'"
        }
    }
    local _par_str ""
    if "`parallels'" != "" {
        foreach _v of numlist `parallels' {
            if "`_par_str'" == "" local _par_str "`_v'"
            else                  local _par_str "`_par_str'|`_v'"
        }
    }
    local _ctr_str ""
    if "`center'" != "" {
        foreach _v of numlist `center' {
            if "`_ctr_str'" == "" local _ctr_str "`_v'"
            else                  local _ctr_str "`_ctr_str'|`_v'"
        }
    }
    local is_basemap    = cond("`basemap'"    != "", 1, 0)

    if "`title'" == "" {
        if "`type'" == "bivariate" local title "Bivariate map: `xvar' vs `yvar'"
        else if "`type'" == "hexbin" local title "Hexbin: `xvar'"
        else if "`type'" == "points" local title "Points: `xvar'"
        else local title "Choropleth: `xvar'"
    }

    if "`layer'" != "" local layer = lower("`layer'")

    if "`export'" == "" {
        local export "`c(pwd)'/sparkta2_`type'_`geo'.html"
    }

    * Parse counties() and zoomto() FIPS lists.
    local _cty_keep_sp ""
    local _cty_keep_set 0
    if "`counties'" != "" {
        local _ctmp = subinstr("`counties'", "|", " ", .)
        local _ctmp = itrim("`_ctmp'")
        foreach _fc of local _ctmp {
            * Mirror the row-loop padding logic exactly (see lines 175-210),
            * so counties() list entries match the formatted row ids 1:1.
            local _fc_p = "`_fc'"
            if strlen("`_fc_p'") < `idwidth' {
                capture local _rn = real("`_fc_p'")
                if !_rc & "`_fc_p'" != "." & !missing(`_rn') {
                    local _padlen = `idwidth' - strlen("`_fc_p'")
                    local _zeros = ""
                    forvalues _z = 1/`_padlen' {
                        local _zeros = "0`_zeros'"
                    }
                    local _fc_p = "`_zeros'`_fc_p'"
                }
            }
            local _cty_keep_sp "`_cty_keep_sp' `_fc_p'"
        }
        local _cty_keep_sp = strtrim("`_cty_keep_sp'")
        local _cty_keep_set 1
    }
    * zoomto() tokens are passed RAW (pipe-joined): the engine zero-pads each
    * one with the ACTIVE tab's idwidth before matching feature ids, so one
    * list works across dashtab() tabs with different id widths.  (Padding
    * here with the global idwidth broke matching on any tab whose
    * dashtabidwidth() differed.)
    local _zoomto_list ""
    if "`zoomto'" != "" {
        local _ztmp = subinstr("`zoomto'", "|", " ", .)
        local _ztmp = itrim("`_ztmp'")
        foreach _fc of local _ztmp {
            if "`_zoomto_list'" == "" local _zoomto_list "`_fc'"
            else                       local _zoomto_list "`_zoomto_list'|`_fc'"
        }
    }

    * ---- dashtab: build tab specs (v0.8.0) --------------------------------
    * A plain call is one tab with no filter; dashtab(varname) makes one tab
    * per level.  Both run the identical row/meta/render pipeline below.
    if "`dashtabstyle'" == "" local dashtabstyle "tabs"
    local dashtabstyle = lower("`dashtabstyle'")
    if !inlist("`dashtabstyle'", "tabs", "buttons") {
        display as error "sparkta2: dashtabstyle(`dashtabstyle') not recognised (tabs | buttons)"
        exit 198
    }
    local _ntabs 1
    local _dt_is_str 0
    if "`dashtab'" != "" {
        if `_cty_keep_set' {
            display as error "sparkta2: counties() cannot be combined with dashtab() — one FIPS list cannot apply across aggregation levels.  Use [if] instead."
            exit 198
        }
        capture confirm string variable `dashtab'
        local _dt_is_str = (_rc == 0)
        local _dt_vallab ""
        if !`_dt_is_str' local _dt_vallab : value label `dashtab'
        quietly levelsof `dashtab' if `touse', local(_dtlevels)
        local _ntabs : word count `_dtlevels'
        if `_ntabs' < 2 {
            display as error "sparkta2: dashtab(`dashtab') has only `_ntabs' level on the active sample — need at least 2 tabs"
            exit 198
        }
        if `_ntabs' > 10 {
            display as error "sparkta2: dashtab(`dashtab') has `_ntabs' levels — more than 10 tabs is unusable.  Recode the variable."
            exit 198
        }
        local _k 0
        foreach _lv of local _dtlevels {
            local ++_k
            local _dtval_`_k' `"`_lv'"'
            if `_dt_is_str' local _dtlab_`_k' `"`_lv'"'
            else {
                if "`_dt_vallab'" != "" {
                    local _dtlab_`_k' : label `_dt_vallab' `_lv'
                }
                else local _dtlab_`_k' "`_lv'"
            }
            * "|" is the tab-list separator downstream — swap it out of labels
            local _dtlab_`_k' : subinstr local _dtlab_`_k' "|" "/", all
        }
    }

    * The per-tab modifiers only mean something with dashtab(); silently
    * applying dashtabgeo() etc. to a single-tab map would mask user error.
    if "`dashtab'" == "" & "`dashtabgeo'`dashtablayer'`dashtabidwidth'" != "" {
        display as error "sparkta2: dashtabgeo()/dashtablayer()/dashtabidwidth() require dashtab()"
        exit 198
    }

    * Per-tab geo / layer / idwidth: pipe (geo, layer) or space (idwidth)
    * lists in levelsof order; empty entries fall back to the global option.
    forvalues _t = 1/`_ntabs' {
        local _tgeo_`_t' "`geo'"
        local _tlayer_`_t' "`layer'"
        local _tidw_`_t' "`idwidth'"
    }
    if "`dashtabgeo'" != "" {
        local _rest "`dashtabgeo'"
        local _t 0
        while "`_rest'" != "" & `_t' < `_ntabs' {
            local ++_t
            local _pp = strpos("`_rest'", "|")
            if `_pp' > 0 {
                local _piece = substr("`_rest'", 1, `_pp' - 1)
                local _rest  = substr("`_rest'", `_pp' + 1, .)
            }
            else {
                local _piece "`_rest'"
                local _rest ""
            }
            if "`_piece'" != "" local _tgeo_`_t' = lower(strtrim("`_piece'"))
        }
    }
    if "`dashtablayer'" != "" {
        local _rest "`dashtablayer'"
        local _t 0
        while "`_rest'" != "" & `_t' < `_ntabs' {
            local ++_t
            local _pp = strpos("`_rest'", "|")
            if `_pp' > 0 {
                local _piece = substr("`_rest'", 1, `_pp' - 1)
                local _rest  = substr("`_rest'", `_pp' + 1, .)
            }
            else {
                local _piece "`_rest'"
                local _rest ""
            }
            if "`_piece'" != "" local _tlayer_`_t' = lower(strtrim("`_piece'"))
        }
    }
    if "`dashtabidwidth'" != "" {
        forvalues _t = 1/`_ntabs' {
            local _w = word("`dashtabidwidth'", `_t')
            if "`_w'" != "" local _tidw_`_t' "`_w'"
        }
    }

    * ---- Resolve engine + per-tab geography assets ------------------------
    forvalues _t = 1/`_ntabs' {
        quietly sparkta2_findfile, geo("`_tgeo_`_t''")
        local _ttopo_`_t' "`r(topopath)'"
        if `_t' == 1 {
            local engpath "`r(engpath)'"
            local d3path  "`r(d3path)'"
            local tcpath  "`r(tcpath)'"
            local hxpath  "`r(hxpath)'"
        }
    }

    * ---- overlays(): classify tokens (v0.8.0) -----------------------------
    * A token that names a variable in memory becomes a dissolve-by overlay
    * (the engine merges focused features sharing that variable's value);
    * anything else is treated as a topojson object name (states, nation, ...)
    * drawn as a boundary mesh.
    local _n_ov 0
    local _ov_gvars ""
    if "`overlays'" != "" {
        foreach _ov of local overlays {
            local ++_n_ov
            * exact: without it, varabbrev reclassifies an intended topo
            * object token (states, nation) as a dissolve variable whenever
            * some variable in memory abbreviates to it (e.g. nationalrank).
            capture confirm variable `_ov', exact
            if !_rc {
                local _ovkind_`_n_ov' "groupvar"
                local _ovkey_`_n_ov' "`_ov'"
                local _lbl : variable label `_ov'
                if `"`_lbl'"' == "" local _lbl "`_ov' boundaries"
                local _ovlab_`_n_ov' `"`_lbl'"'
                local _ov_gvars "`_ov_gvars' `_ov'"
            }
            else {
                local _ovkind_`_n_ov' "object"
                local _ovkey_`_n_ov' = lower("`_ov'")
                local _ovlab_`_n_ov' = strproper("`_ov'") + " outline"
            }
        }
        local _ov_gvars = strtrim("`_ov_gvars'")
    }

    * ---- rasterimage(): base64-embed a georeferenced image (v0.8.0) -------
    local _has_raster 0
    if "`rasterimage'" != "" {
        capture confirm file `"`rasterimage'"'
        if _rc {
            display as error `"sparkta2: rasterimage(`rasterimage') not found"'
            exit 601
        }
        if "`rasterbounds'" == "" {
            display as error "sparkta2: rasterimage() requires rasterbounds(west south east north) in decimal degrees"
            exit 198
        }
        if `rasteropacity' < 0 | `rasteropacity' > 1 {
            display as error "sparkta2: rasteropacity() must be between 0 and 1"
            exit 198
        }
        capture python query
        if _rc {
            display as error "sparkta2: rasterimage() needs Stata's Python integration to base64-encode the image; see {help python}"
            exit 198
        }
        local _rb_w : word 1 of `rasterbounds'
        local _rb_s : word 2 of `rasterbounds'
        local _rb_e : word 3 of `rasterbounds'
        local _rb_n : word 4 of `rasterbounds'
        if !(`_rb_w' < `_rb_e' & `_rb_s' < `_rb_n') {
            display as error "sparkta2: rasterbounds() must be west south east north with west < east and south < north"
            exit 198
        }
        quietly checksum `"`rasterimage'"'
        if r(filelen) > 20000000 {
            display as error "sparkta2: rasterimage() file is > 20 MB — downscale it first (the image is embedded base64 into the HTML)"
            exit 198
        }
        if r(filelen) > 2000000 {
            display as txt "  sparkta2: note — rasterimage() is `=strofreal(r(filelen)/1048576, "%4.1f")' MB; the HTML grows by ~4/3 of that"
        }
        if `"`rasterlabel'"' == "" {
            local rasterlabel = substr(`"`rasterimage'"', strrpos(`"`rasterimage'"', "/") + 1, .)
        }
        * Base64-encode via a generated python script.  A `python:' block
        * cannot live inside a program body (its `end' terminates the ado
        * loader's program parse), and a module-level block would drag
        * Python in at load time for everyone — `python script' keeps the
        * dependency lazy: only rasterimage() callers ever touch Python.
        tempfile rasterb64 _pybase
        local pyscript "`_pybase'.py"
        tempname pyf
        file open `pyf' using "`pyscript'", write text replace
        file write `pyf' "import base64, os, sys" _n
        file write `pyf' "src, dst = sys.argv[1], sys.argv[2]" _n
        file write `pyf' `"ext = os.path.splitext(src)[1].lower().lstrip(".")"' _n
        file write `pyf' `"mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg","' _n
        file write `pyf' `"        "gif": "image/gif", "webp": "image/webp"}.get(ext, "image/png")"' _n
        file write `pyf' `"b64 = base64.b64encode(open(src, "rb").read()).decode("ascii")"' _n
        file write `pyf' `"open(dst, "w").write("data:" + mime + ";base64," + b64)"' _n
        file close `pyf'
        python script "`pyscript'", args(`"`rasterimage'"' `"`rasterb64'"')
        capture erase "`pyscript'"
        local _has_raster 1
    }
    local is_maplabels = cond("`maplabels'" != "", 1, 0)

    tempname rfh

    local filt_vars `"`filters'"'
    local slid_vars `"`sliders'"'
    local tip_vars  `"`tooltipvars'"'

    * Determine if id var is string or numeric -- shapes the padding logic
    capture confirm string variable `id'
    local _id_is_string = (_rc == 0)

    * ---- Per-tab row + meta JSON (v0.8.0: one pass per dashtab level; a
    * ---- plain call is a single pass with no tab filter) ------------------
    local _tabrowjsons ""
    local _tabmetajsons ""
    local _tabtopopaths ""
    local _tabgeos ""
    local _tablayers ""
    local _tabidwidths ""
    local _tablabels ""
    local _rows_total 0

    forvalues _t = 1/`_ntabs' {
        local _tidw "`_tidw_`_t''"

        tempfile rowjson_`_t'
        file open `rfh' using "`rowjson_`_t''", write text replace

        local _first 1
        local _rows_written 0
        quietly {
            forvalues _i = 1/`=_N' {
                if !`touse'[`_i'] continue
                * dashtab filter: this pass keeps only the rows on this tab.
                if `_ntabs' > 1 {
                    if `_dt_is_str' {
                        local _dtv = `dashtab'[`_i']
                        if `"`_dtv'"' != `"`_dtval_`_t''"' continue
                    }
                    else {
                        if `dashtab'[`_i'] != `_dtval_`_t'' continue
                    }
                }
                * Build a padded string id matching this tab's idwidth.
                * Padding uses explicit leading-zero prefixing rather than the
                * real()->display %0Wf round-trip: that idiom silently overflows
                * to scientific notation (" 2.0e+08") for any numeric value past
                * ~10^8, collapsing distinct 9-digit ids into one string and
                * breaking d3.index() with duplicate-key errors downstream.
                if `_id_is_string' {
                    local _idraw = `id'[`_i']
                    local _fid = "`_idraw'"
                    * Empty / "." string ids mirror the numeric-missing skip
                    * below: they can never join a feature, and once the
                    * engine zero-pads them they collapse into duplicate
                    * "00000" keys that crash d3.index().
                    if trim("`_fid'") == "" | "`_fid'" == "." continue
                    * Pad with leading zeros only if shorter than idwidth -- and
                    * only when the raw value is numeric-looking (FIPS-style).
                    * Already-padded or long string ids are written verbatim.
                    if strlen("`_fid'") < `_tidw' {
                        capture local _rn = real("`_fid'")
                        if !_rc & "`_fid'" != "." & !missing(`_rn') {
                            local _padlen = `_tidw' - strlen("`_fid'")
                            local _zeros = ""
                            forvalues _z = 1/`_padlen' {
                                local _zeros = "0`_zeros'"
                            }
                            local _fid = "`_zeros'`_fid'"
                        }
                    }
                }
                else {
                    local _idnum = `id'[`_i']
                    if missing(`_idnum') continue
                    * Format with width 19 (max int64 digits) then strip the
                    * leading sign-padding spaces.  Avoids the `display %0Wf`
                    * scientific-notation overflow on values past ~10^8 that
                    * the legacy idiom triggered.
                    local _fid : display %19.0f `_idnum'
                    local _fid = strtrim("`_fid'")
                    if strlen("`_fid'") < `_tidw' {
                        local _padlen = `_tidw' - strlen("`_fid'")
                        local _zeros = ""
                        forvalues _z = 1/`_padlen' {
                            local _zeros = "0`_zeros'"
                        }
                        local _fid = "`_zeros'`_fid'"
                    }
                }

                if `_cty_keep_set' {
                    if !`:list _fid in _cty_keep_sp' continue
                }

                local _xv = `xvar'[`_i']
                local _yv .
                if "`yvar'" != "" local _yv = `yvar'[`_i']

                local _nm "`_fid'"
                if "`name'" != "" {
                    capture confirm string variable `name'
                    if !_rc {
                        local _nm = `name'[`_i']
                    }
                    else {
                        capture local _nm : display `name'[`_i']
                    }
                    if "`_nm'" == "" local _nm "`_fid'"
                }
                local _nm : subinstr local _nm `"\"' `"\\"', all
                local _nm : subinstr local _nm `"""' `"\""', all

                if `_first' local _first 0
                else file write `rfh' "," _n

                file write `rfh' "        {"
                file write `rfh' `""id":"`_fid'""'
                file write `rfh' `","name":"`macval(_nm)'""'

                if missing(`_xv') file write `rfh' `","x":null"'
                else              file write `rfh' `","x":"' (`_xv')

                if "`yvar'" != "" {
                    if missing(`_yv') file write `rfh' `","y":null"'
                    else              file write `rfh' `","y":"' (`_yv')
                }

                if "`latvar'" != "" {
                    local _ltv = `latvar'[`_i']
                    if missing(`_ltv') file write `rfh' `","lat":null"'
                    else                file write `rfh' `","lat":"' (`_ltv')
                }
                if "`lonvar'" != "" {
                    local _lnv = `lonvar'[`_i']
                    if missing(`_lnv') file write `rfh' `","lon":null"'
                    else                file write `rfh' `","lon":"' (`_lnv')
                }

                foreach _fv of local filt_vars {
                    local _val ""
                    capture confirm string variable `_fv'
                    if !_rc {
                        local _val = `_fv'[`_i']
                    }
                    else {
                        local _lab : value label `_fv'
                        local _num = `_fv'[`_i']
                        if "`_lab'" != "" & !missing(`_num') {
                            local _val : label `_lab' `_num'
                        }
                        else if missing(`_num') {
                            local _val ""
                        }
                        else {
                            local _val = strofreal(`_num')
                        }
                    }
                    local _val : subinstr local _val `"\"' `"\\"', all
                    local _val : subinstr local _val `"""' `"\""', all
                    file write `rfh' `","f__`_fv'":"`macval(_val)'""'
                }
                foreach _sv of local slid_vars {
                    local _snum = `_sv'[`_i']
                    if missing(`_snum') file write `rfh' `","s__`_sv'":null"'
                    else                file write `rfh' `","s__`_sv'":"' (`_snum')
                }
                * v0.8.0 dissolve-by overlay group values (same display logic
                * as filters: string verbatim, value label when present).
                foreach _gv of local _ov_gvars {
                    local _val ""
                    capture confirm string variable `_gv'
                    if !_rc {
                        local _val = `_gv'[`_i']
                    }
                    else {
                        local _lab : value label `_gv'
                        local _num = `_gv'[`_i']
                        if "`_lab'" != "" & !missing(`_num') {
                            local _val : label `_lab' `_num'
                        }
                        else if missing(`_num') {
                            local _val ""
                        }
                        else {
                            local _val = strofreal(`_num')
                        }
                    }
                    local _val : subinstr local _val `"\"' `"\\"', all
                    local _val : subinstr local _val `"""' `"\""', all
                    file write `rfh' `","o__`_gv'":"`macval(_val)'""'
                }
                foreach _tv of local tip_vars {
                    capture confirm string variable `_tv'
                    local _isstr = (_rc == 0)
                    if `_isstr' {
                        local _tval = `_tv'[`_i']
                        local _tval : subinstr local _tval `"\"' `"\\"', all
                        local _tval : subinstr local _tval `"""' `"\""', all
                        file write `rfh' `","t__`_tv'":"`macval(_tval)'""'
                    }
                    else {
                        local _tnum = `_tv'[`_i']
                        local _tlab : value label `_tv'
                        if "`_tlab'" != "" & !missing(`_tnum') {
                            local _tdsp : label `_tlab' `_tnum'
                            local _tdsp : subinstr local _tdsp `"\"' `"\\"', all
                            local _tdsp : subinstr local _tdsp `"""' `"\""', all
                            file write `rfh' `","t__`_tv'":"`macval(_tdsp)'""'
                        }
                        else if missing(`_tnum') {
                            file write `rfh' `","t__`_tv'":null"'
                        }
                        else {
                            file write `rfh' `","t__`_tv'":"' (`_tnum')
                        }
                    }
                }

                file write `rfh' "}" _n
                local ++_rows_written
            }
        }
        file close `rfh'

        if `_rows_written' == 0 {
            if `_ntabs' > 1 {
                display as error `"sparkta2: no rows to plot on dashtab() tab `_t' ("`_dtlab_`_t''") — check [if]/[in] and `dashtab'"'
            }
            else {
                display as error "sparkta2: no rows to plot (check [if]/[in], counties(), or filter expressions)"
            }
            exit 459
        }
        local _rows_total = `_rows_total' + `_rows_written'

        * Restrict the meta-JSON scans (filter levels, slider ranges) to the
        * rows on this tab so each tab's controls match its own data.
        local _tcond ""
        if `_ntabs' > 1 {
            if `_dt_is_str' local _tcond `" & `dashtab' == `"`_dtval_`_t''"'"'
            else            local _tcond " & `dashtab' == `_dtval_`_t''"
        }

        tempfile metajson_`_t'
        file open `rfh' using "`metajson_`_t''", write text replace
        file write `rfh' "{"
        file write `rfh' `""filters":["'
        local _fcount = 0
        foreach _fv of local filt_vars {
            if `_fcount' > 0 file write `rfh' ","
            local ++_fcount
            local _lbl : variable label `_fv'
            if "`_lbl'" == "" local _lbl "`_fv'"
            local _lbl : subinstr local _lbl `"\"' `"\\"', all
            local _lbl : subinstr local _lbl `"""' `"\""', all
            file write `rfh' `"{"var":"`_fv'","label":"`macval(_lbl)'","values":["'
            * Drop the `clean' option: it strips the compound quotes that
            * levelsof wraps multi-word string values in, so values like
            * "Middle / Jr. High" survive as a single token through foreach.
            quietly levelsof `_fv' if `touse' `_tcond', local(_levels)
            local _lvi 0
            foreach _lv of local _levels {
                if `_lvi' > 0 file write `rfh' ","
                local ++_lvi
                capture confirm string variable `_fv'
                if _rc {
                    local _lab : value label `_fv'
                    if "`_lab'" != "" {
                        local _disp : label `_lab' `_lv'
                    }
                    else local _disp "`_lv'"
                }
                else local _disp `"`_lv'"'
                local _disp : subinstr local _disp `"\"' `"\\"', all
                local _disp : subinstr local _disp `"""' `"\""', all
                file write `rfh' `""`macval(_disp)'""'
            }
            file write `rfh' "]}"
        }
        file write `rfh' `"],"sliders":["'
        local _scount = 0
        foreach _sv of local slid_vars {
            quietly summarize `_sv' if `touse' `_tcond', meanonly
            local _lo = r(min)
            local _hi = r(max)
            * If the variable has no observed range (all-missing on `touse'),
            * skip the slider rather than emit Stata's `.' as bare JSON (which
            * would cause the JS parser to bail and the map to render blank).
            if missing(`_lo') | missing(`_hi') {
                display as txt "sparkta2: sliders(`_sv') has no observed range -- skipped"
                continue
            }
            if `_scount' > 0 file write `rfh' ","
            local ++_scount
            local _lbl : variable label `_sv'
            if "`_lbl'" == "" local _lbl "`_sv'"
            local _lbl : subinstr local _lbl `"\"' `"\\"', all
            local _lbl : subinstr local _lbl `"""' `"\""', all
            file write `rfh' `"{"var":"`_sv'","label":"`macval(_lbl)'","min":"' (`_lo') `","max":"' (`_hi') `"}"'
        }
        file write `rfh' `"],"tooltipvars":["'
        local _tcount = 0
        foreach _tv of local tip_vars {
            if `_tcount' > 0 file write `rfh' ","
            local ++_tcount
            local _lbl : variable label `_tv'
            if "`_lbl'" == "" local _lbl "`_tv'"
            local _lbl : subinstr local _lbl `"\"' `"\\"', all
            local _lbl : subinstr local _lbl `"""' `"\""', all
            capture confirm numeric variable `_tv'
            local _isnum = (_rc == 0)
            local _tlabname : value label `_tv'
            local _numfmt = cond(`_isnum' & "`_tlabname'" == "", 1, 0)
            file write `rfh' `"{"var":"`_tv'","label":"`macval(_lbl)'","numeric":`_numfmt'}"'
        }
        file write `rfh' `"]"'
        * v0.8.0 overlay specs: [{kind, key, label}, ...]
        file write `rfh' `","overlays":["'
        forvalues _o = 1/`_n_ov' {
            if `_o' > 1 file write `rfh' ","
            local _olb `"`_ovlab_`_o''"'
            local _olb : subinstr local _olb `"\"' `"\\"', all
            local _olb : subinstr local _olb `"""' `"\""', all
            file write `rfh' `"{"kind":"`_ovkind_`_o''","key":"`_ovkey_`_o''","label":"`macval(_olb)'"}"'
        }
        file write `rfh' `"]"'
        * v0.8.0 raster layer: bounds + opacity + base64 data URI.
        if `_has_raster' {
            local _rlb `"`rasterlabel'"'
            local _rlb : subinstr local _rlb `"\"' `"\\"', all
            local _rlb : subinstr local _rlb `"""' `"\""', all
            file write `rfh' `","raster":{"bounds":[`_rb_w',`_rb_s',`_rb_e',`_rb_n'],"opacity":`rasteropacity',"label":"`macval(_rlb)'","href":""'
            sparkta2_appendfile, fh(`rfh') path("`rasterb64'") outpath("`metajson_`_t''")
            file write `rfh' `""}"'
        }
        file write `rfh' "}"
        file close `rfh'

        * Accumulate the per-tab pipe/space lists for the HTML writer.
        if `_t' == 1 {
            local _tabrowjsons  "`rowjson_`_t''"
            local _tabmetajsons "`metajson_`_t''"
            local _tabtopopaths "`_ttopo_`_t''"
            local _tabgeos      "`_tgeo_`_t''"
            local _tablayers    "`_tlayer_`_t''"
            local _tabidwidths  "`_tidw_`_t''"
            local _tablabels    `"`macval(_dtlab_`_t')'"'
        }
        else {
            local _tabrowjsons  "`_tabrowjsons'|`rowjson_`_t''"
            local _tabmetajsons "`_tabmetajsons'|`metajson_`_t''"
            local _tabtopopaths "`_tabtopopaths'|`_ttopo_`_t''"
            local _tabgeos      "`_tabgeos'|`_tgeo_`_t''"
            local _tablayers    "`_tablayers'|`_tlayer_`_t''"
            local _tabidwidths  "`_tabidwidths' `_tidw_`_t''"
            local _tablabels    `"`macval(_tablabels)'|`macval(_dtlab_`_t')'"'
        }
    }

    sparkta2_writehtml,                                    ///
        engpath("`engpath'")                                ///
        d3path("`d3path'") tcpath("`tcpath'")               ///
        hxpath("`hxpath'")                                  ///
        ntabs(`_ntabs')                                     ///
        tabrowjsons("`_tabrowjsons'")                       ///
        tabmetajsons("`_tabmetajsons'")                     ///
        tabtopopaths("`_tabtopopaths'")                     ///
        tabgeos("`_tabgeos'") tablayers("`_tablayers'")     ///
        tabidwidths("`_tabidwidths'")                       ///
        tablabels(`"`macval(_tablabels)'"')                 ///
        tabstyle("`dashtabstyle'")                          ///
        islabels(`is_maplabels') labelsize(`labelsize')     ///
        export(`"`export'"') isoffline(`is_offline')        ///
        type("`type'") scheme("`scheme'") title(`"`title'"') ///
        hexradius(`hexradius') hexstat("`hexstat'")         ///
        pointsize(`pointsize')                              ///
        latvar("`latvar'") lonvar("`lonvar'")               ///
        subtitle(`"`subtitle'"') note(`"`note'"')           ///
        xlabel(`"`xlabel'"') ylabel(`"`ylabel'"')           ///
        xvar("`xvar'") yvar("`yvar'")                       ///
        mode("`mode'") modes("`modes'")                     ///
        zoomto("`_zoomto_list'")                            ///
        isswap(`is_swap') isdownload(`is_download')         ///
        isdatatable(`is_datatable') isanimate(`is_animate') ///
        istx2036style(`is_tx2036st') downloadpos("`downloadpos'") ///
        iscomparable(`is_comparable') ismultiples(`is_multiples') ///
        iszoom(`is_zoom') issearch(`is_search')             ///
        isbasemap(`is_basemap')                             ///
        projection("`projection'") rotatestr("`_rot_str'")  ///
        parallelsstr("`_par_str'") centerstr("`_ctr_str'")  ///
        bins(`bins')                                         ///
        width(`width') height(`height')

    display as text _n "[sparkta2 v0.8.0]  `type' map written:"
    display as text `"  {browse "`export'":`export'}"'
    display as text "  Rows: `_rows_total'  Geo: `_tabgeos'  Scheme: `scheme'  Mode: `mode'"
    if `_ntabs' > 1 {
        display as text `"  Tabs: `_ntabs' (`dashtab') — `macval(_tablabels)'"'
    }

    return local export "`export'"
    return local type   "`type'"
    return local geo    "`geo'"
    return scalar n_rows = `_rows_total'
    return scalar n_tabs = `_ntabs'

    if "`noopen'" == "" {
        sparkta2_open, file(`"`export'"')
    }
end
