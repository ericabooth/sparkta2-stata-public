*! sparkta2_open v0.3.0  2026-08-12
*! Cross-platform "open this file in the default app" helper.
*! v0.3.0: Windows branch converts forward slashes to backslashes before
*!   handing the path to cmd (`start` treats /x as switches in some
*!   configurations), and quotes survive spaced paths (OneDrive / Google
*!   Drive folders).  Non-Windows platforms take the path verbatim.
program define sparkta2_open
    version 17.0
    syntax , FILE(string)
    local os = lower("`c(os)'")
    if strpos("`os'", "win") {
        local _wf : subinstr local file "/" "\", all
        shell start "" "`_wf'"
    }
    else if strpos("`os'", "mac") {
        shell open `"`file'"'
    }
    else {
        shell xdg-open `"`file'"' &
    }
end
