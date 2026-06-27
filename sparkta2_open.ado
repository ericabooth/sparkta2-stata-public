*! sparkta2_open v0.2.0  2026-06-20
*! Cross-platform "open this file in the default app" helper.
program define sparkta2_open
    version 17.0
    syntax , FILE(string)
    local os = lower("`c(os)'")
    if strpos("`os'", "win") {
        shell start "" `"`file'"'
    }
    else if strpos("`os'", "mac") {
        shell open `"`file'"'
    }
    else {
        shell xdg-open `"`file'"' &
    }
end
