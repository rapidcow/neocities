#!/usr/bin/env bash
# re-derive archive/sha256sum.txt from what neocities serves.
#
# for every YYYY-MM-DD tag, download $tag.tar.gz and $tag.sha256 from
# $BASE_URL, check the tarball's contents against the published
# per-file sums (same recipe as public/%.sha256 in the Makefile), and
# record the sha256 of the tarball itself.  nothing is cached; every
# run fetches from the web again.
#
# usage: archive/fetch.sh   (from anywhere inside the repo)

set -euEo pipefail

BASE_URL=https://rapidcow.neocities.org/archive/site

top=$(git rev-parse --show-toplevel)
out="$top/archive/sha256sum.txt"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

git -C "$top" tag --list | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort |
while read -r tag; do
	>&2 echo "fetching $tag"
	curl -sSfL -o "$tmp/$tag.tar.gz" "$BASE_URL/$tag.tar.gz"
	curl -sSfL -o "$tmp/$tag.sha256" "$BASE_URL/$tag.sha256"
	# DO NOT PASS -v! (see Makefile)
	tar xf "$tmp/$tag.tar.gz" --to-command "'$top/tarsum' sha256" \
		> "$tmp/$tag.computed"
	if ! cmp -s "$tmp/$tag.sha256" "$tmp/$tag.computed"; then
		>&2 echo "error: $tag.tar.gz does not match $tag.sha256"
		>&2 diff -- "$tmp/$tag.sha256" "$tmp/$tag.computed" || :
		exit 1
	fi
	(cd "$tmp" && sha256sum -- "$tag.tar.gz")
done > "$tmp/sha256sum.txt"

mv -- "$tmp/sha256sum.txt" "$out"
>&2 echo "wrote $out"
