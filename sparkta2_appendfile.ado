*! sparkta2_appendfile v0.3.0  2026-08-12
*! Close an open file handle, append another file's contents byte-for-byte,
*! then reopen the same handle in append mode.  Bypasses Stata's file write
*! parser so arbitrary content (minified JS with `"' sequences, lines past
*! the macro length limit, base64 blobs) can be embedded safely.
*!
*! v0.3.0: the copy is done in MATA (fopen/fread/fwrite), replacing the old
*!   `shell cat` / `shell type` round-trip.  The shell version broke on
*!   Windows in two ways a user hit in the wild: cmd's `type` rejects the
*!   forward-slash paths Stata produces, and paths with spaces (OneDrive /
*!   Google Drive folders) fell apart in cmd quoting.  Mata reads and
*!   writes the bytes directly -- no shell, no slash direction, no quoting,
*!   no console window flashing per call on Windows -- and a missing source
*!   file now raises a hard error instead of silently splicing nothing.
program define sparkta2_appendfile
    version 17.0
    syntax , FH(name) PATH(string) OUTPATH(string)

    file close `fh'
    mata: _sparkta2_fappend(st_local("path"), st_local("outpath"))
    file open `fh' using `"`outpath'"', write text append
end

version 17.0
mata:
void _sparkta2_fappend(string scalar src, string scalar dst)
{
    real scalar   fin, fout
    string scalar chunk

    fin = fopen(src, "r")
    fout = fopen(dst, "rw")
    fseek(fout, 0, 1)
    while ((chunk = fread(fin, 1048576)) != J(0, 0, "")) {
        fwrite(fout, chunk)
    }
    fclose(fin)
    fclose(fout)
}
end
