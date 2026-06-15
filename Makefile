DOCUMENTO = catedraciencias
DIR_SALIDA = salida

ARCHIVOS_TEX = \
	$(DOCUMENTO).tex \
	$(wildcard capitulos/*.tex) \
	$(wildcard preambulo/*.tex)
ARCHIVOS_SVG = $(wildcard figuras/*.svg)
ARCHIVOS_CODIGO = $(wildcard codigos/*.*)
ARCHIVOS_PDFTEX = $(patsubst %.svg, %.pdf_tex, $(ARCHIVOS_SVG))
DEPENDENCIAS = $(ARCHIVOS_TEX) $(ARCHIVOS_PDFTEX) \
	$(ARCHIVOS_CODIGO) bibliografia.bib
ARCHIVOS_EPUB = epub.cfg epub.css

# ---- Fuentes embebidas en EPUB ----

# Directorios base de las fuentes
FONTS_TEXGYRE_DIR = /usr/share/texmf/fonts/opentype/public/tex-gyre
FONTS_TEXGYRE_MATH_DIR = /usr/share/texmf/fonts/opentype/public/tex-gyre-math
FONTS_JETBRAINS_DIR = /home/vscode/.local/share/fonts/fonts/ttf

# Listas de fuentes por familia
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

.PHONY: all clean view epub epub-view format format-check
.NOTPARALLEL:

all: $(DIR_SALIDA)/$(DOCUMENTO).pdf $(DIR_SALIDA)/$(DOCUMENTO).epub

# ---- PDF (latexmk) ----

$(DIR_SALIDA)/$(DOCUMENTO).pdf: $(DEPENDENCIAS) .latexmkrc | $(DIR_SALIDA)
	@mkdir -p build/capitulos build/preambulo
	latexmk -f -pdflua $(DOCUMENTO).tex
	cp build/$(DOCUMENTO).pdf $@

figuras/%.pdf_tex : figuras/%.svg
	inkscape --export-latex --export-type=pdf $< \
		--export-filename=figuras/$$(basename -s .svg $<).pdf ;

# ---- Auxiliares EPUB (biber + makeindex) ----

# Una sola pasada de lualatex genera .bcf y .idx
$(DOCUMENTO).bcf $(DOCUMENTO).idx: $(ARCHIVOS_TEX) bibliografia.bib
	@rm -f $(DOCUMENTO).aux capitulos/*.aux preambulo/*.aux
	lualatex -shell-escape -interaction=nonstopmode $(DOCUMENTO).tex >/dev/null 2>&1 || true

$(DOCUMENTO).bbl: $(DOCUMENTO).bcf bibliografia.bib
	biber $(DOCUMENTO)

$(DOCUMENTO).ind: $(DOCUMENTO).idx
	makeindex $(DOCUMENTO).idx

# ---- EPUB ----

$(DIR_SALIDA)/$(DOCUMENTO).epub: $(ARCHIVOS_TEX) $(ARCHIVOS_CODIGO) bibliografia.bib $(ARCHIVOS_EPUB) img/* scripts/fix_epub_fonts.py $(DOCUMENTO).bbl $(DOCUMENTO).ind | $(DIR_SALIDA)
	TEXMF_OUTPUT_DIRECTORY=. tex4ebook -l -c epub.cfg -d epub $(DOCUMENTO).tex 2>/dev/null || true
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
	# Preservar timestamps: tex4ebook regenera .bcf/.idx pero no .bbl/.ind
	@touch $(DOCUMENTO).bbl $(DOCUMENTO).ind

epub: $(DIR_SALIDA)/$(DOCUMENTO).epub

epub-view: $(DIR_SALIDA)/$(DOCUMENTO).epub
	xdg-open $<

# ---- Varios ----

$(DIR_SALIDA):
	mkdir --verbose --parents $(DIR_SALIDA)

view: $(DIR_SALIDA)/$(DOCUMENTO).pdf
	xdg-open $<

clean:
	latexmk -C
	git clean -Xdf

# ---- Formateo ----

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