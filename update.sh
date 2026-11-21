#!/usr/bin/env bash
# update.sh - bump dreamcoder-local to the newest DreamCoder release.
#
# DreamCoder publishes no checksum or signature for its .deb, so this script
# can only pin what it downloads (trust on first use over HTTPS):
#   1. Read the vendor's own installer, https://www.dreamcoder.ai/install.sh,
#      which names the current .deb URL; its version becomes the candidate.
#   2. Download that .deb and check its control file: package name,
#      architecture and version must match.
#   3. Report anything that would need a PKGBUILD review: payload paths
#      outside usr/ and etc/apt/, a maintainer script that names a systemd
#      service, or a change in the Depends: field.
#   4. Pin the .deb's SHA-256 in PKGBUILD, so every later build of this
#      version fails if the vendor's file changes.
#
# Usage:
#   ./update.sh           # update PKGBUILD and .SRCINFO when a newer version exists
#   ./update.sh --check   # report only; write nothing
#   ./update.sh --force   # re-pin even when the version is not newer
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

INSTALLER=https://www.dreamcoder.ai/install.sh
DEBNAME=dreamcoder-dreamcoder
DEPENDS='libc6, libgcc-s1, libgomp1, libstdc++6, zlib1g'   # as of 1.0.15

check_only=0
force=0
for a in "$@"; do
  case "$a" in
    --check) check_only=1 ;;
    --force) force=1 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

for t in curl bsdtar sha256sum vercmp makepkg awk grep; do
  command -v "$t" >/dev/null || { echo "missing required tool: $t" >&2; exit 2; }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch() { curl --proto '=https' --tlsv1.2 -fsSL "$@"; }

# 1. The installer names exactly one Linux .deb URL.
fetch "$INSTALLER" -o "$tmp/install.sh"
re="https://www\.dreamcoder\.ai/downloads/files/public/[0-9][0-9.]*/linux-deb/debian/${DEBNAME}_[0-9][0-9.]*_amd64\.deb"
mapfile -t urls < <(grep -oE "$re" "$tmp/install.sh" | sort -u)
if [ "${#urls[@]}" -ne 1 ]; then
  echo "ABORT: expected one .deb URL in $INSTALLER, found ${#urls[@]}:" >&2
  printf '  %s\n' "${urls[@]}" >&2
  echo "The vendor may have changed its download layout; review source= by hand." >&2
  exit 1
fi
url="${urls[0]}"
ver="$(sed -E 's|.*/public/([0-9][0-9.]*)/linux-deb/.*|\1|' <<<"$url")"
[ "$url" = "https://www.dreamcoder.ai/downloads/files/public/${ver}/linux-deb/debian/${DEBNAME}_${ver}_amd64.deb" ] || {
  echo "ABORT: the URL's directory and file name disagree on the version: $url" >&2
  exit 1
}

cur="$(sed -n 's/^pkgver=//p' PKGBUILD | head -1)"
echo "installer:  $url"
echo "current:    $cur"
echo "newest:     $ver"
if [ "$(vercmp "$ver" "$cur")" -le 0 ] && [ "$force" -eq 0 ]; then
  echo "already at or ahead of the vendor's installer; nothing to do. (--force re-pins)"
  exit 0
fi

# 2. Download the .deb and check its control file.
echo "downloading the .deb ..."
fetch "$url" -o "$tmp/pkg.deb"
mkdir "$tmp/deb" "$tmp/control"
bsdtar -xf "$tmp/pkg.deb" -C "$tmp/deb"
bsdtar -xf "$tmp/deb"/control.tar.* -C "$tmp/control"
field() { sed -n "s/^$1: //p" "$tmp/control/control"; }
[ "$(field Package)" = "$DEBNAME" ] || { echo "ABORT: control Package is '$(field Package)'" >&2; exit 1; }
[ "$(field Architecture)" = amd64 ] || { echo "ABORT: control Architecture is '$(field Architecture)'" >&2; exit 1; }
[ "$(field Version)" = "$ver" ] || { echo "ABORT: control Version '$(field Version)' != $ver" >&2; exit 1; }
sum="$(sha256sum "$tmp/pkg.deb" | cut -d' ' -f1)"
echo "sha256:     $sum"

# 3. Things that would need the PKGBUILD reviewed. Warnings, not aborts.
review=0
outside="$(bsdtar -tf "$tmp/deb"/data.tar.* | sed 's|^\./||' | grep -vE '^(usr/|etc/$|etc/apt/)' || true)"
if [ -n "$outside" ]; then
  review=1
  echo "REVIEW: payload paths outside usr/ and etc/apt/:"
  sed 's/^/  /' <<<"$outside"
fi
if grep -hE '^[[:space:]]*service_names="[^"]+"' "$tmp/control"/{postinst,prerm,postrm} 2>/dev/null; then
  review=1
  echo "REVIEW: a maintainer script now names a systemd service (above)."
fi
if [ "$(field Depends)" != "$DEPENDS" ]; then
  review=1
  echo "REVIEW: Depends changed: '$(field Depends)' (was '$DEPENDS'); update depends= and DEPENDS."
fi

if [ "$check_only" -eq 1 ]; then
  echo "(--check) would update $cur to $ver; run without --check to apply."
  exit 0
fi

# 4. Rewrite pkgver, pkgrel and the .deb pin.
awk -v ver="$ver" -v sum="$sum" '
  /^pkgver=/ { print "pkgver=" ver; next }
  /^pkgrel=/ { print "pkgrel=1"; next }
  /^sha256sums=\(/ { sub(/[0-9a-f]{64}/, sum) }
  { print }' PKGBUILD >"$tmp/PKGBUILD"
grep -q "$sum" "$tmp/PKGBUILD" || { echo "ABORT: could not place the new hash in PKGBUILD" >&2; exit 1; }
cat "$tmp/PKGBUILD" >PKGBUILD
makepkg --printsrcinfo >.SRCINFO

# Keep the verified download so makepkg does not fetch it a second time.
cp "$tmp/pkg.deb" "${DEBNAME}_${ver}_amd64.deb"

echo
echo "PKGBUILD updated: $cur to $ver"
[ "$review" -eq 0 ] || echo "Review the REVIEW lines above before building."
echo "next: makepkg -si   (then: git commit -am \"dreamcoder $ver\")"
