#!/bin/bash
set -euo pipefail

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

# 1. Update version numbers
echo "1. Updating version numbers..."
sed -i '' "s/^VERSION=\".*\"/VERSION=\"${VERSION}\"/" scripts/build-app.sh
sed -i '' "s/^VERSION=\"\${1:-.*}\"/VERSION=\"\${1:-${VERSION}}\"/" scripts/create-dmg.sh
mkdir -p Sources/MacSnapCore/Resources
printf '%s\n' "${VERSION}" > Sources/MacSnapCore/Resources/version.txt
plutil -replace CFBundleShortVersionString -string "${VERSION}" Resources/Info.plist
plutil -replace CFBundleVersion -string "${VERSION}" Resources/Info.plist

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
rm -f "macsnap-cli-v${VERSION}.zip"
zip -q "macsnap-cli-v${VERSION}.zip" macsnap-cli
cd "$ROOT_DIR"

# Calculate SHA256 hashes
DMG_SHA=$(shasum -a 256 "dist/MacSnap-${VERSION}.dmg" | awk '{print $1}')
CLI_SHA=$(shasum -a 256 "dist/macsnap-cli-v${VERSION}.zip" | awk '{print $1}')

echo "   DMG SHA256: $DMG_SHA"
echo "   CLI SHA256: $CLI_SHA"

# 5. Update Homebrew metadata in this repo
echo ""
echo "5. Updating Homebrew metadata..."
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/macsnap.rb
sed -i '' "s/sha256 \".*\"/sha256 \"${DMG_SHA}\"/" Casks/macsnap.rb
sed -i '' "s|/v[0-9.]*\/MacSnap-[0-9.]*.dmg|/v${VERSION}/MacSnap-${VERSION}.dmg|" Casks/macsnap.rb

sed -i '' "s|/v[0-9.]*\/macsnap-cli-v[0-9.]*.zip|/v${VERSION}/macsnap-cli-v${VERSION}.zip|" Formula/macsnap-cli.rb
sed -i '' "s/sha256 \".*\"/sha256 \"${CLI_SHA}\"/" Formula/macsnap-cli.rb
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Formula/macsnap-cli.rb

# 6. Commit and push version changes
echo ""
echo "6. Committing version changes..."
git add -A
git commit -m "Release v${VERSION}" || echo "   No changes to commit"
git push origin main

# 7. Create GitHub release
echo ""
echo "7. Creating GitHub release..."
NOTES_FILE="$(mktemp -t macsnap-release-notes.XXXXXX)"
cat > "${NOTES_FILE}" << EOF
## MacSnap v${VERSION}

### Fixes
- Preferences now honor Cmd+Q to quit and Cmd+O to open the output folder.
- Versioning is unified across app, CLI, and core.

### Install
\`\`\`bash
brew tap 1fc0nfig/macsnap
brew install --cask macsnap
# optional CLI
brew install macsnap-cli
\`\`\`
EOF

gh release create "v${VERSION}" \
    "dist/MacSnap-${VERSION}.dmg" \
    "dist/macsnap-cli-v${VERSION}.zip" \
    --title "MacSnap v${VERSION}" \
    --notes-file "${NOTES_FILE}"
rm -f "${NOTES_FILE}"

echo "   Release created: https://github.com/1fc0nfig/macsnap/releases/tag/v${VERSION}"

# 8. Update Homebrew tap
echo ""
echo "8. Updating Homebrew tap..."
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
