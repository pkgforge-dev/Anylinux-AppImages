#!/bin/sh

# wrapper script for sharun that simplifies deployment to simple one liners
# Will try to detect and force deployment of GTK, QT, OpenGL, etc
# You can also force their deployment by setting the respective env variables
# for example set DEPLOY_OPENGL=1 to force opengl to be deployed

# Set ADD_HOOKS var to deploy the several hooks of this repository
# Example: ADD_HOOKS="self-updater.bg.hook:fix-namespaces.hook" ./quick-sharun.sh
# Using the hooks automatically downloads a generic AppRun if no AppRun is present

# Set DESKTOP and ICON to the path of top level .desktop and icon to deploy them

set -e

ARCH="$(uname -m)"
TMPDIR=${TMPDIR:-/tmp}
APPRUN=${APPRUN:-AppRun-generic}
APPDIR=${APPDIR:-$PWD/AppDir}
SHARUN_LINK=${SHARUN_LINK:-https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$ARCH-aio}
HOOKSRC=${HOOKSRC:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools}
LD_PRELOAD_OPEN=${LD_PRELOAD_OPEN:-https://github.com/fritzw/ld-preload-open.git}

DEPLOY_QT=${DEPLOY_QT:-0}
DEPLOY_GTK=${DEPLOY_GTK:-0}
DEPLOY_OPENGL=${DEPLOY_OPENGL:-0}
DEPLOY_VULKAN=${DEPLOY_VULKAN:-0}
DEPLOY_PIPEWIRE=${DEPLOY_PIPEWIRE:-0}
DEPLOY_DATADIR=${DEPLOY_DATADIR:-1}
DEPLOY_LOCALE=${DEPLOY_LOCALE:-0}

DEBLOAT_LOCALE=${DEBLOAT_LOCALE:-1}
LOCALE_DIR=${LOCALE_DIR:-/usr/share/locale}

# for sharun
export DST_DIR="$APPDIR"
export GEN_LIB_PATH=1
export HARD_LINKS=1
export WITH_HOOKS=1
export STRACE_MODE="${STRACE_MODE:-1}"
export VERBOSE=1

if [ -z "$NO_STRIP" ]; then
	export STRIP=1
fi

_echo() {
	printf '\033[1;92m%s\033[0m\n' " $*"
}

_err_msg(){
	>&2 printf '\033[1;31m%s\033[0m\n' " $*"
}

case "$1" in
	''|--help)
		_err_msg "USAGE: ${0##*/} /path/to/binaries_and_libraries"
		_err_msg
		_err_msg "You can also force bundling with vars, example:"
		_err_msg "DEPLOY_OPENGL=1 ${0##*/} /path/to/bins"
		_err_msg
		exit 1
		;;
	*)
		if [ -e "$1" ] && [ "$2" = "--" ]; then
			STRACE_ARGS_PROVIDED=1
		fi
		;;
esac

if [ -z "$LIB_DIR" ]; then
	if [ -d "/usr/lib/$ARCH-linux-gnu" ]; then
		LIB_DIR="/usr/lib/$ARCH-linux-gnu"
	elif [ -d "/usr/lib" ]; then
		LIB_DIR="/usr/lib"
	else
		_err_msg "ERROR: there is no /usr/lib directory in this system"
		_err_msg "set the LIB_DIR variable to where you have libraries"
		exit 1
	fi
fi

if command -v xvfb-run 1>/dev/null; then
	XVFB_CMD="xvfb-run -a --"
else
	_err_msg "WARNING: xvfb-run was not detected on the system"
	_err_msg "xvfb-run is used with sharun for strace mode, this is needed"
	_err_msg "to find dlopened libraries as normally this script is going"
	_err_msg "to be run in a headless enviromment where the application"
	_err_msg "will fail to start and result strace mode will not be able"
	_err_msg "to find the libraries dlopened by the application"
	XVFB_CMD=""
	sleep 3
fi


