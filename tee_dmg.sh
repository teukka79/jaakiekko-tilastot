#!/bin/bash
# Rakentaa Jääkiekko Tilastot -sovelluksesta Release-version ja pakkaa sen .dmg-levykuvaksi.
set -e
cd "$(dirname "$0")"
NAME="JaakiekkoTilastot"
VER=$(grep -m1 "MARKETING_VERSION" "$NAME.xcodeproj/project.pbxproj" | sed 's/[^0-9.]//g')
BUILD="$(pwd)/build_dmg"
rm -rf "$BUILD"; mkdir -p "$BUILD"
echo "Käännetään Release-versio..."
xcodebuild -project "$NAME.xcodeproj" -scheme "$NAME" -configuration Release \
  -derivedDataPath "$BUILD/dd" CODE_SIGNING_ALLOWED=NO build | tail -3
APP="$BUILD/dd/Build/Products/Release/$NAME.app"
[ -d "$APP" ] || { echo "Sovellusta ei löytynyt: $APP"; exit 1; }
echo "Allekirjoitetaan paikallisesti (ad hoc)..."
codesign --force --deep --sign - "$APP"
STAGE="$BUILD/stage"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Jääkiekko Tilastot.app"
ln -s /Applications "$STAGE/Applications"
OUT="$(pwd)/Jaakiekko-Tilastot-$VER.dmg"
rm -f "$OUT"
hdiutil create -volname "Jääkiekko Tilastot" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
rm -rf "$BUILD"
echo "Valmis: $OUT"
