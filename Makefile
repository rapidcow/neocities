BASE_URL ?= # the empty string, i.e. "/" is root
SITE_URL ?= https://rapidcow.neocities.org
export BASE_URL SITE_URL

SITE_FILES = \
	index.html \
	about.html \
	not_found.html
MORE_FILES = \
	base.css \
	main.css \
	ansi.css \
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

site: $(SITE_FILES:%=public/%) $(MORE_FILES:%=public/%) $(CONTRIB_FILES:%=public/%)
public/%: site/% render
	@mkdir -p $(dir $@)
	carmel exec ./render $* > $@
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
$(patsubst %,public/%.html,index about not_found): temple/base/head.html
# cache invalidation demands that the links be rebuilt
$(patsubst %,public/%.html,index about not_found): $(patsubst %,more/%.css,base ansi main)

# standalone HTML dependencies
public/share/index.html: temple/minimal/head.html

public/share/int10h.org/index.html \
public/share/int10h.org/oldschool-pc-fonts/index.html \
public/share/int10h.org/oldschool-pc-fonts/v2.2/index.html: temple/redirect/index.html
# XXX: does this work? (hook dependencies of redirect
# to also depend on head...)
temple/redirect.html: temple/minimal/head.html

.PHONY: site
