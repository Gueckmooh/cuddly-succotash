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
ICONFILE="$ICONDIR/$TMP"

if test -f "$ICONFILE"
then
    echo $ICONFILE
    exit 0
fi

if ffmpeg -i "$MP3FILE" "$ICONFILE" 2> /dev/null > /dev/null
then
    echo $ICONFILE
    exit 0
fi

find ${MP3FILE%/*} -maxdepth 1 -type f | egrep -i -m1 "$PATTERN"
