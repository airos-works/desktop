#!/bin/bash
# Makes the github_desktop package for x86_64 or arm64 on Linux from a stage
# that build.sh made:
#   script/haiku/cross.sh ARCH [stage directory] [output directory]
# The app is the same JavaScript on every architecture; only the native
# helpers differ. This does what package.sh does on Haiku, with cross tools
# (arm64 air/OS has no compiler of its own; air/OS CI builds both
# architectures this way):
#   AIROS_SDK          an air/OS cross SDK's env.sh for ARCH (CROSS, SYSROOT),
#                      default /data1/airos/sdk/ARCH/env.sh
#   HAIKU_HOST_TOOLS   a Haiku build's host tools (rc, xres, resattr, mimeset,
#                      package) and HAIKU_MIME_DB its MIME database; the
#                      tools keep attributes in that build's own store
#   AURORA_HOST_BINARY aurora-host for ARCH (the aurora package's
#                      data/aurora/aurora-host), Aurora 0.3 or later
# The package requires aurora, cmd:node 22 and cmd:git: HaikuPorts' git on
# x86_64, air/OS CI's arm64 build of it (airos-ci deps/recipes/git.sh) on
# arm64.
set -euo pipefail
ARCH=${1:?usage: cross.sh x86_64|arm64 [stage directory] [output directory]}
case $ARCH in
	arm64|x86_64) ;;
	*) echo "unknown architecture $ARCH" >&2; exit 1 ;;
esac
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STAGE=$(cd -- "${2:-$ROOT/dist/haiku}" && pwd)
OUT=${3:-$STAGE/packages}
# (the SDK's env.sh first: it names its own build's TOOLS and MIMEDB)
. "${AIROS_SDK:-/data1/airos/sdk/$ARCH/env.sh}"
TOOLS=${HAIKU_HOST_TOOLS:?a Haiku build's objects/linux/x86_64/release/tools}
MIMEDB=${HAIKU_MIME_DB:?a Haiku build's objects/common/data/mime_db/mime_db}
HOST_BINARY=${AURORA_HOST_BINARY:?aurora-host for ARCH}
VERSION=$(cat "$STAGE/VERSION")
# package.sh's: one revision for both ways of making the package
REVISION=$(sed -n 's/^REVISION=\([0-9][0-9]*\)$/\1/p' "$STAGE/package.sh")
NAME="GitHub Desktop"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/github-desktop-$ARCH.XXXXXX")
trap '"$TOOLS/rm_attrs" -rf "$WORK" 2>/dev/null || rm -rf "$WORK"' EXIT
PKG=$WORK/package
APP=$PKG/apps/GitHubDesktop

mkdir -p "$APP" "$PKG/data/deskbar/menu/Applications" "$PKG/data/licenses"
cp -a "$STAGE/app" "$APP/app"
cp "$STAGE/aurora.json" "$APP/aurora.json"

echo "== Native helpers"
# as package.sh builds them (Haiku has no libssp: no -fstack-protector)
CC="${CROSS}gcc --sysroot=$SYSROOT"
CFLAGS="-O2 -Wall"
TRAMPOLINE=$STAGE/native/desktop-trampoline
mkdir -p "$APP/app/desktop-trampoline"
$CC $CFLAGS -I"$TRAMPOLINE/include" -o "$APP/app/desktop-trampoline/desktop-askpass-trampoline" \
	"$TRAMPOLINE/src/desktop-trampoline.c" "$TRAMPOLINE/src/socket.c" -lnetwork
$CC $CFLAGS -DCREDENTIAL_HELPER -I"$TRAMPOLINE/include" -o "$APP/app/desktop-trampoline/git-credential-desktop" \
	"$TRAMPOLINE/src/desktop-trampoline.c" "$TRAMPOLINE/src/socket.c" -lnetwork
$CC $CFLAGS -o "$APP/app/printenvz" "$STAGE/native/printenvz/src/printenvz.c"
$CC -O2 -o "$APP/app/process-proxy" "$STAGE/native/process-proxy/main.c" -lnetwork
"${CROSS}strip" "$APP/app/desktop-trampoline/"* "$APP/app/printenvz" "$APP/app/process-proxy"

echo "== Git"
# dugite runs $LOCAL_GIT_DIRECTORY/bin/git with libexec/git-core as its exec
# path and share/git-core/templates as its templates: the system's Git.
mkdir -p "$APP/app/git/bin" "$APP/app/git/libexec" "$APP/app/git/share/git-core"
ln -s /boot/system/bin/git "$APP/app/git/bin/git"
ln -s /boot/system/lib/git-core "$APP/app/git/libexec/git-core"
ln -s /boot/system/data/git-core/templates "$APP/app/git/share/git-core/templates"

echo "== Launcher"
cp "$HOST_BINARY" "$APP/$NAME"
"${CROSS}strip" --strip-debug "$APP/$NAME"
"$TOOLS/rc/rc" -I "$STAGE" -o "$WORK/launcher.rsrc" "$STAGE/GitHubDesktop.rdef"
"$TOOLS/xres" -o "$APP/$NAME" "$WORK/launcher.rsrc"
# on Haiku xres and mimeset give the file its attributes; here resattr does
"$TOOLS/resattr/resattr" -O -o "$APP/$NAME" "$WORK/launcher.rsrc"
(cd "$PKG" && "$TOOLS/mimeset" --all -f --mimedb "$MIMEDB" "apps/GitHubDesktop/$NAME")
ln -s "../../../../apps/GitHubDesktop/$NAME" "$PKG/data/deskbar/menu/Applications/$NAME"
cp "$STAGE/LICENSE" "$PKG/data/licenses/GitHub Desktop"

cat > "$PKG/.PackageInfo" <<INFO
name			github_desktop
version			$VERSION-$REVISION
architecture	$ARCH
summary			"Simple collaboration from your desktop"
description		"GitHub Desktop is an open-source app for working with Git and GitHub: \\
see and commit changes, browse history, manage branches and pull requests. \\
This is an unofficial port: it runs on Haiku with Aurora, uses the system's Git, \\
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
	aurora >= 0.3
	cmd:node >= 22
	cmd:git
}
INFO
mkdir -p "$OUT"
FILE=$OUT/github_desktop-$VERSION-$REVISION-$ARCH.hpkg
rm -f "$FILE"
"$TOOLS/package/package" create -q -C "$PKG" "$FILE"
echo "$FILE"
