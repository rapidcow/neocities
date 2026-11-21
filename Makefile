site:
	./bootstrap
	${MAKE} -f Makefile.inc site

clean:
	rm -rf public

test:
	prove t/*.t

.PHONY: site archive clean test
