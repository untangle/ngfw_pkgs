DESTDIR ?= /usr/share/untangle/web/vue

build:

install: dir yarn copy

dir:
	mkdir -p $(DESTDIR)

yarn:
	npm install --global yarn
	yarn --cwd ./source/ install
	yarn --cwd ./source/ build

copy:
	cp -r ./source/dist/. $(DESTDIR)
	rm -rf ./source/dist

.PHONY: build install dir yarn copy
