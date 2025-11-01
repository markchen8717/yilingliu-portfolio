#!/bin/bash
set -e

############################################
# CONFIGURATION
############################################
FOLDER="yilingliu-portfolio.webflow.io"

############################################
# 1️⃣ Move all contents up one directory
############################################
echo "📦 Moving files out of '$FOLDER/'..."
shopt -s dotglob nullglob
mv "$FOLDER"/* .
shopt -u dotglob nullglob

############################################
# 2️⃣ Fix HTML paths (remove ONE '../' per path)
############################################
echo "🧩 Updating relative paths in HTML files..."

# This regex removes exactly one "../" from any contiguous sequence of them
find . -type f -name "*.html" | while read -r file; do
  echo "  ↳ Fixing $file"
  perl -i -pe 's#(\.\./)(?=(\.\./)+)#""#g' "$file"
done

############################################
# 3️⃣ Clean up empty folder
############################################
rmdir "$FOLDER" 2>/dev/null || true

echo "✅ Done! Files lifted and HTML paths adjusted by one level."
