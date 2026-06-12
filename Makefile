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

.PHONY: all clean view epub epub-view

all: $(DIR_SALIDA)/$(DOCUMENTO).pdf $(DIR_SALIDA)/$(DOCUMENTO).epub

# ---- PDF ----

$(DIR_SALIDA)/$(DOCUMENTO).pdf: $(DEPENDENCIAS) | $(DIR_SALIDA)
	latexmk -shell-escape -synctex=1 -pdflatex=lualatex \
		-interaction=nonstopmode -file-line-error -pdf $(DOCUMENTO).tex
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
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyrepagella-regular.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyrepagella-bold.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyrepagella-italic.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyrepagella-bolditalic.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre-math/texgyrepagella-math.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyreheros-regular.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyreheros-bold.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyreheros-italic.otf epub_work/OEBPS/fonts/
	cp /usr/share/texmf/fonts/opentype/public/tex-gyre/texgyreheros-bolditalic.otf epub_work/OEBPS/fonts/
	cp /home/vscode/.local/share/fonts/fonts/ttf/JetBrainsMonoNL-Regular.ttf epub_work/OEBPS/fonts/
	cp /home/vscode/.local/share/fonts/fonts/ttf/JetBrainsMonoNL-Bold.ttf epub_work/OEBPS/fonts/
	cp /home/vscode/.local/share/fonts/fonts/ttf/JetBrainsMonoNL-Italic.ttf epub_work/OEBPS/fonts/
	cp /home/vscode/.local/share/fonts/fonts/ttf/JetBrainsMonoNL-BoldItalic.ttf epub_work/OEBPS/fonts/
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
	git clean -Xdf