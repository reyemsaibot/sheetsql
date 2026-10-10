#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/sheetql-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/sheetql-swift-cache"
swift build -c release --disable-sandbox
APP="$PWD/output/SheetSQL.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SheetQL "$APP/Contents/MacOS/SheetSQL.new"
mv -f "$APP/Contents/MacOS/SheetSQL.new" "$APP/Contents/MacOS/SheetSQL"
cp Assets/SheetSQLIcon.icns "$APP/Contents/Resources/SheetSQLIcon.icns"
RESOURCE_BUNDLE="$(find .build -type d -path '*/release/SheetQL_SheetQL.bundle' -print -quit)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
  rm -rf "$APP/Contents/Resources/SheetQL_SheetQL.bundle"
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/SheetQL_SheetQL.bundle"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SheetSQL</string>
<key>CFBundleIdentifier</key><string>local.sheetql.app</string>
<key>CFBundleName</key><string>SheetSQL</string>
<key>CFBundleDisplayName</key><string>SheetSQL</string>
<key>CFBundleIconName</key><string>SheetSQLIcon</string>
<key>CFBundleIconFile</key><string>SheetSQLIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Excel Workbook</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>CFBundleTypeExtensions</key><array><string>xlsx</string><string>xlsm</string></array>
</dict><dict>
<key>CFBundleTypeName</key><string>SQL Query</string>
<key>CFBundleTypeRole</key><string>Editor</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>CFBundleTypeExtensions</key><array><string>sql</string></array>
</dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "App erstellt: $APP"
