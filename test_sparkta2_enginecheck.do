*! test_sparkta2_enginecheck.do
*! Regression battery for the engine version check in sparkta2_findfile
*! (v0.8.12).  Run from the repository folder:  stata-mp -b do test_sparkta2_enginecheck.do
*!
*! -net install, replace- updates the ado files but leaves .js files alone,
*! so an upgraded install used to keep the engine from the older release.
*! Each case plants a situation and checks which engine file is returned.
*! PLUS is pointed at a scratch folder, so the real install is not touched,
*! and the "remote" is this repository folder, so no network is needed.

version 17.0
clear all
set more off

local repo "`c(pwd)'"
capture confirm file "`repo'/sparkta2_findfile.ado"
if _rc {
    display as error "run this file from the sparkta2 repository folder"
    exit 601
}
local nfail 0
local ntest 0

sparkta2_version
local V "`r(version)'"

mata:
void sparkta2_ec_first(string scalar path, string scalar lname)
{
    real scalar fh
    fh = fopen(path, "r")
    st_local(lname, fget(fh))
    fclose(fh)
}
end

*--- 1. release guard: both engine files carry the ado version ---------------*
foreach f in sparkta2_engine.js sparkta2_chart_engine.js {
    local ++ntest
    file open fh using "`repo'/`f'", read text
    file read fh line
    file close fh
    if strpos(`"`macval(line)'"', "sparkta2-engine `V' ") == 0 {
        display as error "FAIL 1: first line of `f' does not say sparkta2-engine `V'"
        local ++nfail
    }
}

*--- scratch folders ----------------------------------------------------------*
tempfile stub
local base "`stub'_ec"
capture mkdir "`base'"
foreach d in plus stale oldmark {
    capture mkdir "`base'/`d'"
}
local savedplus "`c(sysdir_plus)'"
local savedremote "$sparkta2_remote_base"

* stale copies: one with no version line (engines before v0.8.12), one with
* an older version line
foreach f in sparkta2_engine.js sparkta2_chart_engine.js {
    file open  fo using "`base'/stale/`f'", write text replace
    file write fo "/* `f' -- an engine from before the version line */" _n
    file close fo
    file open  fo using "`base'/oldmark/`f'", write text replace
    file write fo "/* sparkta2-engine 0.0.1 -- old */" _n
    file close fo
}

