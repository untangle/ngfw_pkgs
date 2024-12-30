DESTDIR ?= /

INSTALL_DIR := $(DESTDIR)/usr/share/untangle/web/vue/

build:

install: dir yarn dist

dir:
	mkdir -p $(INSTALL_DIR)

yarn:
	cd ./source; \
	yarnpkg --force --network-concurrency 1; \
	yarnpkg build

dist: yarn
	cp -r ./source/dist/* $(INSTALL_DIR)
	rm -rf ./source/dist

.PHONY: build install dir yarn dist
