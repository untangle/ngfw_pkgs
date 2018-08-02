install: copy locales

copy:
	mkdir -p $(DESTDIR)
	cp -ra files/* $(DESTDIR)

locales:
	for f in $(shell find ./po -name '*.po') ; do \
	  locale=$(shell echo $${f} | cut -d/ -f 3) ; \
	  dir="$(DESTDIR)/usr/share/locale/$${locale}/LC_MESSAGES" ; \
	  mkdir -p $${dir} ; \
	  msgfmt -o $${dir}/untangle-apache2-config.mo $${f} ; \
	done

.PHONY: install copy locales
