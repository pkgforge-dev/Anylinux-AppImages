#!/bin/sh

# Simple script to simplify the installation of packages from:
# https://github.com/pkgforge-dev/archlinux-pkgs-debloated
# These packages make the resulting AppImages a lot smaller!

set -e

ARCH="$(uname -m)"
TMPFILE="$(mktemp)"
TMPDIR="$(mktemp -d)"
SOURCE=${SOURCE:-https://api.github.com/repos/pkgforge-dev/archlinux-pkgs-debloated/releases/latest}
ERRLOG="$TMPDIR"/.errlog

COMMON_PACKAGES=${COMMON_PACKAGES:-0}
PREFER_NANO=${PREFER_NANO:-0}
ADD_MESA=${ADD_MESA:-0}
ADD_OPENGL=${ADD_OPENGL:-0}
ADD_VULKAN=${ADD_VULKAN:-0}

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

_cleanup() {
	rm -rf "$TMPFILE" "$TMPDIR"
}

trap _cleanup INT TERM EXIT

_echo() {
	printf "$GREEN%s$RESET\n" "$*"
}

_echo2() {
	printf "$YELLOW%s$RESET\n" "$*"
}

_error(){
	if [ -f "$ERRLOG" ]; then
		>&2 cat "$ERRLOG"
	fi
	>&2 printf '\033[1;31m%s\033[0m\n' "ERROR: $*"
	exit 1
}

_help_msg() {
	cat <<-EOF
	Usage: ${0##*/} [OPTIONS] [package names here]

	Downloads and install Arch Linux packages from:
	$SOURCE

	Options:
	--help         Show this message and exit
	--add-common   Install a curated set of common packages, implies --add-mesa
	--add-opengl   Include Mesa OpenGL package
	--add-vulkan   Include Mesa Vulkan drivers
	            x86_64:  vulkan-{intel,radeon,nouveau}
	            aarch64: vulkan-{freedreno,panfrost,broadcom,asahi,radeon,nouveau}
	--add-mesa     Include all of mesa, implies --add-opengl and --add-vulkan
	--prefer-nano  Prefer 'nano' variants of packages instead of 'mini'

	Environment variables:
	SOURCE           Change the source of the packages
	COMMON_PACKAGES  Set to 1 to enable --add-common behavior
	PREFER_NANO      Set to 1 to prefer 'nano' packages
	ADD_MESA         Set to 1 to enable --add-mesa behavior
	ADD_OPENGL       Set to 1 to add OpenGL package
	ADD_VULKAN       Set to 1 to add Vulkan packages

	Examples:
	${0##*/} --add-common
	${0##*/} --add-vulkan
	${0##*/} --add-common --prefer-nano
	${0##*/} --add-vulkan mangohud
	${0##*/} --add-opengl intel-media-driver
	${0##*/} ffmpeg-mini qt6-base-mini

	NOTE:
	- Requires either 'wget' or 'curl'
	EOF
	exit 1
}

_download() {
	COUNT=0
	while true; do
		if $DLCMD "$@" 2>>"$ERRLOG"; then
			break
		fi
		COUNT=$(( COUNT + 1 ))
		if [ "$COUNT" -gt 5 ]; then
			_error "Failed 5 times to download $*"
		fi
	done
}

if ! command -v pacman 1>/dev/null; then
	_error "${0##*/} can only be used on Archlinux like systems!"
elif command -v wget 1>/dev/null; then
	DLCMD="wget --retry-connrefused --tries=30 -O"
elif command -v curl 1>/dev/null; then
	DLCMD="curl --retry-connrefused --retry 30 -Lo"
else
	_error "We need wget or curl to download packages"
fi

case "$ARCH" in
	x86_64)  SUFFIX='x86_64.pkg.tar.zst'       ;;
	aarch64) SUFFIX='aarch64.pkg.tar.xz'       ;;
	''|*)    _error "Unsupported Arch: '$ARCH'";;
esac

while true;
	do case "$1" in
		--help)
			_help_msg
			;;
		--add-common)
			COMMON_PACKAGES=1
			shift
			;;
		--prefer-nano)
			PREFER_NANO=1
			shift
			;;
		--add-opengl)
			ADD_OPENGL=1
			shift
			;;
		--add-vulkan)
			ADD_VULKAN=1
			shift
			;;
		--add-mesa)
			ADD_MESA=1
			shift
			;;
		'')
			break
			;;
		-*)
			_error "Unknown option: $1"
			;;
		*)
			ADD_PACKAGES="$ADD_PACKAGES $1"
			shift
			;;
	esac
