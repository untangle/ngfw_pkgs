DESTDIR ?= /usr/share/untangle/web/vue

build:

install: dir yarn dist

dir:
	mkdir -p $(DESTDIR)

yarn:
	cd ./source; \
	yarnpkg install; \
	yarnpkg build

dist: yarn
	cp -r ./source/dist/. $(DESTDIR)
	rm -rf ./source/dist

.PHONY: build install dir yarn dist
