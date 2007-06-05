# change this !

all: gnome/Makefile
	$(MAKE) -C gnome all

install:


clean: gnome/Makefile
	$(MAKE) -C gnome distclean-generic


gnome/Makefile: gnome/configure
	(cd gnome;configure)

