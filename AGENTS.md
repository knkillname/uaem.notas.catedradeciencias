# AGENTS.md — Cátedra de Ciencias

## Development Environment

This project runs inside a **Debian (trixie) dev container**. All tooling is pre-installed via the [Dockerfile](.devcontainer/Dockerfile):

| Tool | Relevance |
|------|-----------|
| `texlive-full` | Full LaTeX distribution (LuaLaTeX, biber, KOMA-Script, polyglossia, minted dependencies) |
| `inkscape` | SVG → PDF conversion for figures |
| `python3-pygments` | Syntax highlighting backend for `minted` |
| `python3-*` (numpy, scipy, sympy, matplotlib, pandas, networkx) | Python code examples / diagrams |
| JetBrains Mono NL | Monospace font used via `fontspec` |

**VS Code extensions** (in [devcontainer.json](.devcontainer/devcontainer.json)): LaTeX Workshop (primary builder), Python tooling, Spanish spell checker.

## Build & Development

| Command | Purpose |
|---------|---------|
| `make` | Build PDF via `lualatex` → `biber` + `makeindex` → `lualatex` × 2, plus EPUB via `tex4ebook` |
| `make clean` | Remove generated auxiliary files (preserves `salida/` with built PDF & EPUB) |
| `make view` | Open the built PDF |

**Engine:** LuaLaTeX + biber (bibliography) + makeindex (index). The PDF recipe runs lualatex twice after biber/makeindex to resolve all cross-references.
**Note:** `-shell-escape` is required for `minted` (calls `pygmentize`).

## Project Structure

```
catedraciencias.tex       # Main document: preamble, frontmatter, chapters, backmatter
preambulo/
  opciones.tex            # Fonts, KOMA-Script styling, minted, algorithm2e setup
  definiciones.tex        # Custom commands and environments
capitulos/                # Chapter content, one file per chapter (\include'd)
img/                      # Images (JPG, PNG); SVGs auto-converted to PDF via Inkscape
bibliografia.bib          # Biblatex references (numeric style)
Examenes/                 # Exam files in Markdown
```

## LaTeX Conventions

- **Language:** Spanish via `polyglossia`. Use `\setdefaultlanguage{spanish}`.
- **Document class:** `scrbook` (KOMA-Script) — use KOMA commands (`\KOMAoptions`, `\setkomafont`, etc.) for styling.
- **Fonts:** TeX Gyre Pagella (serif/math), TeX Gyre Heros (sans), JetBrains Mono NL (mono).
- **Labels:** Chapters `\label{cha:...}`, sections `\label{sec:...}`, subsections `\label{sub:...}`, figures `\label{fig:...}`, remember blocks `\label{rem:...}`.
- **Index entries:** `\index{key}{display text}` — used throughout for the backmatter index.
- **Citations:** `\cite{key}` using biber/biblatex with `style=numeric`.
- **Cross-references:** Use `\url{}` for URLs, `\href{}{}` for hyperlinks.

## Custom Environments & Commands

Defined in `preambulo/definiciones.tex`:

| Command/Environment | Purpose |
|---------------------|---------|
| `\terminology[optional]{Term}` | Bold term + index entry |
| `\footurl{URL}` | URL as footnote |
| `\Verdadero` / `\Falso` | Small caps True/False |
| `\begin{digress}{Title}...\end{digress}` | Sidebar / digression box (🪄) |
| `\begin{remember}...\end{remember}` | Key concept highlight box (💾) |
| `\begin{theorem}...`, `\begin{lemma}...`, etc. | Theorem environments (numbered by chapter) |
| `\begin{definition}...`, `\begin{example}...`, `\begin{exercise}...` | Definition-style environments |

## Writing Chapters

1. Create a `.tex` file in `capitulos/`
2. Start with `\chapter{Title}\label{cha:...}`
3. Add the `\include{capitulos/...}` line in `catedraciencias.tex` in order (inside `\mainmatter`)
4. Use `\section{}`, `\subsection{}`, `\subsection*{}` (starred = unnumbered) for structure
5. Wrap key concepts in `\begin{remember}...\end{remember}` with a `\label{rem:...}`
6. Use `\terminology[optional]{Term}` for glossary/index terms

## Images

- Place images in `img/`. Reference as `img/filename` (no extension needed if using `\includegraphics` without it).
- **SVG files:** The Makefile auto-converts `figuras/*.svg` to PDF via Inkscape. Currently only `img/` is used (no `figuras/` dir); SVGs placed there need manual conversion or the Makefile rule updated.

## Versioning

Follow the [CHANGELOG.md](CHANGELOG.md) — update it with each release. Version in `\date{}` in the main document.
