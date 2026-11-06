#!/bin/bash
# usage: convert.sh <pptx> <key> <pdf>   (needs finish.applescript next to this script)
PPTX="$1"; KEY="$2"; PDF="$3"; DIR="$(cd "$(dirname "$0")" && pwd)"
pkill osascript 2>/dev/null; pkill -x Keynote 2>/dev/null; sleep 2
rm -f "$KEY" "$PDF"
open -a Keynote "$PPTX"
start=$(date +%s)
while true; do
  n=$(osascript -e 'with timeout of 5 seconds
tell application "Keynote" to count of documents
end timeout' 2>/dev/null || echo 0)
  now=$(date +%s)
  [ "$n" -ge 1 ] && { echo "opened after $((now-start))s"; break; }
  [ $((now-start)) -ge 240 ] && { echo "TIMEOUT opening"; exit 1; }
  sleep 3
done
sleep 4
osascript "$DIR/finish.applescript" "$KEY" "$PDF" || exit 1
ls -la "$KEY" "$PDF"
