#!/bin/bash
set -e

# Release script for Lumen
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 2.1.0

VERSION="${1:?Usage: $0 <version> (e.g. 2.1.0)}"
TAG="v${VERSION}"
REPO="emersonding/lumen-log-viewer"
TAP_REPO_DIR="${TAP_REPO_DIR:-../homebrew-tap}"
FORMULA="${TAP_REPO_DIR}/Formula/lumen.rb"

echo "=== Releasing Lumen ${TAG} ==="

# 1. Ensure we're on a clean main branch
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: working directory is not clean"
    exit 1
fi

# 2. Create and push the tag
echo "Tagging ${TAG}..."
git tag -a "${TAG}" -m "Release ${TAG}"
git push origin "${TAG}"

# 3. Create GitHub release
echo "Creating GitHub release..."
gh release create "${TAG}" \
    --title "Lumen ${TAG}" \
    --generate-notes

# 4. Get the source tarball SHA256
echo "Fetching tarball SHA256..."
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"
SHA256=$(curl -sL "${TARBALL_URL}" | shasum -a 256 | awk '{print $1}')
echo "SHA256: ${SHA256}"

# 5. Update the Homebrew formula
if [ -f "${FORMULA}" ]; then
    echo "Updating formula at ${FORMULA}..."
    sed -i '' "s|url \".*\"|url \"${TARBALL_URL}\"|" "${FORMULA}"
    sed -i '' "s|sha256 \".*\"|sha256 \"${SHA256}\"|" "${FORMULA}"
    sed -i '' "s|version \".*\"|version \"${VERSION}\"|" "${FORMULA}" 2>/dev/null || true

    echo "Committing formula update..."
    cd "${TAP_REPO_DIR}"
    git add Formula/lumen.rb
    git commit -m "lumen ${TAG}"
    git push origin main
    cd -
else
    echo ""
    echo "Formula not found at ${FORMULA}"
    echo "Manually update your tap formula with:"
    echo "  url: ${TARBALL_URL}"
    echo "  sha256: ${SHA256}"
fi

echo ""
echo "=== Done! ==="
echo "Users can install with:"
echo "  brew tap emersonding/tap"
echo "  brew install lumen"
