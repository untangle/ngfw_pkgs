# add -static to the LDFLAGS if you want to debug it easily.
# or you can do 'libtool gdb prog', but not if you use DDD.

noinst_PROGRAMS = image imagewrite charfind module modtest

INCLUDES = -I../include
GOCRLIB = ../src/libgocr.la

image_SOURCES = image.c
image_LDADD = $(GOCRLIB)
image_LDFLAGS = 

imagewrite_SOURCES = imagewrite.c
imagewrite_LDADD = $(GOCRLIB)
imagewrite_LDFLAGS =

charfind_SOURCES = charfind.c
charfind_LDADD = $(GOCRLIB)
charfind_LDFLAGS = -static

module_SOURCES = module.c
module_LDFLAGS = -export-dynamic -static -dlopen "self" -dlopen  /home/gocr/modules/modules/libtester.la
module_LDADD = $(GOCRLIB)

modtest_SOURCES = modtest.c
modtest_LDFLAGS = -export-dynamic
modtest_LDADD = $(GOCRLIB)

clean-local:
	rm -f imagewrite.ppm charfind.ppm
