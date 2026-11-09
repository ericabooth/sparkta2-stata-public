*! sparkta2_dashboard v0.8.11  2026-11-09
*! v0.8.11 2026-11-09: files() takes quoted paths, so paths with spaces
*!   work; each iframe src is written relative to the dashboard's folder
*!   (pages in other folders, Windows backslash paths and ~ now load);
*!   titles and the subtitle are HTML-escaped.
*!   Default look changed: neutral page colors; the house colors and
*!   Montserrat are written only with tx2036style.
*! v0.8.6 2026-11-08: option names now read the same on every Stata version.
*!   Older Stata kept the capitals after a digit (TX2036STyle, D3PATH,
*!   ISTX2036Style), so tx2036style was "not allowed" and internal calls
*!   failed with "option ... required"; the tails are now lowercase.
*! Compose a scrollable single-page dashboard that embeds a list of
*! sparkta2 map / chart HTML files via <iframe>. Each section is
*! self-contained; filters/zoom/etc. work independently per iframe.
*!
*! v0.8.0: tabs option -- replace the anchor-link TOC with a dashtab-style
*!         tab bar (same underline look as sparkta2_writehtml's .dashtabs);
*!         one section visible at a time, others get a hide class. This is
*!         the composition path for dashtab-like switching across sparkta
*!         pass-through charts (which cannot use the native dashtab()
*!         option). Default (no tabs) layout unchanged: long scroll + TOC.
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
*!   - `files()` is a space-separated list of paths; quote a path that
*!     contains spaces.  A relative path is read from the working folder
*!     (or, failing that, from the dashboard's folder).  Each iframe src is
*!     written relative to the dashboard's folder, so keep the pages and
*!     the dashboard together when you move them.
*!   - `titles()` is a pipe-separated list -- one title per file. Optional;
*!     defaults to the basename of each file.
*!   - `heights()` is space-sep pixel heights (one per file); single number
*!     applies to all. Default 1060.
program define sparkta2_dashboard, rclass
    version 17.0

    syntax , FILES(string) EXPORT(string) [TITLE(string) SUBtitle(string) ///
        TITLES(string) HEIGHTS(string) NOOPEN TX2036style TABS]

    local is_tx2036st = cond("`tx2036style'" != "", 1, 0)
    local is_tabs = cond("`tabs'" != "", 1, 0)

    if "`title'" == "" local title "sparkta2 dashboard"

    * Parse file list.  gettoken keeps a quoted path (one with spaces) as
    * one entry and strips its quotes.
    local _nfiles 0
    local _frest `"`macval(files)'"'
    while `"`macval(_frest)'"' != "" {
        gettoken _f _frest : _frest
        if `"`macval(_f)'"' == "" continue
        local ++_nfiles
        local _file`_nfiles' `"`macval(_f)'"'
    }
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

    * iframe src for each page, relative to the dashboard's folder
    if "`c(os)'" == "Windows" local _home : environment USERPROFILE
    else                      local _home : environment HOME
    mata: _s2d_srcs(`_nfiles')
    forvalues _i = 1/`_nfiles' {
        if `_miss`_i'' {
            display as text `"  (note: `macval(_file`_i')' was not found; its src is written as given, relative to the dashboard)"'
        }
    }

    * Heights: single number -> apply to all; multiple -> per-file.
    * Default bumped from 920 to 1060 in v0.4.0 (~15% taller) so each
    * embedded chart shows more vertically before the reader scrolls.
    if "`heights'" == "" local heights "1060"
    local _hlist = itrim("`heights'")
    local _nhts = wordcount("`_hlist'")

    tempname fh
    quietly file open `fh' using `"`export'"', write text replace
    * Give embedded pages a build-specific query string. This prevents a
    * browser from retaining an earlier map after its HTML file is rebuilt.
    local _cachedate = subinstr("`c(current_date)'", " ", "", .)
    local _cachetime = subinstr("`c(current_time)'", ":", "", .)
    local _cachetag "`_cachedate'`_cachetime'"

    mata: st_local("esc_title", _s2d_html(st_local("title")))

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
    * Page color tokens: neutral by default; the authors' house colors
    * only with tx2036style.
    if `is_tx2036st' {
        file write `fh' `":root{--ink:#1B2D55;--accent:#D44500;--link:#2B6CB0;--bg:#F5F7FA;--muted:#6C7A8D;--card:#fff;--line:#e2e8f0;}"' _n
    }
    else {
        file write `fh' `":root{--ink:#202124;--accent:#1a73e8;--link:#1a73e8;--bg:#f8f9fa;--muted:#5f6368;--card:#fff;--line:#e2e8f0;}"' _n
    }
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
    * tabs layout: button styles copied from sparkta2_writehtml's .dashtabs
    * (underline-tab look, --accent active) so the two look identical; the
    * bar itself is sticky like nav.toc above. .hide hides inactive sections.
    if `is_tabs' {
        file write `fh' `".dashtabs{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 18px;border-bottom:2px solid var(--line);position:sticky;top:8px;z-index:10;background:rgba(255,255,255,.92);backdrop-filter:saturate(120%) blur(6px);border-radius:10px 10px 0 0;padding:4px 8px 0;}"' _n
        file write `fh' `".dashtabs button{appearance:none;background:none;border:none;border-bottom:3px solid transparent;padding:8px 14px;font-size:.92rem;font-weight:600;color:var(--muted);cursor:pointer;margin-bottom:-2px;font-family:inherit;}"' _n
        file write `fh' `".dashtabs button:hover{color:var(--ink);}"' _n
        file write `fh' `".dashtabs button.active{color:var(--accent);border-bottom-color:var(--accent);}"' _n
        file write `fh' `".hide{display:none!important}"' _n
    }
    file write `fh' `"footer{color:var(--muted);font-size:.78rem;margin-top:30px}"' _n
    file write `fh' `"</style></head><body>"' _n
    file write `fh' `"<div class="wrap">"' _n
    file write `fh' `"<header><h1>`esc_title'</h1>"' _n
    if "`subtitle'" != "" {
        mata: st_local("esc_sub", _s2d_html(st_local("subtitle")))
        file write `fh' `"<p>`esc_sub'</p>"' _n
    }
    file write `fh' `"</header>"' _n

    * Navigation: tab bar (tabs) or anchor-link table of contents (default)
    if `is_tabs' {
        file write `fh' `"<div class="dashtabs" id="dashtabs">"' _n
        forvalues _i = 1/`_nfiles' {
            local _basename `"`macval(_base`_i')'"'
            if `_i' <= `_ntitles' & `"`macval(_title`_i')'"' != "" {
                mata: st_local("_tname", _s2d_html(st_local("_title`_i'")))
            }
            else local _tname `"`macval(_basename)'"'
            if `_i' == 1 local _act `" class="active""'
            else local _act ""
            file write `fh' `"  <button type="button" data-target="sec`_i'"`_act'>`_tname'</button>"' _n
        }
        file write `fh' `"</div>"' _n
    }
    else {
        file write `fh' `"<nav class="toc"><strong>Jump to:</strong>"' _n
        forvalues _i = 1/`_nfiles' {
            local _basename `"`macval(_base`_i')'"'
            if `_i' <= `_ntitles' & `"`macval(_title`_i')'"' != "" {
                mata: st_local("_tname", _s2d_html(st_local("_title`_i'")))
            }
            else local _tname `"`macval(_basename)'"'
            file write `fh' `"  <a href="#sec`_i'">`_i'. `_tname'</a>"' _n
        }
        file write `fh' `"</nav>"' _n
    }

    * Sections
    forvalues _i = 1/`_nfiles' {
        local _basename `"`macval(_base`_i')'"'
        if `_i' <= `_ntitles' & `"`macval(_title`_i')'"' != "" {
            mata: st_local("_tname", _s2d_html(st_local("_title`_i'")))
        }
        else local _tname `"`macval(_basename)'"'
        if `_nhts' == 1 local _height = word("`_hlist'", 1)
        else if `_nhts' >= `_i' local _height = word("`_hlist'", `_i')
        else local _height = word("`_hlist'", `_nhts')
        * tabs: only the first section visible on load; the rest start hidden
        local _hide ""
        if `is_tabs' & `_i' > 1 local _hide " hide"
        file write `fh' `"<section class="section`_hide'" id="sec`_i'">"' _n
        file write `fh' `"  <h2><span class="num">`_i'.</span>`_tname'<span class="src">`_basename'</span></h2>"' _n
        * scrolling="no" + auto-resize listener below means the iframe grows
        * to fit its content; the height attr is just an initial guess.
        file write `fh' `"  <iframe src="`macval(_src`_i')'?v=`_cachetag'" height="`_height'" scrolling="no" loading="lazy"></iframe>"' _n
        file write `fh' `"</section>"' _n
    }

    sparkta2_version
    local s2ver `"`r(version)'"'
    file write `fh' `"<footer>Built with sparkta2 v`s2ver' — each section is an independent interactive map / chart.</footer>"' _n
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
    * Tab switching: show the clicked button's target section, hide the rest.
    * Hidden iframes are loading="lazy", so they fetch on first reveal; the
    * resize listener above needs no change (it matches on e.source).
    if `is_tabs' {
        file write `fh' `"<script>"' _n
        file write `fh' `"(function(){"' _n
        file write `fh' `"var bar=document.getElementById('dashtabs');"' _n
        file write `fh' `"if(!bar)return;"' _n
        file write `fh' `"var btns=bar.querySelectorAll('button');"' _n
        file write `fh' `"function show(tgt,btn){"' _n
        file write `fh' `"var secs=document.querySelectorAll('section.section');"' _n
        file write `fh' `"for(var j=0;j<secs.length;j++){secs[j].classList.toggle('hide',secs[j].id!==tgt);}"' _n
        file write `fh' `"for(var k=0;k<btns.length;k++){btns[k].classList.toggle('active',btns[k]===btn);}"' _n
        file write `fh' `"}"' _n
        file write `fh' `"for(var i=0;i<btns.length;i++){"' _n
        file write `fh' `"btns[i].addEventListener('click',function(){show(this.getAttribute('data-target'),this);});"' _n
        file write `fh' `"}"' _n
        file write `fh' `"})();"' _n
        file write `fh' `"</script>"' _n
    }
    file write `fh' `"</div></body></html>"' _n
    file close `fh'

    display as text _n "[sparkta2_dashboard]  combined `_nfiles' maps:"
    display as text `"  {browse "`export'":`export'}"'

    return local export "`export'"
    if `is_tabs' return local layout "tabs"
    else return local layout "scroll"
    return scalar n_files = `_nfiles'

    if "`noopen'" == "" {
        sparkta2_open, file(`"`export'"')
    }
