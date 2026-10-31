#!/bin/bash
# Installs the APK on the Android emulator, opens the game and checks that it
# is still on screen 30 seconds later. Prints the crash log if it is not.
# Usage: smoke_test.sh <app.apk>
set -u
APK="$1"
PKG=com.toffeetwist

adb install -r "$APK" || { echo "Could not install the APK"; exit 1; }

# Opens the game, waits, and saves the log and a screenshot.
# Returns 0 if the game is in front and nothing crashed.
check() {
  adb logcat -c
  adb shell am start -W -n "$PKG/.MainActivity"
  sleep 30
  adb logcat -d -v threadtime > logcat.txt
  adb exec-out screencap -p > emulator-screenshot.png
  FOCUS=$(adb shell dumpsys window | grep -m1 -E "mCurrentFocus|mFocusedWindow")
  echo "Window in front: $FOCUS"
  echo "---- crash report ----"
  grep -A 60 -E "FATAL EXCEPTION|\*\*\* \*\*\* \*\*\*" logcat.txt | head -200
  echo "---- Flutter messages ----"
  grep -E " (I|W|E) flutter" logcat.txt | head -100
  echo "---- app process messages ----"
  grep -E "$PKG|AndroidRuntime|libc  |DEBUG   " logcat.txt | grep -v "Access denied finding property" | head -100
  if grep -qE "FATAL EXCEPTION|Unhandled Exception" logcat.txt; then return 2; fi
  echo "$FOCUS" | grep -q "$PKG"
}

check
RESULT=$?
# Android closes apps that use a Google Play services component when the
# emulator's Play services restarts. That is not a crash of the game, so try
# once more.
if [ $RESULT -eq 1 ] && grep -qE "Killing [0-9]+:$PKG/.*depends on provider" logcat.txt; then
  echo "The system closed the game because Google Play services restarted. Trying again."
  check
  RESULT=$?
fi
echo "Game on screen and no crash: $([ $RESULT -eq 0 ] && echo yes || echo no)"
exit $RESULT
