SITE_FILES = index.html
MORE_FILES = \
      base.css \
      robots.txt \
      neocities.png \

site: $(SITE_FILES:%=public/%) $(MORE_FILES:%=public/%)
public/%: site/%
	@mkdir -p $(dir $@)
	carmel exec ./render $* > $@
public/%: more/%
	@mkdir -p $(dir $@)
	cp $< $@
