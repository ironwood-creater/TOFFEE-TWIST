#!/bin/bash
# Installs the APK on the Android emulator, opens the game and checks that it
# is still running 30 seconds later. Prints the crash log if it is not.
# Usage: smoke_test.sh <app.apk>
set -u
APK="$1"
PKG=com.toffetwist.toffeetwist

adb logcat -c
adb install -r "$APK" || { echo "Could not install the APK"; exit 1; }
adb shell am start -W -n "$PKG/.MainActivity"
sleep 30
adb logcat -d -v threadtime > logcat.txt
adb exec-out screencap -p > emulator-screenshot.png

if adb shell pidof "$PKG" > /dev/null; then
  RUNNING=yes
else
  RUNNING=no
fi
echo "App still running after 30 s: $RUNNING"

echo "---- crash report ----"
grep -A 60 -E "FATAL EXCEPTION|\*\*\* \*\*\* \*\*\*" logcat.txt | head -200
echo "---- Flutter messages ----"
grep -E " (I|W|E) flutter" logcat.txt | head -100
echo "---- app process messages ----"
grep -E "$PKG|AndroidRuntime|libc  |DEBUG   " logcat.txt | head -100

[ "$RUNNING" = yes ] && ! grep -q "FATAL EXCEPTION" logcat.txt
