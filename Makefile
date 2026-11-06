WAYBACK_TIME = \
	archive/site/2024-11-09.patch

site:
	./bootstrap
	${MAKE} -f Makefile.inc site

archive: public/archive/site/2024-11-09.patch

public/archive/site/2024-11-09.patch:
	@mkdir -p $(dir $@)
	git format-patch NEOCITIES..2024-11-09 --stdout > $@

clean:
	rm -rf public

test:
	prove t/*.t

.PHONY: site archive clean test
