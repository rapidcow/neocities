archive = \
	public/archive/site/2024-11-09.patch

site: ${archive}
	./bootstrap
	${MAKE} -f Makefile.inc site

public/.ok:
	[ -d public ] || mkdir -- public
	@> public/.ok

public/archive/.ok: public/.ok
	[ -d public/archive ] || mkdir -- public/archive
	@> public/archive/.ok

public/archive/site/.ok: public/archive/.ok
	[ -d public/archive/site ] || mkdir -- public/archive/site
	@> public/archive/site/.ok

public/archive/site/2024-11-09.patch: public/archive/site/.ok
	git format-patch NEOCITIES..2024-11-09 --stdout > $@

clean:
	rm -rf public

test:
	prove t/*.t

.PHONY: site archive clean test
