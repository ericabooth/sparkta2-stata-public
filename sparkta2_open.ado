*! sparkta2_open v0.3.1  2026-11-09
*! v0.3.1: a leading ~ is expanded to the home folder first (the shell does
*!   not expand ~ inside quotes); the macOS and Linux calls quote the path
*!   with plain double quotes (compound quotes reached the shell as a
*!   stray backtick); console Stata on a Mac reports c(os) "Unix", so the
*!   Mac is now recognised from c(machine_type) as well.
*! Cross-platform "open this file in the default app" helper.
*! v0.3.0: Windows branch converts forward slashes to backslashes before
*!   handing the path to cmd (`start` treats /x as switches in some
*!   configurations), and quotes survive spaced paths (OneDrive / Google
*!   Drive folders).  Non-Windows platforms take the path verbatim.
program define sparkta2_open
    version 17.0
    syntax , FILE(string)
    local os = lower("`c(os)'")
    local _tl = substr(`"`file'"', 1, 1) == "~" & inlist(substr(`"`file'"', 2, 1), "", "/", char(92))
    if `_tl' {
        if strpos("`os'", "win") local _home : environment USERPROFILE
        else                     local _home : environment HOME
        local file `"`_home'`=substr(`"`file'"', 2, .)'"'
    }
    if strpos("`os'", "win") {
        local _wf : subinstr local file "/" "\", all
        shell start "" "`_wf'"
    }
    else if strpos("`os'", "mac") | strpos(lower(c(machine_type)), "mac") {
        shell open "`file'"
    }
    else {
        shell xdg-open "`file'" &
    }
end