done

if [ "$PREFER_NANO"  = 1 ]; then
	PKG_TYPE=nano
else
	PKG_TYPE=mini
fi

if [ "$COMMON_PACKAGES" = 1 ]; then
	ADD_MESA=1
	set -- "$@" \
		opus-mini        \
		ffmpeg-mini      \
		libxml2-mini     \
		qt6-base-mini    \
		gtk3-mini        \
		gtk4-mini        \
		llvm-libs-"$PKG_TYPE"
fi

if [ "$ADD_MESA" = 1 ]; then
	ADD_OPENGL=1
	ADD_VULKAN=1
fi

if [ "$ADD_OPENGL" = 1 ]; then
	set -- "$@" mesa-"$PKG_TYPE"
fi

if [ "$ADD_VULKAN" = 1 ]; then
	if [ "$ARCH" = 'x86_64' ]; then
		set -- "$@" vulkan-intel-"$PKG_TYPE"
	elif [ "$ARCH" = 'aarch64' ]; then
		set -- "$@" \
			vulkan-panfrost-"$PKG_TYPE"  \
			vulkan-freedreno-"$PKG_TYPE" \
			vulkan-broadcom-"$PKG_TYPE"  \
			vulkan-asahi-"$PKG_TYPE"
	fi
	set -- "$@" \
		vulkan-radeon-"$PKG_TYPE" \
		vulkan-nouveau-"$PKG_TYPE"
fi

set -- "$@" $ADD_PACKAGES

if [ -z "$1" ]; then
	_help_msg
fi


if ! LIST_ALL=$(_download - "$SOURCE" \
	| sed 's/[()",{} ]/\n/g' | grep -o 'https.*pkg\.tar\.\(zst\|xz\)'); then
	_error "Failed to download packages list!"
fi

LIST_ARCH=$(echo "$LIST_ALL" | grep "$SUFFIX")

for pkg do
	if ! echo "$LIST_ARCH" | grep -m 1 "$pkg" >> "$TMPFILE"; then
		# maybe this package is only available for a certain arch
		# in that case check before quitting with error
		if echo "$LIST_ALL" | grep -m 1 "$pkg"; then
			_echo2 "* Skipped '$pkg' not available for $ARCH"
		else
			_error "Could not find package: $pkg"
		fi
	fi
done

TO_DOWNLOAD=$(sort -u "$TMPFILE")

_echo "------------------------------------------------------------"
_echo "      WE ARE GOING TO INSTALL THE FOLLOWING PACKAGES        "
_echo "------------------------------------------------------------"
_echo2 "$TO_DOWNLOAD"
_echo "------------------------------------------------------------"
_echo ""

set -- $TO_DOWNLOAD
for pkg do
	_download "$TMPDIR"/"${pkg##*/}" "$pkg" &
	pids="$pids $!"
done

for pid in $pids; do
	if ! wait "$pid"; then
		_error "Failed to download packages!"
	fi
done

# this script is meant to be ran on a container, but just in case
if command -v sudo 1>/dev/null; then
	SUDOCMD=sudo
elif command -v doas 1>/dev/null; then
	SUDOCMD=doas
else
	SUDOCMD=""
fi

"$SUDOCMD" pacman -U --noconfirm "$TMPDIR"/*

_echo "------------------------------------------------------------"
_echo "                         ALL DONE!                          "
_echo "------------------------------------------------------------"
