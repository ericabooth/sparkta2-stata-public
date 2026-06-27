*! sparkta2 v0.7.8  2026-06-26
*! sparkta + interactive choropleth maps + native D3 charts in one command.
*!
*! Dispatcher:
*!   type(map|bivariate|choropleth|hexbin|points)     -> sparkta2_map   (D3 map engine)
*!   type(donut|divbar|barrace|bar2|line2)            -> sparkta2_chart (D3 chart engine)
*!   everything else (incl. bar, line, scatter, ...)  -> sparkta (Fahad Mirza)
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

    local sparkta2_version "0.7.8"
    display as text "  [sparkta2 v`sparkta2_version']"

    * Peek at user-supplied type() without consuming any args.
    * If it's a map type, dispatch to sparkta2_map. Otherwise forward to sparkta.
    local _raw `"`0'"'
    local _peek_type ""
    local _lc = lower(`"`_raw'"')
    local _pos = strpos(`"`_lc'"', "type(")
    if `_pos' > 0 {
        local _rest = substr(`"`_raw'"', `_pos' + 5, .)
        local _endpos = strpos(`"`_rest'"', ")")
        if `_endpos' > 0 {
            local _peek_type = lower(strtrim(substr(`"`_rest'"', 1, `_endpos' - 1)))
        }
    }

    local _map_types          "map bivariate choropleth bivariatemap univariate hexbin points point"
    local _native_chart_types "donut divbar barrace bar2 line2"
    if `:list _peek_type in _map_types' {
        sparkta2_map `0'
        exit
    }
    if `:list _peek_type in _native_chart_types' {
        sparkta2_chart `0'
        exit
    }

    capture which sparkta
    if _rc {
        display as error "sparkta2: type(`_peek_type') needs sparkta.ado to be installed."
        display as error "  Install sparkta first (https://github.com/fahad-mirza/sparkta_stata)"
        display as error "  or use a sparkta2-native type:"
        display as error "    Maps:   map | bivariate | choropleth | hexbin | points"
        display as error "    Charts: donut | divbar | barrace | bar2 | line2"
        exit 199
    }
    sparkta `0'
end
