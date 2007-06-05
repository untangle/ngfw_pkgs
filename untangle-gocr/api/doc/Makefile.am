all-local:
if LATEX
	@echo "Running LaTeX..."
	-@LATEX@ -interaction=nonstopmode api.tex
	@echo "Running makeindex..."
	makeindex api.idx
	@echo "Rerunning LaTeX..."
	-@LATEX@ -interaction=nonstopmode api.tex
if DVIPS
	echo "Running dvips..."
	-@DVIPS@ api.dvi
endif
if LATEX2HTML
	echo "Running latex2html..."
	-mkdir tutorial
	-@LATEX2HTML@ -dir tutorial api.tex
endif
endif
if DOXYGEN
	@echo "Running doxygen..."
	@DOXYGEN@ api.doxygen
endif


clean-local:
	rm -f api.aux api.dvi api.ilg api.ind api.idx api.log api.toc

dist-local: clean-local
	rm -f api.ps
	rm -rf html man
