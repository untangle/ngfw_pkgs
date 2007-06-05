AUTOMAKE_OPTIONS = no-dependencies foreign

lib_LTLIBRARIES = libgocr.la

libgocr_la_SOURCES =	\
	_gocr.h 	\
	block.c		\
	find.c		\
	gui.c		\
	hash.c		\
	image.c		\
	init.c 		\
	list.c 		\
	modules.c 	\
	pixel.c		\
	print.c 	\
	recog.c		\
	text.c		\
	unicode.c

libgocr_la_CFLAGS = -g $(CFLAGS)
libgocr_la_LDFLAGS = -export-dynamic
libgocr_la_LIBADD = @LIBLTDL@ "-dlopen" self @PNM_LIBS@
libgocr_la_DEPENDENCIES = @LIBLTDL@

noinst_HEADERS = _gocr.h
