*! sparkta2 v0.8.11  2026-11-09
*!
*! New in 0.8.11: maps and charts stay valid under -set dp comma- and keep
*!   full precision for large values; sparkta2_dashboard takes quoted paths
*!   with spaces and writes iframe paths relative to the dashboard; a
*!   leading ~ works in rasterimage() and when opening the page; notes for
*!   out-of-range bins(), unknown scheme()/mode(); the dispatcher rejects a
*!   repeated or multi-word type(), hints at type(map) when id() is given
*!   without a type, and names duplicate sparkta installs when sparkta fails.
*!   DEFAULT LOOK CHANGED: pages and charts are neutral by default (neutral
*!   page colors, system fonts, tableau10 donut colors).  The authors' house
*!   style is now opt-in only; for the previous look add
*!   tx2036style scheme(tx2036).  An unknown scheme() falls back to the
*!   neutral default with a note.
*!
*! New in 0.8.10: native chart and map labels display exactly as in the data
*!   ($ and backtick text kept, no HTML entities in legends, a closing
*!   script tag in a label no longer breaks the page); title, subtitle and
*!   note all display as plain text; a donut stops with an error when its
*!   values are negative or sum to zero.
*!
*! New in 0.8.9: r()/e() preserved for the hand-off (marginsplot, eventstudy,
*!   matrix(r(table))); type-named variables stay variables with type();
*!   routing by option name, not option text; over() donuts to sparkta;
*!   absolute export() for sparkta; point/bivariatemap/horizontalbar aliases.
*!
*! New in 0.8.8: works with sparkta 3.6.1's syntax (type as the first word);
*!   both forms accepted for every type, hand-off written for the installed
*!   sparkta; dispatcher fixes (no type, type( inside text, ty(), donut).
*!
*! New in 0.8.7: map zero handling is opt-in (zeroneutral, zerolabel());
*!   named d3 schemes interpolate past 9 classes, so barrace and large
*!   donuts/over() groups no longer render blank.
*!
*! New in 0.8.6: option names read the same on every Stata version (older
*!   Stata rejected tx2036style; see the chart/map/writehtml headers).
*!
*! Previously 0.8.5  (line2 default axis labels on the correct axes)
*!
*! New in 0.8.4 (line2): axis titles are drawn from xlabel()/ylabel(), which
*!   previously reached the engine but were used only in the hover tooltip, so
*!   a chart that named both axes still rendered them unlabelled.  Numeric tick
*!   labels drop the locale group separator, so a year reads 2022 rather than
*!   2,022.
*!
*! Previously 0.8.3  2026-09-21
*!
*! New in 0.8.3: line2 renders series that cross zero -- the y-axis now
*!   spans the actual data range instead of starting at zero, a zero line
*!   is drawn when the series has both signs, and tooltip rows are
*!   labelled from ylabel()/xlabel().  Repository moved to
*!   github.com/ericabooth/sparkta2-stata-public.
*!
*! Previously 0.8.2  2026-08-12
*! sparkta + interactive choropleth maps + native D3 charts in one command.
*!
*! New in 0.8.2: linecolor()/linewidth() + basemapcolor()/basemapwidth()
*!   restyle the base feature borders and the backdrop outline (maps).
*! New in 0.8.1: classes()/breaks() classification; variable-label legend
*!   defaults; scalebar + northarrow; overlaycolors()/overlaywidths()/
*!   overlaydash(); Mata asset splice (Windows spaced-path fix).
*!
*! Dispatcher:
*!   type(map|bivariate|choropleth|hexbin|points)     -> sparkta2_map   (D3 map engine)
*!   type(donut|divbar|barrace|bar2|line2)            -> sparkta2_chart (D3 chart engine)
*!   everything else (incl. bar, line, scatter, ...)  -> sparkta (Fahad Mirza)
*!
*! New in 0.8.0:
*!   - dashtab(varname): higher-order tabs above the output — one FULL map
*!     or chart per level of the variable.  Where over() breaks out
*!     subgroups within a chart and by() makes small multiples, dashtab()
*!     switches between entirely different figures (e.g. counties vs
*!     school districts vs regions), each tab with its own geography via
*!     dashtabgeo()/dashtablayer()/dashtabidwidth().  dashtabstyle(tabs|
*!     buttons) picks the bar style.  Native map + chart types only; for
*!     sparkta pass-through types build one file per level and combine
*!     with sparkta2_dashboard, tabs.
*!   - overlays(list): checkbox-toggleable overlay layers on maps.  Tokens
*!     are topojson objects (states, nation) drawn as boundary meshes, or
*!     data variables: focused features are dissolved client-side by the
*!     variable's value (topojson.merge) into labelled group boundaries —
*!     regions on top of counties with no extra shapefile.
*!   - maplabels + labelsize(): toggleable feature name labels.
*!   - rasterimage()/rasterbounds()/rasteropacity(): offline georeferenced
*!     image layer under the data layer (base64-embedded).
*!   - sparkta2_dashboard, tabs: tabbed (instead of long-scroll) dashboard.
*!
*! New in 0.7.7:
*!   - Iframe auto-resize protocol: every sparkta2-native HTML output emits a
*!     postMessage of type "sparkta2-resize" with its rendered content height
*!     on load / resize / DOM mutation.  Parent pages (sparkta2_dashboard
*!     and the companion webdoc2 demos) listen for the message and grow
*!     each iframe to fit its content + set scrolling="no", so embeds never
*!     get clipped behind a scrollbar.  Iframes marked with the HTML
*!     attribute  data-skip-resize="1"  are exempted from the auto-resize
*!     (use for sparkta / Chart.js pass-throughs that don't emit the
*!     postMessage and should keep their native scrollbar).
*!
*! Earlier highlights:
*!   - 0.7.3 chart options: wraplabel(auto|on|off) + gutterwidth(N) (chart).
*!   - 0.7.1 backward-compat rename: native bar -> bar2, native line -> line2;
*!           type(bar)/type(line) continue forwarding to sparkta unchanged.
*!   - 0.7.0 chart engine + native types donut, divbar (Pew-style), barrace.
*!   - 0.6.1 Texas-tuned Albers projection + projection()/rotate()/parallels()
*!           /center() overrides on map.
*!   - 0.6.0 datatable + CSV download, animate (scroll-into-view fade-in),
*!           Export menu (PNG/SVG/Print/View data), tx2036style brand option,
*!           downloadpos(side|below|none).
*!
*! Engines and helpers (Stata only auto-loads one program per ado file,
*! so named sub-programs each need their own file):
*!   Map:   sparkta2_map.ado, sparkta2_writehtml.ado, sparkta2_engine.js
*!   Chart: sparkta2_chart.ado, sparkta2_chart_writehtml.ado, sparkta2_chart_engine.js
*!   Shared: sparkta2_findfile.ado, sparkta2_embedjs.ado,
*!           sparkta2_streamfile.ado, sparkta2_appendfile.ado, sparkta2_open.ado
*!
*! Map engine builds on:
*!   https://observablehq.com/@d3/bivariate-choropleth
*!   https://observablehq.com/@mbostock/methods-of-comparison-compared
*! Chart engine builds on:
*!   https://observablehq.com/@d3/bar-chart-race
*!   https://observablehq.com/@d3/diverging-stacked-bar-chart/2
*!   https://d3-graph-gallery.com/donut.html

program define sparkta2
    version 17.0

    * Hold r() first: margins, estat and r(table) results must reach sparkta
    * untouched (sparkta reads them for marginsplot, eventstudy and
    * matrix(r(table))), and the version calls below would overwrite them.
    tempname _rhold
    _return hold `_rhold'

    sparkta2_version
    display as text "  [sparkta2 v`r(version)']"

    * Chart types sparkta2 draws itself, and the types sparkta draws.  sparkta
    * 3.6.1 renamed hbox/hviolin to hboxplot/hviolinplot; both spellings are
    * accepted here and translated for whichever sparkta is installed.
    local _map_types    "map bivariate choropleth bivariatemap univariate hexbin points point"
    local _native_types "donut divbar barrace bar2 line2"
    local _sk_types     "bar line scatter pie hbar horizontalbar stackedbar stackedhbar stackedarea area bubble stackedline cibar ciline histogram stackedbar100 stackedhbar100 boxplot violin hboxplot hviolinplot hbox hviolin coefplot eventstudy marginsplot"
    local _all_types    "`_map_types' `_native_types' `_sk_types'"

    * Form 1 (sparkta 3.6.1 style): the type is the first word,
    *     sparkta2 scatter price mpg, ...
    * Form 2 (classic): the type is an option,
    *     sparkta2 price mpg, type(scatter) ...
    * A first word that is both a chart type and a variable stays a variable
    * when type() is also given (classic form); otherwise it is the type.
    local _lead ""
    gettoken _first _rest : 0, parse(" ,")
    local _first_l = lower(`"`_first'"')
    if `"`_first_l'"' != "" & `: list _first_l in _all_types' {
        local _lead "`_first_l'"
        local _save0 `"`macval(0)'"'
        local 0 `"`macval(_rest)'"'
    }
    syntax [anything(everything)] [, TYpe(string) *]
    local type = lower(strtrim(`"`type'"'))
    if "`_lead'" != "" {
        capture confirm variable `_first', exact
        local _isvar = (_rc == 0)
        if `_isvar' & "`type'" != "" {
            * classic call whose first variable is named like a chart type
            local 0 `"`macval(_save0)'"'
            syntax [anything(everything)] [, TYpe(string) *]
            local type = lower(strtrim(`"`type'"'))
            local _lead ""
        }
        else if `_isvar' {
            display as text "  (note: `_first' is both a variable and a chart type; read as the chart type." ///
                " Use type() to plot the variable.)"
        }
    }
    if "`_lead'" != "" & "`type'" != "" & "`_lead'" != "`type'" {
        display as error "sparkta2: the chart type is given twice (`_lead' and type(`type'))."
        exit 198
    }
    * A second type()/ty() would otherwise ride through to sparkta unseen.
    local _type1 `"`type'"'
    local _o2 `"`macval(options)'"'
    local 0 `", `macval(_o2)'"'
    capture syntax [, TYpe(string) *]
    if !_rc & `"`type'"' != "" {
        display as error "sparkta2: give the chart type once (type() appears more than once)."
        exit 198
    }
    local options `"`macval(_o2)'"'
    local type = lower(strtrim(`"`_type1'"'))
    if `: word count `type'' > 1 {
        display as error "sparkta2: type(`type') names more than one chart type; give one."
        exit 198
    }
    if "`type'" == "" local type "`_lead'"
    if "`type'" == "horizontalbar" local type "hbar"

    * Read routing options by name (abbreviations included), never by
    * searching the option text, so a title or note cannot change the route.
    local _useropts `"`macval(options)'"'
    local 0 `", `macval(options)'"'
    syntax [, CUTout(string) ROTation(string) CIRCumference(string) SLICEBorder(string) ///
        HOVEROffset(string) PIElabels DASHtab(string) OVer(string) NAme(string) EXPort(string) ///
        ID(string) *]
    local _sk_donut = (`"`cutout'`rotation'`circumference'`sliceborder'`hoveroffset'`pielabels'"' != "")
    local _to_sparkta 0
    if "`type'" == "donut" & (`_sk_donut' | (`"`over'"' != "" & `"`name'"' == "")) local _to_sparkta 1
    local _dashtab `"`dashtab'"'
    local _hasid = (`"`id'"' != "")
    local _export  `"`export'"'
    local _rest_noexp `"`macval(options)'"'
    local options `"`macval(_useropts)'"'

    if "`type'" != "" & `: list type in _map_types' {
        _return restore `_rhold'
        sparkta2_map `macval(anything)', type(`type') `macval(options)'
        exit
    }
    if "`type'" != "" & `: list type in _native_types' & !`_to_sparkta' {
        _return restore `_rhold'
        sparkta2_chart `macval(anything)', type(`type') `macval(options)'
        exit
    }

    * dashtab() cannot ride through to sparkta: the data never pass through
    * sparkta2's renderer, so there is nowhere to split them into tabs.
    if `"`_dashtab'"' != "" {
        display as error "sparkta2: dashtab() works with sparkta2-native types only (maps + donut|divbar|barrace|bar2|line2)."
        display as error "  For sparkta charts, write one file per level and combine:"
        display as error `"    sparkta2_dashboard, files("lvl1.html lvl2.html") titles("Level 1|Level 2") tabs export(combined.html)"'
        exit 198
    }

    * id() belongs to the map engine: an untyped map call would otherwise
    * reach sparkta, which has no id() option.
    if "`type'" == "" & `_hasid' {
        display as text "  (note: id() is a map option; add type(map) to draw a map.)"
    }

    capture which sparkta
    if _rc {
        if "`type'" != "" display as error "sparkta2: type(`type') needs sparkta.ado to be installed."
        else              display as error "sparkta2: charts without a sparkta2-native type() need sparkta.ado to be installed."
        display as error "  Install sparkta first (https://github.com/fahad-mirza/sparkta_stata)"
        display as error "  or use a sparkta2-native type:"
        display as error "    Maps:   map | bivariate | choropleth | hexbin | points"
        display as error "    Charts: donut | divbar | barrace | bar2 | line2"
        exit 199
    }

    * Hand sparkta an absolute export() path: older sparkta resolved a
    * relative path against its Java runtime folder, not the working folder.
    if `"`_export'"' != "" {
        local _e `"`_export'"'
        local _c1 = substr(`"`_e'"', 1, 1)
        local _abs = inlist(`"`_c1'"', "/", "\") | substr(`"`_e'"', 2, 1) == ":"
        if !`_abs' {
            local _e `"`c(pwd)'/`macval(_e)'"'
        }
        local options `"`macval(_rest_noexp)' export(`"`_e'"')"'
    }

    * Write the call in the syntax the installed sparkta expects.
    _sk2_sparkta_syntax
    local _new = r(new)
    local _skver `"`r(version)'"'
    if inlist("`type'", "coefplot", "eventstudy", "marginsplot") & r(old360) == 1 {
        display as error "sparkta2: type(`type') needs sparkta 3.6.0 or later; sparkta `_skver' is installed."
        display as error "  Update sparkta from https://github.com/fahad-mirza/sparkta_stata"
        exit 199
    }
    * Block-form if: an inline -if- expands its command a second time, so
    * backtick or $ text in a title would be substituted (or overflow).
    local _opts ""
    if `"`macval(options)'"' != "" {
        local _opts `", `macval(options)'"'
    }
    if `_new' {
        * 3.6.1+: sparkta <type> varlist, options   (type required for a chart)
        if "`type'" == "hbox"    local type "hboxplot"
        if "`type'" == "hviolin" local type "hviolinplot"
        if "`type'" == "" & `"`macval(anything)'"' != "" local type "bar"
        _return restore `_rhold'
        capture noisily sparkta `type' `macval(anything)' `macval(_opts)'
    }
    else {
        * up to 3.6.0: sparkta varlist, type(<type>) options
        if "`type'" == "hboxplot"    local type "hbox"
        if "`type'" == "hviolinplot" local type "hviolin"
        if "`type'" != "" {
            local _opts `", type(`type') `macval(options)'"'
        }
        _return restore `_rhold'
        capture noisily sparkta `macval(anything)' `macval(_opts)'
    }
    local _skrc = _rc
    if `_skrc' {
        _sk2_dupcheck
        exit `_skrc'
    }
