DOCUMENTO = catedraciencias
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

.PHONY: clean
.PHONY: view

$(DOCUMENTO).pdf: $(DEPENDENCIAS)
	latexmk -shell-escape -synctex=1 -pdflatex=lualatex \
	-interaction=nonstopmode -file-line-error -pdf $(DOCUMENTO).tex

figuras/%.pdf_tex : figuras/%.svg
	inkscape --export-latex --export-type=pdf $< \
		--export-filename=figuras/$$(basename -s .svg $<).pdf ;

$(AUX_DIR):
	mkdir auxiliares --verbose --parents

clean:
	git clean -Xdf

view:
	xdg-open $(DOCUMENTO).pdf