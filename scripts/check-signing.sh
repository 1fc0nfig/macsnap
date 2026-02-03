#!/bin/bash
set -u

echo "=== MacSnap Signing Diagnostics ==="
echo ""

run() {
  echo ">> $*"
  "$@" || echo "   (command failed: $?)"
  echo ""
}

run security list-keychains -d user
run security list-keychains -d system

run security find-identity -v -p codesigning

echo ">> security find-certificate -a -c \"Apple Development\" ~/Library/Keychains/login.keychain-db"
security find-certificate -a -c "Apple Development" ~/Library/Keychains/login.keychain-db || echo "   (command failed: $?)"
echo ""

echo ">> security find-certificate -a -c \"Apple Development\" /Library/Keychains/System.keychain"
security find-certificate -a -c "Apple Development" /Library/Keychains/System.keychain || echo "   (command failed: $?)"
echo ""

echo "Notes:"
echo "- If 'find-identity' shows 0 valid identities, there is no usable signing identity (cert + private key)."
echo "- You should see an 'Apple Development: Your Name (TEAMID)' identity in the output above."
