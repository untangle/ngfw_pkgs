default:
	@cat README

prep:
	$(SHELL) $(CURDIR)/scripts/prep.sh

clean:
	$(MAKE) -f $(CURDIR)/debian/rules clean

binary:
	$(CURDIR)/debian/rules binary

.PHONY: prep
