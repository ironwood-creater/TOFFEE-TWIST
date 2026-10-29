#!/usr/bin/env bash
# Creates your Google Play UPLOAD key (do this ONCE) and android/key.properties.
#
#   bash tool/release/create_upload_key.sh
#
# The key file is saved OUTSIDE the project (default: ~/toffee-twist-upload.jks)
# so it can never be uploaded to GitHub by accident. BACK IT UP, together with
# the password: you need both for every update of the game.
set -euo pipefail
cd "$(dirname "$0")/../.."

KEYSTORE="${KEYSTORE:-$HOME/toffee-twist-upload.jks}"
if [ -f "$KEYSTORE" ]; then
  echo "The key $KEYSTORE already exists - not overwriting it."
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  for jbr in "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin" \
             "$HOME/android-studio/jbr/bin" "/opt/android-studio/jbr/bin"; do
    if [ -x "$jbr/keytool" ]; then PATH="$jbr:$PATH"; break; fi
  done
fi
if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool was not found. Install Android Studio (it includes Java) and try again."
  exit 1
fi

PASS="${KEY_PASSWORD:-}"
if [ -z "$PASS" ]; then
  read -r -s -p "Choose a password for your upload key (at least 6 characters): " PASS; echo
  read -r -s -p "Type the same password again: " PASS2; echo
  if [ "$PASS" != "$PASS2" ]; then echo "The passwords are different. Try again."; exit 1; fi
fi
if [ ${#PASS} -lt 6 ]; then echo "The password must have at least 6 characters."; exit 1; fi
NAME="${KEY_NAME:-}"
if [ -z "$NAME" ]; then read -r -p "Your name or studio name: " NAME; fi

keytool -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=${NAME:-Toffee Twist}"

cat > android/key.properties <<PROPS
storePassword=$PASS
keyPassword=$PASS
keyAlias=upload
storeFile=$KEYSTORE
PROPS
chmod 600 android/key.properties

echo
echo "Done!"
echo "  Upload key:      $KEYSTORE"
echo "  Settings file:   android/key.properties (never commit it - it is in .gitignore)"
echo "Back up the key file AND the password now (for example to a USB stick and a password manager)."
