#!/bin/sh

# If Itsycal.app is not found on the Desktop, quit.
APP_PATH="$HOME/Desktop/Itsycal.app"
if [ ! -d "$APP_PATH" ]
then
    echo "\n"
    echo "  + \033[0;31mNOT FOUND:\033[0m $APP_PATH"
    echo "  + Export notarized Itsycal.app to Desktop."
    echo "  + See BUILD.md for instructions."
    echo "\n"
    exit 1
fi

# Get the bundle version from the plist.
PLIST_FILE="$APP_PATH/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $PLIST_FILE)
SHORT_VERSION_STRING=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $PLIST_FILE)

# Set up file names and paths.
ZIP_NAME="Itsycal-$SHORT_VERSION_STRING.zip"
ZIP_NAME=${ZIP_NAME// /-}
DEST_DIR="$HOME/Desktop/Itsycal-$SHORT_VERSION_STRING"
XML_PATH="$DEST_DIR/itsycal.xml"
ZIP_PATH1="$DEST_DIR/$ZIP_NAME"
ZIP_PATH2="$DEST_DIR/Itsycal.zip"

# Run some diagnostics so we can see all is ok."
echo ""
( set -x; spctl -vvv --assess --type exec $APP_PATH )
echo ""
( set -x; codesign -vvv --deep --strict $APP_PATH )
echo ""
( set -x; codesign -dvv $APP_PATH )

echo ""
echo "Making zips and appcast for \033[0;32m$SHORT_VERSION_STRING ($VERSION)\033[0m..."

# Make output dir (if necessary) and clear its contents.
rm -frd "$DEST_DIR"
mkdir -p "$DEST_DIR"

# Compress Itsycal.app and make a copy without version suffix.
ditto -c -k --rsrc --keepParent "$APP_PATH" "$ZIP_PATH1"
cp "$ZIP_PATH1" "$ZIP_PATH2"

# Get the date and zip file size for the Sparkle XML.
DATE=$(TZ=GMT date)
FILESIZE=$(stat -f "%z" "$ZIP_PATH1")

# Make the Sparkle appcast XML file.
cat > "$XML_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss
    version="2.0"
    xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
    xmlns:dc="http://purl.org/dc/elements/1.1/" >
  <channel>
    <title>Itsycal Changelog</title>
    <link>https://s3.amazonaws.com/itsycal/itsycal.xml</link>
    <description>Most recent changes</description>
    <language>en</language>
    <item>
      <title>Version $SHORT_VERSION_STRING</title>
      <sparkle:minimumSystemVersion>10.14</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://s3.amazonaws.com/itsycal/changelog.html</sparkle:releaseNotesLink>
      <pubDate>$DATE +0000</pubDate>
      <enclosure
          url="https://s3.amazonaws.com/itsycal/$ZIP_NAME"
          sparkle:version="$VERSION"
          sparkle:shortVersionString="$SHORT_VERSION_STRING"
          length="$FILESIZE"
          type="application/octet-stream" />
    </item>
    <item>
      <title>Version 0.11.17</title>
      <sparkle:minimumSystemVersion>10.12</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://s3.amazonaws.com/itsycal/changelog-0.11.x.html</sparkle:releaseNotesLink>
      <pubDate>Thu Aug 22 23:21:07 GMT 2019 +0000</pubDate>
      <enclosure
          url="https://s3.amazonaws.com/itsycal/Itsycal-0.11.17.zip"
          sparkle:version="1388"
          sparkle:shortVersionString="0.11.17"
          length="960022"
          type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Done!"
echo ""

open -R "$DEST_DIR/itsycal.xml"

