DESTDIR ?= /usr/share/untangle/web/vue

build:

install: dir prepare yarn copy

dir:
	mkdir -p $(DESTDIR)

prepare:
	sudo apt -y install nodejs yarnpkg

yarn:
	yarn --cwd ./source/ install
	yarn --cwd ./source/ build

copy:
	cp -r ./source/dist/. $(DESTDIR)
	rm -rf ./source/dist

.PHONY: build install dir prepare yarn copy
