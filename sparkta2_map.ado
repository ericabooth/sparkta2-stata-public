*! sparkta2_map v0.7.7  2026-06-26
*! Choropleth / bivariate / hexbin / points map renderer for sparkta2.
*!
*! v0.6.1 fixes:
*!   - Texas projection tilt: d3.geoAlbersUsa() was used for every layer
*!     including geo(texas), but its CONUS-wide standard parallels
*!     (29.5N / 45.5N) and -96 rotation center the projection near
*!     Kansas.  Texas, south and west of that center, rendered with a
*!     ~3.3 degree downward lean of the panhandle's top edge.  Now:
*!       - geo(texas)   defaults to a Texas-tuned d3.geoAlbers()
*!                      (rotate=[99,0], center=[0,31.5], parallels=[27.5,35.5])
*!         which drops the panhandle lean to ~1.3 degrees.
*!       - geo(us) / layer(states|nation) keeps d3.geoAlbersUsa() (unchanged).
*!       - New projection() option overrides the default:
*!           albers_usa | albers_tx | albers | mercator
*!       - New rotate(), parallels(), center() options let power users
*!         tune any projection numerically.
*!     Backward-compat: pass projection(albers_usa) to restore the old
*!     geo(texas) look exactly.
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

    quietly sparkta2_findfile, geo("`geo'")
    local topopath  "`r(topopath)'"
    local engpath   "`r(engpath)'"
    local d3path    "`r(d3path)'"
    local tcpath    "`r(tcpath)'"
    local hxpath    "`r(hxpath)'"

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
    local _zoomto_list ""
    if "`zoomto'" != "" {
        local _ztmp = subinstr("`zoomto'", "|", " ", .)
        local _ztmp = itrim("`_ztmp'")
        foreach _fc of local _ztmp {
            * Same padding rule as the counties() and row-loop paths.
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
            if "`_zoomto_list'" == "" local _zoomto_list "`_fc_p'"
            else                       local _zoomto_list "`_zoomto_list'|`_fc_p'"
        }
    }

    tempfile rowjson
    tempname rfh
    file open `rfh' using "`rowjson'", write text replace

    local filt_vars `"`filters'"'
    local slid_vars `"`sliders'"'
    local tip_vars  `"`tooltipvars'"'

    * Determine if id var is string or numeric -- shapes the padding logic
    capture confirm string variable `id'
    local _id_is_string = (_rc == 0)

    local _first 1
    local _rows_written 0
    quietly {
        forvalues _i = 1/`=_N' {
            if !`touse'[`_i'] continue
            * Build a padded string id matching idwidth.
            * Padding uses explicit leading-zero prefixing rather than the
            * real()->display %0Wf round-trip: that idiom silently overflows
            * to scientific notation (" 2.0e+08") for any numeric value past
            * ~10^8, collapsing distinct 9-digit ids into one string and
            * breaking d3.index() with duplicate-key errors downstream.
            if `_id_is_string' {
                local _idraw = `id'[`_i']
                local _fid = "`_idraw'"
                * Pad with leading zeros only if shorter than idwidth -- and
                * only when the raw value is numeric-looking (FIPS-style).
                * Already-padded or long string ids are written verbatim.
                if strlen("`_fid'") < `idwidth' {
                    capture local _rn = real("`_fid'")
                    if !_rc & "`_fid'" != "." & !missing(`_rn') {
                        local _padlen = `idwidth' - strlen("`_fid'")
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
                if strlen("`_fid'") < `idwidth' {
                    local _padlen = `idwidth' - strlen("`_fid'")
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
            file write `rfh' `","name":"`_nm'""'

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
                file write `rfh' `","f__`_fv'":"`_val'""'
            }
            foreach _sv of local slid_vars {
                local _snum = `_sv'[`_i']
                if missing(`_snum') file write `rfh' `","s__`_sv'":null"'
                else                file write `rfh' `","s__`_sv'":"' (`_snum')
            }
            foreach _tv of local tip_vars {
                capture confirm string variable `_tv'
                local _isstr = (_rc == 0)
                if `_isstr' {
                    local _tval = `_tv'[`_i']
                    local _tval : subinstr local _tval `"\"' `"\\"', all
                    local _tval : subinstr local _tval `"""' `"\""', all
                    file write `rfh' `","t__`_tv'":"`_tval'""'
                }
                else {
                    local _tnum = `_tv'[`_i']
                    local _tlab : value label `_tv'
                    if "`_tlab'" != "" & !missing(`_tnum') {
                        local _tdsp : label `_tlab' `_tnum'
                        local _tdsp : subinstr local _tdsp `"\"' `"\\"', all
                        local _tdsp : subinstr local _tdsp `"""' `"\""', all
                        file write `rfh' `","t__`_tv'":"`_tdsp'""'
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
        display as error "sparkta2: no rows to plot (check [if]/[in], counties(), or filter expressions)"
        exit 459
    }

    tempfile metajson
    file open `rfh' using "`metajson'", write text replace
    file write `rfh' "{"
    file write `rfh' `""filters":["'
    local _fcount = 0
    foreach _fv of local filt_vars {
        if `_fcount' > 0 file write `rfh' ","
        local ++_fcount
        local _lbl : variable label `_fv'
        if "`_lbl'" == "" local _lbl "`_fv'"
        local _lbl : subinstr local _lbl `"""' `"\""', all
        file write `rfh' `"{"var":"`_fv'","label":"`_lbl'","values":["'
        * Drop the `clean' option: it strips the compound quotes that
        * levelsof wraps multi-word string values in, so values like
        * "Middle / Jr. High" survive as a single token through foreach.
        quietly levelsof `_fv' if `touse', local(_levels)
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
            file write `rfh' `""`_disp'""'
        }
        file write `rfh' "]}"
    }
    file write `rfh' `"],"sliders":["'
    local _scount = 0
    foreach _sv of local slid_vars {
        quietly summarize `_sv' if `touse', meanonly
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
        local _lbl : subinstr local _lbl `"""' `"\""', all
        file write `rfh' `"{"var":"`_sv'","label":"`_lbl'","min":"' (`_lo') `","max":"' (`_hi') `"}"'
    }
    file write `rfh' `"],"tooltipvars":["'
    local _tcount = 0
    foreach _tv of local tip_vars {
        if `_tcount' > 0 file write `rfh' ","
        local ++_tcount
        local _lbl : variable label `_tv'
        if "`_lbl'" == "" local _lbl "`_tv'"
        local _lbl : subinstr local _lbl `"""' `"\""', all
        capture confirm numeric variable `_tv'
        local _isnum = (_rc == 0)
        local _tlabname : value label `_tv'
        local _numfmt = cond(`_isnum' & "`_tlabname'" == "", 1, 0)
        file write `rfh' `"{"var":"`_tv'","label":"`_lbl'","numeric":`_numfmt'}"'
    }
    file write `rfh' "]}"
    file close `rfh'

    sparkta2_writehtml,                                    ///
        topopath("`topopath'") engpath("`engpath'")         ///
        d3path("`d3path'") tcpath("`tcpath'")               ///
        hxpath("`hxpath'")                                  ///
        rowjson("`rowjson'") metajson("`metajson'")         ///
        export(`"`export'"') isoffline(`is_offline')        ///
        type("`type'") scheme("`scheme'") title(`"`title'"') ///
        geo("`geo'") layer("`layer'")                       ///
        idwidth(`idwidth')                                  ///
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

    display as text _n "[sparkta2 v0.7.7]  `type' map written:"
    display as text `"  {browse "`export'":`export'}"'
    display as text "  Rows: `_rows_written'  Geo: `geo'  Scheme: `scheme'  Mode: `mode'"

    return local export "`export'"
    return local type   "`type'"
    return local geo    "`geo'"
    return scalar n_rows = `_rows_written'

    if "`noopen'" == "" {
        sparkta2_open, file(`"`export'"')
    }
end
