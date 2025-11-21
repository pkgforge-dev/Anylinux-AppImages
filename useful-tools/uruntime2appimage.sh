#!/bin/sh

# quickly turns an AppDir to a DWARFS AppImage with uruntime
# It will download both the uruntime and mkdwarfs
# The only dependency is zsyncmake

# By default it will assume that the AppDir is in the $PWD
# And will output the AppImage there as well

set -e

ARCH=${ARCH:-$(uname -m)}
APPDIR=${APPDIR:-$PWD/AppDir}
OUTPATH=${OUTPATH:-$PWD}
DWARFS_COMP="${DWARFS_COMP:-zstd:level=22 -S26 -B6}"
TMPDIR=${TMPDIR:-/tmp}
DWARFS_CMD=${DWARFS_CMD:-$TMPDIR/mkdwarfs}
RUNTIME=${RUNTIME:-$TMPDIR/uruntime}
DWARFSPROF=${DWARFSPROF:-$APPDIR/.dwarfsprofile}
OPTIMIZE_LAUNCH=${OPTIMIZE_LAUNCH:-0}

APPIMAGE_ARCH=$(uname -m)
URUNTIME_LINK=${URUNTIME_LINK:-https://github.com/VHSgunzo/uruntime/releases/download/v0.5.6/uruntime-appimage-dwarfs-lite-$APPIMAGE_ARCH}
DWARFS_LINK=${DWARFS_LINK:-https://github.com/mhx/dwarfs/releases/download/v0.14.1/dwarfs-universal-0.14.1-Linux-$APPIMAGE_ARCH}

# github actions doesn't set user causing some apps
# crash when making the dwarfs image profile
export USER="${LOGNAME:-${USER:-${USERNAME:-yomama}}}"

_echo() {
	printf '\033[1;92m%s\033[0m\n' "$*"
}

_err_msg(){
	>&2 printf '\033[1;31m%s\033[0m\n' " $*"
}

_download() {
	if command -v wget 1>/dev/null; then
		DOWNLOAD_CMD="wget -qO"
	elif command -v curl 1>/dev/null; then
		DOWNLOAD_CMD="curl -Lso"
	else
		>&2 echo "ERROR: we need wget or curl to download $1"
		exit 1
	fi
	$DOWNLOAD_CMD "$@"
}

_deploy_desktop_and_icon() {
	if [ ! -f "$APPDIR"/*.desktop ]; then
		if [ "$DESKTOP" = "DUMMY" ]; then
			# use the first binary name in shared/bin as filename
			set -- "$APPDIR"/shared/bin/*
			[ -f "$1" ] || exit 1
			f=${1##*/}
			_echo "* Adding dummy $f desktop entry to $APPDIR..."
			cat <<-EOF > "$APPDIR"/"$f".desktop
			[Desktop Entry]
			Name=$f
			Exec=$f
			Comment=Dummy made by quick-sharun
			Type=Application
			Hidden=true
			Categories=Utility
			Icon=$f
			EOF
		elif [ -f "$DESKTOP" ]; then
			_echo "* Adding $DESKTOP to $APPDIR..."
			cp -v "$DESKTOP" "$APPDIR"
		elif [ -n "$DESKTOP" ]; then
			_echo "* Downloading $DESKTOP to $APPDIR..."
			_download "$APPDIR"/"${DESKTOP##*/}" "$DESKTOP"
		fi

		# make sure desktop entry ends with .desktop
		if [ ! -f "$APPDIR"/*.desktop ] && [ -f "$APPDIR"/*.desktop.* ]; then
			filename="${DESKTOP##*/}"
			mv "$APPDIR"/*.desktop.* "$APPDIR"/"${filename%.desktop*}".desktop
		fi
	fi

	if [ ! -f "$APPDIR"/.DirIcon ]; then
		if [ "$ICON" = "DUMMY" ]; then
			# use the first binary name in shared/bin as filename
			set -- "$APPDIR"/shared/bin/*
			[ -f "$1" ] || exit 1
			f=${1##*/}
			_echo "* Adding dummy $f icon to $APPDIR..."
			:> "$APPDIR"/"$f".png
			:> "$APPDIR"/.DirIcon
		elif [ -f "$ICON" ]; then
			_echo "* Adding $ICON to $APPDIR..."
			cp -v "$ICON" "$APPDIR"
			cp -v "$ICON" "$APPDIR"/.DirIcon
		elif [ -n "$ICON" ]; then
			_echo "* Downloading $ICON to $APPDIR..."
			_download "$APPDIR"/"${ICON##*/}" "$ICON"
			cp -v "$APPDIR"/"${ICON##*/}" "$APPDIR"/.DirIcon
		fi
	fi
}

_check_window_class() {
	set -- "$APPDIR"/*.desktop

	# do not bother if class is declared already
	if grep -q 'StartupWMClass=' "$1"; then
		return 0
	fi

	if [ -z "$STARTUPWMCLASS" ]; then
		_err_msg "WARNING: '$1' is missing StartupWMClass!"
		_err_msg "We will fix it using the name of the binary but this"
		_err_msg "may be wrong so please add the correct value if so"
		_err_msg "set STARTUPWMCLASS so I can use that vallue instead"
		bin="$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$1")"
		bin=${bin##*/}
		if [ -z "$bin" ]; then
			_err_msg "ERROR: Unable to determine name of binary"
			exit 1
		fi
	fi

	class=${STARTUPWMCLASS:-$bin}
	sed -i -e "/\[Desktop Entry\]/a\StartupWMClass=$class" "$1"
}

