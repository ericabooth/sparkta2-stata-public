*! sparkta2_dashboard v0.7.8  2026-06-26
*! Compose a scrollable single-page dashboard that embeds a list of
*! sparkta2 map / chart HTML files via <iframe>. Each section is
*! self-contained; filters/zoom/etc. work independently per iframe.
*!
*! v0.4.0: tx2036style option (Texas 2036 brand + Montserrat for the
*!         wrapper page); default iframe height bumped 920 -> 1060
*!         (~15% taller) to reduce the amount of scrolling per section.
*!
*! Usage:
*!   sparkta2_dashboard,                                                   ///
*!       files("map1.html map2.html map3.html")                            ///
*!       titles("Bivariate full UI|Univariate poverty|Small multiples")    ///
*!       export("dashboard.html")                                           ///
*!       title("Texas counties: sparkta2 demo gallery")
*!
*! Notes:
*!   - `files()` is space-sep paths. Relative paths resolved against the
*!     dashboard's parent directory at runtime (each iframe src is taken
*!     verbatim, so just pass basenames if the dashboard sits in the same
*!     folder as the map files).
*!   - `titles()` is a pipe-separated list -- one title per file. Optional;
*!     defaults to the basename of each file.
*!   - `heights()` is space-sep pixel heights (one per file); single number
*!     applies to all. Default 920.
program define sparkta2_dashboard, rclass
    version 17.0

    syntax , FILES(string) EXPORT(string) [TITLE(string) SUBtitle(string) ///
        TITLES(string) HEIGHTS(string) NOOPEN TX2036STyle]

    local is_tx2036st = cond("`tx2036style'" != "", 1, 0)

    if "`title'" == "" local title "sparkta2 dashboard"

    * Parse file list
    local _flist = itrim("`files'")
    local _nfiles = wordcount("`_flist'")
    if `_nfiles' == 0 {
        display as error "sparkta2_dashboard: files() must contain at least one path"
        exit 198
    }

    * Parse titles list (pipe-sep) into _title1, _title2, ...
    local _ntitles = 0
    if "`titles'" != "" {
        local _trest `"`titles'"'
        local _ntitles = 0
        local _tpos = strpos(`"`_trest'"', "|")
        while `_tpos' > 0 {
            local ++_ntitles
            local _title`_ntitles' = strtrim(substr(`"`_trest'"', 1, `_tpos' - 1))
            local _trest = substr(`"`_trest'"', `_tpos' + 1, .)
            local _tpos = strpos(`"`_trest'"', "|")
        }
        local ++_ntitles
        local _title`_ntitles' = strtrim(`"`_trest'"')
    }

    * Heights: single number -> apply to all; multiple -> per-file.
    * Default bumped from 920 to 1060 in v0.4.0 (~15% taller) so each
    * embedded chart shows more vertically before the reader scrolls.
    if "`heights'" == "" local heights "1060"
    local _hlist = itrim("`heights'")
    local _nhts = wordcount("`_hlist'")

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
    * tx2036style: pull Montserrat from Google Fonts for the wrapper page.
    * Inner iframes are independent documents and bring their own typography
    * (each chart/map sets its own font stack via its writehtml).
    if `is_tx2036st' {
        file write `fh' `"<link rel="preconnect" href="https://fonts.googleapis.com">"' _n
        file write `fh' `"<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>"' _n
        file write `fh' `"<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&display=swap" rel="stylesheet">"' _n
    }
    file write `fh' `"<style>"' _n
    file write `fh' `":root{--ink:#1B2D55;--accent:#D44500;--link:#2B6CB0;--bg:#F5F7FA;--muted:#6C7A8D;--card:#fff;--line:#e2e8f0;}"' _n
    if `is_tx2036st' {
        file write `fh' `"*{box-sizing:border-box}body{margin:0;font-family:'Montserrat',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--ink);font-weight:400;letter-spacing:-0.005em}"' _n
        file write `fh' `"header h1{font-weight:700;letter-spacing:-0.01em}"' _n
        file write `fh' `".section h2{font-weight:600}"' _n
    }
    else {
        file write `fh' `"*{box-sizing:border-box}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--ink)}"' _n
    }
    file write `fh' `".wrap{max-width:1300px;margin:0 auto;padding:24px 18px 60px}"' _n
    file write `fh' `"header h1{font-size:1.7rem;margin:0 0 4px;color:var(--ink)}"' _n
    file write `fh' `"header p{color:var(--muted);margin:0 0 22px;font-size:.95rem}"' _n
    file write `fh' `".section{background:var(--card);border:1px solid var(--line);border-radius:12px;margin:0 0 22px;overflow:hidden;box-shadow:0 1px 2px rgba(15,23,42,.05)}"' _n
    file write `fh' `".section h2{margin:0;padding:12px 16px;font-size:1.05rem;background:#fff;color:var(--ink);border-bottom:1px solid var(--line)}"' _n
    file write `fh' `".section h2 .num{display:inline-block;color:var(--accent);font-weight:700;margin-right:8px}"' _n
    file write `fh' `".section h2 .src{color:var(--muted);font-size:.78rem;font-weight:400;margin-left:8px}"' _n
    file write `fh' `".section iframe{display:block;width:100%;border:0}"' _n
    file write `fh' `"nav.toc{position:sticky;top:8px;background:rgba(255,255,255,.92);backdrop-filter:saturate(120%) blur(6px);border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin:0 0 18px;font-size:.85rem}"' _n
    file write `fh' `"nav.toc strong{display:block;color:var(--muted);text-transform:uppercase;letter-spacing:.05em;font-size:.72rem;margin-bottom:4px}"' _n
    file write `fh' `"nav.toc a{color:var(--link);text-decoration:none;margin-right:14px;display:inline-block;margin-bottom:2px}"' _n
    file write `fh' `"nav.toc a:hover{text-decoration:underline}"' _n
    file write `fh' `"footer{color:var(--muted);font-size:.78rem;margin-top:30px}"' _n
    file write `fh' `"</style></head><body>"' _n
    file write `fh' `"<div class="wrap">"' _n
    file write `fh' `"<header><h1>`esc_title'</h1>"' _n
    if "`subtitle'" != "" {
        local esc_sub : subinstr local subtitle `"&"' `"&amp;"', all
        file write `fh' `"<p>`esc_sub'</p>"' _n
    }
    file write `fh' `"</header>"' _n

    * Table of contents
    file write `fh' `"<nav class="toc"><strong>Jump to:</strong>"' _n
    forvalues _i = 1/`_nfiles' {
        local _fpath = word("`_flist'", `_i')
        local _basename = substr("`_fpath'", strrpos("`_fpath'", "/") + 1, .)
        if `_i' <= `_ntitles' & "`_title`_i''" != "" {
            local _tname "`_title`_i''"
        }
        else local _tname "`_basename'"
        file write `fh' `"  <a href="#sec`_i'">`_i'. `_tname'</a>"' _n
    }
    file write `fh' `"</nav>"' _n

    * Sections
    forvalues _i = 1/`_nfiles' {
        local _fpath = word("`_flist'", `_i')
        local _basename = substr("`_fpath'", strrpos("`_fpath'", "/") + 1, .)
        if `_i' <= `_ntitles' & "`_title`_i''" != "" {
            local _tname "`_title`_i''"
        }
        else local _tname "`_basename'"
        if `_nhts' == 1 local _height = word("`_hlist'", 1)
        else if `_nhts' >= `_i' local _height = word("`_hlist'", `_i')
        else local _height = word("`_hlist'", `_nhts')
        file write `fh' `"<section class="section" id="sec`_i'">"' _n
        file write `fh' `"  <h2><span class="num">`_i'.</span>`_tname'<span class="src">`_basename'</span></h2>"' _n
        * scrolling="no" + auto-resize listener below means the iframe grows
        * to fit its content; the height attr is just an initial guess.
        file write `fh' `"  <iframe src="`_basename'" height="`_height'" scrolling="no" loading="lazy"></iframe>"' _n
        file write `fh' `"</section>"' _n
    }

    file write `fh' `"<footer>Built with sparkta2 v0.7.8 — each section is an independent interactive map / chart.</footer>"' _n
    * Auto-resize listener: every embedded sparkta2 page posts its content
    * height back to the parent; we grow the matching iframe to fit.
    file write `fh' `"<script>"' _n
    file write `fh' `"window.addEventListener('message',function(e){"' _n
    file write `fh' `"if(!e.data||e.data.type!=='sparkta2-resize')return;"' _n
    file write `fh' `"var ifrs=document.querySelectorAll('iframe');"' _n
    file write `fh' `"for(var i=0;i<ifrs.length;i++){"' _n
    file write `fh' `"if(ifrs[i].contentWindow===e.source){ifrs[i].style.height=(e.data.height+12)+'px';ifrs[i].setAttribute('scrolling','no');break;}"' _n
    file write `fh' `"}});"' _n
    file write `fh' `"</script>"' _n
    file write `fh' `"</div></body></html>"' _n
    file close `fh'

    display as text _n "[sparkta2_dashboard]  combined `_nfiles' maps:"
    display as text `"  {browse "`export'":`export'}"'

    return local export "`export'"
    return scalar n_files = `_nfiles'

    if "`noopen'" == "" {
        sparkta2_open, file(`"`export'"')
    }
end
