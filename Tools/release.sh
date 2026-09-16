#!/bin/zsh
# Cut a direct-download release: notarized Developer ID build → GitHub release → Homebrew cask update.
#
#   Tools/release.sh            uses CFBundleShortVersionString from Info.plist
#   Tools/release.sh --dry-run  build + notarize only
#
# Needs: Developer ID Application cert in the keychain, notarization credentials (see build.sh),
#        `gh` logged in, and the tap checked out at $TAP_DIR (default ../mdview/homebrew-tap).
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
TAG="v$VERSION"
ZIP="build/SVGViewer-$VERSION.zip"
TAP_DIR="${TAP_DIR:-../mdview/homebrew-tap}"
CASK="$TAP_DIR/Casks/svg-viewer.rb"

if [[ -n "$(git status --porcelain)" ]]; then echo "error: working tree not clean" >&2; exit 1; fi
if gh release view "$TAG" >/dev/null 2>&1; then echo "error: release $TAG already exists" >&2; exit 1; fi

./build.sh --universal --sign devid --notarize
[[ $DRY == 1 ]] && { echo "dry run: $ZIP"; exit 0; }

echo "==> Tagging and publishing $TAG"
git tag -a "$TAG" -m "SVG Viewer $VERSION" 2>/dev/null || true
git push origin "$TAG"
gh release create "$TAG" "$ZIP" --title "SVG Viewer $VERSION" --generate-notes

echo "==> Updating Homebrew cask"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
sed -i '' -e "s/version \".*\"/version \"$VERSION\"/" -e "s/sha256 .*/sha256 \"$SHA\"/" "$CASK"
git -C "$TAP_DIR" add Casks/svg-viewer.rb
git -C "$TAP_DIR" commit -q -m "Update svg-viewer cask to v$VERSION"
git -C "$TAP_DIR" push -q
echo "==> Done. Install with: brew install --cask patbonecrusher/tap/svg-viewer"
