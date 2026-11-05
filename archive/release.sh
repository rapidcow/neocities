#!/usr/bin/env bash
# upload archive/$tag.tar.gz as site.tar.gz on a DRAFT github release
# for $tag, with the tarball's sha256sum as the release notes.
#
# before uploading, the annexed file is checked against sha256sum.txt
# (both the annex key and the content itself).  tags that already
# have a release (draft or not) are skipped.  publishing the drafts
# is left to you.
#
# usage: archive/release.sh [TAG...]   (default: every tag in sha256sum.txt)

set -euEo pipefail

REPO=rapidcow/neocities

top=$(git rev-parse --show-toplevel)
cd "$top/archive"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

# a release published while this is on can never be changed or
# deleted again, so refuse to go anywhere near it
if gh api "repos/$REPO/immutable-releases" --jq .enabled | grep -qx false; then
	:
else
	>&2 echo "error: immutable releases are (or may be) on for $REPO; not touching it"
	exit 1
fi

# releases (drafts included) that already exist, by tag
gh api --paginate "repos/$REPO/releases" --jq '.[].tag_name' > "$tmp/existing"

if [ $# -eq 0 ]; then
	set -- $(cut -d ' ' -f 3 sha256sum.txt | sed 's/\.tar\.gz$//')
fi

for tag in "$@"; do
	file="$tag.tar.gz"
	hash=$(awk -v f="$file" '$2 == f { print $1 }' sha256sum.txt)
	if [ -z "$hash" ]; then
		>&2 echo "error: $file is not in sha256sum.txt"
		exit 1
	fi

	# the annex key should carry the same hash...
	key=$(basename "$(readlink -- "$file")")
	if ! [[ $key =~ ^SHA256E-s([0-9]+)--$hash\.tar\.gz$ ]]; then
		>&2 echo "error: annex key $key of $file does not match sha256sum.txt"
		exit 1
	fi
	# ...and so should the content (which has to be present)
	if ! [ -e "$file" ]; then
		>&2 echo "error: content of $file is not here (git annex get $file?)"
		exit 1
	fi
	if [ "$(sha256sum < "$file" | cut -d ' ' -f 1)" != "$hash" ] ||
	   [ "$(stat -L -c %s -- "$file")" != "${BASH_REMATCH[1]}" ]; then
		>&2 echo "error: content of $file does not match its annex key"
		exit 1
	fi

	if grep -qxF -- "$tag" "$tmp/existing"; then
		>&2 echo "skipping $tag: it already has a release"
		continue
	fi

	mkdir -p "$tmp/$tag"
	cp -- "$file" "$tmp/$tag/site.tar.gz"
	printf '```\n%s  site.tar.gz\n```\n' "$hash" > "$tmp/$tag/notes"
	>&2 echo "drafting $tag"
	gh release create "$tag" "$tmp/$tag/site.tar.gz" -R "$REPO" \
		--draft --verify-tag --title "$tag" --notes-file "$tmp/$tag/notes"

	# github computes its own digest of the upload; make sure it agrees
	# (it can take a moment to show up)
	for try in 1 2 3 4 5 6 7 8 9 10; do
		digest=$(gh api --paginate "repos/$REPO/releases" --jq \
			".[] | select(.tag_name == \"$tag\" and .draft) | .assets[] |
			select(.name == \"site.tar.gz\") | .digest")
		[ -z "$digest" ] || break
		sleep 2
	done
	if [ "$digest" != "sha256:$hash" ]; then
		>&2 echo "error: github has '$digest' for $tag/site.tar.gz, expected sha256:$hash"
		exit 1
	fi
	>&2 echo "ok: $tag/site.tar.gz is $digest"
done
