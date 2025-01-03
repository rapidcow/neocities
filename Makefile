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

site: $(SITE_FILES:%=public/%) $(MORE_FILES:%=public/%)
public/%: site/% render
	@mkdir -p $(dir $@)
	carmel exec ./render $* > $@
public/%: more/%
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

.PHONY: site
