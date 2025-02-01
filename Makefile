BASE_URL ?= # the empty string, i.e. "/" is root
SITE_URL ?= https://rapidcow.neocities.org
export BASE_URL SITE_URL

PERL5 ?= carmel exec perl -Ilib

SITE_FILES = \
	index.html \
	about.html \
	not_found.html \
	news/index.html \
	news/2025-01-03.html
MORE_FILES = \
	base.css \
	main.css \
	ansi.css \
	news.css \
	robots.txt
# note: some contrib files are generated dynamically
# (placed within site/), they are to be excluded from
# git log and the like stuff
CONTRIB_FILES = \
	share/index.html \
	share/int10h.org/index.html \
	share/int10h.org/oldschool-pc-fonts/index.html \
	share/int10h.org/oldschool-pc-fonts/v2.2/index.html \
	share/int10h.org/oldschool-pc-fonts/v2.2/README.TXT \
	share/int10h.org/oldschool-pc-fonts/v2.2/LICENSE.TXT \
	share/int10h.org/oldschool-pc-fonts/v2.2/Web437_IBM_VGA_8x16.woff
WAYBACK_TIME = \
	$(patsubst %,archive/site/%.tar.gz,2024-11-09 2024-11-10 2025-01-03)

site: $(SITE_FILES:%=public/%) $(MORE_FILES:%=public/%) $(CONTRIB_FILES:%=public/%)
public/%: site/% render
	@mkdir -p $(dir $@)
	$(PERL5) render $* > $@
public/%: more/%
	@mkdir -p $(dir $@)
	cp $< $@
public/share/%: share/%
	@mkdir -p $(dir $@)
	cp $< $@
# i don't know how "appending" prerequisite works...
# i hope this does it?
# https://www.gnu.org/software/make/manual/make.html#Match_002dAnything-Rules
public/index.html: $(patsubst %,include/%.txt,WELCOME SITEMAP EPILOG TAGLINE)
public/about.html: $(patsubst %,include/%.txt,README TAGLINE)

# all HTMLs inherit from the base template so far...
$(patsubst %,public/%.html,index about not_found news/index.html): temple/base/head.html
# cache invalidation demands that the links be rebuilt
$(patsubst %,public/%.html,index about not_found news/index.html): $(patsubst %,more/%.css,base ansi main)
public/news/index.html: more/news.css

# standalone HTML dependencies
public/share/index.html: temple/minimal/head.html

public/share/int10h.org/index.html \
public/share/int10h.org/oldschool-pc-fonts/index.html \
public/share/int10h.org/oldschool-pc-fonts/v2.2/index.html: temple/redirect/index.html
# XXX: does this work? (hook dependencies of redirect
# to also depend on head...)
temple/redirect.html: temple/minimal/head.html

archive: $(WAYBACK_TIME:%=public/%)
public/archive/site/2024-11-%.tar.gz:
	@mkdir -p $(dir $@)
	git archive --format=tgz --prefix=public/ 2024-11-$*:site/ > $@

public/archive/site/%.tar.gz:
	@mkdir -p $(dir $@)
	@rm -rf tmp
	git clone $(shell git rev-parse --git-dir) tmp
	git -c advice.detachedHead=false -C tmp checkout $*
	cd tmp && carmel install
	@# i will assume that you have my List::BinarySearch installed...
	$(MAKE) -C tmp site
	fakeroot tar czf $@ -C tmp public
	@rm -rf tmp

clean:
	rm -rf public

.PHONY: site archive clean
