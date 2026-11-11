#!/bin/sh

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Legacy version for macOS 11+. It is no longer built, so its appcast
# item is hardcoded here and written alongside the current version's.
# Sparkle offers each Mac the newest item its macOS supports.
LEGACY_SHORT_VERSION_STRING="0.15.15"
LEGACY_VERSION="2400"
LEGACY_MINIMUM_SYSTEM_VERSION="11.0"
LEGACY_DATE="Fri Sep 25 00:18:54 GMT 2026"
LEGACY_EDDSA_AND_FILESIZE='sparkle:edSignature="WtAzCI8Zmiez2QdXRTZJWRahGSFTs43DqP1wxaHADOZcJjV8Nk+Dp7C18wmQttle8UpOGkEftVQmtVu+iXblDg==" length="1074708"'
LEGACY_RELEASE_NOTES_LINK="https://itsycal.s3.amazonaws.com/releasenotes-macos11.html"

# If Itsycal.app is not found on the Desktop, quit.
APP_PATH="${HOME}/Desktop/Itsycal.app"
if [ ! -d "${APP_PATH}" ]
then
    echo "\n"
    echo "  + ${RED}NOT FOUND:${NC} ${APP_PATH}"
    echo "  + Export notarized Itsycal.app to Desktop."
    echo "  + See BUILD.md for instructions."
    echo "\n"
    exit 1
fi

# Get the bundle version from the plist.
PLIST_FILE="${APP_PATH}/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${PLIST_FILE})
SHORT_VERSION_STRING=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${PLIST_FILE})
MINIMUM_SYSTEM_VERSION=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" ${PLIST_FILE})

# The app must be the current version, not a legacy build.
if [ "${MINIMUM_SYSTEM_VERSION}" = "${LEGACY_MINIMUM_SYSTEM_VERSION}" ] || [ "${VERSION}" -le "${LEGACY_VERSION}" ]
then
    echo "\n"
    echo "  + ${RED}LEGACY BUILD:${NC} ${SHORT_VERSION_STRING} (${VERSION}), macOS ${MINIMUM_SYSTEM_VERSION}+"
    echo "  + This script only makes zips for the current version."
    echo "  + The legacy ${LEGACY_SHORT_VERSION_STRING} item is hardcoded at the top of the script."
    echo "\n"
    exit 1
fi

# Set up file names and paths.
ZIP_NAME="Itsycal-${SHORT_VERSION_STRING}.zip"
ZIP_NAME=${ZIP_NAME// /-}
DEST_DIR="${HOME}/Desktop/Itsycal-${SHORT_VERSION_STRING}"
XML_PATH="${DEST_DIR}/itsycal.xml"
ZIP_PATH1="${DEST_DIR}/${ZIP_NAME}"
ZIP_PATH2="${DEST_DIR}/Itsycal.zip"

# Run some diagnostics so we can see all is ok."
echo ""
( set -x; spctl -vvv --assess --type exec ${APP_PATH} )
echo ""
( set -x; codesign -vvv --deep --strict ${APP_PATH} )
echo ""
( set -x; codesign -dvv ${APP_PATH} )

echo ""
echo "Making zips and appcast for ${GREEN}${SHORT_VERSION_STRING} (${VERSION})${NC}..."

# Make output dir (if necessary) and clear its contents.
rm -frd "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

# Compress Itsycal.app and make a copy without version suffix.
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH1}"
cp "${ZIP_PATH1}" "${ZIP_PATH2}"

# Get EdDSA signature (with private key in Keychain) and file size.
EDDSA_AND_FILESIZE=$(../Sparkle-1.27.1/bin/sign_update "${ZIP_PATH1}")

# On error, sign_update returns a message starting with "ERROR".
if [[ ${EDDSA_AND_FILESIZE} == ERROR* ]]
then
    echo
    echo "${RED}${EDDSA_AND_FILESIZE}${NC}"
    echo
    exit 1
fi

DATE=$(TZ=GMT date)

# Make the Sparkle appcast XML file.
cat > "${XML_PATH}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss
    version="2.0"
    xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
    xmlns:dc="http://purl.org/dc/elements/1.1/" >
  <channel>
    <title>Itsycal Release Notes</title>
    <link>https://s3.amazonaws.com/itsycal/itsycal.xml</link>
    <description>Most recent changes</description>
    <language>en</language>
    <item>
      <title>Version ${SHORT_VERSION_STRING}</title>
      <sparkle:minimumSystemVersion>${MINIMUM_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://itsycal.s3.amazonaws.com/releasenotes.html</sparkle:releaseNotesLink>
      <pubDate>${DATE} +0000</pubDate>
      <enclosure
          url="https://s3.amazonaws.com/itsycal/${ZIP_NAME}"
          ${EDDSA_AND_FILESIZE}
          sparkle:version="${VERSION}"
          sparkle:shortVersionString="${SHORT_VERSION_STRING}"
          type="application/octet-stream" />
    </item>
    <item>
      <title>Version ${LEGACY_SHORT_VERSION_STRING}</title>
      <sparkle:minimumSystemVersion>${LEGACY_MINIMUM_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>${LEGACY_RELEASE_NOTES_LINK}</sparkle:releaseNotesLink>
      <pubDate>${LEGACY_DATE} +0000</pubDate>
      <enclosure
          url="https://s3.amazonaws.com/itsycal/Itsycal-${LEGACY_SHORT_VERSION_STRING}.zip"
          ${LEGACY_EDDSA_AND_FILESIZE}
          sparkle:version="${LEGACY_VERSION}"
          sparkle:shortVersionString="${LEGACY_SHORT_VERSION_STRING}"
          type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Done!"
echo ""

open -R "${DEST_DIR}/itsycal.xml"

