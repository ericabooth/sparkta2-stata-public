*! sparkta2_findfile v0.4.1  2026-06-20
*! Locate engine + map asset files for sparkta2. Auto-downloads from the
*! configured GitHub mirror on first use when Stata's `net install' couldn't
*! copy the .js / .topojson assets (it only copies recognised extensions).
program define sparkta2_findfile, rclass
    version 17.0
    syntax , GEO(string)

    * Files we need.  The geo file is tried as <geo>_counties.topojson first
    * (the default Texas layout); if that fails, fall back to <geo>.geojson
    * (the layout used by texas_districts.geojson and other GeoJSON drop-ins).
    local topofile_a "`geo'_counties.topojson"
    local topofile_b "`geo'.geojson"
    local engfile  "sparkta2_engine.js"
    local d3file   "d3.min.js"
    local tcfile   "topojson-client.min.js"
    local hxfile   "d3-hexbin.min.js"

    foreach f in topo eng d3 tc hx {
        local `f'path ""
    }

    * Pass 1: findfile on adopath
    foreach cand in "`topofile_a'" "`topofile_b'" {
        if "`topopath'" == "" {
            capture findfile "`cand'"
            if !_rc local topopath "`r(fn)'"
        }
    }
    capture findfile "`engfile'"
    if !_rc local engpath "`r(fn)'"
    capture findfile "`d3file'"
    if !_rc local d3path "`r(fn)'"
    capture findfile "`tcfile'"
    if !_rc local tcpath "`r(fn)'"
    capture findfile "`hxfile'"
    if !_rc local hxpath "`r(fn)'"

    * Pass 2: walk sysdir subfolders for any still-missing assets
    if "`topopath'" == "" | "`engpath'" == "" | "`d3path'" == "" | "`tcpath'" == "" | "`hxpath'" == "" {
        local plus     : sysdir PLUS
        local personal : sysdir PERSONAL
        foreach base in "`plus's/sparkta2/" "`personal'sparkta2/" {
            foreach cand in "`topofile_a'" "`topofile_b'" {
                if "`topopath'" == "" {
                    capture confirm file "`base'`cand'"
                    if !_rc local topopath "`base'`cand'"
                }
            }
            foreach pair in eng:`engfile' d3:`d3file' tc:`tcfile' hx:`hxfile' {
                local key  = substr("`pair'", 1, strpos("`pair'", ":") - 1)
                local file = substr("`pair'", strpos("`pair'", ":") + 1, .)
                if "``key'path'" == "" {
                    capture confirm file "`base'`file'"
                    if !_rc local `key'path "`base'`file'"
                }
            }
        }
    }

    * Pass 3: auto-bootstrap from the configured remote.
    * The user can set a global `sparkta2_remote_base' to override the default.
    * Default points at the GitHub mirror; only fetches files that local lookup missed.
    local remote_base "`sparkta2_remote_base'"
    if "`remote_base'" == "" {
        local remote_base "https://raw.githubusercontent.com/texas-2036/sparkta2-stata-public/main/"
    }
    if "`topopath'" == "" | "`engpath'" == "" | "`d3path'" == "" | "`tcpath'" == "" | "`hxpath'" == "" {
        local plus : sysdir PLUS
        local dest "`plus's/sparkta2/"
        capture mkdir "`plus's"
        capture mkdir "`dest'"
        * Topo: try both filename patterns
        if "`topopath'" == "" {
            foreach cand in "`topofile_a'" "`topofile_b'" {
                display as text "  sparkta2: fetching `cand' from `remote_base'…"
                capture copy "`remote_base'`cand'" "`dest'`cand'", replace
                if !_rc {
                    local topopath "`dest'`cand'"
                    continue, break
                }
            }
        }
        foreach pair in eng:`engfile' d3:`d3file' tc:`tcfile' hx:`hxfile' {
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

    if "`topopath'" == "" | "`engpath'" == "" | "`d3path'" == "" | "`tcpath'" == "" {
        display as error "sparkta2: required support files not found locally and could not be downloaded."
        display as error "  Either:"
        display as error `"    (a) net install sparkta2, from("https://raw.githubusercontent.com/texas-2036/sparkta2-stata-public/main/") replace force"'
        display as error `"        (sparkta2_findfile will auto-download the JS / TopoJSON on first use)"'
        display as error `"    (b) clone https://github.com/texas-2036/sparkta2-stata-public locally and adopath ++ ".../sparkta2-stata-public""'
        if "`topopath'" == "" display as error "    - missing: `topofile'"
        if "`engpath'"  == "" display as error "    - missing: `engfile'"
        if "`d3path'"   == "" display as error "    - missing: `d3file'"
        if "`tcpath'"   == "" display as error "    - missing: `tcfile'"
        exit 601
    }
    if "`hxpath'" == "" {
        display as text "  (note: d3-hexbin.min.js not found; type(hexbin) will not work offline)"
    }

    return local topopath "`topopath'"
    return local engpath  "`engpath'"
    return local d3path   "`d3path'"
    return local tcpath   "`tcpath'"
    return local hxpath   "`hxpath'"
end