end

* When sparkta fails, a second copy of sparkta.ado or sparkta.jar on the
* adopath (one in PERSONAL, another in PLUS, say) is a common cause:
* the ado of one version then loads the jar of another.  Name the copies.
program define _sk2_dupcheck
    foreach _f in sparkta.ado sparkta.jar {
        capture findfile `_f', all
        if !_rc {
            local _fns `"`r(fn)'"'
            if `: word count `_fns'' > 1 {
                display as error "  sparkta2: more than one `_f' is on the adopath:"
                foreach _p of local _fns {
                    display as error `"    `_p'"'
                }
                display as error "  Remove the stray copy (or run ado uninstall sparkta and reinstall)."
            }
        }
    }
end

* Does the installed sparkta take the type as its first word (3.6.1 and
* later) or as type()?  Read the version from its header; the global
* sparkta2_sparkta_syntax ("new" or "old") overrides the detection.
program define _sk2_sparkta_syntax, rclass
    local _g = strtrim(lower(`"$sparkta2_sparkta_syntax"'))
    if "`_g'" == "new" {
        return scalar new = 1
        exit
    }
    if "`_g'" == "old" {
        return scalar new = 0
        exit
    }
    if `"`_g'"' != "" {
        display as text `"  (note: ignoring global sparkta2_sparkta_syntax "$sparkta2_sparkta_syntax"; use new or old)"'
    }
    local new 0
    local old360 0
    local found 0
    quietly findfile sparkta.ado
    local _fn `"`r(fn)'"'
    tempname fh
    file open `fh' using `"`r(fn)'"', read text
    forvalues i = 1/40 {
        file read `fh' line
        if r(eof) continue, break
        local _ll = lower(`"`macval(line)'"')
        if regexm(`"`macval(_ll)'"', "sparkta version ([0-9]+)[.]([0-9]+)([.]([0-9]+))?") {
            * compare major, minor, patch in turn (3.5.111 is older than 3.6.1);
            * a missing patch number counts as 0
            local M = real(regexs(1))
            local m = real(regexs(2))
            local p = real(regexs(4))
            if missing(`p') local p 0
            local found 1
            return local version "`M'.`m'.`p'"
            if `M' > 3 | (`M' == 3 & `m' > 6) | (`M' == 3 & `m' == 6 & `p' >= 1) local new 1
            if `M' < 3 | (`M' == 3 & `m' < 6) local old360 1
            continue, break
        }
    }
    file close `fh'
    * No version line found: recognise 3.6.1's type-first parser in the code.
    if !`found' {
        file open `fh' using `"`_fn'"', read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "gettoken type 0 : 0") {
                local new 1
                continue, break
            }
            file read `fh' line
        }
        file close `fh'
    }
    return scalar new = `new'
    return scalar old360 = `old360'
end
