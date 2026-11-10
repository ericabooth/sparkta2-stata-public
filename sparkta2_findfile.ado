*! sparkta2_findfile v0.6.0  2026-11-10
*! v0.6.0: the two engine files carry a version on their first line, and it
*!         must equal the ado version.  -net install, replace- updates the
*!         ado files but not .js files, so an upgraded install kept drawing
*!         with the engine from the older release and said nothing.  An
*!         engine that does not match is now replaced by a current copy in
*!         PLUS/s/sparkta2/ (downloaded if needed); if no current copy can
*!         be had, the old one is used and a note says so.
*! Locate engine + asset files for sparkta2 maps and charts. Auto-downloads
*! from the configured GitHub mirror on first use when Stata's `net install'
*! couldn't copy the .js / .topojson assets (it only copies recognised
*! extensions).
*! v0.5.0: new charts option resolves sparkta2_chart_engine.js + d3.min.js
*!         through the same three-pass lookup (adopath incl. cwd, the
*!         PLUS/s/sparkta2/ cache, then download) that maps already used;
*!         before this, sparkta2_chart called -findfile- directly and every
*!         fresh net install failed its first chart with r(601).
*!         geo() is now optional; specify geo() and/or charts.
*!         The documented global sparkta2_remote_base override is now honored
*!         (it was read as a local macro, so it could never apply).
program define sparkta2_findfile, rclass
    version 17.0
    syntax , [GEO(string) CHARTs]

    local wantmap   = "`geo'" != ""
    local wantchart = "`charts'" != ""
    if !`wantmap' & !`wantchart' {
        display as error "sparkta2_findfile: specify geo() and/or charts"
        exit 198
    }

    * Files we need.  The geo file is tried as <geo>_counties.topojson first
    * (the default Texas layout); if that fails, fall back to <geo>.geojson
    * (the layout used by texas_districts.geojson and other GeoJSON drop-ins).
    * Charts need only the chart engine and d3 itself.
    local topofile_a "`geo'_counties.topojson"
    local topofile_b "`geo'.geojson"
    local engfile   "sparkta2_engine.js"
    local chartfile "sparkta2_chart_engine.js"
    local d3file    "d3.min.js"
    local tcfile    "topojson-client.min.js"
    local hxfile    "d3-hexbin.min.js"

    local pairs "d3:`d3file'"
    if `wantmap'   local pairs "`pairs' eng:`engfile' tc:`tcfile' hx:`hxfile'"
    if `wantchart' local pairs "`pairs' chart:`chartfile'"

    foreach f in topo eng chart d3 tc hx {
        local `f'path ""
    }

    * Pass 1: findfile on adopath (which includes the current directory, so
    * assets fetched by -net get- into the working folder are found here)
    if `wantmap' {
        foreach cand in "`topofile_a'" "`topofile_b'" {
            if "`topopath'" == "" {
                capture findfile "`cand'"
                if !_rc local topopath "`r(fn)'"
            }
        }
    }
    foreach pair of local pairs {
        local key  = substr("`pair'", 1, strpos("`pair'", ":") - 1)
        local file = substr("`pair'", strpos("`pair'", ":") + 1, .)
        capture findfile "`file'"
        if !_rc local `key'path "`r(fn)'"
    }

    * Pass 2: walk sysdir cache subfolders for any still-missing assets
    local plus     : sysdir PLUS
    local personal : sysdir PERSONAL
    foreach base in "`plus's/sparkta2/" "`personal'sparkta2/" {
        if `wantmap' {
            foreach cand in "`topofile_a'" "`topofile_b'" {
                if "`topopath'" == "" {
                    capture confirm file "`base'`cand'"
                    if !_rc local topopath "`base'`cand'"
                }
            }
        }
        foreach pair of local pairs {
            local key  = substr("`pair'", 1, strpos("`pair'", ":") - 1)
            local file = substr("`pair'", strpos("`pair'", ":") + 1, .)
            if "``key'path'" == "" {
                capture confirm file "`base'`file'"
                if !_rc local `key'path "`base'`file'"
            }
        }
    }

    * Pass 3: auto-bootstrap from the configured remote.
    * Set global sparkta2_remote_base (URL or local path, trailing slash) to
    * override the default GitHub mirror; only files that both local passes
    * missed are fetched, into sysdir PLUS/s/sparkta2/ for reuse.
    local remote_base "$sparkta2_remote_base"
    if "`remote_base'" == "" {
        local remote_base "https://raw.githubusercontent.com/ericabooth/sparkta2-stata-public/main/"
    }
    local anymiss = (`wantmap' & "`topopath'" == "")
    foreach pair of local pairs {
        local key = substr("`pair'", 1, strpos("`pair'", ":") - 1)
        if "``key'path'" == "" local anymiss 1
    }
    if `anymiss' {
        local dest "`plus's/sparkta2/"
        capture mkdir "`plus's"
        capture mkdir "`dest'"
        if `wantmap' & "`topopath'" == "" {
            foreach cand in "`topofile_a'" "`topofile_b'" {
                display as text "  sparkta2: fetching `cand' from `remote_base'…"
                capture copy "`remote_base'`cand'" "`dest'`cand'", replace
                if !_rc {
                    local topopath "`dest'`cand'"
                    continue, break
                }
            }
        }
        foreach pair of local pairs {
            local key  = substr("`pair'", 1, strpos("`pair'", ":") - 1)
            local file = substr("`pair'", strpos("`pair'", ":") + 1, .)
            if "``key'path'" == "" {
                display as text "  sparkta2: fetching `file' from `remote_base'…"
                capture copy "`remote_base'`file'" "`dest'`file'", replace
                if !_rc {
                    local `key'path "`dest'`file'"
                }
                else {
                    display as text "    (failed to fetch `file'; rc=" _rc ")"
                }
            }
        }
    }

    * Version check on the two engine files.  Each carries the release it
    * belongs to on its first line.  A copy from another release (left by an
    * upgrade, or by an old -net get- into the working folder) is replaced by
    * the cached copy if that one is current, or by a fresh download.
    sparkta2_version
    local adover "`r(version)'"
    local cache "`plus's/sparkta2/"
    local checks ""
    if `wantmap'   local checks "`checks' eng:`engfile'"
    if `wantchart' local checks "`checks' chart:`chartfile'"
    foreach pair of local checks {
        local key  = substr("`pair'", 1, strpos("`pair'", ":") - 1)
        local file = substr("`pair'", strpos("`pair'", ":") + 1, .)
        if "``key'path'" == "" continue
        mata: sparkta2_ff_marker(st_local("`key'path"), "have")
        if "`have'" == "`adover'" continue
        local found "``key'path'"
        * a current copy already in the cache?
        local fixed 0
        capture confirm file "`cache'`file'"
        if !_rc & "`found'" != "`cache'`file'" {
            mata: sparkta2_ff_marker(st_local("cache") + st_local("file"), "cv")
            if "`cv'" == "`adover'" {
                local `key'path "`cache'`file'"
                local fixed 1
            }
        }
        * otherwise download one, check it, and only then put it in the cache
        if !`fixed' {
            tempfile fresh
            capture copy "`remote_base'`file'" "`fresh'", replace
            if !_rc {
                mata: sparkta2_ff_marker(st_local("fresh"), "nv")
                if "`nv'" == "`adover'" {
                    capture mkdir "`plus's"
                    capture mkdir "`cache'"
                    capture copy "`fresh'" "`cache'`file'", replace
                    if !_rc {
                        local `key'path "`cache'`file'"
                        local fixed 1
                    }
                }
            }
        }
        local was = cond("`have'" == "", "an earlier release", "v`have'")
        if `fixed' {
            noisily display as text "  sparkta2: `file' at `found' is from `was';"
            noisily display as text "            using the v`adover' copy in `cache'"
        }
        else {
            noisily display as text "  sparkta2 note: `file' is from `was', but sparkta2 is v`adover',"
            noisily display as text "    and a matching copy could not be downloaded.  Some options may"
            noisily display as text "    not draw as documented.  File in use: `found'"
            noisily display as text `"    To fix, connect once and rerun, or: net get sparkta2, from("https://raw.githubusercontent.com/ericabooth/sparkta2-stata-public/main/") replace"'
        }
    }

    * Requirements depend on what was asked for: maps need the topo layer,
    * map engine, d3, and topojson-client; charts need the chart engine and d3.
    local short 0
    if `wantmap'   & ("`topopath'" == "" | "`engpath'" == "" | "`d3path'" == "" | "`tcpath'" == "") local short 1
    if `wantchart' & ("`chartpath'" == "" | "`d3path'" == "") local short 1
    if `short' {
        display as error "sparkta2: required support files not found locally and could not be downloaded."
        display as error "  Either:"
        display as error `"    (a) net install sparkta2, from("https://raw.githubusercontent.com/ericabooth/sparkta2-stata-public/main/") replace force"'
        display as error `"        (sparkta2_findfile will auto-download the JS / TopoJSON on first use)"'
        display as error `"    (b) net get sparkta2, from("https://raw.githubusercontent.com/ericabooth/sparkta2-stata-public/main/")"'
        display as error `"    (c) clone https://github.com/ericabooth/sparkta2-stata-public locally and adopath ++ "<clone dir>""'
        if `wantmap' & "`topopath'" == "" display as error "    - missing: `topofile_a' (or `topofile_b')"
        if `wantmap' & "`engpath'"  == "" display as error "    - missing: `engfile'"
        if "`d3path'" == ""               display as error "    - missing: `d3file'"
        if `wantmap' & "`tcpath'"   == "" display as error "    - missing: `tcfile'"
        if `wantchart' & "`chartpath'" == "" display as error "    - missing: `chartfile'"
        exit 601
    }
    if `wantmap' & "`hxpath'" == "" {
        display as text "  (note: d3-hexbin.min.js not found; type(hexbin) will not work offline)"
    }

    return local topopath  "`topopath'"
    return local engpath   "`engpath'"
    return local chartpath "`chartpath'"
    return local d3path    "`d3path'"
    return local tcpath    "`tcpath'"
    return local hxpath    "`hxpath'"
end

version 17.0
mata:
// Read the release number from the first line of an engine file into the
// caller's local macro.  Empty when the file has no such line (engines
// shipped before v0.8.12) or cannot be opened.
void sparkta2_ff_marker(string scalar path, string scalar lname)
{
    real scalar fh
    string matrix line

    st_local(lname, "")
    fh = _fopen(path, "r")
    if (fh < 0) return
    line = fget(fh)
    fclose(fh)
    if (rows(line) == 0) return
    if (regexm(line, "sparkta2-engine ([0-9]+\.[0-9]+\.[0-9]+)")) {
        st_local(lname, regexs(1))
    }
}
end
