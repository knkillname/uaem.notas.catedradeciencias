DOCUMENTO = catedraciencias
DIR_SALIDA = salida

ARCHIVOS_TEX = \
	$(DOCUMENTO).tex \
	$(wildcard capitulos/*.tex) \
	$(wildcard preambulo/*.tex)
ARCHIVOS_SVG = $(wildcard figuras/*.svg)
ARCHIVOS_CODIGO = $(wildcard codigos/*.*)
ARCHIVOS_PDFTEX = $(patsubst %.svg, %.pdf_tex, $(ARCHIVOS_SVG))
AUX_DIR = auxiliares
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

.PHONY: all clean view epub epub-view

all: $(DIR_SALIDA)/$(DOCUMENTO).pdf $(DIR_SALIDA)/$(DOCUMENTO).epub

# ---- PDF ----

$(DIR_SALIDA)/$(DOCUMENTO).pdf: $(DEPENDENCIAS) | $(DIR_SALIDA)
	lualatex -shell-escape -synctex=1 \
		-interaction=nonstopmode -file-line-error $(DOCUMENTO).tex
	-biber $(DOCUMENTO)
	-makeindex $(DOCUMENTO).idx
	lualatex -shell-escape -synctex=1 \
		-interaction=nonstopmode -file-line-error $(DOCUMENTO).tex
	lualatex -shell-escape -synctex=1 \
		-interaction=nonstopmode -file-line-error $(DOCUMENTO).tex
	cp $(DOCUMENTO).pdf $@

figuras/%.pdf_tex : figuras/%.svg
	inkscape --export-latex --export-type=pdf $< \
		--export-filename=figuras/$$(basename -s .svg $<).pdf ;

$(AUX_DIR):
	mkdir auxiliares --verbose --parents

# ---- EPUB ----

$(DIR_SALIDA)/$(DOCUMENTO).epub: $(ARCHIVOS_TEX) $(ARCHIVOS_CODIGO) bibliografia.bib $(ARCHIVOS_EPUB) img/* scripts/fix_epub_fonts.py | $(DIR_SALIDA)
	-tex4ebook -l -c epub.cfg -d epub $(DOCUMENTO).tex 2>/dev/null
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

epub: $(DIR_SALIDA)/$(DOCUMENTO).epub

epub-view: $(DIR_SALIDA)/$(DOCUMENTO).epub
	xdg-open $<

# ---- Varios ----

$(DIR_SALIDA):
	mkdir --verbose --parents $(DIR_SALIDA)

view: $(DIR_SALIDA)/$(DOCUMENTO).pdf
	xdg-open $<

clean:
	rm -rf _minted/ epub/ catedraciencias-epub/ auxiliares/ .mypy_cache/
	for ext in 4ct 4tc aux bbl bcf blg css dvi fdb_latexmk fls html idv idx ilg \
	          ind lg log ncx out pdf pyg run.xml synctex.gz tmp toc trc xref; do \
		rm -f "$(DOCUMENTO).$$ext"; \
	done
	rm -f $(DOCUMENTO)ch*.html $(DOCUMENTO)li*.html content.opf
	rm -f capitulos/*.aux preambulo/*.aux