_try_to_find_icon() {
	>&2 echo "No $APPDIR/.DirIcon found, trying to find it in $APPDIR"

	# try the first top level .png or .svg before searching
	if cp -v "$APPDIR"/*.png "$APPDIR"/.DirIcon 2>/dev/null \
	  || cp -v "$APPDIR"/*.svg "$APPDIR"/.DirIcon 2>/dev/null; then
		>&2 echo "Found icon and copied it to $APPDIR/.DirIcon"
		return 0
	fi

	# Now search depper
	icon_name=$(awk -F'=' '/^Icon=/{print $2; exit}' "$APPDIR"/*.desktop)
	icon=$(find "$APPDIR" -type f -name "$icon_name".png -print -quit)
	if [ -n "$icon" ] && cp -v "$icon" "$APPDIR"/.DirIcon; then
		>&2 echo "Found $icon and copied it to $APPDIR/.DirIcon"
	else
		return 1
	fi
}

if [ ! -d "$APPDIR" ]; then
	>&2 echo "ERROR: No $APPDIR directory found"
	>&2 echo "Set APPDIR if you have it at another location"
	exit 1
elif [ ! -f "$APPDIR"/AppRun ]; then
	>&2 echo "ERROR: No $APPDIR/AppRun file found!"
	exit 1
fi

_deploy_desktop_and_icon

DESKTOP_ENTRY=$(echo "$APPDIR"/*.desktop)
APPNAME=${APPNAME:-$(awk -F'=' '/^Name=/{gsub(/ /,"_",$2); print $2; exit}' "$DESKTOP_ENTRY")}

# sanitize VERSION and APPNAME
if [ -n "$VERSION" ]; then
	VERSION=$(printf '%s' "$VERSION" | tr '":><*|\?\r\n' '_')
fi
if [ -n "$APPNAME" ]; then
	APPNAME=$(printf '%s' "$APPNAME" | tr '":><*|\?\r\n' '_')
fi

# add appimage info to desktop entry, first make sure to remove existing info
sed -i \
	-e '/X-AppImage-Name/d'    \
	-e '/X-AppImage-Version/d' \
	-e '/X-AppImage-Arch/d'    \
	"$DESKTOP_ENTRY"

echo "
X-AppImage-Name=$APPNAME
X-AppImage-Version=${VERSION:-UNKNOWN}
X-AppImage-Arch=$APPIMAGE_ARCH
" >> "$DESKTOP_ENTRY"

if [ ! -f "$DESKTOP_ENTRY" ]; then
	>&2 echo "ERROR: No top level .desktop file found in $APPDIR"
	>&2 echo "Note it cannot be more than .desktop file in that location"
	exit 1
elif [ ! -f "$APPDIR"/.DirIcon ] && ! _try_to_find_icon; then
	>&2 echo "ERROR: No top level .DirIcon file found in $APPDIR"
	exit 1
elif ! mkdir -p "$OUTPATH"; then
	>&2 echo "ERROR: Cannot create output directory: '$OUTPATH'"
	exit 1
elif [ ! -x "$APPDIR"/AppRun ]; then
	>&2 echo "WARNING: Fixing exec perms of $APPDIR/AppRun"
	chmod +x "$APPDIR"/AppRun
fi

_check_window_class

if [ -z "$OUTNAME" ]; then
	if [ -n "$VERSION" ]; then
		OUTNAME="$APPNAME"-"$VERSION"-anylinux-"$ARCH".AppImage
	else
		OUTNAME="$APPNAME"-anylinux-"$ARCH".AppImage
		>&2 echo "WARNING: VERSION is not set"
		>&2 echo "WARNING: set it to include it in $OUTNAME"
	fi
fi

if [ -z "$UPINFO" ]; then
	>&2 echo "No update information given, trying to guess it..."
	if [ -n "$GITHUB_REPOSITORY" ]; then
		UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
		>&2 echo
		>&2 echo "Guessed $UPINFO as the update information"
		>&2 echo "It may be wrong so please set the UPINFO instead"
		>&2 echo
	else
		>&2 echo
		>&2 echo "We were not able to guess the update information"
		>&2 echo "Please add it if you will distribute the AppImage"
		>&2 echo
	fi
fi

if ! command -v zsyncmake 1>/dev/null; then
	>&2 echo "ERROR: Missing dependency zsyncmake"
	exit 1
fi

if command -v mkdwarfs 1>/dev/null; then
	DWARFS_CMD="$(command -v mkdwarfs)"
elif [ ! -x "$TMPDIR"/mkdwarfs ]; then
	_echo "Downloading dwarfs binary from $DWARFS_LINK"
	_download "$DWARFS_CMD" "$DWARFS_LINK"
	chmod +x "$DWARFS_CMD"
fi

if [ ! -x "$RUNTIME" ]; then
	_echo "Downloading uruntime from $URUNTIME_LINK"
	_download "$RUNTIME" "$URUNTIME_LINK"
	chmod +x "$RUNTIME"
fi

if [ "$URUNTIME_PRELOAD" = 1 ]; then
	_echo "------------------------------------------------------------"
	_echo "Setting runtime to always keep the mount point..."
	_echo "------------------------------------------------------------"
	sed -i -e 's|URUNTIME_MOUNT=[0-9]|URUNTIME_MOUNT=0|' "$RUNTIME"
fi

if [ -n "$UPINFO" ]; then
	_echo "------------------------------------------------------------"
	_echo "Adding update information \"$UPINFO\" to runtime..."
	_echo "------------------------------------------------------------"
	"$RUNTIME" --appimage-addupdinfo "$UPINFO"
fi

# make sure the .env has all the "unset" last, due to a bug in the dotenv
# library used by sharun all the unsets have to be declared last in the .env
if [ -f "$APPDIR"/.env ]; then
	sorted_env="$(LC_ALL=C awk '
		{
			if ($0 ~ /^unset/) {
				unset_array[++u] = $0
			} else {
				print
			}
		}
		END {
			for (i = 1; i <= u; i++) {
				print unset_array[i]
			}
		}' "$APPDIR"/.env
	)"
	echo "$sorted_env" > "$APPDIR"/.env
fi

_echo "------------------------------------------------------------"
_echo "Making AppImage..."
_echo "------------------------------------------------------------"

set -- \
	--force               \
	--set-owner 0         \
	--set-group 0         \
	--no-history          \
	--no-create-timestamp \
	--header "$RUNTIME"   \
	--input  "$APPDIR"

if [ "$OPTIMIZE_LAUNCH" = 1 ]; then
	tmpappimage="$TMPDIR"/.analyze
	deps="xvfb-run pkill"
	for d in $deps; do
		if ! command -v "$d" 1>/dev/null; then
			>&2 echo "ERROR: Using OPTIMIZE_LAUNCH requires $d"
			exit 1
		fi
	done

	_echo "* Making dwarfs profile optimization at $DWARFSPROF..."
	"$DWARFS_CMD" "$@" -C zstd:level=5 -S19 --output "$tmpappimage"
	chmod +x "$tmpappimage"

	( DWARFS_ANALYSIS_FILE="$DWARFSPROF" xvfb-run -a -- "$tmpappimage" ) &
	pid=$!

	sleep 10
	pkill -P "$pid" || true
	umount "$TMPDIR"/.mount_* || true
	wait "$pid" || true
	rm -f "$tmpappimage"
fi


if [ -f "$DWARFSPROF" ]; then
	_echo "* Using $DWARFSPROF..."
	set -- --categorize=hotness --hotness-list="$DWARFSPROF" "$@"
fi

if ! "$DWARFS_CMD" "$@" -C $DWARFS_COMP --output "$OUTPATH"/"$OUTNAME"; then
	>&2 echo "ERROR: Something went wrong making dwarfs image!"
	if [ -f "$DWARFSPROF" ]; then
		>&2 echo "Found '$DWARFSPROF' file in '$APPDIR', may be causing issues:"
		>&2 echo "------------------------------------------------------------"
		>&2 cat "$DWARFSPROF" || :
		>&2 echo "------------------------------------------------------------"
	fi
	exit 1
fi

if [ -n "$UPINFO" ]; then
	_echo "------------------------------------------------------------"
	_echo "Making zsync file..."
	_echo "------------------------------------------------------------"
	zsyncmake -u "$OUTNAME" "$OUTPATH"/"$OUTNAME"

	# there is a nasty bug that zsync make places the .zsync file in PWD
	if [ ! -f "$OUTPATH"/"$OUTNAME".zsync ] && [ -f "$OUTNAME".zsync ]; then
		mv "$OUTNAME".zsync "$OUTPATH"/"$OUTNAME".zsync
	fi
fi

chmod +x "$OUTPATH"/"$OUTNAME"

# make a appinfo file next to the artifact, this can be used for
# later getting info when making a github release
echo "
X-AppImage-Name=$APPNAME
X-AppImage-Version=${VERSION:-UNKNOWN}
X-AppImage-Arch=$APPIMAGE_ARCH
" > "$OUTPATH"/appinfo

_echo "------------------------------------------------------------"
_echo "All done! AppImage at: $OUTPATH/$OUTNAME"
_echo "------------------------------------------------------------"
