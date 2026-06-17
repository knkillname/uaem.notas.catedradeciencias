# .latexmkrc — Cátedra de Ciencias
# LuaLaTeX + biber + makeindex + minted (shell-escape)
#
# latexmk automatically determines the number of compilation runs
# needed to resolve all references, citations, and indices.

# ── Engine ───────────────────────────────────────────────────────
$pdf_mode = 4;

# ── Auxiliary directory ───────────────────────────────────────────
$aux_dir = "build";
$out_dir = "build";

# ── Environment for minted ────────────────────────────────────────
# minted v3 requires TEXMF_OUTPUT_DIRECTORY to know where pygmentize
# should write its temporary files.
$ENV{TEXMF_OUTPUT_DIRECTORY} = 'build';

# ── Compiler ──────────────────────────────────────────────────────
# -recorder generates .fls (file list) for dependency tracking.
$lualatex = "lualatex -shell-escape -synctex=1 -recorder "
          . "-interaction=nonstopmode -file-line-error %O %S";

# ── Bibliography ──────────────────────────────────────────────────
$bibtex = "biber %O %S";
$bibtex_use = 2;

# ── Index ─────────────────────────────────────────────────────────
$makeindex = "makeindex %O -o %D %S";

# ── Cleaning ──────────────────────────────────────────────────────
$clean_ext = "4ct 4tc aux bbl bcf blg css dvi fdb_latexmk fls html "
           . "idv idx ilg ind lg log ncx out pyg run.xml synctex.gz "
           . "tmp toc trc xref";

# ── Preview ───────────────────────────────────────────────────────
$pdf_previewer = "xdg-open %S";

# ── Diagnostics ───────────────────────────────────────────────────
$silence_logfile_warnings = 0;          # show warnings summary
