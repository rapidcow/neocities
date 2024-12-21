SRC = \
      robots.txt \
      index.html \
      base.css \
      main.css

site: $(SRC:%=public/%)
public/%.html: site/%.html
	@mkdir -p $(dir $@)
	carmel exec ./render $*.html > $@
public/%: site/%
	@mkdir -p $(dir $@)
	cp $< $@
