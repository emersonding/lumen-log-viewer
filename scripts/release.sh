#!/bin/bash
set -e

# Release script for Lumen
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 2.1.0

VERSION="${1:?Usage: $0 <version> (e.g. 2.1.0)}"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: VERSION must be semver (e.g. 2.1.0 or 2.1.0-beta.1)"
    exit 1
fi
TAG="v${VERSION}"
REPO="emersonding/lumen-log-viewer"
ARCH="$(uname -m)"  # arm64 or x86_64

# Print what completed so far on failure
trap 'echo ""; echo "ERROR: Release partially completed. Check GitHub release ${TAG} and tap repo state manually."' ERR

# Resolve absolute paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_FORMULA="${PROJECT_DIR}/Formula/lumen.rb"
TAP_REPO_DIR="${TAP_REPO_DIR:-$HOMEBREW_TAP_REPO_DIR}"
FORMULA="${TAP_REPO_DIR}/Formula/lumen.rb"

# Pre-flight checks
if [ ! -d "${TAP_REPO_DIR}/.git" ]; then
    echo "Error: homebrew-tap repo not found at ${TAP_REPO_DIR}"
    echo "Set TAP_REPO_DIR or HOMEBREW_TAP_REPO_DIR to your homebrew-tap clone location."
    exit 1
fi

if [ ! -f "${SOURCE_FORMULA}" ]; then
    echo "Error: source formula not found at ${SOURCE_FORMULA}"
    exit 1
fi

echo "=== Releasing Lumen ${TAG} (${ARCH}) ==="
echo "  Source:  ${PROJECT_DIR}"
echo "  Tap:     ${TAP_REPO_DIR}"

# 1. Warn if working directory is not clean
if [ -n "$(git status --porcelain)" ]; then
    echo "Warning: working directory has uncommitted changes."
    read -p "Continue anyway? [y/N] " answer
    if [[ "${answer}" != [yY] ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 2. Build the binary using the existing build script
echo ""
echo "=== Building ==="
cd "${PROJECT_DIR}"
./build_app.sh

# 3. Package the binary and .app bundle for Homebrew
TARBALL_NAME="lumen-${VERSION}-${ARCH}.tar.gz"
TARBALL_PATH="${PROJECT_DIR}/build/${TARBALL_NAME}"
STAGING_DIR="${PROJECT_DIR}/build/staging"
echo ""
echo "=== Packaging ${TARBALL_NAME} ==="
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
# CLI binary (lowercase for Homebrew convention)
cp "${PROJECT_DIR}/.build/release/Lumen" "${STAGING_DIR}/lumen"
# .app bundle (built by build_app.sh)
cp -R "${PROJECT_DIR}/build/Lumen.app" "${STAGING_DIR}/Lumen.app"
tar -czf "${TARBALL_PATH}" -C "${STAGING_DIR}" lumen Lumen.app
rm -rf "${STAGING_DIR}"

SHA256=$(shasum -a 256 "${TARBALL_PATH}" | awk '{print $1}')
echo "SHA256: ${SHA256}"

# 4. Tag and release on GitHub
if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo ""
    echo "Tag ${TAG} already exists."
    read -p "Skip tagging and just update the formula? [y/N] " answer
    if [[ "${answer}" != [yY] ]]; then
        echo "Aborted."
        exit 1
    fi
    # Upload the binary to the existing release
    echo "Uploading ${TARBALL_NAME} to existing release ${TAG}..."
    gh release upload "${TAG}" "${TARBALL_PATH}" --clobber
else
    echo ""
    echo "=== Creating release ${TAG} ==="
    git tag -a "${TAG}" -m "Release ${TAG}"
    git push origin "${TAG}"
    gh release create "${TAG}" "${TARBALL_PATH}" \
        --title "Lumen ${TAG}" \
        --generate-notes
fi

# 5. Update the Homebrew formula
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${TARBALL_NAME}"
echo ""
echo "=== Updating formula ==="
mkdir -p "$(dirname "${FORMULA}")"
cp "${SOURCE_FORMULA}" "${FORMULA}"

# Patch version, url, and sha256 for this release (anchored to line start)
sed -i '' '/^[[:space:]]*url /s|url \".*\"|url \"'"${DOWNLOAD_URL}"'\"|' "${FORMULA}"
sed -i '' '/^[[:space:]]*sha256 /s|sha256 \".*\"|sha256 \"'"${SHA256}"'\"|' "${FORMULA}"
sed -i '' '/^[[:space:]]*version /s|version \".*\"|version \"'"${VERSION}"'\"|' "${FORMULA}"

echo "Committing formula update..."
cd "${TAP_REPO_DIR}"
git add Formula/lumen.rb
git commit -m "lumen ${TAG}"
git push origin main
cd -

echo ""
echo "=== Done! ==="
echo "Users can install/upgrade with:"
echo "  brew install emersonding/tap/lumen"
echo "  brew upgrade emersonding/tap/lumen"
