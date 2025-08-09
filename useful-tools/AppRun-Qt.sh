#!/bin/sh

# This AppRun is Qt apps. checks for a .stylesheet file next to the AppImage
# setst the var APPIMAGE_QT_THEME to it and passes it to the array to be loaded
# NOTE: It is meant to be used with sharun which uses a top level bin dir

set -e

CURRENTDIR="$(cd "${0%/*}" && echo "$PWD")"
MAIN_BIN="$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$CURRENTDIR"/*.desktop)"
MAIN_BIN="${MAIN_BIN##*/}"
BIN="${ARGV0:-$0}"
BIN="${BIN##*/}"
unset ARGV0

# uncomment these if you also need to add udev rules or want to self update
#"$CURRENTDIR"/self-updater.sh &
#"$CURRENTDIR"/udev-installer.sh

# check if there is a custom stylesheet and append it to the arrray
if [ -f "$APPIMAGE".stylesheet ]; then
	APPIMAGE_QT_THEME="$APPIMAGE.stylesheet"
fi
if [ -f "$APPIMAGE_QT_THEME" ]; then
	set -- "$@" "-stylesheet" "$APPIMAGE_QT_THEME"
fi

# Check if ARGV0 matches any bundled binary, fallback to $1, then main bin
if [ -f "$CURRENTDIR"/bin/"$BIN" ]; then
	exec "$CURRENTDIR"/bin/"$BIN" "$@"
elif [ -f "$CURRENTDIR"/bin/"$1" ]; then
	BIN="$1"
	shift
	exec "$CURRENTDIR"/bin/"$BIN" "$@"
else
	exec "$CURRENTDIR"/bin/"$MAIN_BIN" "$@"
fi

