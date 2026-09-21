*! sparkta2_version v1.0.0  2026-09-21
*! The one place the sparkta2 version number is written.
*!
*! WHY THIS FILE EXISTS
*!     The version a user sees used to be typed into four different programs:
*!     the dispatcher's banner, the map writer, the chart writer, and the
*!     dashboard's HTML footer.  They drifted.  Charts and dashboards went on
*!     stamping v0.8.0 through the 0.8.1 and 0.8.2 releases, so a dashboard
*!     footer reported a version that had not produced it for months, and
*!     nothing in the output revealed the mismatch.
*!
*!     A local macro cannot fix this: locals are scoped to the program that
*!     sets them, so a version stored in sparkta2.ado is invisible inside
*!     sparkta2_chart.  A global would cross that boundary but persists for
*!     the whole session, which means it keeps reporting the old number after
*!     a mid-session -net install-, exactly when a developer is most likely to
*!     be checking.  An rclass return crosses the boundary AND is rebuilt on
*!     every call, so it cannot go stale.
*!
*! USAGE
*!     sparkta2_version
*!     display "running `r(version)'"
*!
*! RELEASING
*!     Change the string below.  Nothing else in the package carries a version
*!     number that a user can see, so that one edit is the whole release.
program define sparkta2_version, rclass
    version 17.0
    return local version "0.8.5"
end
