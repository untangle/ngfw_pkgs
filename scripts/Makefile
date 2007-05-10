DISTRIBUTION ?= `cat ../../version/resources/RELEASE_CODENAME`

checkroot:
	@if [ "$$UID" = "0" ]; then \
	  echo "You can't be root to build packages"; \
	  exit 1; \
	fi

clean: checkroot
	fakeroot debian/rules clean

version: checkroot
	dch -i -D $(DISTRIBUTION) "auto build"

pkg: checkroot version
	# FIXME: sign packages when we move to apt 0.6
	/usr/bin/debuild -i --no-tgz-check -us -uc

release: checkroot pkg
	svn commit -m"released" debian/changelog
	dput -c ../scripts/dput.cf mephisto ../`dpkg-parsechangelog | grep "Version: " | perl -npe 's/.*: //'`*.changes

.PHONY: checkroot clean version pkg release