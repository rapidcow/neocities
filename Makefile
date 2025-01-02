BASE_URL ?= # the empty string, i.e. "/" is root
SITE_URL ?= https://neocities.rapidcow.org
export BASE_URL SITE_URL

SITE_FILES = \
	index.html \
	about.html
MORE_FILES = \
	base.css \
	main.css \
	ansi.css \
	robots.txt

site: $(SITE_FILES:%=public/%) $(MORE_FILES:%=public/%)
public/%: site/%
	@mkdir -p $(dir $@)
	carmel exec ./render $* > $@
public/%: more/%
	@mkdir -p $(dir $@)
	cp $< $@
