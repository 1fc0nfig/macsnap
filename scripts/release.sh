#!/bin/bash
set -e

# MacSnap Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.3.2

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.3.2"
    exit 1
fi

echo "=== Releasing MacSnap v${VERSION} ==="
echo ""

# 1. Update version in build scripts
echo "1. Updating version numbers..."
sed -i '' "s/^VERSION=\".*\"/VERSION=\"${VERSION}\"/" scripts/build-app.sh
sed -i '' "s/^VERSION=\"\${1:-.*}\"/VERSION=\"\${1:-${VERSION}}\"/" scripts/create-dmg.sh

# 2. Build the app
echo ""
echo "2. Building app..."
./scripts/build-app.sh

# 3. Create DMG
echo ""
echo "3. Creating DMG..."
./scripts/create-dmg.sh "$VERSION"

# 4. Create CLI zip
echo ""
echo "4. Creating CLI zip..."
cd dist
zip -q "macsnap-cli-v${VERSION}.zip" macsnap-cli
cd "$ROOT_DIR"

# Calculate SHA256 hashes
DMG_SHA=$(shasum -a 256 "dist/MacSnap-${VERSION}.dmg" | awk '{print $1}')
CLI_SHA=$(shasum -a 256 "dist/macsnap-cli-v${VERSION}.zip" | awk '{print $1}')

echo "   DMG SHA256: $DMG_SHA"
echo "   CLI SHA256: $CLI_SHA"

# 5. Commit and push version changes
echo ""
echo "5. Committing version changes..."
git add scripts/build-app.sh scripts/create-dmg.sh
git commit -m "Bump version to ${VERSION}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>" || echo "   No changes to commit"
git push origin main

# 6. Create GitHub release
echo ""
echo "6. Creating GitHub release..."
gh release create "v${VERSION}" \
    "dist/MacSnap-${VERSION}.dmg" \
    "dist/macsnap-cli-v${VERSION}.zip" \
    --title "MacSnap v${VERSION}" \
    --notes "## MacSnap v${VERSION}

### Install
\`\`\`bash
brew tap 1fc0nfig/macsnap
brew install --cask macsnap
# optional CLI
brew install macsnap-cli
\`\`\`"

echo "   Release created: https://github.com/1fc0nfig/macsnap/releases/tag/v${VERSION}"

# 7. Update Homebrew tap
echo ""
echo "7. Updating Homebrew tap..."
HOMEBREW_TAP="/opt/homebrew/Library/Taps/1fc0nfig/homebrew-macsnap"

if [ -d "$HOMEBREW_TAP" ]; then
    cd "$HOMEBREW_TAP"
    git pull origin main

    # Update cask
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/macsnap.rb
    sed -i '' "s/sha256 \".*\"/sha256 \"${DMG_SHA}\"/" Casks/macsnap.rb

    # Update formula
    sed -i '' "s|/v[0-9.]*\/macsnap-cli-v[0-9.]*.zip|/v${VERSION}/macsnap-cli-v${VERSION}.zip|" Formula/macsnap-cli.rb
    sed -i '' "s/sha256 \".*\"/sha256 \"${CLI_SHA}\"/" Formula/macsnap-cli.rb
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Formula/macsnap-cli.rb

    git add .
    git commit -m "Update to v${VERSION}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
    git push origin main

    cd "$ROOT_DIR"
    echo "   Homebrew tap updated"
else
    echo "   Warning: Homebrew tap not found at $HOMEBREW_TAP"
    echo "   Run: brew tap 1fc0nfig/macsnap"
fi

echo ""
echo "=== Release v${VERSION} complete! ==="
echo ""
echo "Users can install via:"
echo "  brew tap 1fc0nfig/macsnap"
echo "  brew install --cask macsnap"
