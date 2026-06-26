*! sparkta2_chart v0.7.1  2026-06-26
*! D3-native non-map chart types for sparkta2.
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
        TX2036STyle                                                  ///  Texas 2036 brand + Montserrat
        WRAPlabel(string)                                            ///  auto (default) | on | off -- category-label wrap policy
        GUTTERwidth(integer 0)                                       ///  left-margin width in px for category labels (0 = use default)
        WIDTH(integer 980) HEIGHT(integer 644)                       ///
        EXPORT(string) OFFLINE NOOPEN                                ///
        TOOLTIPvars(varlist)                                         ///
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

    * Defaults per type
    if "`scheme'" == "" {
        if      "`engine_type'" == "donut"   local scheme "tx2036"
        else if "`engine_type'" == "divbar"  local scheme "rdbu"
        else                                  local scheme "blues"
    }
    local scheme = lower("`scheme'")

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

    if "`title'" == "" {
        if      "`engine_type'" == "donut"   local title "Donut: `xvar'"
        else if "`engine_type'" == "bar"     local title "Bar: `xvar'"
        else if "`engine_type'" == "line"    local title "Line: `yvar' vs `xvar'"
        else if "`engine_type'" == "divbar"  local title "Diverging bar: `xvar' by `name'"
        else if "`engine_type'" == "barrace" local title "Bar chart race: `xvar' over `time'"
    }

    if "`export'" == "" {
        local export "`c(pwd)'/sparkta2_`type'.html"
    }

    * --- Discover the engine paths (chart engine, plus d3 + helpers) -------
    capture findfile sparkta2_chart_engine.js
    if _rc {
        display as error "sparkta2_chart: sparkta2_chart_engine.js not on adopath."
        exit 601
    }
    local engpath "`r(fn)'"
    capture findfile d3.min.js
    if _rc {
        display as error "sparkta2_chart: d3.min.js not on adopath."
        exit 601
    }
    local d3path "`r(fn)'"

    * --- Build the row JSON ----------------------------------------------
    tempfile rowjson
    tempname rfh
    file open `rfh' using "`rowjson'", write text replace

    local tip_vars `"`tooltipvars'"'

    local _first 1
    local _rows_written = 0
    quietly {
        forvalues _i = 1/`=_N' {
            if !`touse'[`_i'] continue

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
            local _nm : subinstr local _nm `"\"' `"\\"', all
            local _nm : subinstr local _nm `"""' `"\""', all

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
            local _ov : subinstr local _ov `"\"' `"\\"', all
            local _ov : subinstr local _ov `"""' `"\""', all

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
            local _lv : subinstr local _lv `"\"' `"\\"', all
            local _lv : subinstr local _lv `"""' `"\""', all

            * time() resolution (barrace)
            local _tm .
            if "`time'" != "" {
                local _tm = `time'[`_i']
                if missing(`_tm') continue
            }

            if `_first' local _first 0
            else file write `rfh' "," _n

            file write `rfh' "        {"
            file write `rfh' `""x":"' (`_xv')
            if "`yvar'" != "" file write `rfh' `","y":"' (`_yv')
            if "`name'"  != "" file write `rfh' `","name":"`_nm'""'
            if "`over'"  != "" file write `rfh' `","g":"`_ov'""'
            if "`level'" != "" file write `rfh' `","lev":"`_lv'""'
            if "`time'"  != "" file write `rfh' `","t":"' (`_tm')

            * Tooltipvars: bare and numeric-aware
            foreach _tv of local tip_vars {
                local _val ""
                capture confirm string variable `_tv'
                if !_rc {
                    local _val = `_tv'[`_i']
                    local _val : subinstr local _val `"\"' `"\\"', all
                    local _val : subinstr local _val `"""' `"\""', all
                    file write `rfh' `","t__`_tv'":"`_val'""'
                }
                else {
                    local _tlab : value label `_tv'
                    local _tnum = `_tv'[`_i']
                    if "`_tlab'" != "" & !missing(`_tnum') {
                        local _tldisp : label `_tlab' `_tnum'
                        local _tldisp : subinstr local _tldisp `"\"' `"\\"', all
                        local _tldisp : subinstr local _tldisp `"""' `"\""', all
                        file write `rfh' `","t__`_tv'":"`_tldisp'""'
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
        display as error "sparkta2_chart: no rows to plot (check [if]/[in], missing values, or required varname options)"
        exit 459
    }

    * --- Build the meta JSON for tooltipvars -----------------------------
    tempfile tipjson
    file open `rfh' using "`tipjson'", write text replace
    file write `rfh' `"["'
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
    file write `rfh' "]"
    file close `rfh'

    * --- Emit final HTML --------------------------------------------------
    * Pass the INTERNAL engine name (without the "2" suffix) so the JS
    * engine's renderType switch stays clean.
    sparkta2_chart_writehtml,                                       ///
        engpath("`engpath'") d3path("`d3path'")                     ///
        rowjson("`rowjson'") tipjson("`tipjson'")                   ///
        export(`"`export'"') isoffline(`is_offline')                ///
        type("`engine_type'") scheme("`scheme'")                    ///
        title(`"`title'"') subtitle(`"`subtitle'"') note(`"`note'"') ///
        xlabel(`"`xlabel'"') ylabel(`"`ylabel'"')                   ///
        xvar("`xvar'") yvar("`yvar'") name("`name'") over("`over'") ///
        level("`level'") time("`time'")                             ///
        levelorder(`"`levelorder'"') centerlevel(`"`centerlevel'"') ///
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

    display as text _n "[sparkta2 v0.7.4]  `type' chart written:"
    display as text `"  {browse "`export'":`export'}"'
    display as text "  Rows: `_rows_written'  Scheme: `scheme'"

    return local export "`export'"
    return local type   "`type'"
    return scalar n_rows = `_rows_written'

    if "`noopen'" == "" {
        sparkta2_open, file(`"`export'"')
    }
end
