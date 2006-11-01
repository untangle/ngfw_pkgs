RELEASE ?= `whoami`

clean:
	fakeroot debian/rules clean

pkg:
	fakeroot debian/rules binary

version:
	dch -i "auto build"

release: clean version pkg
	@if [ "`hostname`" = "bebe" ] ; then \
		( cd ../ ; sudo ./scripts/deb-add.sh /var/www/${RELEASE}/ ./*disabler*deb &> /dev/null ; sudo ./scripts/deb-scan.sh /var/www/${RELEASE}/ &> /dev/null ) ; \
	else echo "Must be run on bebe"; \
	fi
	svn commit -m"released" debian/changelog
#	echo ${PACKAGENAME} `cat debian/changelog | head -n 1 | awk '{print $$2}'` "released." | mail -s release pkgs@untangle.com ; \


