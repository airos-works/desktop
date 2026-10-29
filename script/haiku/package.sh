#!/bin/bash
# Makes the github_desktop package on Haiku from a stage that build.sh made:
#   ./package.sh <output directory>
# Builds the native helpers (Git's credential and askpass trampolines, the
# hooks proxy and printenvz), lays out Haiku's Git as dugite expects it, and
# makes the app's launcher from Aurora's aurora-host (AURORA_HOST_BINARY, or
# the installed aurora package's).
set -euo pipefail
STAGE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUT=${1:?output directory}
VERSION=$(cat "$STAGE/VERSION")
# The package's revision: raise it for a new package of the same version
# (pkgman does not replace an installed package with an equal version).
REVISION=3
ARCH=$(uname -m)
HOST_BINARY=${AURORA_HOST_BINARY:-/boot/system/data/aurora/aurora-host}
NAME="GitHub Desktop"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/github-desktop-package.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
PKG=$WORK/package
APP=$PKG/apps/GitHubDesktop

mkdir -p "$APP" "$PKG/data/deskbar/menu/Developer" "$PKG/data/licenses"
cp -a "$STAGE/app" "$APP/app"
cp "$STAGE/aurora.json" "$APP/aurora.json"

echo "== Native helpers"
# Haiku has no libssp: no -fstack-protector.
CFLAGS="-O2 -Wall"
TRAMPOLINE=$STAGE/native/desktop-trampoline
mkdir -p "$APP/app/desktop-trampoline"
cc $CFLAGS -I"$TRAMPOLINE/include" -o "$APP/app/desktop-trampoline/desktop-askpass-trampoline" \
	"$TRAMPOLINE/src/desktop-trampoline.c" "$TRAMPOLINE/src/socket.c" -lnetwork
# Git runs credential helper "desktop" as git-credential-desktop, found on
# PATH (the app puts desktop-trampoline first, src/lib/haiku/environment.ts).
cc $CFLAGS -DCREDENTIAL_HELPER -I"$TRAMPOLINE/include" -o "$APP/app/desktop-trampoline/git-credential-desktop" \
	"$TRAMPOLINE/src/desktop-trampoline.c" "$TRAMPOLINE/src/socket.c" -lnetwork
cc $CFLAGS -o "$APP/app/printenvz" "$STAGE/native/printenvz/src/printenvz.c"
cc -O2 -o "$APP/app/process-proxy" "$STAGE/native/process-proxy/main.c" -lnetwork
strip "$APP/app/desktop-trampoline/"* "$APP/app/printenvz" "$APP/app/process-proxy"

echo "== Git"
# dugite runs $LOCAL_GIT_DIRECTORY/bin/git with libexec/git-core as its exec
# path and share/git-core/templates as its templates: Haiku's own Git.
mkdir -p "$APP/app/git/bin" "$APP/app/git/libexec" "$APP/app/git/share/git-core"
ln -s /boot/system/bin/git "$APP/app/git/bin/git"
ln -s /boot/system/lib/git-core "$APP/app/git/libexec/git-core"
ln -s /boot/system/data/git-core/templates "$APP/app/git/share/git-core/templates"

echo "== Launcher"
cp "$HOST_BINARY" "$APP/$NAME"
strip --strip-debug "$APP/$NAME"
rc -I "$STAGE" -o "$WORK/launcher.rsrc" "$STAGE/GitHubDesktop.rdef"
xres -o "$APP/$NAME" "$WORK/launcher.rsrc"
mimeset -f "$APP/$NAME"
ln -s "../../../../apps/GitHubDesktop/$NAME" "$PKG/data/deskbar/menu/Developer/$NAME"
cp "$STAGE/LICENSE" "$PKG/data/licenses/GitHub Desktop"

cat > "$PKG/.PackageInfo" <<INFO
name			github_desktop
version			$VERSION-$REVISION
architecture	$ARCH
summary			"Simple collaboration from your desktop"
description		"GitHub Desktop is an open-source app for working with Git and GitHub: \
see and commit changes, browse history, manage branches and pull requests. \
This is an unofficial port: it runs on Haiku with Aurora, uses Haiku's own Git, \
and keeps credentials in Haiku's key store."
packager		"KunanyiOS contributors"
vendor			"KunanyiOS"
copyrights		{ "2016-2026 GitHub, Inc." }
licenses		{ "MIT" }
urls			{ "https://github.com/jmgasper/desktop" }
provides {
	github_desktop = $VERSION
	app:GitHub_Desktop = $VERSION
}
requires {
	haiku
	aurora >= 0.2
	cmd:node >= 22
	cmd:git
}
INFO
mkdir -p "$OUT"
FILE=$OUT/github_desktop-$VERSION-$REVISION-$ARCH.hpkg
rm -f "$FILE"
package create -C "$PKG" "$FILE"
echo "$FILE"
