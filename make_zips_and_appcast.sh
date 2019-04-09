#!/bin/sh

# Get the bundle version from the plist.
PLIST_FILE="Itsycal/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $PLIST_FILE)
SHORT_VERSION_STRING=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $PLIST_FILE)

# Set up file names and paths.
APP_PATH="$HOME/Desktop/Itsycal.app"
ZIP_NAME="Itsycal-$SHORT_VERSION_STRING.zip"
ZIP_NAME=${ZIP_NAME// /-}
DEST_DIR="$HOME/Desktop/Itsycal-$SHORT_VERSION_STRING"
XML_PATH="$DEST_DIR/itsycal.xml"
ZIP_PATH1="$DEST_DIR/$ZIP_NAME"
ZIP_PATH2="$DEST_DIR/Itsycal.zip"

if [ -d "$APP_PATH" ]
then
	echo "Making zips and appcast..."
else
    echo ""
	echo "$APP_PATH: NOT FOUND!"
    echo ""
    echo "Export notarized Itsycal.app to Desktop."
    echo "See BUILD.md for instructions."
    echo ""
    exit 1
fi

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
<sparkle:minimumSystemVersion>10.12</sparkle:minimumSystemVersion>
<sparkle:releaseNotesLink>https://s3.amazonaws.com/itsycal/changelog.html</sparkle:releaseNotesLink>
<pubDate>$DATE +0000</pubDate>
<enclosure
    url="https://s3.amazonaws.com/itsycal/$ZIP_NAME"
    sparkle:version="$VERSION"
    sparkle:shortVersionString="$SHORT_VERSION_STRING"
    length="$FILESIZE"
    type="application/octet-stream" />
</item>
</channel>
</rss>
EOF

echo "Done!"

open -R "$DEST_DIR/itsycal.xml"

