DISTRIBUTION ?= `cat ../../version/resources/RELEASE_CODENAME`

checkroot:
	@if [ "$$UID" = "0" ]; then \
	  echo "You can't be root to build packages"; \
	  exit 1; \
	fi

clean: checkroot
	fakeroot debian/rules clean

version: checkroot
	sh ../scripts/incVersion.sh $(DISTRIBUTION)
	# so we can use that later to find out what to upload if needs be
	dpkg-parsechangelog | awk '/Version: / { print $$2 }' >| debian/version
#	dch -i -D $(DISTRIBUTION) "auto build"

pkg: checkroot version
	# FIXME: sign packages when we move to apt 0.6
	/usr/bin/debuild --no-tgz-check -i -us -uc

release: checkroot pkg
	svn commit revert debian/changelog
	dput -c ../scripts/dput.cf mephisto ../*`dpkg-parsechangelog | awk '/Version: / { print $$2 }'`*.changes

.PHONY: checkroot clean version pkg release