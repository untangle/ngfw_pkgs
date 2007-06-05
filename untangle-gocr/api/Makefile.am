AUTOMAKE_OPTIONS = foreign

# INCLUDES = $(INCLTDL)

SUBDIRS = libltdl include src 
#doc

EXTRA_DIST =	Changelog \
		STATUS \
		doc/Makefile.am \
		doc/Makefile.in \
		doc/api.doxygen \
		doc/api.tex \
		doc/developers.txt

dist-hook:
	cp -rp tests $(distdir)
	rm -rf `find $(distdir) -type d -name CVS -print`
	rm -rf `find $(distdir) -type d -name ".deps" -print`

