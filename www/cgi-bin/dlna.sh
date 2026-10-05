#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
urldecode(){ printf '%b' "$(echo "$1" | sed 's/+/ /g;s/%/\\x/g')"; }
RAW_FOLDER=$(echo "$QUERY_STRING" | grep -oE '(^|&)folder=[^&]*' | sed 's/.*folder=//')
RAW_START=$(echo "$QUERY_STRING" | grep -oE '(^|&)start=[^&]*' | sed 's/.*start=//')
FOLDER=$(urldecode "$RAW_FOLDER")
START=$(urldecode "$RAW_START")
[ -z "$FOLDER" ] && FOLDER='cartoon'
[ -z "$START" ] && START=0
TARGET_DIR="/www/videos_lib/$FOLDER"
if [ ! -d "$TARGET_DIR" ]; then
    echo '{"total":0,"start":0,"items":[]}'
    exit 0
fi
cd "$TARGET_DIR"
FILES=$(find . -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" \) 2>/dev/null | sed 's|^\./||' | sort)
if [ -z "$FILES" ]; then
    echo '{"total":0,"start":0,"items":[]}'
    exit 0
fi
TOTAL=$(echo "$FILES" | wc -l)
printf '{"total":%s,"start":%s,"items":[' "$TOTAL" "$START"
COUNT=0
CACHE_DIR="/tmp/dur_cache"
mkdir -p "$CACHE_DIR"
echo "$FILES" | sed -n "$((START+1)),$((START+12))p" | while read -r FILE_NAME; do
    [ -z "$FILE_NAME" ] && continue
    TITLE="${FILE_NAME%.*}"
    URL="http://192.168.20.1/videos_lib/$FOLDER/$FILE_NAME"

    FSIZE=$(stat -c%s "$FILE_NAME" 2>/dev/null)
    CACHE_KEY=$(echo "${FOLDER}_${FILE_NAME}_${FSIZE}" | md5sum | cut -d' ' -f1)
    CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

    DUR="00:00"

    if [ -f "$CACHE_FILE" ]; then
        DUR=$(cat "$CACHE_FILE")
    else
        RAW=$(ffmpeg -i "$FILE_NAME" 2>&1 | grep -i "Duration:" | head -1)
        HMS=$(echo "$RAW" | sed -n 's/.*Duration: \([0-9][0-9]*:[0-9][0-9]*:[0-9][0-9]*\).*/\1/p')

        if [ -n "$HMS" ]; then
            H=$(echo "$HMS" | cut -d: -f1 | sed 's/^0*//')
            M=$(echo "$HMS" | cut -d: -f2 | sed 's/^0*//')
            S=$(echo "$HMS" | cut -d: -f3 | cut -d. -f1 | sed 's/^0*//')
            [ -z "$H" ] && H=0
            [ -z "$M" ] && M=0
            [ -z "$S" ] && S=0
            case "$H$M$S" in
                *[!0-9]*) DUR="00:00" ;;
                *)
                    TOTAL_MIN=$(expr "$H" \* 60 + "$M" 2>/dev/null)
                    if [ -n "$TOTAL_MIN" ]; then
                        DUR=$(printf "%02d:%02d" "$TOTAL_MIN" "$S" 2>/dev/null)
                        [ -z "$DUR" ] && DUR="00:00"
                    fi
                    ;;
            esac
        fi
        echo "$DUR" > "$CACHE_FILE"
    fi

    SAFE_TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')

    [ "$COUNT" -gt 0 ] && printf ','
    printf '{"type":"video","title":"%s","url":"%s","dur":"%s"}' "$SAFE_TITLE" "$URL" "$DUR"
    COUNT=$((COUNT+1))
done
printf ']}'
