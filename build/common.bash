#!bash

# package [-u OWNER] [-g GROUP] TAG DIR OUT is basically
# tar czvf OUT DIR (the tag is an afterthought)
#
# OWNER and GROUP are NAME:ID as in GNU tar's --owner/--group,
# so both the name and the number get pinned no matter which
# machine we are on.  defaults are root:0 and wheel:0; pass
# -g root:0 to reproduce archives from before then.
package () {
	local tag dir out commitdate owner group opt OPTIND OPTARG
	owner=root:0
	group=wheel:0
	while getopts g:u: opt; do
		case "$opt" in
		g) group=$OPTARG ;;
		u) owner=$OPTARG ;;
		*) >&2 echo "usage: package [-u OWNER] [-g GROUP] TAG DIR OUT"
		   return 2 ;;
		esac
	done
	shift $((OPTIND - 1))
	tag="$1"
	shift
	dir="$1"
	out="$2"
	# comes from https://reproducible-builds.org/docs/archives/ again
	oid=$(git rev-parse refs/tags/"$tag")
	commitdate="$(git show -s --pretty=format:%ct $oid^0 --)"
	echo packaging "$out" dated "$commitdate"
	# comment migrated from Makefile:
	# https://reproducible-builds.org/docs/archives/
	# https://stackoverflow.com/a/58141664
	# Pin archive metadata and suppress gzip's filename and timestamp.
	#
	# also: use commit date intsead of annotated tag date,
	# because the latter can be (unnecessarily) off
	find "$dir" -print0 | LC_COLLATE=C sort -z |
	$GNU_TAR cvvf - --no-recursion --null --files-from=- \
		--mtime=@$commitdate --owner="$owner" --group="$group" |
	$GNU_GZIP -n > "$out"
}

# Older builds require GNU make.
find_gnu_make () {
	local cand cands
	if [ -n "${GNU_MAKE:-}" ]; then
		cands=("$GNU_MAKE")
	else
		cands=(gmake make)
	fi
	for cand in "${cands[@]}"; do
		if "$cand" --version 2>/dev/null | head -n 1 | grep -q 'GNU Make'; then
			GNU_MAKE=$(command -v -- "$cand")
			return 0
		fi
	done
	>&2 echo "error: GNU Make not found (tried ${cands[*]})"
	return 1
}
find_gnu_make

# package relies on GNU tar flags; bsdtar would either reject them
# or do something different, so find GNU tar up front (homebrew
# installs it as gtar).  set GNU_TAR to use that one and only that.
find_gnu_tar () {
	local cand cands
	if [ -n "${GNU_TAR:-}" ]; then
		cands=("$GNU_TAR")
	else
		cands=(gtar tar)
	fi
	for cand in "${cands[@]}"; do
		if "$cand" --version 2>/dev/null | head -n 1 | grep -q 'GNU tar'; then
			GNU_TAR=$(command -v -- "$cand")
			return 0
		fi
	done
	>&2 echo "error: GNU tar not found (tried ${cands[*]})"
	return 1
}
find_gnu_tar

find_gnu_gzip () {
	local compressor=${GNU_GZIP:-gzip}
	local OS=$(uname -s)
	case "$OS" in
	Darwin|FreeBSD)
		# GNU tar's -z can otherwise pick Apple's gzip, which produces
		# different bytes. Homebrew provides GNU gzip via `brew install gzip'.
		# FreeBSD has GNU gzip `pkg install archivers/gzip'.
		if ! $compressor --version 2>/dev/null | grep -q 'Free Software Foundation'; then
			>&2 echo "error: package requires GNU gzip on ${OS}."
			>&2 echo "error: If you have one, set GNU_GZIP to its path."
			case "$OS" in
			Darwin)
				# My sincerest apologies to the MacPorts users. :(
				>&2 echo "error: You may install it with: brew install gzip"
				;;
			FreeBSD)
				>&2 echo "error: You may install it with: pkg install gzip"
				>&2 echo "error: Then: env GNU_GZIP=/usr/local/bin/gzip"
				;;
			esac
			return 1
		fi
	esac
	GNU_GZIP=$compressor
}
find_gnu_gzip

# fetch_git DEST COMMIT URL... clones the first URL that has
# COMMIT into DEST, detached at COMMIT.  since we pin the full
# commit id, it doesn't matter which mirror ends up answering.
fetch_git () {
	local dest commit url
	dest="$1"
	commit="$2"
	shift 2
	for url in "$@"; do
		rm -rf -- "$dest"
		if git clone --quiet --no-checkout -- "$url" "$dest" &&
			git -C "$dest" -c advice.detachedHead=false \
				checkout --quiet --detach "$commit" &&
			[ "$(git -C "$dest" rev-parse HEAD)" = "$commit" ]
		then
			echo "got $commit from $url"
			return 0
		fi
		>&2 echo "warning: could not get $commit from $url"
	done
	rm -rf -- "$dest"
	>&2 echo "error: none of the mirrors have $commit"
	return 1
}

# RdKw::Algo::BSearch v0.00_44 (replaces List::BisectSearch)
# add more mirrors here; any of them will do
ALGO_BSEARCH_COMMIT=5e6f1f811461dbfc371a8f7b9414ad3992d60547
ALGO_BSEARCH_MIRRORS=(
	https://git.rapidcow.org/pub/lib/perl5/Algo-BSearch.git
# Popular guys
	https://github.com/rapidcow/p5-Algo-BSearch.git
	https://gitlab.com/rapidcow/p5-Algo-BSearch.git
# Less popular guys
	https://gitea.com/rapidcow/p5-Algo-BSearch.git
	https://bitbucket.org/rapidcow/p5-Algo-BSearch.git
# China
	https://gitcode.com/rapidcow/p5-Algo-BSearch.git
	https://gitee.com/rapidcow/p5-Algo-BSearch.git
)

# we should be in my/site/neocities/build
TREE_ROOT="$(realpath "$(dirname ${BASH_SOURCE[0]})"/../../../..)/"

# https://stackoverflow.com/a/687052
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

target="${PWD}/$1"

git clone --shared "$(git rev-parse --git-dir)" "$tmp"

# all good
return 0