# POSIX shell doesn't support arrays we use awk to save it into a variable
# then with 'eval set -- $var' we add it to the positional array
# see https://unix.stackexchange.com/questions/421158/how-to-use-pseudo-arrays-in-posix-shell-script
_save_array() {
	LC_ALL=C awk -v q="'" '
	BEGIN{
		for (i=1; i<ARGC; i++) {
			gsub(q, q "\\" q q, ARGV[i])
			printf "%s ", q ARGV[i] q
		}
		print ""
	}' "$@"
}

_download() {
	if command -v wget 1>/dev/null; then
		DOWNLOAD_CMD="wget"
		set -- -qO "$@"
	elif command -v curl 1>/dev/null; then
		DOWNLOAD_CMD="curl"
		set -- -Lso "$@"
	else
		_err_msg "ERROR: we need wget or curl to download $1"
		exit 1
	fi
	"$DOWNLOAD_CMD" "$@"
}

_determine_what_to_deploy() {
	for bin do
		# ignore flags
		case "$bin" in
			--) break   ;;
			-*) continue;;
		esac

		# check linked libraries and enable each mode accordingly
		for lib in $(ldd "$bin" | awk '{print $1}'); do
			case "$lib" in
				*libQt5Core.so*)
					DEPLOY_QT=1
					QT_DIR=qt5
					;;
				*libQt6Core.so*)
					DEPLOY_QT=1
					QT_DIR=qt6
					;;
				*libgtk-3*.so*)
					DEPLOY_GTK=1
					GTK_DIR=gtk-3.0
					;;
				*libgtk-4*.so*)
					DEPLOY_GTK=1
					GTK_DIR=gtk-4.0
					;;
				*libgdk_pixbuf*.so*)
					DEPLOY_GDK=1
					;;
				*libpipewire*.so*)
					DEPLOY_PIPEWIRE=1
					;;
			esac
		done
	done

	if [ "$DEPLOY_QT" = 1 ] && [ -z "$QT_DIR" ]; then
		_err_msg
		_err_msg "WARNING: Qt deployment was forced but we do not know"
		_err_msg "what version of Qt needs to be deployed!"
		_err_msg "Defaulting to Qt6, if you do not want that set"
		_err_msg "QT_DIR to the name of the Qt dir in $LIB_DIR"
		_err_msg
		QT_DIR=qt6
	fi

	if [ "$DEPLOY_GTK" = 1 ] && [ -z "$GTK_DIR" ]; then
		_err_msg
		_err_msg "WARNING: GTK deployment was forced but we do not know"
		_err_msg "what version of GTK needs to be deployed!"
		_err_msg "Defaulting to gtk-3.0, if you do not want that set"
		_err_msg "GTK_DIR to the name of the gtk dir in $LIB_DIR"
		_err_msg
		GTK_DIR=gtk-3.0
	fi
}

