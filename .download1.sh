#!/bin/bash
set -e

############################################
# 1️⃣ CONFIGURATION
############################################
SITE_URL="https://yilingliu-portfolio.webflow.io/"

# Webflow CDN domains
CDN_DOMAINS=(
  "assets-global.website-files.com"
  "uploads-ssl.webflow.com"
  "cdn.prod.website-files.com"
)

# Google Fonts domains
FONT_DOMAINS=(
  "fonts.googleapis.com"
  "fonts.gstatic.com"
)

# Optional: third-party CDNs
THIRD_PARTY_CDNS=(
  "ajax.googleapis.com"
  "cdn.jsdelivr.net"
  "cdnjs.cloudflare.com"
)

# Merge all domains for asset detection
ALL_DOMAINS=("${CDN_DOMAINS[@]}" "${FONT_DOMAINS[@]}" "${THIRD_PARTY_CDNS[@]}")

# Directories
BASE_DOMAIN=$(echo "$SITE_URL" | awk -F/ '{print $3}')
SITE_DIR="./site"
TARGET_ASSETS_DIR="${SITE_DIR}/assets"
FONTS_DIR="${TARGET_ASSETS_DIR}/fonts"

echo "📂 Preparing directories..."
mkdir -p "$TARGET_ASSETS_DIR" "$FONTS_DIR"

ALL_DOMAINS_CSV=$(IFS=,; echo "${ALL_DOMAINS[*]}")

############################################
# 2️⃣ DOWNLOAD MAIN SITE
############################################
echo "🌐 Downloading full site from $SITE_URL ..."
wget --mirror --convert-links --adjust-extension --page-requisites --no-parent -nv \
     -H -D "${BASE_DOMAIN},${ALL_DOMAINS_CSV}" \
     -e robots=off "$SITE_URL"

############################################
# 3️⃣ MOVE DOWNLOADED SITE INTO CLEAN FOLDER
############################################
if [ -d "./${BASE_DOMAIN}" ]; then
  echo "📦 Moving site files into ${SITE_DIR}/"
  mv -v "./${BASE_DOMAIN}"/* "$SITE_DIR/"
  rmdir "./${BASE_DOMAIN}" 2>/dev/null || true
fi

############################################
# 4️⃣ MOVE DOWNLOADED CDN ASSETS LOCALLY
############################################
for DOMAIN in "${ALL_DOMAINS[@]}"; do
  if [ -d "./${DOMAIN}" ]; then
    echo "📦 Moving assets from ${DOMAIN} → ${TARGET_ASSETS_DIR}/"
    mv -v "./${DOMAIN}"/* "$TARGET_ASSETS_DIR/" 2>/dev/null || true
    rmdir "${DOMAIN}" 2>/dev/null || true
  fi
done

############################################
# 5️⃣ DECOMPRESS .gz FILES
############################################
echo "🗜️ Decompressing any .gz files..."
find . -type f -name '*.gz' -exec gzip -d {} \; 2>/dev/null || true

############################################
# 6️⃣ EXTRACT ALL ASSET & FONT URLs
############################################
echo "🔍 Extracting asset and font URLs..."
> urls.txt
for DOMAIN in "${ALL_DOMAINS[@]}"; do
  grep -Eroh "(https://${DOMAIN}/[a-zA-Z0-9/_\.\-%\?\=&]+)" "$SITE_DIR" \
    | sort -u >> urls.txt || true
done
sort -u -o urls.txt urls.txt

############################################
# 7️⃣ DOWNLOAD ANY MISSING ASSETS
############################################
echo "⬇️ Downloading missing CDN assets and fonts..."
while read -r url; do
  [ -z "$url" ] && continue
  DOMAIN=$(echo "$url" | awk -F/ '{print $3}')
  REL_PATH=$(echo "$url" | sed -E "s|https://[^/]+/||")

  # Fonts go under assets/fonts/, others go under assets/
  if [[ " ${FONT_DOMAINS[*]} " == *" ${DOMAIN} "* ]]; then
    LOCAL_PATH="${FONTS_DIR}/${REL_PATH}"
  else
    LOCAL_PATH="${TARGET_ASSETS_DIR}/${REL_PATH}"
  fi

  mkdir -p "$(dirname "$LOCAL_PATH")"
  if [ ! -f "$LOCAL_PATH" ]; then
    echo "⬇️ $url"
    curl -s -L "$url" -o "$LOCAL_PATH"
  fi
done < urls.txt

############################################
# 8️⃣ REWRITE HTML & CSS LINKS
############################################
echo "✏️ Rewriting CDN and font references to local paths..."
for DOMAIN in "${ALL_DOMAINS[@]}"; do
  find "$SITE_DIR" -type f \( -name "*.html" -or -name "*.css" \) | while read -r f; do
    if [[ " ${FONT_DOMAINS[*]} " == *" ${DOMAIN} "* ]]; then
      sed -i '' "s|https://${DOMAIN}/|assets/fonts/|g" "$f"
    else
      sed -i '' "s|https://${DOMAIN}/|assets/|g" "$f"
    fi
  done
done

############################################
# 9️⃣ FIX INTERNAL LINKS FOR OFFLINE USE
############################################
echo "🔗 Fixing internal links (/page → page.html)..."
find "$SITE_DIR" -type f -name "*.html" | while read -r f; do
  sed -i '' -E 's|href="/([^"#][^"]*)"|href="\1.html"|g' "$f"
done

############################################
# 🔧 FIX .gz REFERENCES
############################################
find "$SITE_DIR" -type f -name "*.html" -exec sed -i '' "s|.css.gz|.css|g" {} \;
find "$SITE_DIR" -type f -name "*.html" -exec sed -i '' "s|.js.gz|.js|g" {} \;

############################################
# 🔹 CLEANUP EMPTY DIRS
############################################
find . -type d -empty -delete 2>/dev/null || true

############################################
# ✅ DONE
############################################
echo ""
echo "✅ Static offline Webflow site exported!"
echo "📁 Output folder: ${SITE_DIR}/"
echo "📦 Assets folder: ${TARGET_ASSETS_DIR}/"
echo "🔤 Fonts folder: ${FONTS_DIR}/"
echo "🧭 Open ${SITE_DIR}/index.html to view offline."
