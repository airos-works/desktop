#!/bin/bash
# Builds GitHub Desktop for Haiku on Linux and stages it for packaging:
#   script/haiku/build.sh [stage directory]      (default: dist/haiku)
# The stage holds the app (webpack's out/), the sources of its native helpers
# and the packaging files; script/haiku/package.sh, run on Haiku in the stage,
# makes the package. See docs/technical/haiku.md.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STAGE=${1:-$ROOT/dist/haiku}

cd "$ROOT"
if [[ ${SKIP_COMPILE:-0} != 1 ]]; then
	# webpack leaves files of earlier builds (other chunks) in out/.
	rm -rf out
	DESKTOP_TARGET_PLATFORM=haiku RELEASE_CHANNEL=${RELEASE_CHANNEL:-production} yarn build:prod
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/native/desktop-trampoline" "$STAGE/native/printenvz" "$STAGE/native/process-proxy"
cp -a out "$STAGE/app"
# The bundle analysis and webpack's notes are not part of the app.
rm -f "$STAGE/app/renderer.report.html"
cp -a vendor/desktop-trampoline/src vendor/desktop-trampoline/include "$STAGE/native/desktop-trampoline/"
cp -a vendor/printenvz/src "$STAGE/native/printenvz/"
cp node_modules/process-proxy/native/main.c "$STAGE/native/process-proxy/"
cp script/haiku/package.sh script/haiku/files/* "$STAGE/"
cp LICENSE "$STAGE/LICENSE"
node -p 'require("./app/package.json").version' > "$STAGE/VERSION"
echo "Staged $(cat "$STAGE/VERSION") in $STAGE"
