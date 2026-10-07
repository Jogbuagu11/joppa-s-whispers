#!/bin/zsh
# Takes the store screenshots from an iPhone simulator.
#
#   tool/take_store_screenshots.sh "iPhone 17 Pro Max" apple-6.9
#   tool/take_store_screenshots.sh "iPhone 8 Plus" google-play
#
# It runs integration_test/store_shots.dart, which stages each screen and
# asks for a picture; the pictures land in dist/store/screenshots/<folder>/.
set -e
DEVICE_NAME="$1"; FOLDER="$2"
ROOT="${0:A:h:h}"; OUT="$ROOT/dist/store/screenshots/$FOLDER"
mkdir -p "$OUT"
UDID=$(xcrun simctl list devices available | grep -F "$DEVICE_NAME (" | head -1 | grep -oE "[0-9A-F-]{36}" || true)
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_NAME")
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# The tidy status bar the stores expect.
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi
cd "$ROOT"
LOG="$OUT/_run.log"
flutter test --no-pub integration_test/store_shots.dart -d "$UDID" > "$LOG" 2>&1 &
RUN=$!
while kill -0 $RUN 2>/dev/null; do
  DATA=$(xcrun simctl get_app_container "$UDID" com.whispersofjoppa.game data 2>/dev/null || true)
  REQUEST="$DATA/Documents/shot_request.txt"
  if [ -n "$DATA" ] && [ -f "$REQUEST" ]; then
    NAME=$(cat "$REQUEST")
    xcrun simctl io "$UDID" screenshot "$OUT/$NAME.png" >/dev/null 2>&1
    rm -f "$REQUEST"
    echo "took $NAME"
  fi
  sleep 0.3
done
xcrun simctl status_bar "$UDID" clear
tail -1 "$LOG" | tr '\r' '\n' | tail -1

# Google Play allows a picture at most twice as tall as it is wide. The
# 6.9-inch pictures are a little taller, so the Play set is the same pictures
# with the status bar and the strip under the game trimmed off.
if [ "$FOLDER" = "apple-6.9" ]; then
  PLAY="$ROOT/dist/store/screenshots/google-play"
  mkdir -p "$PLAY"
  for f in "$OUT"/*.png; do
    sips --cropOffset 168 0 -c 2640 1320 "$f" --out "$PLAY/$(basename "$f")" >/dev/null
  done
  echo "made the Google Play set"
fi