_make_deployment_array() {
	# always deploy minimal amount of gconv
	if [ -d "$LIB_DIR"/gconv ]; then
		_echo "* Deploying minimal gconv"
		set -- "$@" \
			"$LIB_DIR"/gconv/UTF*.so*   \
			"$LIB_DIR"/gconv/ANSI*.so*  \
			"$LIB_DIR"/gconv/CP*.so*    \
			"$LIB_DIR"/gconv/LATIN*.so* \
			"$LIB_DIR"/gconv/UNICODE*.so*
	fi
	if [ "$DEPLOY_QT" = 1 ]; then
		# some distros have a qt dir rather than qt6 or qt5 dir
		if [ ! -d "$LIB_DIR"/"$QT_DIR" ]; then
			QT_DIR=qt
		fi
		_echo "* Deploying $QT_DIR"
		set -- "$@" \
			"$LIB_DIR"/"$QT_DIR"/plugins/imageformats/*.so* \
			"$LIB_DIR"/"$QT_DIR"/plugins/iconengines/*.so*  \
			"$LIB_DIR"/"$QT_DIR"/plugins/platform*/*.so*    \
			"$LIB_DIR"/"$QT_DIR"/plugins/styles/*.so*       \
			"$LIB_DIR"/"$QT_DIR"/plugins/tls/*.so*          \
			"$LIB_DIR"/"$QT_DIR"/plugins/wayland-*/*.so*    \
			"$LIB_DIR"/"$QT_DIR"/plugins/xcbglintegrations/*.so*
	fi
	if [ "$DEPLOY_GTK" = 1 ]; then
		_echo "* Deploying $GTK_DIR"
		DEPLOY_GDK=1
		set -- "$@" \
			"$LIB_DIR"/"$GTK_DIR"/*/immodules/*   \
			"$LIB_DIR"/gvfs/libgvfscommon.so      \
			"$LIB_DIR"/gio/modules/libgvfsdbus.so \
			"$LIB_DIR"/gio/modules/libdconfsettings.so
	fi
	if [ "$DEPLOY_GDK" = 1 ]; then
		_echo "* Deploying gdk-pixbuf"
		set -- "$@" \
			"$LIB_DIR"/gdk-pixbuf-*/*/loaders/*

	fi
	if [ "$DEPLOY_OPENGL" = 1 ] || [ "$DEPLOY_VULKAN" = 1 ]; then
		set -- "$@" \
			"$LIB_DIR"/dri/*   \
			"$LIB_DIR"/vdpau/* \
			"$LIB_DIR"/libgallium*.so*
		if [ "$DEPLOY_OPENGL" = 1 ]; then
			_echo "* Deploying OpenGL"
			set -- "$@" \
				"$LIB_DIR"/libEGL*.so*   \
				"$LIB_DIR"/libGLX*.so*   \
				"$LIB_DIR"/libGL.so*     \
				"$LIB_DIR"/libOpenGL.so* \
				"$LIB_DIR"/libGLESv2.so*
		fi
		if [ "$DEPLOY_VULKAN" = 1 ]; then
			_echo "* Deploying vulkan"
			set -- "$@" \
				"$LIB_DIR"/libvulkan*.so*  \
				"$LIB_DIR"/libVkLayer*.so*
		fi
	fi
	if [ "$DEPLOY_PIPEWIRE" = 1 ]; then
		_echo "* Deploying pipewire"
		set -- "$@" \
			"$LIB_DIR"/pipewire-*/* \
			"$LIB_DIR"/spa-*/*      \
			"$LIB_DIR"/spa-*/*/*    \
			"$LIB_DIR"/alsa-lib/*pipewire*.so*
	fi

	TO_DEPLOY_ARRAY=$(_save_array "$@")
}


_echo "------------------------------------------------------------"
_echo "Starting deployment, checking if extra libraries need to be added..."
echo ""

mkdir -p "$APPDIR"
_determine_what_to_deploy "$@"
_make_deployment_array

echo ""
_echo "Now jumping to sharun..."
_echo "------------------------------------------------------------"

if [ ! -x "$TMPDIR"/sharun-aio ]; then
	_echo "Downloading sharun..."
	_download "$TMPDIR"/sharun-aio "$SHARUN_LINK"
	chmod +x "$TMPDIR"/sharun-aio
fi

# when strace args are given sharun will only use them when
# you pass a single binary to it that is:
# 'sharun-aio l /path/to/bin -- google.com' works (the app does the action)
# 'sharun-aio l /path/to/lib /path/to/bin -- google.com' does not work
if [ "$STRACE_ARGS_PROVIDED" = 1 ]; then
	$XVFB_CMD "$TMPDIR"/sharun-aio l "$@"
fi

# now merge the deployment array
ARRAY=$(_save_array "$@")
eval set -- "$TO_DEPLOY_ARRAY" "$ARRAY"

$XVFB_CMD "$TMPDIR"/sharun-aio l "$@"

echo ""
_echo "------------------------------------------------------------"
echo ""

if [ -n "$PATH_MAPPING" ]; then
	case "$PATH_MAPPING" in
		*'${SHARUN_DIR}'*) true;;
		*)
			_err_msg 'ERROR: PATH_MAPPING must contain unexpanded'
			_err_msg '${SHARUN_DIR} variable for this to work'
			_err_msg 'Example:'
			_err_msg "'PATH_MAPPING=/etc:\${SHARUN_DIR}/etc'"
			_err_msg 'NOTE: The braces in the variable are needed'
			exit 1
			;;
	esac

	deps="git make"
	for d in $deps; do
		if ! command -v "$d" 1>/dev/null; then
			_err_msg "ERROR: Using PATH_MAPPING requires $d"
			exit 1
		fi
	done

	_echo "* Building $LD_PRELOAD_OPEN..."

	rm -rf "$TMPDIR"/ld-preload-open
	git clone "$LD_PRELOAD_OPEN" "$TMPDIR"/ld-preload-open && (
		cd "$TMPDIR"/ld-preload-open
		make all
	)

	mv -v "$TMPDIR"/ld-preload-open/path-mapping.so "$APPDIR"/lib
	echo "path-mapping.so" >> "$APPDIR"/.preload
	echo "PATH_MAPPING=$PATH_MAPPING" >> "$APPDIR"/.env
	_echo "* PATH_MAPPING successfully added!"
	echo ""
elif [ "$PATH_MAPPING_RELATIVE" = 1 ]; then
	sed -i -e 's|/usr|././|g' "$APPDIR"/shared/bin/*
	echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}' >> "$APPDIR"/.env
	_echo "* Patched away /usr from binaries..."
	echo ""
fi

if [ "$DEPLOY_DATADIR" = 1 ]; then
	for bin in "$APPDIR"/bin/*; do
		[ -x "$bin" ] || continue
		bin="${bin##*/}"
		for datadir in /usr/local/share/* /usr/share/*; do
			if echo "$datadir" | grep -qi "$bin"; then
				mkdir -p "$APPDIR"/share
				_echo "* Adding datadir $datadir..."
				cp -vr "$datadir" "$APPDIR/share"
				echo ""
				break
			fi
		done
	done
fi

if [ "$DEPLOY_LOCALE" = 1 ]; then
	mkdir -p "$APPDIR"/share
	_echo "* Adding locales..."
	cp -vr "$LOCALE_DIR" "$APPDIR"/share
	if [ "$DEBLOAT_LOCALE" = 1 ]; then
		_echo "* Removing unneeded locales..."
		set -- \
		    ! -name '*glib*' \
		    ! -name '*gdk*'  \
		    ! -name '*gtk*'  \
		    ! -name '*tls*'  \
		    ! -name '*p11*'  \
		    ! -name '*v4l*'  \
		    ! -name '*gettext*'
		for f in "$APPDIR"/shared/bin/*; do
			f=${f##*/}
			set -- "$@" ! -name "*$f*"
		done
		find "$APPDIR"/share/locale "$@" -type f -delete
	fi
	echo ""
