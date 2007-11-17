default:
	@cat README

prep:
	bash $(CURDIR)/scripts/prep.sh

clean:
	$(MAKE) -f $(CURDIR)/debian/rules clean

binary:
	$(CURDIR)/debian/rules binary

.PHONY: prep
