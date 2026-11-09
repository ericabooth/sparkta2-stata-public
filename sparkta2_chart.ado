*! sparkta2_chart v0.8.11  2026-11-09
*! v0.8.11 2026-11-09: numbers are written with a period decimal point under
*!   -set dp comma- (restored afterwards) and with 15 significant digits for
*!   doubles (_s2c_num); temp-file "(file ... not found)" notes are gone.
*!   Default look changed: type(donut) defaults to the neutral tableau10
*!   palette (was tx2036) and the page uses neutral colors.  For the
*!   previous look add tx2036style scheme(tx2036).  An unknown scheme()
*!   falls back to the default for the chart type with a note.
*! v0.8.10 2026-11-09: name()/over()/level() labels keep $ and backtick text
*!   (block-form writes, macval); JSON strings escaped by _s2c_js; a donut
*!   with negative values or a zero total stops with r(459).
*! v0.8.6 2026-11-08: option names now read the same on every Stata version.
*!   Older Stata kept the capitals after a digit (TX2036STyle, D3PATH,
*!   ISTX2036Style), so tx2036style was "not allowed" and internal calls
*!   failed with "option ... required"; the tails are now lowercase.
*! D3-native non-map chart types for sparkta2.
*!
*! v0.8.0: dashtab(varname) — higher-order tabs, mirroring the map side.
*!   Where over() splits within a chart and by() makes small multiples,
*!   dashtab() renders one FULL chart per level of the variable and puts a
*!   tab bar above the output (dashtabstyle(tabs|buttons)).  Levels come
*!   from levelsof on the active sample (2–10 required); tab labels come
*!   from the string value / value label / number, with "|" swapped to "/".
*!   Rows with a missing dashtab value belong to no tab.  A plain call is
*!   simply ntabs==1 with no tab bar — same row/JSON/render pipeline, so
*!   both paths are exercised by every run.  New return scalar n_tabs.
*!
*! v0.7.9: asset discovery now goes through sparkta2_findfile (new charts
*!   option), so the chart engine and d3.min.js resolve from the adopath,
*!   the PLUS/s/sparkta2/ cache, or the auto-download mirror, exactly like
*!   the map types.  Previously two bare -findfile- calls errored r(601) on
*!   any install where net install had placed only the ado files.
*!
*! Supported types:
*!   donut    : ring chart, one slice per row
*!   bar2     : sparkta2-native vertical or horizontal bars
*!              (renamed from bar in v0.7.1 to preserve sparkta's bar API)
*!   line2    : sparkta2-native line chart (renamed from line in v0.7.1)
*!   divbar   : Pew-style diverging stacked bar for Likert/survey items
*!              (long-form input: item x level x share)
*!   barrace  : "bar chart race" -- animated horizontal bar chart over time()
*!
*! All chart types inherit the v0.6.0 Export menu (PNG/SVG/CSV/Print/View
*! data), the v0.6.0 `animate' option, and the v0.6.0 `datatable' option.
*!
*! Why bar2 / line2 instead of bar / line:
*!   sparkta (Fahad Mirza) already implements type(bar) and type(line) via
*!   Chart.js, with its own multi-variable / stat() / fit() syntax.  Reusing
*!   those names for the sparkta2-native D3 versions would silently break
*!   every existing do-file that called the sparkta versions.  v0.7.1 keeps
*!   bar / line forwarding to sparkta and exposes the new D3 engine as
*!   bar2 / line2.
*!
*! Data-shape conventions:
*!   donut    sparkta2 value,  name(category)                              type(donut)
*!   bar2     sparkta2 value,  name(category) [over(group)]                type(bar2)
*!            [horizontal] [stacked] [normalize]
*!   line2    sparkta2 y x,                                  [over(series)] type(line2)
*!   divbar   sparkta2 share,  name(item) level(response_level) ///
*!                             levelorder("a|b|c|d|e") [centerlevel(c)]    type(divbar)
*!   barrace  sparkta2 value,  name(category) time(year)                   type(barrace)
*!
*! All numeric inputs in `varlist' are required.  Stata `[if] [in]'
*! qualifiers are honored row-by-row (excluded rows do not ship).

program define sparkta2_chart, rclass
    version 17.0

    * Numbers in the page must use a period decimal point; see the same
    * guard in sparkta2_map.
    if c(dp) == "comma" {
        set dp period
        capture noisily sparkta2_chart `macval(0)'
        local _rc = _rc
        set dp comma
        if !`_rc' return add
        exit `_rc'
    }

    syntax varlist(min=1 max=2 numeric) [if] [in], TYPE(string) [    ///
        NAME(varname)                                                ///  category / item label
        OVER(varname)                                                ///  grouping / series var (bar, line)
        LEVel(varname)                                               ///  response level var (divbar)
        LEVELORDer(string)                                           ///  pipe-separated explicit level order (divbar)
        CENTERlevel(string)                                          ///  centering response value (divbar)
        TIME(varname numeric)                                        ///  time var (barrace)
        HORIzontal                                                   ///  horizontal orientation (bar)
        STACKed                                                      ///  stacked bars (bar with over)
        NORMAlize                                                    ///  normalize stacks to 100%
        INNERradius(real 0.55)                                       ///  donut inner radius (fraction of outer)
        SUPPRESSaxis                                                 ///  Pew-style: no x-axis ticks (divbar)
        DIRECTlabels                                                 ///  direct labels on bars / slices
        TOP(integer 12)                                              ///  barrace top-N categories per frame
        FPS(integer 12)                                              ///  barrace frames per second
        DURation(real 25)                                            ///  barrace total seconds
        SORTed(string)                                               ///  ascending|descending|category
        SCHEME(string)                                               ///  color palette name
        TITLE(string) SUBtitle(string) NOTE(string)                  ///
        XLABel(string) YLABel(string)                                ///
        DOWNload DATATable ANIMate                                   ///  v0.6.0 features
        DOWNLOADPos(string)                                          ///  side (default) | below | none
        TX2036style                                                  ///  authors' house style (internal); off by default
        WRAPlabel(string)                                            ///  auto (default) | on | off -- category-label wrap policy
        GUTTERwidth(integer 0)                                       ///  left-margin width in px for category labels (0 = use default)
        WIDTH(integer 980) HEIGHT(integer 644)                       ///
        EXPORT(string) OFFLINE NOOPEN                                ///
        TOOLTIPvars(varlist)                                         ///
        DASHtab(varname)                                             ///  higher-order tabs: one full chart per level of this var
        DASHTABStyle(string)                                         ///  tabs (default) | buttons
    ]

    marksample touse, novarlist

    local type = lower("`type'")
    local _valid_types "donut bar2 line2 divbar barrace"
    if !`:list type in _valid_types' {
        display as error "sparkta2_chart: type(`type') not recognised."
        display as error "  Valid: donut | bar2 | line2 | divbar | barrace"
        exit 198
    }

    * Internal engine names drop the "2" suffix used in the public API.
    local engine_type "`type'"
    if "`engine_type'" == "bar2"  local engine_type "bar"
    if "`engine_type'" == "line2" local engine_type "line"

    local nvar : word count `varlist'
    local xvar : word 1 of `varlist'
    local yvar : word 2 of `varlist'

    * v0.8.1: axis/legend labels default to the VARIABLE LABEL when unset,
    * so charts read labels rather than raw varnames.
    *
    * v0.8.5 (2026-09-21): default to the label of the variable ACTUALLY ON THAT
    * AXIS. xlabel titles the horizontal axis, ylabel the vertical. For every
    * chart type except the line chart, the first varlist word (xvar) is on the
    * horizontal axis, so xlabel defaults from xvar. The LINE renderer is the
    * exception: it plots the second word (yvar) on the horizontal axis and the
    * first (xvar) on the vertical (see renderLine in the engine). Before this
    * fix a line chart that let both labels default rendered them on the wrong
    * axes; an explicit xlabel()/ylabel() was always honoured correctly and is
    * unaffected. cond() picks the on-axis variable without an if/else block.
    if `"`macval(xlabel)'"' == "" {
        local _hvar = cond("`engine_type'" == "line", "`yvar'", "`xvar'")
        local xlabel : variable label `_hvar'
    }
    if "`yvar'" != "" & `"`macval(ylabel)'"' == "" {
        local _vvar = cond("`engine_type'" == "line", "`xvar'", "`yvar'")
        local ylabel : variable label `_vvar'
    }

    * Per-type required-input checks
    if "`engine_type'" == "line" {
        if `nvar' != 2 {
            display as error "sparkta2_chart: type(line2) requires two numeric vars (y x)"
            exit 198
        }
    }
    else if `nvar' != 1 {
        display as error "sparkta2_chart: type(`type') takes one numeric var (the value)"
        exit 198
    }
    if "`type'" == "divbar" {
        if "`level'" == "" {
            display as error "sparkta2_chart: type(divbar) requires level(varname)"
            exit 198
        }
        if "`name'" == "" {
            display as error "sparkta2_chart: type(divbar) requires name(varname) (item label var)"
            exit 198
        }
    }
    if "`type'" == "barrace" {
        if "`time'" == "" {
            display as error "sparkta2_chart: type(barrace) requires time(varname)"
            exit 198
        }
        if "`name'" == "" {
            display as error "sparkta2_chart: type(barrace) requires name(varname) (category var)"
            exit 198
        }
    }

    * Defaults per type.  Every default is a neutral palette: tableau10
    * (categorical) for a donut, rdbu for divbar, blues otherwise.  The
    * authors' house palette is used only on request, scheme(tx2036).  A
    * name the chart engine does not know falls back to the default with
    * a note.
    local _dflt_scheme "blues"
    if "`engine_type'" == "donut" {
        local _dflt_scheme "tableau10"
    }
    if "`engine_type'" == "divbar" {
        local _dflt_scheme "rdbu"
    }
    local _known_sch "tableau10 tx2036 blues reds greens oranges purples greys viridis magma inferno plasma cividis rdbu brbg puor rdylbu rdylgn"
    if `"`macval(scheme)'"' == "" {
        local scheme "`_dflt_scheme'"
    }
    else {
        local _sch_hit ""
        foreach _s of local _known_sch {
            if strlower(strtrim(`"`macval(scheme)'"')) == "`_s'" {
                local _sch_hit "`_s'"
            }
        }
        if "`_sch_hit'" == "" {
            display as text `"  (note: scheme(`macval(scheme)') is not a sparkta2 chart scheme; using the default, `_dflt_scheme'."'
            display as text "   Chart schemes: `_known_sch')"
            local _sch_hit "`_dflt_scheme'"
        }
        local scheme "`_sch_hit'"
    }

    local is_horizontal = cond("`horizontal'" != "", 1, 0)
    local is_stacked    = cond("`stacked'"    != "", 1, 0)
    local is_normalize  = cond("`normalize'"  != "", 1, 0)
    local is_suppressax = cond("`suppressaxis'" != "", 1, 0)
    local is_directlbl  = cond("`directlabels'" != "", 1, 0)
    if "`engine_type'" == "divbar" {
        * Pew-style defaults: no bottom axis, direct labels on
        if "`suppressaxis'" == "" local is_suppressax = 1
        if "`directlabels'" == "" local is_directlbl  = 1
    }

    local is_offline    = cond("`offline'"    != "", 1, 0)
    local is_download   = cond("`download'"   != "", 1, 0)
    local is_datatable  = cond("`datatable'"  != "", 1, 0)
    local is_animate    = cond("`animate'"    != "", 1, 0)
    local is_tx2036st   = cond("`tx2036style'" != "", 1, 0)

    if "`downloadpos'" == "" local downloadpos "side"
    local downloadpos = lower("`downloadpos'")
    local _valid_dlpos "side below none"
    if !`:list downloadpos in _valid_dlpos' {
        display as error "sparkta2_chart: downloadpos(`downloadpos') not recognised."
        display as error "  Valid: side | below | none"
        exit 198
    }

    * wraplabel validation.  Synonyms collapse to a canonical form so the
    * engine's switch stays tight: "wrap" -> "on", "truncate" -> "off".
    * Public option names use non-overlapping prefixes (wraplabel, gutterwidth)
    * to dodge a Stata syntax-parser quirk that rejects sibling options sharing
    * a common prefix even when the abbreviation rules technically disambiguate.
    if "`wraplabel'" == "" local wraplabel "auto"
    local wraplabel = lower("`wraplabel'")
    local _valid_wraplabel "auto on off wrap truncate"
    if !`:list wraplabel in _valid_wraplabel' {
        display as error "sparkta2_chart: wraplabel(`wraplabel') not recognised."
        display as error "  Valid: auto | on | off  (synonyms: wrap | truncate)"
        exit 198
    }
    if "`wraplabel'" == "wrap"     local wraplabel "on"
    if "`wraplabel'" == "truncate" local wraplabel "off"
    if `gutterwidth' < 0 {
        display as error "sparkta2_chart: gutterwidth(`gutterwidth') must be non-negative."
        exit 198
    }

    if `"`macval(title)'"' == "" {
        if      "`engine_type'" == "donut"   local title "Donut: `xvar'"
        else if "`engine_type'" == "bar"     local title "Bar: `xvar'"
        else if "`engine_type'" == "line"    local title "Line: `yvar' vs `xvar'"
        else if "`engine_type'" == "divbar"  local title "Diverging bar: `xvar' by `name'"
        else if "`engine_type'" == "barrace" local title "Bar chart race: `xvar' over `time'"
    }

    if "`export'" == "" {
        local export "`c(pwd)'/sparkta2_`type'.html"
    }

    * ---- dashtab: build tab specs (v0.8.0) --------------------------------
    * A plain call is one tab with no filter; dashtab(varname) makes one tab
    * per level.  Both run the identical row/JSON/render pipeline below.
    if "`dashtabstyle'" == "" local dashtabstyle "tabs"
    local dashtabstyle = lower("`dashtabstyle'")
    if !inlist("`dashtabstyle'", "tabs", "buttons") {
        display as error "sparkta2_chart: dashtabstyle(`dashtabstyle') not recognised (tabs | buttons)"
        exit 198
    }
    local _ntabs 1
    local _dt_is_str 0
    if "`dashtab'" != "" {
        capture confirm string variable `dashtab'
        local _dt_is_str = (_rc == 0)
        local _dt_vallab ""
        if !`_dt_is_str' local _dt_vallab : value label `dashtab'
        if `_dt_is_str' {
            * -levelsof- drops $name text from string values (a level such as
            * "Reg $A" comes back as "Reg "), so string levels are read in Mata.
            mata: _s2c_slevels("`dashtab'", "`touse'", "_dtval_")
            local _ntabs `_dtval_n'
        }
        else {
            quietly levelsof `dashtab' if `touse', local(_dtlevels)
            local _ntabs : word count `_dtlevels'
        }
        if `_ntabs' < 2 {
            display as error "sparkta2_chart: dashtab(`dashtab') has only `_ntabs' level on the active sample — need at least 2 tabs"
            exit 198
        }
        if `_ntabs' > 10 {
            display as error "sparkta2_chart: dashtab(`dashtab') has `_ntabs' levels — more than 10 tabs is unusable.  Recode the variable."
            exit 198
        }
        if `_dt_is_str' {
            forvalues _k = 1/`_ntabs' {
                local _dtlab_`_k' `"`macval(_dtval_`_k')'"'
            }
        }
        else {
            local _k 0
            foreach _lv of local _dtlevels {
                local ++_k
                local _dtval_`_k' `"`_lv'"'
                if "`_dt_vallab'" != "" {
                    local _dtlab_`_k' : label `_dt_vallab' `_lv'
                }
                else local _dtlab_`_k' "`_lv'"
            }
        }
        * "|" is the tab-list separator downstream — swap it out of labels
        forvalues _k = 1/`_ntabs' {
            local _dtlab_`_k' : subinstr local _dtlab_`_k' "|" "/", all
        }
    }

    * --- Discover the engine paths (chart engine + d3) ---------------------
    * Route through sparkta2_findfile so charts get the same three-pass
    * lookup maps use (adopath incl. cwd, the PLUS/s/sparkta2/ cache, then
    * auto-download); a bare -findfile- here made the first chart after a
    * fresh net install fail with r(601), because net install cannot place
    * the .js ancillaries.
    sparkta2_findfile, charts
    local engpath "`r(chartpath)'"
    local d3path  "`r(d3path)'"

    * --- Build the row JSON (v0.8.0: one pass per dashtab level; a plain
    * --- call is a single pass with no tab filter) -------------------------
    tempname rfh

    local tip_vars `"`tooltipvars'"'

    local _tabrowjsons ""
    local _tablabels ""
    local _rows_total 0

    forvalues _t = 1/`_ntabs' {

    tempfile rowjson_`_t'
    quietly file open `rfh' using "`rowjson_`_t''", write text replace

    local _first 1
    local _rows_written = 0
    local _dn_sum = 0
    local _dn_neg = 0
    quietly {
        forvalues _i = 1/`=_N' {
            if !`touse'[`_i'] continue

            * dashtab filter: this pass keeps only the rows on this tab.
            * Rows with a missing dashtab value belong to no tab (a missing
            * value never equals a levelsof level, so they are skipped on
            * every pass).
            if `_ntabs' > 1 {
                if `_dt_is_str' {
                    local _dtv = `dashtab'[`_i']
                    local _dtsame = (`"`macval(_dtv)'"' == `"`macval(_dtval_`_t')'"')
                    if !`_dtsame' continue
                }
                else {
                    if `dashtab'[`_i'] != `_dtval_`_t'' continue
                }
            }

            local _xv = `xvar'[`_i']
            local _yv .
            if "`yvar'" != "" local _yv = `yvar'[`_i']
            if missing(`_xv') continue
            if "`yvar'" != "" {
                if missing(`_yv') continue
            }

            * Resolve name() with value-label fallback
            local _nm ""
            if "`name'" != "" {
                capture confirm string variable `name'
                if !_rc {
                    local _nm = `name'[`_i']
                }
                else {
                    local _lab : value label `name'
                    local _num = `name'[`_i']
                    if "`_lab'" != "" & !missing(`_num') {
                        local _nm : label `_lab' `_num'
                    }
                    else if !missing(`_num') {
                        local _nm = strofreal(`_num')
                    }
                }
            }
            mata: st_local("_nm", _s2c_js(st_local("_nm")))

            * over() resolution (grouping var for bar/line)
            local _ov ""
            if "`over'" != "" {
                capture confirm string variable `over'
                if !_rc {
                    local _ov = `over'[`_i']
                }
                else {
                    local _olab : value label `over'
                    local _onum = `over'[`_i']
                    if "`_olab'" != "" & !missing(`_onum') {
                        local _ov : label `_olab' `_onum'
                    }
                    else if !missing(`_onum') {
                        local _ov = strofreal(`_onum')
                    }
                }
            }
            mata: st_local("_ov", _s2c_js(st_local("_ov")))

            * level() resolution (divbar response level)
            local _lv ""
            if "`level'" != "" {
                capture confirm string variable `level'
                if !_rc {
                    local _lv = `level'[`_i']
                }
                else {
                    local _llab : value label `level'
                    local _lnum = `level'[`_i']
                    if "`_llab'" != "" & !missing(`_lnum') {
                        local _lv : label `_llab' `_lnum'
                    }
                    else if !missing(`_lnum') {
                        local _lv = strofreal(`_lnum')
                    }
                }
            }
            mata: st_local("_lv", _s2c_js(st_local("_lv")))

            * time() resolution (barrace)
            local _tm .
            if "`time'" != "" {
                local _tm = `time'[`_i']
                if missing(`_tm') continue
            }

            if "`engine_type'" == "donut" {
                if `_xv' < 0 local ++_dn_neg
                else local _dn_sum = `_dn_sum' + `_xv'
            }

            if `_first' local _first 0
            else file write `rfh' "," _n

            file write `rfh' "        {"
            mata: _s2c_numl("_ns", "`xvar'", `_i')
            file write `rfh' `""x":`_ns'"'
            if "`yvar'" != "" {
                mata: _s2c_numl("_ns", "`yvar'", `_i')
                file write `rfh' `","y":`_ns'"'
            }
            * Block form, not an inline -if-: an inline -if- expands its
            * command a second time, which dropped $name and backtick text
            * from labels.  The escaped text is inert anyway (see _s2c_js).
            if "`name'" != "" {
                file write `rfh' `","name":"`macval(_nm)'""'
            }
            if "`over'" != "" {
                file write `rfh' `","g":"`macval(_ov)'""'
            }
            if "`level'" != "" {
                file write `rfh' `","lev":"`macval(_lv)'""'
            }
            if "`time'"  != "" {
                mata: _s2c_numl("_ns", "`time'", `_i')
                file write `rfh' `","t":`_ns'"'
            }

            * Tooltipvars: bare and numeric-aware
            foreach _tv of local tip_vars {
                local _val ""
                capture confirm string variable `_tv'
                if !_rc {
                    local _val = `_tv'[`_i']
                    mata: st_local("_val", _s2c_js(st_local("_val")))
                    file write `rfh' `","t__`_tv'":"`macval(_val)'""'
                }
                else {
                    local _tlab : value label `_tv'
                    local _tnum = `_tv'[`_i']
                    if "`_tlab'" != "" & !missing(`_tnum') {
                        local _tldisp : label `_tlab' `_tnum'
                        mata: st_local("_tldisp", _s2c_js(st_local("_tldisp")))
                        file write `rfh' `","t__`_tv'":"`macval(_tldisp)'""'
                    }
                    else if missing(`_tnum') {
                        file write `rfh' `","t__`_tv'":null"'
                    }
                    else {
                        mata: _s2c_numl("_ns", "`_tv'", `_i')
                        file write `rfh' `","t__`_tv'":`_ns'"'
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
            display as error `"sparkta2_chart: no rows to plot on dashtab() tab `_t' ("`macval(_dtlab_`_t')'") — check [if]/[in], missing values, and `dashtab'"'
        }
        else {
            display as error "sparkta2_chart: no rows to plot (check [if]/[in], missing values, or required varname options)"
        }
        exit 459
    }
    * A donut shows shares of a total, so its values must be non-negative
    * with a positive sum.  All zeros used to draw an empty ring and
    * negative values gave negative shares, both with rc 0.
    if "`engine_type'" == "donut" {
        local _dn_where ""
        if `_ntabs' > 1 {
            local _dn_where `" on dashtab() tab `_t' ("`macval(_dtlab_`_t')'")"'
        }
        if `_dn_neg' > 0 {
            display as error `"sparkta2_chart: type(donut) needs non-negative values; `xvar' has `_dn_neg' negative value(s)`macval(_dn_where)'."'
            display as error "  A donut shows shares of a total.  Use bar2 for values that can be negative."
            exit 459
        }
        if `_dn_sum' <= 0 {
            display as error `"sparkta2_chart: type(donut) needs a positive total; the values of `xvar' sum to zero`macval(_dn_where)'."'
            display as error "  There are no shares to draw.  Check [if]/[in] and the value variable."
            exit 459
        }
    }
    local _rows_total = `_rows_total' + `_rows_written'

    * Accumulate the per-tab pipe lists for the HTML writer.
    if `_t' == 1 {
        local _tabrowjsons "`rowjson_`_t''"
        local _tablabels   `"`macval(_dtlab_`_t')'"'
    }
    else {
        local _tabrowjsons "`_tabrowjsons'|`rowjson_`_t''"
        local _tablabels   `"`macval(_tablabels)'|`macval(_dtlab_`_t')'"'
    }

    }   // end of per-tab row-JSON pass

    * --- Build the meta JSON for tooltipvars -----------------------------
    * Variable metadata only (label + numeric-format flag) — nothing here
    * depends on which rows ship, so ONE shared file is re-referenced by
    * every tab in the payload loop.
    tempfile tipjson
    quietly file open `rfh' using "`tipjson'", write text replace
    file write `rfh' `"["'
    local _tcount = 0
    foreach _tv of local tip_vars {
        if `_tcount' > 0 file write `rfh' ","
        local ++_tcount
        local _lbl : variable label `_tv'
        if `"`macval(_lbl)'"' == "" local _lbl "`_tv'"
        mata: st_local("_lbl", _s2c_js(st_local("_lbl")))
        capture confirm numeric variable `_tv'
        local _isnum = (_rc == 0)
        local _tlabname : value label `_tv'
        local _numfmt = cond(`_isnum' & "`_tlabname'" == "", 1, 0)
        file write `rfh' `"{"var":"`_tv'","label":"`macval(_lbl)'","numeric":`_numfmt'}"'
    }
    file write `rfh' "]"
    file close `rfh'

    * --- Emit final HTML --------------------------------------------------
    * Pass the INTERNAL engine name (without the "2" suffix) so the JS
    * engine's renderType switch stays clean.
    sparkta2_chart_writehtml,                                       ///
        engpath("`engpath'") d3path("`d3path'")                     ///
        ntabs(`_ntabs')                                             ///
        tabrowjsons("`_tabrowjsons'")                               ///
        tablabels(`"`macval(_tablabels)'"')                                 ///
        tabstyle("`dashtabstyle'")                                  ///
        tipjson("`tipjson'")                                        ///
        export(`"`export'"') isoffline(`is_offline')                ///
        type("`engine_type'") scheme("`scheme'")                    ///
        title(`"`macval(title)'"') subtitle(`"`macval(subtitle)'"') ///
        note(`"`macval(note)'"')                                    ///
        xlabel(`"`macval(xlabel)'"') ylabel(`"`macval(ylabel)'"')   ///
        xvar("`xvar'") yvar("`yvar'") name("`name'") over("`over'") ///
        level("`level'") time("`time'")                             ///
        levelorder(`"`macval(levelorder)'"')                        ///
        centerlevel(`"`macval(centerlevel)'"')                      ///
        horizontal(`is_horizontal') stacked(`is_stacked')           ///
        normalize(`is_normalize') suppressaxis(`is_suppressax')     ///
        directlabels(`is_directlbl')                                ///
        innerradius(`innerradius') top(`top') fps(`fps')            ///
        duration(`duration') sortedstr("`sorted'")                  ///
        isdownload(`is_download') isdatatable(`is_datatable')       ///
        isanimate(`is_animate') istx2036style(`is_tx2036st')         ///
        downloadpos("`downloadpos'")                                ///
        wraplabel("`wraplabel'") gutterwidth(`gutterwidth')          ///
        width(`width') height(`height')

    sparkta2_version
    display as text _n "[sparkta2 v`r(version)']  `type' chart written:"
    display as text `"  {browse "`export'":`export'}"'
    display as text "  Rows: `_rows_total'  Scheme: `scheme'"
    if `_ntabs' > 1 {
        display as text `"  Tabs: `_ntabs' (`dashtab') — `macval(_tablabels)'"'
    }

    return local export "`export'"
    return local type   "`type'"
    return scalar n_rows = `_rows_total'
    return scalar n_tabs = `_ntabs'

    if "`noopen'" == "" {
        sparkta2_open, file(`"`export'"')
    }
end

* Escape text for a double-quoted JSON/JS string that is spliced into an
* inline script block.  Besides backslash, double quote and control
* characters, six more characters become backslash-u escapes: less-than,
* greater-than, ampersand, apostrophe, the backtick and the dollar sign.
* The browser reads them back unchanged, a closing script tag in the data
* can no longer end the script block, and the escaped text holds nothing
* that Stata's macro parser would expand, so later file writes keep it
* exactly as written.
version 17.0
mata:
string scalar _s2c_u(real scalar c)
{
    string scalar h
    h = inbase(16, c)
    while (strlen(h) < 4) h = "0" + h
    return(char(92) + "u" + h)
}
string scalar _s2c_js(string scalar s)
{
    real scalar   i
    string scalar r
    r = subinstr(s, char(92), char(92) + char(92))
    r = subinstr(r, char(34), char(92) + char(34))
    r = subinstr(r, char(10), char(92) + "n")
    r = subinstr(r, char(13), char(92) + "r")
    r = subinstr(r, char(9),  char(92) + "t")
    for (i = 1; i <= 31; i++) {
        if (i != 9 & i != 10 & i != 13) r = subinstr(r, char(i), _s2c_u(i))
    }
    r = subinstr(r, char(60), _s2c_u(60))
    r = subinstr(r, char(62), _s2c_u(62))
    r = subinstr(r, char(38), _s2c_u(38))
    r = subinstr(r, char(39), _s2c_u(39))
    r = subinstr(r, char(96), _s2c_u(96))
    r = subinstr(r, char(36), _s2c_u(36))
    return(r)
}
// A number as JSON text: period decimal point, 7 significant digits for
// values held at float precision and 15 otherwise, null when missing.
string scalar _s2c_num(real scalar x)
{
    if (x >= .) return("null")
    if (x == floatround(x)) return(strtrim(strofreal(x, "%15.7g")))
    return(strtrim(strofreal(x, "%24.15g")))
}
void _s2c_numl(string scalar mac, string scalar var, real scalar i)
{
    st_local(mac, _s2c_num(_st_data(i, st_varindex(var))))
}
// Distinct non-empty values of a string variable over the rows where
// sel is nonzero, sorted, into caller locals pfx1, pfx2, ... and pfxn.
// Used instead of -levelsof-, which drops dollar-sign text from values.
void _s2c_slevels(string scalar var, string scalar sel, string scalar pfx)
{
    string colvector u
    real scalar      i
    u = uniqrows(st_sdata(., var, sel))
    if (rows(u)) u = select(u, u :!= "")
    for (i = 1; i <= rows(u); i++) st_local(pfx + strofreal(i), u[i])
    st_local(pfx + "n", strofreal(rows(u)))
}
end
