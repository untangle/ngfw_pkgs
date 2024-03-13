DESTDIR ?= /usr/share/untangle/web/vue

build:

install: dir yarn copy

dir:
	mkdir -p $(DESTDIR)

yarn:
	cd ./source; \
	yarnpkg install; \
	yarnpkg build

copy:
	cp -r ./source/dist/. $(DESTDIR)
	rm -rf ./source/dist

.PHONY: build install dir prepare yarn copy