end

version 17.0
mata:
// Text for HTML element content: escape the three markup characters.
string scalar _s2d_html(string scalar s)
{
    string scalar r
    r = subinstr(s, "&", "&amp;")
    r = subinstr(r, "<", "&lt;")
    r = subinstr(r, ">", "&gt;")
    return(r)
}
// Split an absolute path into its root ("/", "C:/" or "//") and its
// segments, after turning backslashes into slashes and resolving the
// . and .. segments.
void _s2d_split(string scalar p, string scalar root, string rowvector seg)
{
    string rowvector t
    string scalar    r
    real scalar      i
    r = subinstr(p, char(92), "/")
    if (substr(r, 2, 1) == ":") {
        root = substr(r, 1, 2) + "/"
        r    = substr(r, 3, .)
    }
    else if (substr(r, 1, 2) == "//") {
        root = "//"
        r    = substr(r, 3, .)
    }
    else root = "/"
    t   = tokens(r, "/")
    seg = J(1, 0, "")
    for (i = 1; i <= cols(t); i++) {
        if (t[i] == "/" | t[i] == "" | t[i] == ".") continue
        if (t[i] == "..") {
            if (cols(seg)) seg = cols(seg) > 1 ? seg[1..cols(seg) - 1] : J(1, 0, "")
            continue
        }
        seg = seg, t[i]
    }
}
// Is the path absolute (/x, C:\x, C:/x, \\server\x)?
real scalar _s2d_isabs(string scalar p)
{
    string scalar c
    c = substr(p, 1, 1)
    return(c == "/" | c == char(92) | substr(p, 2, 1) == ":")
}
// A leading ~ means the home folder.
string scalar _s2d_tilde(string scalar p, string scalar home)
{
    if (p == "~" | substr(p, 1, 2) == "~/" | substr(p, 1, 2) == "~" + char(92)) {
        return(home + substr(p, 2, .))
    }
    return(p)
}
// Percent-encode the characters that would break a URL in a src attribute.
string scalar _s2d_url(string scalar s)
{
    string scalar r
    r = subinstr(s, "%", "%25")
    r = subinstr(r, " ", "%20")
    r = subinstr(r, "#", "%23")
    r = subinstr(r, "?", "%3F")
    r = subinstr(r, char(34), "%22")
    r = subinstr(r, "&", "&amp;")
    return(r)
}
// For locals _file1.._filen, set _src# (iframe src relative to the folder
// of local export), _base# (file name) and _miss# (1 when the file was not
// found from the working folder or from the dashboard's folder).
void _s2d_srcs(real scalar n)
{
    string scalar    home, pwd, exp, f, abs, droot, froot, src
    string rowvector dseg, fseg, eseg
    real scalar      i, j, k, win, same

    win  = (st_global("c(os)") == "Windows")
    home = st_local("_home")
    pwd  = st_global("c(pwd)")
    exp  = _s2d_tilde(st_local("export"), home)
    if (!_s2d_isabs(exp)) exp = pwd + "/" + exp
    _s2d_split(exp, droot, eseg)
    dseg = cols(eseg) > 1 ? eseg[1..cols(eseg) - 1] : J(1, 0, "")

    for (i = 1; i <= n; i++) {
        f = _s2d_tilde(st_local("_file" + strofreal(i)), home)
        st_local("_miss" + strofreal(i), "0")
        if (_s2d_isabs(f)) abs = f
        else if (fileexists(pwd + "/" + f)) abs = pwd + "/" + f
        else {
            // read from the dashboard's folder, as the page itself will
            abs = droot + (cols(dseg) ? invtokens(dseg, "/") + "/" : "") + f
            if (!fileexists(abs)) st_local("_miss" + strofreal(i), "1")
        }
        _s2d_split(abs, froot, fseg)
        st_local("_base" + strofreal(i), _s2d_html(cols(fseg) ? fseg[cols(fseg)] : f))
        same = win ? (strlower(froot) == strlower(droot)) : (froot == droot)
        if (!same) {
            // another drive: only an absolute file URL can reach it
            src = "file:///" + subinstr(froot, "//", "") + invtokens(fseg, "/")
        }
        else {
            k = 0
            for (j = 1; j <= min((cols(dseg), cols(fseg) - 1)); j++) {
                if (win ? strlower(dseg[j]) != strlower(fseg[j]) : dseg[j] != fseg[j]) break
                k = j
            }
            src = ""
            for (j = k + 1; j <= cols(dseg); j++) src = src + "../"
            src = src + invtokens(fseg[k + 1..cols(fseg)], "/")
        }
        st_local("_src" + strofreal(i), _s2d_url(src))
    }
}
end
