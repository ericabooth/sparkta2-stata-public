*! sparkta2_writehtml v0.2.2  2026-06-26
*! Assemble the final self-contained HTML for a sparkta2 map.
*!
*! v0.2.2: forward projection / rotate / parallels / center option strings
*!   into the meta JSON so the engine's projection builder can apply them.
*!
*! v0.2.1: optional datatable + animate features.  Adds export-menu CSS,
*!   collapsible data-table container, and print-only stylesheet.
program define sparkta2_writehtml
    version 17.0
    syntax , TOPOPATH(string) ENGPATH(string) D3PATH(string) TCPATH(string) ///
        ROWJSON(string) METAJSON(string)                                     ///
        EXPORT(string) ISOFFline(integer)                                    ///
        TYPE(string) SCHEME(string) TITLE(string)                            ///
        XVAR(string)                                                         ///
        MODE(string) MODES(string)                                           ///
        ISSWap(integer) ISDOWNload(integer) ISCOMParable(integer)            ///
        ISMULTiples(integer) ISBASemap(integer)                              ///
        ISZoom(integer) ISSEArch(integer)                                    ///
        BINS(integer)                                                        ///
        WIDTH(integer) HEIGHT(integer)                                       ///
        IDWidth(integer)                                                     ///
        HEXRadius(integer) POINTSIze(integer)                                ///
        [HXPATH(string) GEO(string)                                          ///
         SUBtitle(string) NOTE(string) XLAbel(string) YLAbel(string)         ///
         YVAR(string) ZOOMTo(string) LAYer(string) HEXStat(string)           ///
         LATvar(string) LONvar(string)                                       ///
         ISDATAtable(integer 0) ISANImate(integer 0)                         ///
         ISTX2036Style(integer 0) DOWNLOADPos(string)                        ///
         PROJection(string) ROTATestr(string)                                ///
         PARALLELSstr(string) CENTERstr(string)]
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
    * tx2036style: pull Montserrat from Google Fonts (Texas 2036 brand body
    * font).  Offline mode falls back to system sans-serif via the
    * font-family stack below.
    if `istx2036style' {
        file write `fh' `"<link rel="preconnect" href="https://fonts.googleapis.com">"' _n
        file write `fh' `"<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>"' _n
        file write `fh' `"<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&display=swap" rel="stylesheet">"' _n
    }
    file write `fh' `"<style>"' _n
    file write `fh' `":root{--ink:#1B2D55;--accent:#D44500;--link:#2B6CB0;--bg:#F5F7FA;--muted:#6C7A8D;--card:#ffffff;--line:#e2e8f0;}"' _n
    if `istx2036style' {
        file write `fh' `"*{box-sizing:border-box;}body{margin:0;font-family:'Montserrat',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--ink);font-weight:400;letter-spacing:-0.005em;}"' _n
        file write `fh' `"h1{font-weight:700;letter-spacing:-0.01em;}"' _n
        file write `fh' `".controls h3{font-weight:600;}"' _n
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
    file write `fh' `".controls .row{display:flex;gap:6px;margin-top:8px;}"' _n
    file write `fh' `".modes{display:flex;flex-wrap:wrap;gap:4px;margin:6px 0 2px;}"' _n
    file write `fh' `".modes button{flex:1 1 auto;padding:4px 8px;font-size:.78rem;}"' _n
    file write `fh' `".modes button.active{background:var(--ink);color:#fff;border-color:var(--ink);}"' _n
    file write `fh' `".sliderbox{margin:8px 0 4px;}"' _n
    file write `fh' `".sliderbox .lbl{display:flex;justify-content:space-between;font-size:.78rem;color:var(--muted);}"' _n
    file write `fh' `".sliderbox .track{position:relative;height:6px;background:#e2e8f0;border-radius:3px;margin:6px 4px 0;}"' _n
    file write `fh' `".sliderbox .fill{position:absolute;top:0;height:100%;background:var(--ink);border-radius:3px;}"' _n
    file write `fh' `".sliderbox input[type=range]{position:absolute;top:-6px;left:-4px;width:calc(100% + 8px);height:18px;background:none;-webkit-appearance:none;pointer-events:none;}"' _n
    file write `fh' `".sliderbox input[type=range]::-webkit-slider-thumb{pointer-events:auto;-webkit-appearance:none;width:14px;height:14px;border-radius:50%;background:#fff;border:2px solid var(--ink);cursor:pointer;}"' _n
    file write `fh' `".sliderbox input[type=range]::-moz-range-thumb{pointer-events:auto;width:12px;height:12px;border-radius:50%;background:#fff;border:2px solid var(--ink);cursor:pointer;}"' _n
    file write `fh' `".meta{font-size:.78rem;color:var(--muted);margin-top:10px;}"' _n
    file write `fh' `".mapcard{padding:8px;}"' _n
    file write `fh' `".mapcard svg{display:block;width:100%;height:auto;}"' _n
    file write `fh' `"#panels{display:none;}"' _n
    file write `fh' `"#panels.active{display:grid;gap:12px;}"' _n
    file write `fh' `"#panels.active .panel{border:1px solid var(--line);border-radius:8px;padding:8px;background:#fff;}"' _n
    file write `fh' `"#panels.active .panel h4{margin:0 0 6px;font-size:.95rem;color:var(--ink);font-weight:600;}"' _n
    file write `fh' `"#panels.active .panel svg{display:block;width:100%;height:auto;}"' _n
    file write `fh' `".legend text{font:12px sans-serif;fill:#334155;}"' _n
    file write `fh' `".region{stroke:#fff;stroke-width:.45px;}"' _n
    file write `fh' `".region.dim{fill:#f1f5f9 !important;}"' _n
    file write `fh' `".region.hl{stroke:#0f172a;stroke-width:1.3px;}"' _n
    file write `fh' `"#tooltip{position:absolute;pointer-events:none;background:rgba(15,23,42,.94);color:#fff;padding:8px 10px;border-radius:6px;font-size:12px;line-height:1.4;opacity:0;transition:opacity .12s;max-width:280px;z-index:30;box-shadow:0 4px 10px rgba(0,0,0,.18);}"' _n
    file write `fh' `".note{margin-top:14px;color:var(--muted);font-size:.78rem;}"' _n
    * Under-chart export footer (downloadpos=below).  Drops in below the SVG
    * inside the chartcard, right-aligned, so the side controls column can
    * stay narrow (or collapse entirely when only View is active).
    file write `fh' `"#chart-footer{display:none;justify-content:flex-end;align-items:center;gap:8px;padding:8px 0 0;border-top:1px solid var(--line);margin-top:8px;}"' _n
    file write `fh' `"#chart-footer.active{display:flex;}"' _n
    file write `fh' `"#chart-footer button{padding:4px 10px;font-size:.8rem;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--ink);cursor:pointer;}"' _n
    file write `fh' `"#chart-footer button:hover{background:#eef2f7;}"' _n
    file write `fh' `"#chart-footer .exportmenu{position:relative;}"' _n
    file write `fh' `"#chart-footer .exportlist{left:auto;right:0;min-width:170px;}"' _n
    * When downloadpos=below and no other controls live in the side panel,
    * the layout collapses to a single column so the page doesn't reserve
    * the 240px sidebar.
    file write `fh' `".panels.no-sidebar{grid-template-columns:1fr !important;}"' _n
    file write `fh' `".controls.empty{display:none;}"' _n
    * Export menu (PNG/SVG/CSV/Print/View data) — dropdown anchored to the
    * "Export" button in the View controls section.
    file write `fh' `".exportmenu{position:relative;}"' _n
    file write `fh' `".exportbtn{width:100%;padding:6px 8px;font-size:.85rem;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--ink);cursor:pointer;text-align:left;}"' _n
    file write `fh' `".exportbtn:hover{background:#eef2f7;}"' _n
    file write `fh' `".exportlist{position:absolute;top:calc(100% + 4px);left:0;right:0;background:#fff;border:1px solid var(--line);border-radius:6px;box-shadow:0 4px 12px rgba(15,23,42,.12);z-index:40;display:flex;flex-direction:column;padding:4px;}"' _n
    file write `fh' `".exportlist button{width:100%;padding:6px 8px;font-size:.85rem;border:none;border-radius:4px;background:none;color:var(--ink);cursor:pointer;text-align:left;}"' _n
    file write `fh' `".exportlist button:hover{background:#eef2f7;}"' _n
    * Data-table panel (collapsible, full-width, below the chart).
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
    * Print stylesheet — for "Print to PDF…" via window.print().  Hide the
    * controls panel, the tooltip, and the data table so only the chart and
    * page header print.
    file write `fh' `"@media print {.controls{display:none !important;}#tooltip{display:none !important;}#datatable{display:none !important;}.panels{grid-template-columns:1fr !important;}body{background:#fff;}}"' _n
    file write `fh' `"</style>"' _n

    if `isoffline' {
        sparkta2_embedjs, fh(`fh') path("`d3path'")  outpath(`"`export'"')
        sparkta2_embedjs, fh(`fh') path("`tcpath'")  outpath(`"`export'"')
        if "`hxpath'" != "" {
            sparkta2_embedjs, fh(`fh') path("`hxpath'") outpath(`"`export'"')
        }
        sparkta2_embedjs, fh(`fh') path("`engpath'") outpath(`"`export'"')
    }
    else {
        file write `fh' `"<script src="https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"></script>"' _n
        file write `fh' `"<script src="https://cdn.jsdelivr.net/npm/topojson-client@3.1.0/dist/topojson-client.min.js"></script>"' _n
        file write `fh' `"<script src="https://cdn.jsdelivr.net/npm/d3-hexbin@0.2.2/build/d3-hexbin.min.js"></script>"' _n
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
    file write `fh' `"  <div class="card mapcard"><svg id="map"></svg><div id="panels"></div><div id="chart-footer"></div></div>"' _n
    file write `fh' `"</div>"' _n
    * Collapsible data-table container — populated by the JS engine on demand.
    file write `fh' `"<div id="datatable"></div>"' _n
    if "`note'" != "" {
        local esc_note : subinstr local note `"&"' `"&amp;"', all
        file write `fh' `"<p class="note">`esc_note'</p>"' _n
    }
    file write `fh' `"</div><div id="tooltip"></div>"' _n

    * --- Auto-resize messaging (same as chart writehtml) -----------------
    file write `fh' `"<script>"' _n
    file write `fh' `"(function(){if(window.parent===window)return;"' _n
    file write `fh' `"function r(){var h=Math.max(document.body.scrollHeight,document.documentElement.scrollHeight,document.body.offsetHeight,document.documentElement.offsetHeight);try{window.parent.postMessage({type:'sparkta2-resize',height:h},'*');}catch(e){}}"' _n
    file write `fh' `"window.addEventListener('load',function(){r();setTimeout(r,400);setTimeout(r,1200);setTimeout(r,2500);});"' _n
    file write `fh' `"window.addEventListener('resize',r);"' _n
    file write `fh' `"if(typeof MutationObserver!=='undefined'){new MutationObserver(r).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['style','class']});}"' _n
    file write `fh' `"})();"' _n
    file write `fh' `"</script>"' _n

    file write `fh' `"<script>"' _n
    file write `fh' `"window.__SPARKTA2__ = {"' _n
    file write `fh' `""meta":{"' _n
    file write `fh' `""type":"`type'","scheme":"`scheme'","' _n
    file write `fh' `""xvar":"`xvar'","yvar":"`yvar'","' _n
    file write `fh' `""xlabel":"`xlabel'","ylabel":"`ylabel'","' _n
    file write `fh' `""mode":"`mode'","modes":"`modes'","' _n
    file write `fh' `""comparable":`iscomparable',"swap":`isswap',"download":`isdownload',"multiples":`ismultiples',"' _n
    file write `fh' `""datatable":`isdatatable',"animate":`isanimate',"' _n
    file write `fh' `""tx2036style":`istx2036style',"downloadpos":"`downloadpos'","' _n
    file write `fh' `""projection":"`projection'","rotate":"`rotatestr'","parallels":"`parallelsstr'","center":"`centerstr'","' _n
    file write `fh' `""zoom":`iszoom',"search":`issearch',"basemap":`isbasemap',"zoomto":"`zoomto'","' _n
    file write `fh' `""layer":"`layer'","geo":"`geo'","idwidth":`idwidth',"' _n
    file write `fh' `""hexradius":`hexradius',"hexstat":"`hexstat'","pointsize":`pointsize',"' _n
    file write `fh' `""latvar":"`latvar'","lonvar":"`lonvar'","' _n
    file write `fh' `""bins":`bins',"width":`width',"height":`height'"' _n
    file write `fh' `"},"' _n
    file write `fh' `""controls":"' _n
    sparkta2_appendfile, fh(`fh') path("`metajson'") outpath(`"`export'"')
    file write `fh' `","' _n
    file write `fh' `""data":["' _n
    sparkta2_appendfile, fh(`fh') path("`rowjson'") outpath(`"`export'"')
    file write `fh' `"],"' _n
    file write `fh' `""topo":"' _n
    sparkta2_appendfile, fh(`fh') path("`topopath'") outpath(`"`export'"')
    file write `fh' _n `"};"' _n
    file write `fh' `"sparkta2Render(window.__SPARKTA2__);"' _n
    file write `fh' `"</script></body></html>"' _n
    file close `fh'
end