fi

if [ -n "$ADD_HOOKS" ]; then
	IFS=':'
	set -- $ADD_HOOKS
	hook_dst="$APPDIR"/bin
	for hook do
		if _download "$hook_dst"/"$hook" "$HOOKSRC"/"$hook"; then
			_echo "* Added $hook"
			echo ""
		else
			_err_msg "ERROR: Failed to download $hook, valid link?"
			_err_msg "$HOOKSRC/$hook"
			exit 1
		fi
	done
fi

set -- "$APPDIR"/bin/*.hook
if [ -f "$1" ] && [ ! -f "$APPDIR"/AppRun ]; then
	_echo "* Adding $APPRUN..."
	_download "$APPDIR"/AppRun "$HOOKSRC"/"$APPRUN"
elif [ ! -f "$APPDIR"/AppRun ]; then
	_echo "* Hardlinking $APPDIR/sharun as $APPDIR/AppRun..."
	ln -v "$APPDIR"/sharun "$APPDIR"/AppRun
fi

chmod +x "$APPDIR"/AppRun "$APPDIR"/bin/*.hook 2>/dev/null || true

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
elif [ -n "$ICON" ]; then
	_echo "* Downloading $ICON to $APPDIR..."
	_download "$APPDIR"/"${ICON##*/}" "$ICON"
fi

echo ""
_echo "------------------------------------------------------------"
_echo "Finished deployment!"
_echo "------------------------------------------------------------"
