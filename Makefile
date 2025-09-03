BASE_URL ?= # the empty string, i.e. "/" is root
SITE_URL ?= https://rapidcow.neocities.org
export BASE_URL SITE_URL

PERL5 ?= carmel exec perl -Ilib

SITE_FILES = \
	index.html \
	about.html \
	not_found.html \
	news/index.html \
	news/2024-11-09.html \
	news/2024-11-10.html \
	news/2025-01-03.html \
	news/2025-02-02.html \
	goods/index.html
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
WAYPOINTS = \
	2024-11-09 2024-11-10 2025-01-03 2025-02-02
WAYBACK_TIME = \
       $(patsubst %,archive/site/%.tar.gz,$(WAYPOINTS)) \
       $(patsubst %,archive/site/%.sha256,$(WAYPOINTS)) \
       archive/site/2024-11-09.patch

site: $(SITE_FILES:%=public/%) $(MORE_FILES:%=public/%) $(CONTRIB_FILES:%=public/%)
public/%: site/% render
	@mkdir -p $(dir $@)
	$(PERL5) ./render $* > $@
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
$(addprefix public/news/,index.html 2024-11-09.html): include/NEWS/2024-11-09.txt
$(addprefix public/news/,index.html 2024-11-10.html): include/NEWS/2024-11-10.txt
$(addprefix public/news/,index.html 2025-01-03.html): include/NEWS/2025-01-03.txt
$(addprefix public/news/,index.html 2025-02-02.html): include/NEWS/2025-02-02.txt

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
	git archive --format=tgz --prefix=public/ 2024-11-$* -- site/ > $@

public/archive/site/2024-11-09.patch:
	@mkdir -p $(dir $@)
	git format-patch NEOCITIES..2024-11-09 --stdout > $@

public/archive/site/%.tar.gz:
	@mkdir -p $(dir $@)
	@# A caveat: since we are effectively using recursive make,
	@# something like make -B will not work because it would
	@# cause Makefiles of Perl package to always self-destruct
	@# Good that we don't have to re-build archives all the time,
	@# otherwise this would really drive me insane.... ^^;
	build/$* $@

public/%.sha256: public/%.tar.gz
	@# computing shasum from tarball...
	@# (.... GNU tar to the rescue! :D)
	@# https://stackoverflow.com/a/42170163
	@# for the format, use GNU format...
	@# HASH HT FILE
	@# https://superuser.com/q/1566136
	@# DO NOT PASS -v!
	tar xf $< --to-command './tarsum sha256' > $@

clean:
	rm -rf public

.PHONY: site archive clean
