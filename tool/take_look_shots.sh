#!/bin/zsh
# Takes pictures of the pop-ups and the Blessing Wheel from an iPhone
# simulator, to look at a design before showing it.
#
#   tool/take_look_shots.sh <simulator id> <folder to put them in>
#
# It runs integration_test/look_shots.dart, which stages each screen and
# asks for a picture.
set -e
UDID="$1"; OUT="$2"
ROOT="${0:A:h:h}"
mkdir -p "$OUT"
cd "$ROOT"
LOG="$OUT/_run.log"
flutter test --no-pub integration_test/look_shots.dart -d "$UDID" > "$LOG" 2>&1 &
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
tail -1 "$LOG" | tr '\r' '\n' | tail -1
