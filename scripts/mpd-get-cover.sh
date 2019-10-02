#!/bin/bash

if test $# -eq "0"
then
    exit 1
fi

ICONDIR=/tmp/mpd-icons
if ! test -d "$ICONDIR"; then mkdir -p "$ICONDIR"; fi

PATTERN='*\.(jpg|jpeg|png|gif)$'

MP3FILE="$1"
if test $# -ge "2"
then
    PATTERN="$2"
fi

TMP=${MP3FILE//\//.}
TMP=${TMP/.mp3/.png}
TMP=${TMP:1}
ICONFILE="$ICONDIR/$TMP"

if test -f "$ICONFILE"
then
    echo $ICONFILE
    exit 0
fi

if ffmpeg -i "$MP3FILE" "$ICONFILE" 2> /dev/null > /dev/null
then
    EXIF=$(exiftool "$ICONFILE")
    WIDTH=$(echo "$EXIF" | awk '/Image Width/ {print $4}')
    HEIGHT=$(echo "$EXIF" | awk '/Image Height/ {print $4}')
    if test "$WIDTH" -gt "$HEIGHT"
    then
        ADJUST=$((($WIDTH/2) - ($HEIGHT/2)))
        convert "$ICONFILE" -crop "${HEIGHT}x${HEIGHT}+${ADJUST}+0" "$ICONFILE"
    fi
    echo $ICONFILE
    exit 0
fi

find ${MP3FILE%/*} -maxdepth 1 -type f | egrep -i -m1 "$PATTERN"
