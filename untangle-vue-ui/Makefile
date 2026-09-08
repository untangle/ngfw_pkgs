DESTDIR ?= /

INSTALL_DIR := $(DESTDIR)/usr/share/untangle/web/vue/

build:

install: dir yarn dist

dir:
	mkdir -p $(INSTALL_DIR)

yarn:
	@# Trixie's apt yarnpkg is Yarn Berry (4.x) which rejects --force and lacks
	@# the `clean` subcommand. Install Yarn Classic (1.x) via npm and use that;
	@# keeps yarn.lock and existing build scripts working unchanged.
	command -v yarn >/dev/null 2>&1 || npm install -g yarn@1.22.22
	cd ./source; \
	yarn install --force --network-concurrency 1 --ignore-engines; \
	yarn clean; \
	yarn build

dist: yarn
	cp -r ./source/dist/* $(INSTALL_DIR)
	rm -rf ./source/dist

.PHONY: build install dir yarn dist
