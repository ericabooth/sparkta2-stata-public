*! sparkta2_chart_writehtml v0.7.0  2026-06-26
*! Assemble the self-contained HTML for a sparkta2 native chart
*! (donut | bar | line | divbar | barrace).
*!
*! Mirrors the page structure of sparkta2_writehtml.ado (Texas 2036 brand
*! tokens, Export menu CSS, datatable CSS, print stylesheet) but omits the
*! map-specific machinery (topojson, hexbin, projection, layer selection)
*! since the chart engine doesn't need any of it.

program define sparkta2_chart_writehtml
    version 17.0
    syntax , ENGPATH(string) D3PATH(string)                              ///
        ROWJSON(string) TIPJSON(string)                                  ///
        EXPORT(string) ISOFFline(integer)                                ///
        TYPE(string) SCHEME(string) TITLE(string)                        ///
        XVAR(string)                                                     ///
        HORIzontal(integer) STACKed(integer)                             ///
        NORMAlize(integer) SUPPRESSaxis(integer)                         ///
        DIRECTlabels(integer)                                            ///
        INNERradius(real) TOP(integer) FPS(integer)                      ///
        DURation(real)                                                   ///
        ISDOWNload(integer) ISDATAtable(integer) ISANImate(integer)      ///
        ISTX2036Style(integer) DOWNLOADPos(string)                       ///
        WIDTH(integer) HEIGHT(integer)                                   ///
        [ SUBtitle(string) NOTE(string)                                  ///
          XLAbel(string) YLAbel(string)                                  ///
          YVAR(string) NAME(string) OVER(string)                         ///
          LEVel(string) TIME(string)                                     ///
          LEVELORDer(string) CENTERlevel(string)                         ///
          SORTEDstr(string)                                              ///
          WRAPlabel(string) GUTTERwidth(integer 0) ]
    if "`downloadpos'" == "" local downloadpos "side"

    tempname fh
    file open `fh' using `"`export'"', write text replace

    local esc_title : subinstr local title `"&"' `"&amp;"', all
    local esc_title : subinstr local esc_title `"<"' `"&lt;"', all
    local esc_title : subinstr local esc_title `">"' `"&gt;"', all

    file write `fh' `"<!DOCTYPE html>"' _n
    file write `fh' `"<html lang="en"><head>"' _n
    file write `fh' `"<meta charset="utf-8">"' _n
    file write `fh' `"<meta name="viewport" content="width=device-width, initial-scale=1">"' _n
    file write `fh' `"<title>`esc_title'</title>"' _n
    * tx2036style: Montserrat from Google Fonts (Texas 2036 brand body font).
    if `istx2036style' {
        file write `fh' `"<link rel="preconnect" href="https://fonts.googleapis.com">"' _n
        file write `fh' `"<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>"' _n
        file write `fh' `"<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&display=swap" rel="stylesheet">"' _n
    }
    file write `fh' `"<style>"' _n
    * Texas 2036 brand tokens (matches the map writehtml)
    file write `fh' `":root{--ink:#1B2D55;--accent:#D44500;--link:#2B6CB0;--bg:#F5F7FA;--muted:#6C7A8D;--card:#ffffff;--line:#e2e8f0;}"' _n
    if `istx2036style' {
        file write `fh' `"*{box-sizing:border-box;}body{margin:0;font-family:'Montserrat',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--ink);font-weight:400;letter-spacing:-0.005em;}"' _n
        file write `fh' `"h1{font-weight:700;letter-spacing:-0.01em;}"' _n
        file write `fh' `".controls h3{font-weight:600;}"' _n
        * SVG text deliberately stays on the system stack so getComputedTextLength
        * measurements (used by the divbar wrap, donut label suppression, etc.)
        * stay stable across the Google Fonts async load.  HTML title/subtitle
        * still gets Montserrat from the body rule above.
    }
    else {
        file write `fh' `"*{box-sizing:border-box;}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--ink);}"' _n
    }
    file write `fh' `".wrap{max-width:1180px;margin:0 auto;padding:24px 18px 48px;}"' _n
    file write `fh' `"h1{font-size:1.5rem;margin:0 0 4px;color:var(--ink);}"' _n
    file write `fh' `".sub{color:var(--muted);margin:0 0 16px;font-size:.95rem;}"' _n
    file write `fh' `".panels{display:grid;grid-template-columns:240px 1fr;gap:18px;align-items:start;}"' _n
    file write `fh' `"@media (max-width:780px){.panels{grid-template-columns:1fr;}}"' _n
    file write `fh' `".card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;box-shadow:0 1px 2px rgba(15,23,42,.05);}"' _n
    file write `fh' `".controls h3{font-size:.78rem;text-transform:uppercase;letter-spacing:.05em;margin:0 0 6px;color:var(--muted);}"' _n
    file write `fh' `".controls label{display:block;font-size:.85rem;margin:8px 0 2px;color:var(--ink);font-weight:500;}"' _n
    file write `fh' `".controls select,.controls button{width:100%;padding:6px 8px;font-size:.85rem;border:1px solid var(--line);border-radius:6px;background:#fff;}"' _n
    file write `fh' `".controls button{cursor:pointer;background:#fff;color:var(--ink);transition:background .12s;}"' _n
    file write `fh' `".controls button:hover{background:#eef2f7;}"' _n
    file write `fh' `".meta{font-size:.78rem;color:var(--muted);margin-top:10px;}"' _n
    file write `fh' `".chartcard{padding:14px;}"' _n
    file write `fh' `".chartcard svg{display:block;width:100%;height:auto;}"' _n
    file write `fh' `".chartcard .axis text{font:11px sans-serif;fill:#475569;}"' _n
    file write `fh' `".chartcard .axis path,.chartcard .axis line{stroke:#cbd5e1;}"' _n
    file write `fh' `".chartcard .bar{stroke:#fff;stroke-width:.5px;}"' _n
    file write `fh' `".chartcard .slice{stroke:#fff;stroke-width:1.5px;}"' _n
    file write `fh' `".chartcard .label{font:11px sans-serif;fill:#1f2937;pointer-events:none;}"' _n
    file write `fh' `".chartcard .label-light{fill:#fff;}"' _n
    file write `fh' `".chartcard .item-label{font:12px sans-serif;fill:#1f2937;}"' _n
    file write `fh' `".chartcard .legend text{font:11px sans-serif;fill:#334155;}"' _n
    file write `fh' `".chartcard .zero{stroke:#475569;stroke-width:1px;stroke-dasharray:none;}"' _n
    file write `fh' `".chartcard .race-time{font:30px sans-serif;font-weight:700;fill:#94a3b8;text-anchor:end;}"' _n
    file write `fh' `"#tooltip{position:absolute;pointer-events:none;background:rgba(15,23,42,.94);color:#fff;padding:8px 10px;border-radius:6px;font-size:12px;line-height:1.4;opacity:0;transition:opacity .12s;max-width:280px;z-index:30;box-shadow:0 4px 10px rgba(0,0,0,.18);}"' _n
    file write `fh' `".note{margin-top:14px;color:var(--muted);font-size:.78rem;}"' _n
    * Under-chart export footer (downloadpos=below).
    file write `fh' `"#chart-footer{display:none;justify-content:flex-end;align-items:center;gap:8px;padding:8px 0 0;border-top:1px solid var(--line);margin-top:8px;}"' _n
    file write `fh' `"#chart-footer.active{display:flex;}"' _n
    file write `fh' `"#chart-footer button{padding:4px 10px;font-size:.8rem;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--ink);cursor:pointer;}"' _n
    file write `fh' `"#chart-footer button:hover{background:#eef2f7;}"' _n
    file write `fh' `"#chart-footer .exportmenu{position:relative;}"' _n
    file write `fh' `"#chart-footer .exportlist{left:auto;right:0;min-width:170px;}"' _n
    file write `fh' `".panels.no-sidebar{grid-template-columns:1fr !important;}"' _n
    file write `fh' `".controls.empty{display:none;}"' _n
    * Export menu (PNG/SVG/CSV/Print/View data) — same shape as the map writehtml
    file write `fh' `".exportmenu{position:relative;}"' _n
    file write `fh' `".exportbtn{width:100%;padding:6px 8px;font-size:.85rem;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--ink);cursor:pointer;text-align:left;}"' _n
    file write `fh' `".exportbtn:hover{background:#eef2f7;}"' _n
    file write `fh' `".exportlist{position:absolute;top:calc(100% + 4px);left:0;right:0;background:#fff;border:1px solid var(--line);border-radius:6px;box-shadow:0 4px 12px rgba(15,23,42,.12);z-index:40;display:flex;flex-direction:column;padding:4px;}"' _n
    file write `fh' `".exportlist button{width:100%;padding:6px 8px;font-size:.85rem;border:none;border-radius:4px;background:none;color:var(--ink);cursor:pointer;text-align:left;}"' _n
    file write `fh' `".exportlist button:hover{background:#eef2f7;}"' _n
    * Data-table panel
    file write `fh' `"#datatable{display:none;margin-top:14px;border:1px solid var(--line);border-radius:8px;background:#fff;}"' _n
    file write `fh' `"#datatable.open{display:block;}"' _n
    file write `fh' `"#datatable .dt-header{display:flex;align-items:center;justify-content:space-between;padding:8px 12px;border-bottom:1px solid var(--line);background:#f8fafc;border-radius:8px 8px 0 0;font-size:.9rem;}"' _n
    file write `fh' `"#datatable .dt-count{color:var(--muted);font-size:.8rem;font-weight:normal;margin-left:8px;}"' _n
    file write `fh' `"#datatable .dt-close{background:none;border:none;font-size:1.3rem;line-height:1;cursor:pointer;color:var(--muted);padding:0 4px;}"' _n
    file write `fh' `"#datatable .dt-scroll{max-height:360px;overflow:auto;}"' _n
    file write `fh' `"#datatable table.dt-table{width:100%;border-collapse:collapse;font-size:.8rem;}"' _n
    file write `fh' `"#datatable .dt-table th{position:sticky;top:0;background:#fff;border-bottom:1px solid var(--line);padding:6px 10px;text-align:left;font-weight:600;color:var(--ink);white-space:nowrap;}"' _n
    file write `fh' `"#datatable .dt-table td{padding:5px 10px;border-bottom:1px solid #f1f5f9;color:#334155;}"' _n
    file write `fh' `"#datatable .dt-table tr:hover td{background:#f8fafc;}"' _n
    file write `fh' `"#datatable .dt-truncated{padding:8px 12px;border-top:1px solid var(--line);color:var(--muted);font-size:.78rem;background:#f8fafc;border-radius:0 0 8px 8px;}"' _n
    * Print stylesheet
    file write `fh' `"@media print {.controls{display:none !important;}#tooltip{display:none !important;}#datatable{display:none !important;}.panels{grid-template-columns:1fr !important;}body{background:#fff;}}"' _n
    file write `fh' `"</style>"' _n

    if `isoffline' {
        sparkta2_embedjs, fh(`fh') path("`d3path'")  outpath(`"`export'"')
        sparkta2_embedjs, fh(`fh') path("`engpath'") outpath(`"`export'"')
    }
    else {
        file write `fh' `"<script src="https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"></script>"' _n
        sparkta2_embedjs, fh(`fh') path("`engpath'") outpath(`"`export'"')
    }

    file write `fh' `"</head><body>"' _n
    file write `fh' `"<div class="wrap">"' _n
    file write `fh' `"<h1>`esc_title'</h1>"' _n
    if "`subtitle'" != "" {
        local esc_sub : subinstr local subtitle `"&"' `"&amp;"', all
        file write `fh' `"<p class="sub">`esc_sub'</p>"' _n
    }
    file write `fh' `"<div class="panels">"' _n
    file write `fh' `"  <div class="card controls" id="controls"></div>"' _n
    file write `fh' `"  <div class="card chartcard"><svg id="chart"></svg><div id="chart-footer"></div></div>"' _n
    file write `fh' `"</div>"' _n
    file write `fh' `"<div id="datatable"></div>"' _n
    if "`note'" != "" {
        local esc_note : subinstr local note `"&"' `"&amp;"', all
        file write `fh' `"<p class="note">`esc_note'</p>"' _n
    }
    file write `fh' `"</div><div id="tooltip"></div>"' _n

    * --- Auto-resize messaging ------------------------------------------
    * When this page is embedded in an iframe (e.g. inside sparkta2_dashboard
    * or a webdoc2 page), it posts its total content height to the parent so
    * the parent can grow the iframe accordingly and the chart never gets
    * clipped behind a scrollbar.  Standalone (not embedded), the function
    * short-circuits via the `window.parent === window` check.
    file write `fh' `"<script>"' _n
    file write `fh' `"(function(){if(window.parent===window)return;"' _n
    file write `fh' `"function r(){var h=Math.max(document.body.scrollHeight,document.documentElement.scrollHeight,document.body.offsetHeight,document.documentElement.offsetHeight);try{window.parent.postMessage({type:'sparkta2-resize',height:h},'*');}catch(e){}}"' _n
    file write `fh' `"window.addEventListener('load',function(){r();setTimeout(r,400);setTimeout(r,1200);setTimeout(r,2500);});"' _n
    file write `fh' `"window.addEventListener('resize',r);"' _n
    file write `fh' `"if(typeof MutationObserver!=='undefined'){new MutationObserver(r).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['style','class']});}"' _n
    file write `fh' `"})();"' _n
    file write `fh' `"</script>"' _n

    * --- The JSON payload ------------------------------------------------
    file write `fh' `"<script>"' _n
    file write `fh' `"window.__SPARKTA2_CHART__ = {"' _n
    file write `fh' `""meta":{"' _n
    file write `fh' `""type":"`type'","scheme":"`scheme'","' _n
    file write `fh' `""xvar":"`xvar'","yvar":"`yvar'","' _n
    file write `fh' `""xlabel":"`xlabel'","ylabel":"`ylabel'","' _n
    file write `fh' `""name":"`name'","over":"`over'","' _n
    file write `fh' `""level":"`level'","time":"`time'","' _n
    file write `fh' `""levelorder":"`levelorder'","centerlevel":"`centerlevel'","' _n
    file write `fh' `""horizontal":`horizontal',"stacked":`stacked',"normalize":`normalize',"' _n
    file write `fh' `""suppressaxis":`suppressaxis',"directlabels":`directlabels',"' _n
    file write `fh' `""innerradius":`innerradius',"top":`top',"fps":`fps',"duration":`duration',"' _n
    file write `fh' `""sorted":"`sortedstr'","' _n
    file write `fh' `""download":`isdownload',"datatable":`isdatatable',"animate":`isanimate',"' _n
    file write `fh' `""tx2036style":`istx2036style',"downloadpos":"`downloadpos'","' _n
    file write `fh' `""labelwrap":"`wraplabel'","labelwidth":`gutterwidth',"' _n
    file write `fh' `""width":`width',"height":`height'"' _n
    file write `fh' `"},"' _n
    file write `fh' `""tooltipvars":"' _n
    sparkta2_appendfile, fh(`fh') path("`tipjson'") outpath(`"`export'"')
    file write `fh' `","' _n
    file write `fh' `""data":["' _n
    sparkta2_appendfile, fh(`fh') path("`rowjson'") outpath(`"`export'"')
    file write `fh' `"]"' _n
    file write `fh' `"};"' _n
    file write `fh' `"sparkta2RenderChart(window.__SPARKTA2_CHART__);"' _n
    file write `fh' `"</script></body></html>"' _n
    file close `fh'
end
