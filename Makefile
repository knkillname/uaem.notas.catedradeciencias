# ───────────────────────────────────────────────────────────────────
# Cátedra de Ciencias — Makefile idiomático
# ───────────────────────────────────────────────────────────────────
# LuaLaTeX + latexmk (multipasada automática) + includeonly (rápido
# por capítulo) + dependencias precisas vía .fls (latexmk -recorder).
# ───────────────────────────────────────────────────────────────────

DOCUMENTO  = catedraciencias
DIR_SALIDA = salida
DIR_BUILD  = build

# ── Archivos fuente ───────────────────────────────────────────────
ARCHIVOS_TEX = \
	$(DOCUMENTO).tex \
	$(wildcard capitulos/*.tex) \
	$(wildcard preambulo/*.tex)
ARCHIVOS_SVG    = $(wildcard figuras/*.svg)
ARCHIVOS_CODIGO = $(wildcard codigos/*.*)
ARCHIVOS_PDFTEX = $(patsubst %.svg, %.pdf_tex, $(ARCHIVOS_SVG))
ARCHIVOS_IMG    = $(wildcard img/*)

# Dependencias base: si cualquiera de estos cambia, se recompila.
# Las dependencias precisas (imágenes, archivos auxiliares) se
# añaden dinámicamente desde el .fls generado por lualatex -recorder.
DEPENDENCIAS = $(ARCHIVOS_TEX) $(ARCHIVOS_PDFTEX) \
               $(ARCHIVOS_CODIGO) bibliografia.bib

# ── Capítulos (para compilación rápida con includeonly) ────────────
# Uso: make fast CHAPTER=filosofiaciencia
#      make CHAPTER=filosofiaciencia   (solo PDF)
#      make list-chapters              (ver disponibles)
CAPITULOS = $(notdir $(basename $(wildcard capitulos/*.tex)))
CHAPTER  ?=

# ── EPUB ───────────────────────────────────────────────────────────
# Fuentes embebidas
FONTS_TEXGYRE_DIR      = /usr/share/texmf/fonts/opentype/public/tex-gyre
FONTS_TEXGYRE_MATH_DIR = /usr/share/texmf/fonts/opentype/public/tex-gyre-math
FONTS_JETBRAINS_DIR    = /home/vscode/.local/share/fonts/fonts/ttf

FONTS_PAGELLA = \
	texgyrepagella-regular.otf \
	texgyrepagella-bold.otf \
	texgyrepagella-italic.otf \
	texgyrepagella-bolditalic.otf
FONTS_HEROS = \
	texgyreheros-regular.otf \
	texgyreheros-bold.otf \
	texgyreheros-italic.otf \
	texgyreheros-bolditalic.otf
FONTS_TEXGYRE = $(FONTS_PAGELLA) $(FONTS_HEROS)
FONT_PAGELLA_MATH = texgyrepagella-math.otf
FONTS_JETBRAINS = \
	JetBrainsMonoNL-Regular.ttf \
	JetBrainsMonoNL-Bold.ttf \
	JetBrainsMonoNL-Italic.ttf \
	JetBrainsMonoNL-BoldItalic.ttf

ARCHIVOS_EPUB = epub.cfg epub.css

# ── Dependencias dinámicas generadas desde .fls ────────────────────
# Se incluyen si existen; en la primera compilación se ignoran.
-include $(DIR_BUILD)/$(DOCUMENTO).d

# ── Targets principales ────────────────────────────────────────────
.PHONY: all pdf epub fast dev clean view epub-view \
        format format-check list-chapters chapters \
        _reset_includeonly
.NOTPARALLEL:
.DEFAULT_GOAL := all

all: pdf epub

pdf: $(DIR_SALIDA)/$(DOCUMENTO).pdf

epub: $(DIR_SALIDA)/$(DOCUMENTO).epub

# ═══════════════════════════════════════════════════════════════════
# Dependencia auxiliar: fuerza recompilación cuando cambia el modo
# includeonly (capítulo ↔ completo).  Al ser .PHONY siempre se
# ejecuta; si detecta un cambio de modo, elimina el PDF para que
# latexmk recompile desde cero.
# ═══════════════════════════════════════════════════════════════════
_reset_includeonly:
	@if [ -z "$(CHAPTER)" ] && [ -f $(DIR_BUILD)/includeonly.cfg ]; then \
		echo "  [reset]  volviendo a compilación completa..."; \
		rm -f $(DIR_BUILD)/$(DOCUMENTO).pdf; \
	fi
	@if [ -n "$(CHAPTER)" ]; then \
		rm -f $(DIR_BUILD)/$(DOCUMENTO).pdf; \
	fi

# ═══════════════════════════════════════════════════════════════════
# PDF — latexmk con LuaLaTeX
# ═══════════════════════════════════════════════════════════════════

# Regla principal del PDF.
# ─ generate-includeonly ─: si CHAPTER está definido, escribe
#   build/includeonly.cfg para que LaTeX solo procese ese capítulo.
#   Las referencias cruzadas se mantienen porque los .aux del resto
#   de capítulos (de una compilación completa previa) se siguen leyendo.
# ─ generate-deps ─: convierte el .fls (lista de archivos leídos)
#   en un .d con formato Make para dependencias precisas.

define generate_includeonly
	@if [ -n "$(CHAPTER)" ]; then \
		echo '\includeonly{capitulos/$(CHAPTER).tex}' > $(DIR_BUILD)/includeonly.cfg; \
		echo "  [includeonly]  solo capítulo: $(CHAPTER)"; \
	else \
		rm -f $(DIR_BUILD)/includeonly.cfg; \
	fi
endef

define generate_deps
	@echo "# Dependencias generadas desde .fls" > $(DIR_BUILD)/$(DOCUMENTO).d.tmp
	@echo '$(DIR_SALIDA)/$(DOCUMENTO).pdf: \' >> $(DIR_BUILD)/$(DOCUMENTO).d.tmp
	@awk '/^INPUT / { \
		f = $$2; \
		sub("^'"$$PWD"'/", "", f); \
		sub("^\\./", "", f); \
		if (f !~ /^\// && f !~ /^build\// && f !~ /luatex\./ && f !~ /^\/tmp\// && f !~ /\.(aux|bbl|bcf|blg|dvi|fdb_latexmk|fls|idx|ilg|ind|log|out|pdf|run\.xml|synctex\.gz|toc|tmp|xref|4ct|4tc|css|html|idv|lg|ncx)$$/) \
			print "  " f " \\"; \
	}' $(DIR_BUILD)/$(DOCUMENTO).fls | sort -u >> $(DIR_BUILD)/$(DOCUMENTO).d.tmp 2>/dev/null
	@echo "" >> $(DIR_BUILD)/$(DOCUMENTO).d.tmp
	@mv $(DIR_BUILD)/$(DOCUMENTO).d.tmp $(DIR_BUILD)/$(DOCUMENTO).d
endef

$(DIR_SALIDA)/$(DOCUMENTO).pdf: $(DEPENDENCIAS) .latexmkrc _reset_includeonly | $(DIR_SALIDA) $(DIR_BUILD)
	@mkdir -p $(DIR_BUILD)/capitulos $(DIR_BUILD)/preambulo
	$(generate_includeonly)
	latexmk -f -pdflua $(DOCUMENTO).tex
	cp $(DIR_BUILD)/$(DOCUMENTO).pdf $@
	$(generate_deps)

# ── SVG → PDF (para Inkscape) ─────────────────────────────────────
figuras/%.pdf_tex: figuras/%.svg
	inkscape --export-latex --export-type=pdf $< \
		--export-filename=figuras/$$(basename -s .svg $<).pdf

# ── Compilación rápida por capítulo ────────────────────────────────
# Requiere una compilación completa previa (make) para tener los .aux
# del resto de capítulos y que las referencias cruzadas funcionen.
# Fuerza la recompilación eliminando el PDF previo porque el cambio
# en \includeonly no es detectado por latexmk como cambio de fuente.
fast: $(DEPENDENCIAS) .latexmkrc | $(DIR_SALIDA) $(DIR_BUILD)
ifndef CHAPTER
	$(error Define CHAPTER=... para compilar un solo capítulo. Ej: make fast CHAPTER=filosofiaciencia)
endif
	@mkdir -p $(DIR_BUILD)/capitulos $(DIR_BUILD)/preambulo
	$(generate_includeonly)
	@rm -f $(DIR_BUILD)/$(DOCUMENTO).pdf
	latexmk -f -pdflua $(DOCUMENTO).tex
	cp $(DIR_BUILD)/$(DOCUMENTO).pdf $(DIR_SALIDA)/$(DOCUMENTO).pdf
	$(generate_deps)

# ── Modo desarrollo: detecta el capítulo modificado más recientemente
dev:
	@latest=$$(find capitulos -name '*.tex' -newer $(DIR_SALIDA)/$(DOCUMENTO).pdf 2>/dev/null | head -1); \
	if [ -n "$$latest" ]; then \
		ch=$$(basename "$$latest" .tex); \
		echo "→ Capítulo modificado: $$ch"; \
		$(MAKE) fast CHAPTER="$$ch"; \
	else \
		echo "→ Sin cambios en capítulos. PDF actualizado."; \
	fi

# ═══════════════════════════════════════════════════════════════════
# EPUB — tex4ebook
# ═══════════════════════════════════════════════════════════════════

# Una sola pasada de lualatex genera .bcf y .idx
build/$(DOCUMENTO).bcf build/$(DOCUMENTO).idx &: $(ARCHIVOS_TEX) bibliografia.bib | build
	TEXMF_OUTPUT_DIRECTORY=build lualatex -shell-escape -interaction=nonstopmode $(DOCUMENTO).tex >/dev/null 2>&1 || true

build/$(DOCUMENTO).bbl: build/$(DOCUMENTO).bcf bibliografia.bib
	biber --output-directory=build build/$(DOCUMENTO)

build/$(DOCUMENTO).ind: build/$(DOCUMENTO).idx
	makeindex -o build/$(DOCUMENTO).ind build/$(DOCUMENTO).idx

$(DIR_SALIDA)/$(DOCUMENTO).epub: $(ARCHIVOS_TEX) $(ARCHIVOS_CODIGO) bibliografia.bib \
                                  $(ARCHIVOS_EPUB) $(ARCHIVOS_IMG) scripts/fix_epub_fonts.py \
                                  build/$(DOCUMENTO).bbl build/$(DOCUMENTO).ind | $(DIR_SALIDA)
	# tex4ebook necesita el .log en el directorio actual; sin
	# TEXMF_OUTPUT_DIRECTORY lo genera aquí y luego limpiamos.
	tex4ebook -l -c epub.cfg -d epub $(DOCUMENTO).tex 2>/dev/null || true
	# Extraer EPUB, inyectar fuentes + CSS, y re-empaquetar
	mkdir -p epub_work/OEBPS/fonts
	cd epub_work && unzip -o ../epub/$(DOCUMENTO).epub 2>/dev/null
	# Concatenar nuestro epub.css al CSS generado
	cat epub.css >> epub_work/OEBPS/$(DOCUMENTO).css
	# Copiar fuentes
	$(foreach f,$(FONTS_TEXGYRE),cp $(FONTS_TEXGYRE_DIR)/$(f) epub_work/OEBPS/fonts/;)
	cp $(FONTS_TEXGYRE_MATH_DIR)/$(FONT_PAGELLA_MATH) epub_work/OEBPS/fonts/
	$(foreach f,$(FONTS_JETBRAINS),cp $(FONTS_JETBRAINS_DIR)/$(f) epub_work/OEBPS/fonts/;)
	# Actualizar OPF y re-empaquetar
	python3 scripts/fix_epub_fonts.py epub_work $(DIR_SALIDA)/$(DOCUMENTO).epub
	# Limpiar
	rm -rf epub_work
	# Preservar timestamps
	@touch build/$(DOCUMENTO).bbl build/$(DOCUMENTO).ind

# ═══════════════════════════════════════════════════════════════════
# Utilidades
# ═══════════════════════════════════════════════════════════════════

$(DIR_SALIDA):
	mkdir -p $@

$(DIR_BUILD):
	mkdir -p $@/capitulos $@/preambulo

view: $(DIR_SALIDA)/$(DOCUMENTO).pdf
	xdg-open $<

epub-view: $(DIR_SALIDA)/$(DOCUMENTO).epub
	xdg-open $<

# Listar capítulos disponibles para make fast CHAPTER=...
list-chapters chapters:
	@echo "Capítulos disponibles:"
	@for c in $(CAPITULOS); do echo "  $$c"; done

clean:
	latexmk -C
	# Clean any aux files that leaked to the workspace root
	rm -f $(DOCUMENTO).4ct $(DOCUMENTO).4tc $(DOCUMENTO).aux $(DOCUMENTO).bbl \
	      $(DOCUMENTO).bcf $(DOCUMENTO).blg $(DOCUMENTO).css $(DOCUMENTO).dvi \
	      $(DOCUMENTO).html $(DOCUMENTO).idv $(DOCUMENTO).idx $(DOCUMENTO).ilg \
	      $(DOCUMENTO).ind $(DOCUMENTO).lg $(DOCUMENTO).log $(DOCUMENTO).ncx \
	      $(DOCUMENTO).out $(DOCUMENTO).run.xml $(DOCUMENTO).toc \
	      $(DOCUMENTO).tmp $(DOCUMENTO).xref content.opf
	rm -f $(DOCUMENTO)ch*.html $(DOCUMENTO)li*.html $(DOCUMENTO)*x.svg
	rm -f fullbuild.log indent.log
	rm -f $(DOCUMENTO).pdf
	git clean -Xdf

# ── Formateo ───────────────────────────────────────────────────────
format:
	latexindent -w -s -l $(DOCUMENTO).tex
	latexindent -w -s -l capitulos/*.tex
	latexindent -w -s -l preambulo/*.tex

format-check:
	@fail=0; \
	for f in $(DOCUMENTO).tex capitulos/*.tex preambulo/*.tex; do \
		tmp=$$(mktemp /tmp/latexindent-XXXXXX.tex); \
		latexindent -s -l "$$f" -o="$$tmp" 2>/dev/null; \
		if ! cmp -s "$$f" "$$tmp"; then \
			echo "FAIL: $$f needs formatting"; \
			fail=1; \
		fi; \
		rm -f "$$tmp"; \
	done; \
	if [ $$fail -eq 0 ]; then echo "OK: all files formatted"; fi; \
	exit $$fail