capture noisily {
    sysdir set PLUS "`base'/plus/"

    *--- 2. stale engine on the adopath, remote available: refreshed ---------*
    adopath ++ "`base'/stale"
    global sparkta2_remote_base "`repo'/"
    sparkta2_findfile, geo(texas) charts
    foreach k in eng chart {
        local ++ntest
        local got "`r(`k'path)'"
        if strpos("`got'", "`base'/plus/s/sparkta2/") != 1 {
            display as error "FAIL 2: `k' engine not taken from the cache: `got'"
            local ++nfail
        }
    }
    local ++ntest
    file open fh using "`base'/plus/s/sparkta2/sparkta2_engine.js", read text
    file read fh line
    file close fh
    if strpos(`"`macval(line)'"', "sparkta2-engine `V' ") == 0 {
        display as error "FAIL 2: cached engine is not v`V'"
        local ++nfail
    }

    *--- 3. cache now current, remote gone: cache copy still used ------------*
    global sparkta2_remote_base "`base'/nowhere/"
    sparkta2_findfile, charts
    local ++ntest
    if strpos("`r(chartpath)'", "`base'/plus/s/sparkta2/") != 1 {
        display as error "FAIL 3: current cache copy not used: `r(chartpath)'"
        local ++nfail
    }
    adopath - "`base'/stale"

    *--- 4. stale engine, nothing current anywhere: old file used, rc 0 ------*
    erase "`base'/plus/s/sparkta2/sparkta2_engine.js"
    erase "`base'/plus/s/sparkta2/sparkta2_chart_engine.js"
    adopath ++ "`base'/oldmark"
    capture noisily sparkta2_findfile, charts
    local ++ntest
    if _rc | "`r(chartpath)'" != "`base'/oldmark/sparkta2_chart_engine.js" {
        display as error "FAIL 4: rc=" _rc " path=`r(chartpath)'"
        local ++nfail
    }
    * a download that is itself the wrong version must not enter the cache
    global sparkta2_remote_base "`base'/stale/"
    sparkta2_findfile, charts
    local ++ntest
    capture confirm file "`base'/plus/s/sparkta2/sparkta2_chart_engine.js"
    if !_rc {
        display as error "FAIL 4: a wrong-version download was cached"
        local ++nfail
    }
    adopath - "`base'/oldmark"

    *--- 5. current engine on the adopath: returned as found, nothing cached -*
    global sparkta2_remote_base "`base'/nowhere/"
    sparkta2_findfile, charts
    local ++ntest
    if "`r(chartpath)'" != "`repo'/sparkta2_chart_engine.js" & ///
       "`r(chartpath)'" != "./sparkta2_chart_engine.js" {
        display as error "FAIL 5: expected the repository copy, got `r(chartpath)'"
        local ++nfail
    }
    local ++ntest
    capture confirm file "`base'/plus/s/sparkta2/sparkta2_chart_engine.js"
    if !_rc {
        display as error "FAIL 5: a current engine triggered a download"
        local ++nfail
    }

    *--- 5b. the stale copy IS the cache copy (the usual upgrade): replaced --*
    * Work from an empty folder so the cache holds the only engine.  The
    * programs are already in memory from the cases above, so the
    * repository does not need to be on the adopath here.
    capture mkdir "`base'/empty"
    capture mkdir "`base'/plus/s"
    capture mkdir "`base'/plus/s/sparkta2"
    copy "`base'/stale/sparkta2_chart_engine.js" ///
         "`base'/plus/s/sparkta2/sparkta2_chart_engine.js", replace
    copy "`repo'/d3.min.js" "`base'/plus/s/sparkta2/d3.min.js", replace
    global sparkta2_remote_base "`repo'/"
    cd "`base'/empty"
    capture noisily sparkta2_findfile, charts
    local rc5 = _rc
    local got5 "`r(chartpath)'"
    cd "`repo'"
    local ++ntest
    mata: sparkta2_ec_first("`base'/plus/s/sparkta2/sparkta2_chart_engine.js", "l5")
    if `rc5' | "`got5'" != "`base'/plus/s/sparkta2/sparkta2_chart_engine.js" | ///
       strpos(`"`l5'"', "sparkta2-engine `V' ") == 0 {
        display as error "FAIL 5b: rc=`rc5' path=`got5'"
        local ++nfail
    }
    erase "`base'/plus/s/sparkta2/sparkta2_chart_engine.js"
    erase "`base'/plus/s/sparkta2/d3.min.js"

    *--- 6. end to end: a chart built over a stale engine embeds the new one -*
    adopath ++ "`base'/stale"
    global sparkta2_remote_base "`repo'/"
    clear
    input str4 g v
    "A" 3
    "B" 5
    end
    sparkta2 v, name(g) type(bar2) offline noopen export("`base'/bar2.html")
    local ++ntest
    mata: st_local("hit", strofreal(strpos(fread(fopen("`base'/bar2.html","r"), 20000000), "sparkta2-engine `V' ") > 0))
    if `hit' != 1 {
        display as error "FAIL 6: the page does not embed the v`V' chart engine"
        local ++nfail
    }
    adopath - "`base'/stale"
}
local rc = _rc
cd "`repo'"
sysdir set PLUS "`savedplus'"
global sparkta2_remote_base "`savedremote'"
if `rc' {
    display as error "battery stopped with rc=`rc'"
    exit `rc'
}

display as text _n "enginecheck: `ntest' checks, `nfail' failed"
if `nfail' exit 9
display as result "ENGINECHECK_OK"
