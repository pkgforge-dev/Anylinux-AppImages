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

APPIMAGE_ARCH=$(uname -m)
ARCH=${ARCH:-$APPIMAGE_ARCH}
TMPDIR=${TMPDIR:-/tmp}
APPDIR=${APPDIR:-$PWD/AppDir}
APPENV=$APPDIR/.env
DIRICON=$APPDIR/.DirIcon
DST_LIB_DIR=$APPDIR/shared/lib
MAIN_BIN=${MAIN_BIN##*/}

SHARUN_LINK=${SHARUN_LINK:-https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$APPIMAGE_ARCH-aio}
HOOKSRC=${HOOKSRC:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/hooks}
LD_PRELOAD_OPEN=${LD_PRELOAD_OPEN:-https://github.com/VHSgunzo/pathmap.git}

OUTPATH=${OUTPATH:-$PWD}
DWARFS_COMP="${DWARFS_COMP:-zstd:level=22 -S26 -B6}"
DWARFS_CMD=${DWARFS_CMD:-$TMPDIR/mkdwarfs}
RUNTIME=${RUNTIME:-$TMPDIR/uruntime}
DWARFSPROF=${DWARFSPROF:-$APPDIR/.dwarfsprofile}
OPTIMIZE_LAUNCH=${OPTIMIZE_LAUNCH:-0}
URUNTIME_LINK=${URUNTIME_LINK:-https://github.com/VHSgunzo/uruntime/releases/download/v0.5.7/uruntime-appimage-dwarfs-lite-$APPIMAGE_ARCH}
DWARFS_LINK=${DWARFS_LINK:-https://github.com/mhx/dwarfs/releases/download/v0.15.1/dwarfs-universal-0.15.1-Linux-$APPIMAGE_ARCH}

ANYLINUX_LIB=${ANYLINUX_LIB:-1}
ANYLINUX_LIB_SOURCE=${ANYLINUX_LIB_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/anylinux.c}
GTK_CLASS_FIX=${GTK_CLASS_FIX:-0}
GTK_CLASS_FIX_SOURCE=${GTK_CLASS_FIX_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/gtk-class-fix.c}
NOTIFY_SOURCE=${NOTIFY_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/bin/notify}
APPRUN_SOURCE=${APPRUN_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/bin/AppRun-generic}

DEPLOY_DATADIR=${DEPLOY_DATADIR:-1}
DEPLOY_LOCALE=${DEPLOY_LOCALE:-1}
DEBLOAT_LOCALE=${DEBLOAT_LOCALE:-1}
LOCALE_DIR=${LOCALE_DIR:-/usr/share/locale}

DEPENDENCIES="
	awk
	cc
	cp
	find
	grep
	ldd
	mv
	rm
	sleep
	strings
	tr
"

# check if the _tmp_* vars have not be declared already
# likely to happen if this script run more than once
PATH_MAPPING_SCRIPT="$APPDIR"/bin/path-mapping-hardcoded.hook

if [ -f "$PATH_MAPPING_SCRIPT" ]; then
	while IFS= read -r line; do
		case "$line" in
			_tmp_*) eval "$line";;
		esac
	done < "$PATH_MAPPING_SCRIPT"
fi

regex='A-Za-z0-9_=-'
_tmp_bin="${_tmp_bin:-$(tr -dc "$regex" < /dev/urandom | head -c 3)}"
_tmp_lib="${_tmp_lib:-$(tr -dc "$regex" < /dev/urandom | head -c 3)}"
_tmp_share="${_tmp_share:-$(tr -dc "$regex" < /dev/urandom | head -c 5)}"

if [ "$DEPLOY_PYTHON" = 1 ]; then
	DEPLOY_SYS_PYTHON=1
fi

if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
	if [ "$DEBLOAT_PYTHON" = 0 ]; then
		DEBLOAT_SYS_PYTHON=${DEBLOAT_SYS_PYTHON:-0}
	fi
	DEBLOAT_SYS_PYTHON=${DEBLOAT_SYS_PYTHON:-1}
fi

if [ -e "$1" ] && [ "$2" = "--" ]; then
	STRACE_ARGS_PROVIDED=1
fi

# for sharun
export DST_DIR="$APPDIR"
export GEN_LIB_PATH=1
export HARD_LINKS=1
export WITH_HOOKS=1
export STRACE_MODE=${STRACE_MODE:-1}
export WRAPPE_CLVL=${WRAPPE_CLVL:-15}
export VERBOSE=1

if [ -z "$NO_STRIP" ]; then
	export STRIP=1
fi

# github actions doesn't set USER and XDG_RUNTIME_DIR
# causing some apps crash when running xvfb-run
export USER="${LOGNAME:-${USER:-${USERNAME:-yomama}}}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

# apps often need this to work
export $(dbus-launch 2>/dev/null || echo 'NO_DBUS=1')

# CI containers often run as root which prevents
# web apps from running with lib4bin strace mode
export ELECTRON_DISABLE_SANDBOX=1
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export QTWEBENGINE_DISABLE_SANDBOX=1

_echo() {
	printf '\033[1;92m%s\033[0m\n' " $*"
}

_err_msg(){
	>&2 printf '\033[1;31m%s\033[0m\n' " $*"
}

_is_cmd() {
	for cmd do
		command -v "$cmd" 1>/dev/null || return 1
	done
	return 0
}

_is_elf() {
	if [ -f "$1" ] && head -c 4 "$1" | grep -qa 'ELF'; then
		return 0
	fi
	return 1
}

_download() {
	if _is_cmd wget; then
		DOWNLOAD_CMD="wget"
		set -- -qO "$@"
	elif _is_cmd curl; then
		DOWNLOAD_CMD="curl"
		set -- -Lso "$@"
	else
		_err_msg "ERROR: we need wget or curl to download $1"
		exit 1
	fi
	COUNT=0
	while [ "$COUNT" -lt 5 ]; do
		if "$DOWNLOAD_CMD" "$@"; then
			return 0
		fi
		_err_msg "Download failed! Trying again..."
		COUNT=$((COUNT + 1))
		sleep 5
	done
	_err_msg "ERROR: Failed to download 5 times!"
	return 1
}

_help_msg() {
	cat <<-EOF
	  USAGE: ${0##*/} /path/to/binaries_and_libraries

	  DESCRIPTION:
	  POSIX shell script wrapper for sharun that simplifies the deployment
	  of AppImages to simple oneliners. It automates detection and deployment of common
	  libraries such as GTK, Qt, OpenGL, Vulkan, Pipewire, GStreamer, etc.

	  Features:
	  - Automatic detection and forced deployment of libraries.
	  - Support for environment-based configuration to force deployment, e.g., DEPLOY_OPENGL=1
	  - Deployment of app-specific hooks, desktop entries, icons, locale data and more.
	  - Automatic patching of hardcoded paths in binaries and libraries.

	  OPTIONS / ENVIRONMENT VARIABLES:
	  ADD_HOOKS          List of hooks (colon-separated) to deploy with the application.
	  DESKTOP            Path or URL to a .desktop file to include.
	  ICON               Path or URL to an icon file to include.
	  OUTPUT_APPIMAGE    Set to 1 to turn the deployed AppDir into an AppImage.
	  DEPLOY_QT          Set to 1 to force deployment of Qt. Will determine to deploy
	                 QtWebEngine and Qml as well, these can be controlled with
	                 DEPLOY_QT_WEB_ENGINE and DEPLOY_QML. Set to 1 enable, 0 disable
					 Set QT_DIR if the system Qt directory in LIB_DIR has a different name.
	  DEPLOY_SDL          Set to 1 to force deployment of SDL.
	  DEPLOY_GTK          Set to 1 to force deployment of GTK.
	  DEPLOY_GDK          Set to 1 to force deployment of gdk-pixbuf.
	  DEPLOY_GLYCIN       Set to 1 to force deployment of Glycin.
	  DEPLOY_OPENGL       Set to 1 to force deployment of OpenGL.
	  DEPLOY_VULKAN       Set to 1 to force deployment of Vulkan.
	  DEPLOY_IMAGEMAGICK  Set to 1 to force deployment of ImageMagick.
	  DEPLOY_LIBHEIF      Set to 1 to force deployment of libheif.
	  DEPLOY_GEGL         Set to 1 to force deployment of GEGL.
	  DEPLOY_BABL         Set to 1 to force deployment of babl.
	  DEPLOY_P11KIT       Set to 1 to force deployment of p11-kit.
	  DEPLOY_PIPEWIRE     Set to 1 to force deployment of Pipewire.
	  DEPLOY_PULSE        Set to 1 to force deployment of pulseaudio.
	  DEPLOY_GSTREAMER    Set to 1 to force deployment of GStreamer. By default
	                several gstreamer plugins are removed, set DEPLOY_GSTREAMER_ALL=1
	                if you can to deploy ALL Gstreamer plugins. (Very bloated).
	  DEPLOY_LOCALE       Set to 1 to deploy locale data.
	  DEPLOY_PYTHON   Set to 1 to deploy system Python. Will remove all pycache
	                  files, set DEBLOAT_PYTHON to 0 to prevent this.

	  LIB_DIR          Set source library directory if autodetection fails.
	  NO_STRIP         Disable stripping binaries and libraries if set.
	  APPDIR           Destination AppDir (default: ./AppDir).
	  ANYLINUX_LIB     Preloads a library that unsets environment variables known to
	                   cause problems to child processes. Set to 0 to disable.
	                   Additionally you can set ANYLINUX_DO_NOT_LOAD_LIBS to a
	                   list of colon separated libraries to prevent from being
	                   dlopened, the entries support simple globbing, example:
	                     export ANYLINUX_DO_NOT_LOAD_LIBS='libpipewire-0.3.so*'
	                   Useful for applications that will try to dlopen several
	                   optional dependencies that you do not want to include.

	  ALWAYS_SOFTWARE  Set to 1 to enable. Sets several env variables to make
	                   applications use software rendering, use this option when
	                   you do not want hardware acceleration.
	                   Will fail if the application makes use of mesa during deployment.

	  PATH_MAPPING    Configures and preloads pathmap.
	                  Set this variable if the application is hardcoded to look
	                  into /usr and similar locations, example:
	                    export PATH_MAPPING='
	                      /usr/lib/myapp_libs:\${SHARUN_DIR}/lib/myapp_libs
	                      /etc/myapp.conf:\${SHARUN_DIR}/etc/myapp.conf
	                    '
	                  \${SHARUN_DIR} here must NOT expand!
	                  The braces in the variable are mandatory!

	  NOTE:
	  Several of these options get turned on automatically based on what is being deployed.

	  EXAMPLES:
	  DEPLOY_OPENGL=1 ./quick-sharun.sh /path/to/myapp
	  DESKTOP=/path/to/app.desktop ICON=/path/to/icon.png ./quick-sharun.sh /path/to/myapp
	  ADD_HOOKS="self-updater.bg.hook:fix-namespaces.hook" ./quick-sharun.sh /path/to/myapp

	  SEE ALSO:
	  sharun  (https://github.com/VHSgunzo/sharun)
	  pathmap (https://github.com/VHSgunzo/pathmap)
	EOF
	exit 1
}

_get_icon() {
	if [ -f "$DIRICON" ]; then
		return 0
	fi

	icon_name=$(awk -F'=' '/^Icon=/{print $2; exit}' "$DESKTOP_ENTRY")
	icon_name=${icon_name##*/}

	if [ "$ICON" = "DUMMY" ]; then
		if [ -z "$icon_name" ]; then
			_err_msg "ERROR: Cannot get icon name from $DESKTOP_ENTRY"
			_err_msg "Make sure it contains a valid 'Icon=' key!"
			exit 1
		fi
		_echo "* Adding dummy $icon_name icon to $APPDIR..."
		:> "$APPDIR"/"$icon_name".png
		:> "$DIRICON"
	elif [ -f "$ICON" ]; then
		_echo "* Adding $ICON to $APPDIR..."
		cp -v "$ICON" "$APPDIR"
		cp -v "$ICON" "$DIRICON"
	elif echo "$ICON" | grep -q 'http'; then
		_echo "* Downloading $ICON to $APPDIR..."
		dst=$APPDIR/${ICON##*/}
		_download "$dst" "$ICON"
		cp -v "$dst" "$DIRICON"
	elif [ -n "$ICON" ]; then
		_err_msg "$ICON is NOT a valid path!"
		exit 1
	fi

	if [ ! -f "$DIRICON" ]; then
		# try the first top level .png or .svg before searching
		set -- "$APPDIR"/*.png "$APPDIR"/*.svg
		for i do
			if [ -f "$i" ]; then
				cp -v "$i" "$DIRICON"
				return 0
			fi
		done
		set --

		# Now search deeper
		if [ -n "$icon_name" ]; then
			sizes='256x256 512x512 192x192 128x128 scalable'
			for s in $sizes; do
				set -- "$@" "$APPDIR"/share/icons/hicolor/"$s"/apps/"$icon_name"*
			done
			for s in $sizes; do
				set -- "$@" /usr/share/icons/hicolor/"$s"/apps/"$icon_name"*
			done
			for i do
				if [ -f "$i" ]; then
					case "$i" in
						*.png|*.svg)
							cp -v "$i" "$APPDIR"
							cp -v "$i" "$DIRICON"
							break
							;;
					esac
				fi
			done
			set --
		fi
	fi

	if [ ! -f "$DIRICON" ]; then
		_err_msg "ERROR: Missing '$DIRICON'!"
		_err_msg "Could not find icon listed in $DESKTOP_ENTRY either"
		_err_msg "Set ICON env variable to the location/url of the icon"
		exit 1
	fi
}

_sanity_check() {
	for d in $DEPENDENCIES; do
		_is_cmd "$d" || _err_msg "ERROR: Missing dependency '$d'!"
	done

	if ! mkdir -p "$APPDIR"/share "$APPDIR"/bin; then
		_err_msg "ERROR: Cannot create '$APPDIR' directory!"
		exit 1
	fi

	if  [ -n "$PATH_MAPPING" ] && ! echo "$PATH_MAPPING" | grep -q 'SHARUN_DIR'; then
		_err_msg 'ERROR: PATH_MAPPING must contain unexpanded ${SHARUN_DIR} variable'
		_err_msg 'Example:'
		_err_msg "'PATH_MAPPING=/etc:\${SHARUN_DIR}/etc'"
		_err_msg 'NOTE: The braces in the variable are needed!'
		exit 1
	fi

	if [ "$STRACE_MODE" = 1 ]; then
		if _is_cmd xvfb-run; then
			XVFB_CMD="xvfb-run -a --"
		else
			_err_msg "WARNING: xvfb-run was not detected on the system"
			_err_msg "xvfb-run is used with sharun for strace mode, this is needed"
			_err_msg "to find dlopened libraries as normally this script is going"
			_err_msg "to be run in a headless enviromment where the application"
			_err_msg "will fail to start and result strace mode will not be able"
			_err_msg "to find the libraries dlopened by the application"
			XVFB_CMD=""
			sleep 5
		fi
	fi

	unset LIB32
	if [ -z "$LIB_DIR" ]; then
		if [ -d "/usr/lib/$APPIMAGE_ARCH-linux-gnu" ]; then
			LIB_DIR="/usr/lib/$APPIMAGE_ARCH-linux-gnu"
		elif [ -d "/usr/lib" ]; then
			LIB_DIR="/usr/lib"
		else
			_err_msg "ERROR: there is no /usr/lib directory in this system"
			_err_msg "set the LIB_DIR variable to where you have libraries"
			exit 1
		fi
	elif [ "$LIB_DIR" = /usr/lib32 ] || [ "$LIB_DIR" = /usr/lib/i386-linux-gnu ]; then
		LIB32=1
	fi

	if [ "$LIB32" = 1 ]; then
		DST_LIB_DIR=$APPDIR/shared/lib32
		_err_msg "WARNING: 32bit deployment is experimental!"
	fi
}

# do a basic test to make sure at least the application is not totally broken
# like when libraries are missing symbols and similar stuff
_test_appimage() {
	if [ -z "$1" ]; then
		_err_msg "ERROR: Missing application to run!"
		exit 1
	elif ! _is_cmd xvfb-run; then
		_err_msg "ERROR: --test requires 'xvfb-run'!"
		exit 1
	fi

	APP=$1
	shift

	_echo "------------------------------------------------------------"
	_echo "Testing '$APP'..."
	_echo "------------------------------------------------------------"

	# Allow host vulkan for vulkan-swrast since there is no GPU in the CI
	export SHARUN_ALLOW_SYS_VKICD=1

	# since there is no fuse available in CI and userns are also broken
	# the appimage may not run if it is bigger than 400 MiB due to a restriction
	# in the uruntime, so we will have to always force it to extract and run
	export APPIMAGE_TARGET_DIR="$PWD"/_test-app
	export APPIMAGE_EXTRACT_AND_RUN=1

	xvfb-run -a -- "$APP" "$@" &
	pid=$!

	# let the app run for 12 seconds, if it exits early it means something is wrong
	COUNT=0
	while kill -0 $pid 2>/dev/null && [ "$COUNT" -lt 12 ]; do
		sleep 1
		COUNT=$((COUNT + 1))
	done

	set +e
	if kill -0 $pid 2>/dev/null; then
		_echo "------------------------------------------------------------"
		_echo "Test went OK."
		_echo "------------------------------------------------------------"
		kill $pid 2>/dev/null || :
		sleep 1
		exit 0
	else
		# process exited before timeout, something went wrong.
		wait $pid
		status=$?
		_err_msg "------------------------------------------------------------"
		_err_msg "ERROR: '$APP' failed in ${COUNT} seconds with code $status"
		_err_msg "------------------------------------------------------------"
		# wait 20 seconds before failing, this way for example if we have a Ci run
		# for x86_64 and aarch64, if one fails it does not instantly stop the other
		# and people are left wondering if the problem affects both matrix or just one
		sleep 20
		exit 1
	fi
}

# if full test is not possible lets at least check some possible issues
_simple_test_appimage() {
	log="$TMPDIR"/simple-test.log
	APP=$1
	shift

	_echo "------------------------------------------------------------"
	_echo "Doing simple test '$APP'..."
	_echo "------------------------------------------------------------"

	"$APP" "$@" 2>"$log" &
	pid=$!

	sleep 7
	kill $pid 2>/dev/null || :
	sleep 1

	test="$(cat "$log")"
	case "$test" in
		*'symbol lookup error'*|\
		*'error while loading shared libraries'*)
			>&2 echo "$test"
			_err_msg "------------------------------------------------------------"
			_err_msg "ERROR: '$APP' failed simple test!"
			_err_msg "------------------------------------------------------------"
			sleep 20
			exit 1
			;;
	esac

	_echo "------------------------------------------------------------"
	_echo "Test went OK."
	_echo "------------------------------------------------------------"
	exit 0
}

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

_remove_empty_dirs() {
	find "$1" -type d \
	  -exec rmdir -p --ignore-fail-on-non-empty {} + 2>/dev/null || true
}

# skip non executable binaries and .node binaries
# these are actually libraries and cannot be wrapped with sharun
_is_deployable_binary() {
	if [ -x "$1" ]; then
		case "$1" in
			*.node) :;;
			*) return 0;;
		esac
	fi
	return 1
}

_determine_what_to_deploy() {
	for bin do
		# ignore flags
		case "$bin" in
			--) break   ;;
			-*) continue;;
		esac

		if [ ! -e "$bin" ]; then
			_err_msg "'$bin' is NOT present!"
			exit 1
		fi

		# if the argument is a directory save it to later it copy it
		if [ -d "$bin" ]; then
			ADD_DIR="
				$ADD_DIR
				$bin
			"
		elif [ -x "$bin" ]; then
			# some apps may dlopen pulseaudio instead of linking directly
			if grep -aoq -m 1 'libpulse.so' "$bin"; then
				DEPLOY_PULSE=${DEPLOY_PULSE:-1}
			fi
			if grep -aoq -m 1 'disable-gpu-sandbox' "$bin" \
			  && grep -aoq -m 1 'no-zygote-sandbox' "$bin"; then
				DEPLOY_ELECTRON=${DEPLOY_ELECTRON:-1}
				ELECTRON_BIN=$(readlink -f "$bin")
			fi
		fi

		# check if what we are doing to deploy is not fucking broken
		if _is_elf "$bin" && ldd "$bin" | grep "not found"; then
			_err_msg "$bin is missing libraries! Aborting..."
			exit 1
		fi

		NEEDED_LIBS="$(ldd "$bin" 2>/dev/null | awk '{print $3}') $NEEDED_LIBS"

		# bin may be a shared library, in that case add it as well
		case "$bin" in
			*.so*) NEEDED_LIBS="$bin $NEEDED_LIBS";;
		esac

		# check linked libraries and enable each mode accordingly
		for lib in $NEEDED_LIBS; do
			case "$lib" in
				*libQt5Core.so*)
					DEPLOY_QT=${DEPLOY_QT:-1}
					QT_DIR=${QT_DIR:-qt5}
					;;
				*libQt6Core.so*)
					DEPLOY_QT=${DEPLOY_QT:-1}
					QT_DIR=${QT_DIR:-qt6}
					;;
				*libQt*Qml*.so*)
					DEPLOY_QML=${DEPLOY_QML:-1}
					;;
				*libQt*WebEngineCore.so*)
					DEPLOY_QT_WEB_ENGINE=${DEPLOY_QT_WEB_ENGINE:-1}
					DEPLOY_ELECTRON=${DEPLOY_ELECTRON:-1}
					;;
				*libgtk-3*.so*)
					DEPLOY_GTK=${DEPLOY_GTK:-1}
					GTK_DIR=gtk-3.0
					;;
				*libgtk-4*.so*)
					DEPLOY_GTK=${DEPLOY_GTK:-1}
					GTK_DIR=gtk-4.0
					;;
				*libgdk_pixbuf*.so*)
					DEPLOY_GDK=${DEPLOY_GDK:-1}
					;;
				*libglycin*.so*)
					DEPLOY_GLYCIN=${DEPLOY_GLYCIN:-1}
					;;
				*libwebkit*gtk*.so*)
					DEPLOY_WEBKIT2GTK=${DEPLOY_WEBKIT2GTK:-1}
					;;
				*libsoup-*.so*)
					DEPLOY_GLIB_NETWORKING=${DEPLOY_GLIB_NETWORKING:-1}
					;;
				*libSDL*.so*)
					DEPLOY_SDL=${DEPLOY_SDL:-1}
					;;
				*libflutter*linux*.so*)
					DEPLOY_FLUTTER=${DEPLOY_FLUTTER:-1}
					FLUTTER_LIB=$lib
					;;
				*libpipewire*.so*)
					DEPLOY_PIPEWIRE=${DEPLOY_PIPEWIRE:-1}
					;;
				*libgstreamer*.so*)
					DEPLOY_GSTREAMER=${DEPLOY_GSTREAMER:-1}
					;;
				*libMagick*.so*)
					DEPLOY_IMAGEMAGICK=${DEPLOY_IMAGEMAGICK:-1}
					;;
				*libImlib2.so*)
					DEPLOY_IMLIB2=${DEPLOY_IMLIB2:-1}
					;;
				*libgegl*.so*)
					DEPLOY_GEGL=${DEPLOY_GEGL:-1}
					;;
				*libbabl*.so*)
					DEPLOY_BABL=${DEPLOY_BABL:-1}
					;;
				*libheif.so*)
					DEPLOY_LIBHEIF=${DEPLOY_LIBHEIF:-1}
					;;
				*libp11-kit.so*)
					DEPLOY_P11KIT=${DEPLOY_P11KIT:-1}
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
	# gconv is always deployed, removing it only saves ~30 KiB
	# in the final appimage size and not worth the hassle
	# It also causes hard to spot issues when needed and not present
	#
	# https://github.com/pkgforge-dev/Dolphin-emu-AppImage/issues/20
	# https://github.com/pkgforge-dev/Anylinux-AppImages/pull/410
	#
	if [ -d "$LIB_DIR"/gconv ]; then
		_echo "* Deploying minimal gconv"
		set -- "$@" \
			"$LIB_DIR"/gconv/UTF*.so*     \
			"$LIB_DIR"/gconv/ANSI*.so*    \
			"$LIB_DIR"/gconv/CP*.so*      \
			"$LIB_DIR"/gconv/LATIN*.so*   \
			"$LIB_DIR"/gconv/UNICODE*.so* \
			"$LIB_DIR"/gconv/ISO8859*.so*
	fi
	if [ "$ALWAYS_SOFTWARE" = 1 ]; then
		DEPLOY_OPENGL=0
		DEPLOY_VULKAN=0
		echo 'GSK_RENDERER=cairo'        >> "$APPENV"
		echo 'GDK_DISABLE=gl,vulkan'     >> "$APPENV"
		echo 'GDK_GL=disable'            >> "$APPENV"
		echo 'QT_QUICK_BACKEND=software' >> "$APPENV"
		export GSK_RENDERER=cairo
		export GDK_DISABLE=gl,vulkan
		export GDK_GL=disable
		export QT_QUICK_BACKEND=software

		ANYLINUX_DO_NOT_LOAD_LIBS="libgallium-*:libvulkan*:libGLX_mesa.so*:libGLX_indirect.so*${ANYLINUX_DO_NOT_LOAD_LIBS:+:$ANYLINUX_DO_NOT_LOAD_LIBS}"
	fi
	if [ "$DEPLOY_PYTHON" = 1 ]; then
		_echo "* Deploying system python"
	fi
	if [ "$DEPLOY_QT" = 1 ]; then
		DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}

		_echo "* Deploying $QT_DIR"

		if [ -d "$QT_LOCATION" ]; then
			plugindir="$QT_LOCATION"/plugins
		else
			# some distros have a qt dir rather than qt6 or qt5 dir
			if [ ! -d "$LIB_DIR"/"$QT_DIR" ]; then
				QT_DIR=qt
			fi
			plugindir="$LIB_DIR"/"$QT_DIR"/plugins
		fi

		for lib in $NEEDED_LIBS; do
			case "$lib" in
				*libQt*Gui.so*)
					# terrible hack to prevent partial gtk deployment
					# see: https://github.com/VHSgunzo/sharun/issues/91
					p="$plugindir"/platformthemes/libqgtk3.so
					if [ "$DEPLOY_GTK" != 1 ] \
					  && [ -n "$CI" ] && [ -w "$p" ]; then
						mv "$p" "$TMPDIR"
					fi
					set -- "$@" \
						"$plugindir"/imageformats/* \
						"$plugindir"/iconengines/*  \
						"$plugindir"/styles/*       \
						"$plugindir"/platform*/*    \
						"$plugindir"/wayland-*/*    \
						"$plugindir"/xcbglintegrations/*
					;;
				*libQt*Network.so*)
					set -- "$@" \
						"$plugindir"/tls/* \
						"$plugindir"/bearer/*
					;;
				*libQt*Sql.so*)
					set -- "$@" "$plugindir"/sqldrivers/*
					;;
				*libQt*Multimedia.so*)
					set -- "$@" "$plugindir"/multimedia/*
					;;
				*libQt*PrintSupport*)
					set -- "$@" "$plugindir"/printsupport/*
					;;
				*libQt*Positioning.so*)
					set -- "$@" "$plugindir"/position/*
					;;
			esac
		done

		if [ "$DEPLOY_QT_WEB_ENGINE" = 1 ]; then
			if ! enginebin=$(find "${QT_LOCATION:-$LIB_DIR}" -type f \
			  -name 'QtWebEngineProcess' -print -quit 2>/dev/null); then
				_err_msg "Cannot find QtWebEngineProcess!"
				exit 1
			fi
			set -- "$@" "$enginebin"
		fi

		if [ "$DEPLOY_QML" = 1 ]; then
			_echo "* Deploying qml"
			qmldir="${QT_LOCATION:-$LIB_DIR/$QT_DIR}"/qml
			ADD_DIR="
				$ADD_DIR
				$qmldir
			"
		fi
	fi
	if [ "$DEPLOY_GTK" = 1 ]; then
		_echo "* Deploying $GTK_DIR"
		DEPLOY_GDK=${DEPLOY_GDK:-1}
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
		set -- "$@" \
			"$LIB_DIR"/"$GTK_DIR"/*/immodules/*   \
			"$LIB_DIR"/gvfs/libgvfscommon.so      \
			"$LIB_DIR"/gio/modules/libgvfsdbus.so \
			"$LIB_DIR"/gio/modules/libdconfsettings.so

		case "$GTK_DIR" in
			*4*)
				DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
				echo 'GSETTINGS_BACKEND=keyfile' >> "$APPENV"
				;;
		esac

		if [ "$DEPLOY_WEBKIT2GTK" = 1 ]; then
			_echo "* Deploying webkit2gtk"
			DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
			DEPLOY_P11KIT=${DEPLOY_P11KIT:-1}
			DEPLOY_GLIB_NETWORKING=${DEPLOY_GLIB_NETWORKING:-1}
			set -- "$@" "$LIB_DIR"/libnss_mdns*minimal.so*
		fi

		if [ "$DEPLOY_GLIB_NETWORKING" = 1 ]; then
			_echo "* Deploying Glib-Netwroking"
			DEPLOY_P11KIT=${DEPLOY_P11KIT:-1}
			set -- "$@" \
				"$LIB_DIR"/gio/modules/libgiognutls.so   \
				"$LIB_DIR"/gio/modules/libgiolibproxy.so \
				"$LIB_DIR"/gio/modules/libgiognomeproxy.so
		fi

		if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
			set -- "$@" "$LIB_DIR"/libgirepository*.so*
		fi
	fi
	if [ "$DEPLOY_GDK" = 1 ]; then
		_echo "* Deploying gdk-pixbuf"
		gdkdir="$(echo "$LIB_DIR"/gdk-pixbuf-*/*/loaders)"

		set -- "$@" "$gdkdir"/*svg*.so*
		for lib in $NEEDED_LIBS; do
			case "$lib" in
				*libjxl.so*)  set -- "$@" "$gdkdir"/*jxl*.so* ;;
				*libavif.so*) set -- "$@" "$gdkdir"/*avif*.so*;;
				*libheif.so*) set -- "$@" "$gdkdir"/*heif*.so*;;
			esac
		done
	fi
	if [ "$DEPLOY_SDL" = 1 ]; then
		_echo "* Deploying SDL"
		DEPLOY_PULSE=${DEPLOY_PULSE:-1}
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
		set -- "$@" \
			"$LIB_DIR"/libSDL*.so*   \
			"$LIB_DIR"/libudev.so*   \
			"$LIB_DIR"/libusb-1*.so* \
			"$LIB_DIR"/libdecor*.so*
	fi
	if [ "$DEPLOY_GLYCIN" = 1 ]; then
		_echo "* Deploying glycin"
		set -- "$@" "$LIB_DIR"/glycin-loaders/*/*
		_add_bwrap_wrapper
	fi
	if [ "$DEPLOY_FLUTTER" = 1 ]; then
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
		DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
	fi
	if [ "$DEPLOY_ELECTRON" = 1 ] || [ "$DEPLOY_CHROMIUM" = 1 ]; then
		_echo "* Deploying electron/chromium"
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
		DEPLOY_P11KIT=${DEPLOY_P11KIT:-1}
		DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
		DEPLOY_VULKAN=${DEPLOY_VULKAN:-1}
		set -- "$@" \
			"$LIB_DIR"/libva.so*          \
			"$LIB_DIR"/libva-drm.so*      \
			"$LIB_DIR"/libpci.so*         \
			"$LIB_DIR"/libnss*.so*        \
			"$LIB_DIR"/libsoftokn3.so*    \
			"$LIB_DIR"/libfreeblpriv3.so* \
			"$LIB_DIR"/libnss_mdns*_minimal.so*
		# electron has a resources directory that may have binaries
		d="${ELECTRON_BIN%/*}"/resources
		if [ -d "$d" ]; then
			for f in $(find "$d" -type f ! -name '*.so*'); do
				if _is_deployable_binary "$f"; then
					set -- "$@" "$f"
				fi
			done
		fi
	fi
	if [ "$DEPLOY_OPENGL" = 1 ] || [ "$DEPLOY_VULKAN" = 1 ]; then
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
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
			ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}vulkan-check.src.hook"
		fi
	fi
	if [ "$DEPLOY_PIPEWIRE" = 1 ]; then
		_echo "* Deploying pipewire"
		DEPLOY_PULSE=${DEPLOY_PULSE:-1}
		set -- "$@" \
			"$LIB_DIR"/pipewire-*/* \
			"$LIB_DIR"/spa-*/*      \
			"$LIB_DIR"/spa-*/*/*    \
			"$LIB_DIR"/alsa-lib/*pipewire*.so*
	fi
	if [ "$DEPLOY_PULSE" = 1 ]; then
		set -- "$@" \
			"$LIB_DIR"/libpulse.so* \
			"$LIB_DIR"/alsa-lib/libasound*pulse*.so*
	fi
	if [ "$DEPLOY_GSTREAMER_ALL" = 1 ] || [ "$DEPLOY_GSTREAMER" = 1 ]; then
		GST_DIR=$(echo "$LIB_DIR"/gstreamer-*)
		if [ "$DEPLOY_GSTREAMER_ALL" = 1 ]; then
			_echo "* Deploying all gstreamer"
		elif [ "$DEPLOY_GSTREAMER" = 1 ]; then
			_echo "* Deploying minimal gstreamer"

			# we need to delete the plugins on the host because copying
			# the libs to a different place and pointing to that dir
			# does not work, all the plugins still end up being deployed

			# check we have write access to the directory
			# and make sure we are in a container since someone could
			# run this script in their personal PC with elevated rights...
			if [ -w "$GST_DIR" ] && [ -n "$CI" ]; then
				# gstreamer has a lot of plugins
				# remove the following since they pull a lot of deps:

				# has a dependency to libicudata (30 MIB lib)
				rm -f "$GST_DIR"/*gstladspa*
				# gstx265 has a dependency to libx265, massive library
				rm -f "$GST_DIR"/*gstx265*
				# gstsvt-hevc video encoder, rarely needed
				rm -f "$GST_DIR"/*gstsvthevcenc*
				# Apparently this is only useful in windows?
				rm -f "$GST_DIR"/*gstopenmpt*
				# Never heard of this format before lol
				rm -f "$GST_DIR"/*gstopenexr*
				# used to scan barcodes
				rm -f "$GST_DIR"/*gstzxing*
				# dvd playback
				rm -f "$GST_DIR"/*gstdvdspu*
				rm -f "$GST_DIR"/*gstresindvd*
				# only needed for recording with some capture card
				rm -f "$GST_DIR"/*gstdecklink*
				# mpeg2 video encoder
				rm -f "$GST_DIR"/*gstmpeg2enc*
				# wtf is this?
				rm -f "$GST_DIR"/*gstmplex*
				# gstreamer already has png and svg plugins
				# so it is unlikely that we also need gdkpixbuf
				rm -f "$GST_DIR"/*libgstgdkpixbuf*
				# Apprently this can be used by some video players
				# but I cannot find a single one that uses it lol
				rm -f "$GST_DIR"/*libgstcairo*
				# text to speech
				rm -f "$GST_DIR"/*libgstfestival*
				# gstvulkan pulls vulkan, remove unless vulkan is deployed
				if [ "$DEPLOY_VULKAN" != 1 ]; then
					rm -f "$GST_DIR"/*gstvulkan*
				fi
				# also make sure to delete gstreamer plugins
				# that are missing libraries, otherwise they
				# will load libraries from the host and crash
				for plugin in "$GST_DIR"/*.so*; do
					if ldd "$plugin" | grep -q 'not found'; then
						rm -f "$plugin"
					fi
				done
			fi
		fi
		set -- "$@" \
			"$GST_DIR"/*.so*      \
			"$GST_DIR"/gst*helper \
			"$GST_DIR"/gst*scanner
		# On ubuntu and alpine the gstreamer binaries are on a different dir
		if [ ! -f "$GST_DIR"/gst-plugin-scanner ]; then
			gst_bin_path=$(find /usr/lib* -type f \
				-name 'gst-plugin-scanner' -print -quit)
			gst_bin_dir=${gst_bin_path%/*}
			set -- "$@" \
				"$gst_bin_dir"/gst*scanner \
				"$gst_bin_dir"/gst*helper
		fi
	fi
	if [ "$DEPLOY_IMAGEMAGICK" = 1 ]; then
		_echo "* Deploying ImageMagick"
		set -- "$@" "$LIB_DIR"/libMagick*.so*
		if b=$(command -v magick);  then set -- "$@" "$b"; fi
		if b=$(command -v convert); then set -- "$@" "$b"; fi
		# imagemagick optionally requires potrace to convert png to svg
		if b=$(command -v potrace); then set -- "$@" "$b"; fi

		magickdir=$(echo "$LIB_DIR"/ImageMagick*)
		ADD_DIR="
			$ADD_DIR
			$magickdir
		"
	fi
	if [ "$DEPLOY_IMLIB2" = 1 ]; then
		_echo "* Deploying Imlib2"
		set -- "$@" \
			"$LIB_DIR"/libImlib2.so*    \
			"$LIB_DIR"/imlib2/filters/* \
			"$LIB_DIR"/imlib2/loaders/*
	fi
	if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
		if pythonbin=$(command -v python); then
			set -- "$@" "$pythonbin"*
		elif pythonbin=$(command -v python3); then
			set -- "$@" "$pythonbin"*
		fi
	fi
	if [ "$DEPLOY_GEGL" = 1 ]; then
		_echo "* Deploying gegl"
		set -- "$@" "$LIB_DIR"/gegl-*/*
		if b=$(command -v gegl);        then set -- "$@" "$b"; fi
		if b=$(command -v gegl-imgcmp); then set -- "$@" "$b"; fi
	fi
	if [ "$DEPLOY_BABL" = 1 ]; then
		_echo "* Deploying babl"
		set -- "$@" "$LIB_DIR"/babl-*/*
	fi
	if [ "$DEPLOY_LIBHEIF" = 1 ]; then
		_echo "* Deploying libheif"

		if [ -d "$LIB_DIR"/libheif/plugins ]; then
			heifdir="$LIB_DIR"/libheif/plugins
		elif [ -d "$LIB_DIR"/libheif ]; then
			heifdir="$LIB_DIR"/libheif
		fi

		# do not add the ffmpeg plugin by default
		# only do it if libavcodec is already required
		for p in "$heifdir"/*; do
			case "$p" in
				*ffmpeg*) continue;;
				*)        set -- "$@" "$p";;
			esac
		done
		for lib in $NEEDED_LIBS; do
			case "$lib" in
				*libavcodec.so*)  set -- "$@" "$heifdir"/*ffmpeg*.so*;;
			esac
		done
	fi
	if [ "$DEPLOY_P11KIT" = 1 ]; then
		_echo "* Deploying p11kit"
		set -- "$@" "$LIB_DIR"/pkcs11/*
	fi
	if [ "$DEPLOY_DOTNET" = 1 ]; then
		_echo "* Deploying dotnet"
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
		if [ -z "$DOTNET_DIR" ]; then
			if [ -d /usr/lib/dotnet ]; then
				DOTNET_DIR=/usr/lib/dotnet
			elif [ -d /usr/share/dotnet ]; then
				DOTNET_DIR=/usr/share/dotnet
			fi
		fi
		if [ ! -d "$DOTNET_DIR" ]; then
			_err_msg "Cannot find dotnet installation, searched for"
			_err_msg "/usr/lib/dotnet and /usr/share/dotnet"
			_err_msg "Set DOTNET_DIR variable if it is somewhere else"
			exit 1
		fi
		set -- "$@" \
			"$(command -v dotnet)"  \
			$(find "$DOTNET_DIR"/shared -type f -name '*.so*' -print)
		cp -r "$DOTNET_DIR"/shared "$APPDIR"/bin
		cp -r "$DOTNET_DIR"/host   "$APPDIR"/bin
		echo 'DOTNET_ROOT=${SHARUN_DIR}/bin' >> "$APPENV"
	fi
	# these are needed by several toolkits
	if [ "$DEPLOY_COMMON_LIBS" = 1 ]; then
		set -- "$@" \
			"$LIB_DIR"/libXi.so*             \
			"$LIB_DIR"/libXcursor.so*        \
			"$LIB_DIR"/libxcb-dri*.so*       \
			"$LIB_DIR"/libxcb-glx.so*        \
			"$LIB_DIR"/libxcb-ewmh.so*       \
			"$LIB_DIR"/libxcb-icccm.so*      \
			"$LIB_DIR"/libxkbcommon.so*      \
			"$LIB_DIR"/libxkbcommon-x11.so*  \
			"$LIB_DIR"/libXext.so*           \
			"$LIB_DIR"/libXfixes.so*         \
			"$LIB_DIR"/libXrandr.so*         \
			"$LIB_DIR"/libXss.so*            \
			"$LIB_DIR"/libX11-xcb.so*        \
			"$LIB_DIR"/libwayland-egl.so*    \
			"$LIB_DIR"/libwayland-cursor.so* \
			"$LIB_DIR"/libwayland-client.so*
	fi

	# also pass all the files in the directories to add to lib4bin
	# so we deploy any possible library and binary in the directories
	# later on the binaries in lib will be wrapped with sharun
	if [ -n "$ADD_DIR" ]; then
		_echo "* Deploying directories:"
		while read -r d; do
			if [ -d "$d" ]; then
				_echo " - $d"
				for f in \
					"$d"/*        \
					"$d"/*/*      \
					"$d"/*/*/*    \
					"$d"/*/*/*/*  \
					"$d"/*/*/*/*/*; do

					if [ ! -f "$f" ]; then
						continue
					fi

					case "$f" in
						*.so*)
							set -- "$@" "$f"
							;;
						*)
							if _is_deployable_binary "$f"; then
								set -- "$@" "$f"
							fi
							;;
					esac
				done
			fi
		done <<-EOF
		$ADD_DIR
		EOF
	fi

	TO_DEPLOY_ARRAY=$(_save_array "$@")
}

_get_sharun() {
	if [ ! -x "$TMPDIR"/sharun-aio ]; then
		_echo "Downloading sharun..."
		_download "$TMPDIR"/sharun-aio "$SHARUN_LINK"
		if head -c 4 "$TMPDIR"/sharun-aio | grep -qa 'ELF'; then
			chmod +x "$TMPDIR"/sharun-aio
		else
			_err_msg "ERROR: What was downloaded is not sharun!"
			_err_msg "This is usually caused by network issues"
			exit 1
		fi
	fi
}

_deploy_libs() {
	# when strace args are given sharun will only use them when
	# you pass a single binary to it that is:
	# 'sharun-aio l /path/to/bin -- google.com' works (site is opened)
	# 'sharun-aio l /path/to/lib /path/to/bin -- google.com' does not work
	if [ "$STRACE_ARGS_PROVIDED" = 1 ]; then
		$XVFB_CMD "$TMPDIR"/sharun-aio l "$@"
	fi

	# now merge the deployment array
	ARRAY=$(_save_array "$@")
	eval set -- "$TO_DEPLOY_ARRAY" "$ARRAY"

	$XVFB_CMD "$TMPDIR"/sharun-aio l "$@"
}

_handle_bins_scripts() {
	# check for gstreamer binaries these need to be in the gstreamer libdir
	# since sharun will set the following vars to that location:
	# GST_PLUGIN_PATH
	# GST_PLUGIN_SYSTEM_PATH
	# GST_PLUGIN_SYSTEM_PATH_1_0
	# GST_PLUGIN_SCANNER
	set -- "$DST_LIB_DIR"/gstreamer-*
	if [ -d "$1" ]; then
		gstlibdir="$1"
		set -- "$APPDIR"/shared/bin/gst-*
		for bin do
			if [ -f "$bin" ]; then
				ln "$APPDIR"/sharun "$gstlibdir"/"${bin##*/}"
			fi
		done
	fi

	if [ "$DEPLOY_QT_WEB_ENGINE" = 1 ]; then
		src_res=/usr/share/$QT_DIR/resources
		dst_res=$DST_LIB_DIR/$QT_DIR/resources
		if [ -d "$src_res" ] && [ ! -d "$dst_res" ]; then
			mkdir -p "${dst_res%/*}"
			cp -r "$src_res" "$dst_res"
		fi
	fi

	# handle shell scripts
	set -- "$APPDIR"/bin/*
	for s do
		if ! head -c 20 "$s" | grep -q '#!.*sh'; then
			continue
		fi
		# some very very old distros do not have /usr/bin/env
		# so it is better to always use #!/bin/sh shebang instead
		sed -i -e 's|/usr/bin/env sh|/bin/sh|' "$s"

		# patch away hardcoded paths from dotnet scripts
		if grep -q 'dotnet' "$s"; then
			sed -i -e '/^#/!s|/usr|"$APPDIR"|g' "$s"
		fi
	done

}

_add_anylinux_lib() {
	cfile=$APPDIR/.anylinux.c
	target=$DST_LIB_DIR/anylinux.so

	if [ "$ANYLINUX_LIB" != 1 ]; then
		return 0
	elif [ ! -f "$target" ]; then
		_echo "* Building anylinux.so..."
		_download "$cfile" "$ANYLINUX_LIB_SOURCE"

		set -- -shared -fPIC -O2 "$cfile" -o "$target"
		if [ "$LIB32" = 1 ]; then
			set -- -m32 "$@"
		fi
		cc "$@"
	fi

	if ! grep -q 'anylinux.so' "$APPDIR"/.preload 2>/dev/null; then
		echo "anylinux.so" >> "$APPDIR"/.preload
	fi

	# remove xdg-open wrapper not needed when the lib is in use
	# we still need to have a wrapper for gio-launch-desktop though
	if [ -f "$APPDIR"/bin/gio-launch-desktop ]; then
		rm -f "$APPDIR"/bin/gio-launch-desktop
		cat <<-'EOF' > "$APPDIR"/bin/gio-launch-desktop
		#!/bin/sh
		export GIO_LAUNCHED_DESKTOP_FILE_PID=$$
		exec "$@"
		EOF
		chmod +x "$APPDIR"/bin/gio-launch-desktop
	fi
	rm -f "$APPDIR"/bin/xdg-open
	_echo "* anylinux.so successfully added!"
}

_add_gtk_class_fix() {
	cfile=$APPDIR/.gtk-class-fix.c
	target=$DST_LIB_DIR/gtk-class-fix.so

	if [ "$GTK_CLASS_FIX" != 1 ]; then
		return 0
	elif [ ! -f "$DESKTOP_ENTRY" ]; then
		_err_msg "ERROR: Using GTK_CLASS_FIX requires a desktop entry in $APPDIR"
		exit 1
	fi

	_echo "* Building gtk-class-fix.so"
	_download "$cfile" "$GTK_CLASS_FIX_SOURCE"

	set -- -shared -fPIC -O2 "$cfile" -o "$target" -ldl
	if [ "$LIB32" = 1 ]; then
		set -- -m32 "$@"
	fi
	cc "$@"

	# _check_window_class will make sure StartupWMClass is added to desktop entry
	# for this to work in wayland, the class needs to have one dot in its name
	if ! grep -q 'StartupWMClass=.*\..*' "$DESKTOP_ENTRY"; then
		sed -i -e 's/\(StartupWMClass=.*\)/\1.anylinux/' "$DESKTOP_ENTRY"
	fi

	class=$(awk -F'=| ' '/^StartupWMClass=/{print $2; exit}' "$DESKTOP_ENTRY")

	echo "GTK_WINDOW_CLASS=$class"  >> "$APPDIR"/.env
	echo "gtk-class-fix.so"         >> "$APPDIR"/.preload
	_echo "* gtk-class-fix.so successfully added!"
}

_check_always_software() {
	if [ "$ALWAYS_SOFTWARE" != 1 ]; then
		return 0
	fi
	set -- "$DST_LIB_DIR"/libgallium-*.so*
	if [ -f "$1" ]; then
		_err_msg "ALWAYS_SOFTWARE was enabled but mesa was deployed!"
		_err_msg "Likely this application needs hardware acceleration."
		_err_msg "Do not use this option or find a way to make sure"
		_err_msg "the application does not dlopen mesa when running!"
		exit 1
	fi
}

_add_p11kit_cert_hook() {
	cert_check="$APPDIR"/bin/check-ca-certs.src.hook
	if [ -f "$cert_check" ]; then
		return 0
	fi

	cat <<-'EOF' > "$cert_check"
	#!/bin/sh

	_possible_certs='
	  /etc/ssl/certs/ca-certificates.crt
	  /etc/pki/tls/cert.pem
	  /etc/pki/tls/cacert.pem
	  /etc/ssl/cert.pem
	  /var/lib/ca-certificates/ca-bundle.pem
	'

	for c in $_possible_certs; do
	    if [ -f "$c" ]; then
	        break
	    fi
	done

	if [ -f "$c" ]; then
	    # With p11kit we have to make a symlink in /tmp because the meme
	    # library does not check any of these variables set by sharun:
	    #
	    # REQUESTS_CA_BUNDLE
	    # CURL_CA_BUNDLE
	    # SSL_CERT_FILE
	    #
	    # So we had to patch it to a path in /tmp and now symlink to the
	    # found certificate at runtime...
	    _host_cert=/tmp/.___host-certs/ca-certificates.crt
	    if [ -d "$APPDIR"/lib/pkcs11 ] && [ ! -f "$_host_cert" ]; then
	        mkdir -p /tmp/.___host-certs || :
	        ln -sfn "$c" "$_host_cert" || :
	    fi
	fi
	EOF
	chmod +x "$cert_check"
}

_map_paths_ld_preload_open() {
	# format new line entries in PATH_MAPPING into comma separated
	# entries for sharun, pathmap accepts new lines in the variable
	# but the .env library used by sharun does not
	if [ -n "$PATH_MAPPING" ] && [ ! -f "$DST_LIB_DIR"/path-mapping.so ]; then
		PATH_MAPPING=$(echo "$PATH_MAPPING"   \
			| tr '\n' ',' | tr -d '[:space:]' | sed 's/,*$//; s/^,*//'
		)

		deps="git make"
		if ! _is_cmd $deps; then
			_err_msg "ERROR: Using PATH_MAPPING requires $deps"
			exit 1
		fi

		_echo "* Building $LD_PRELOAD_OPEN..."

		rm -rf "$TMPDIR"/ld-preload-open
		git clone "$LD_PRELOAD_OPEN" "$TMPDIR"/ld-preload-open && (
			cd "$TMPDIR"/ld-preload-open
			make all
		)

		mv -v "$TMPDIR"/ld-preload-open/path-mapping.so "$DST_LIB_DIR"
		echo "path-mapping.so" >> "$APPDIR"/.preload
		echo "PATH_MAPPING=$PATH_MAPPING" >> "$APPENV"
		_echo "* PATH_MAPPING successfully added!"
		echo ""
	fi
}

_map_paths_binary_patch() {
	if [ "$PATH_MAPPING_HARDCODED" = 1 ]; then
		set -- "$APPDIR"/shared/bin/*
		for bin do
			_patch_away_usr_bin_dir   "$bin"
			_patch_away_usr_lib_dir   "$bin"
			_patch_away_usr_share_dir "$bin"
		done
	elif [ -n "$PATH_MAPPING_HARDCODED" ]; then
		set -f
		set -- $PATH_MAPPING_HARDCODED
		set +f
		_echo "* Patching files listed in PATH_MAPPING_HARDCODED..."
		# only search for files to patch in the lib and bin dirs
		path1="$APPDIR"/shared/bin
		path2=$DST_LIB_DIR
		for f do
			file=$(find -L "$path1"/ "$path2"/ -type f -name "$f")
			if [ -n "$file" ]; then
				for found in $file; do
					_patch_away_usr_bin_dir   "$found" || :
					_patch_away_usr_lib_dir   "$found" || :
					_patch_away_usr_share_dir "$found" || :
				done
			else
				_err_msg "ERROR: Could not find $f in $APPDIR"
				exit 1
			fi
		done
	fi
}

_deploy_datadir() {
	if [ "$DEPLOY_DATADIR" = 1 ]; then
		# find if there is a datadir that matches bundled binary name
		set -- "$APPDIR"/bin/*
		for bin do
			if [ ! -f "$bin" ] || [ ! -x "$bin" ]; then
				continue
			fi
			bin="${bin##*/}"

			# skip already handled cases
			case "$bin" in
				dotnet) continue;;
			esac

			for datadir in /usr/local/share/* /usr/share/*; do
				if echo "${datadir##*/}" | grep -qi "$bin"; then
					_echo "* Adding datadir $datadir..."
					# fallback to cp -r if cp -Lr fails
					# due to broken symlinks in datadir
					cp -Lr "$datadir" "$APPDIR"/share \
					  || cp -r "$datadir" "$APPDIR"/share
					break
				fi
			done
		done

		set -- "$APPDIR"/*.desktop

		# Some apps have a datadir that does not match the binary name
		# in that case we need to get it by reading the binary
		if [ -f "$1" ]; then

			bin=$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$1")
			bin=${bin##*/}
			possible_dirs=$(
				strings "$APPDIR"/shared/bin/"$bin" \
				  | grep -v '[;:,.(){}?<>*]' \
				  | tr '/' '\n'
			)

			for datadir in $possible_dirs; do
				# skip dirs not wanted or handled by sharun
				case "$datadir" in
					alsa        |\
					applications|\
					awk         |\
					bash        |\
					dbus-1      |\
					defaults    |\
					doc         |\
					dotnet      |\
					et          |\
					factory     |\
					file        |\
					fish        |\
					fonts       |\
					fontconfig  |\
					git         |\
					glvnd       |\
					gvfs        |\
					help        |\
					i18n        |\
					icons       |\
					info        |\
					java        |\
					locale      |\
					man         |\
					misc        |\
					model       |\
					pipewire    |\
					pixmaps     |\
					qt          |\
					qt4         |\
					qt5         |\
					qt6         |\
					qt7         |\
					ss          |\
					systemd     |\
					themes      |\
					vala        |\
					vulkan      |\
					wayland     |\
					WebP        |\
					X11         |\
					xcb         |\
					zoneinfo    |\
					zsh         )
						continue
						;;
				esac

				for path in /usr/local/share /usr/share; do

					src_datadir="$path"/"$datadir"
					dst_datadir="$APPDIR"/share/"$datadir"

					if [ -d "$src_datadir" ] \
						&& [ ! -d  "$dst_datadir" ]; then
						_echo "* Adding datadir $src_datadir..."
						# cp can fail here if src_datadir contains broken links
						if ! cp -Lr "$src_datadir" "$dst_datadir"; then
							rm -rf "$dst_datadir"
							cp -r "$src_datadir" "$dst_datadir"
						fi
						break
					fi
				done
			done
		fi

		# try to find and deploy a dbus service that matches .desktop
		desktopname="${1%.desktop}"
		desktopname="${desktopname##*/}"
		dst_dbus_dir="$APPDIR"/share/dbus-1/services
		for f in /usr/share/dbus-1/services/*; do
			case "${f##*/}" in
				*"$desktopname"*)
					_echo "* Adding dbus service $f"
					mkdir -p "$dst_dbus_dir"
					cp -L "$f" "$dst_dbus_dir"
					;;
			esac
		done
		sed -i -e 's|/usr/.*/||g' "$dst_dbus_dir"/* 2>/dev/null || :
	fi
}

_deploy_locale() {
	if [ ! -d /usr/share/locale ]; then
		_err_msg "This system does not have /usr/share/locale"
		return 0
	fi

	set -- "$APPDIR"/shared/bin/*
	for bin do
		if grep -Eaoq -m 1 "/usr/share/locale" "$bin"; then
			DEPLOY_LOCALE=1
			_patch_away_usr_share_dir "$bin" || true
		fi
	done
	set --

	if [ "$DEPLOY_LOCALE" = 1 ]; then
		_echo "* Adding locales..."
		cp -r "$LOCALE_DIR" "$APPDIR"/share
		if [ "$DEBLOAT_LOCALE" = 1 ]; then
			_echo "* Removing unneeded locales..."
			for f in "$APPDIR"/shared/bin/* "$APPDIR"/bin/*; do
				if [ -f "$f" ]; then
					f=${f##*/}
					set -- "$@" ! -name "*$f*"
				fi
			done
			find "$APPDIR"/share/locale "$@" \( -type f -o -type l \) -delete
			_remove_empty_dirs "$APPDIR"/share/locale
		fi
		echo ""
	fi
}

_get_desktop() {
	DESKTOP_ENTRY=$(echo "$APPDIR"/*.desktop)
	if [ -f "$DESKTOP_ENTRY" ]; then
		return 0
	fi

	if [ "$DESKTOP" = "DUMMY" ]; then
		if [ -z "$MAIN_BIN" ]; then
			_err_msg "ERROR: DESKTOP=DUMMY needs MAIN_BIN to be set"
			exit 1
		fi
		_echo "* Adding dummy $MAIN_BIN desktop entry to $APPDIR..."
		cat <<-EOF > "$APPDIR"/"$MAIN_BIN".desktop
		[Desktop Entry]
		Name=$MAIN_BIN
		Exec=$MAIN_BIN
		Comment=Dummy made by quick-sharun
		Type=Application
		Hidden=true
		Categories=Utility
		Icon=$MAIN_BIN
		EOF
	elif [ -f "$DESKTOP" ]; then
		_echo "* Adding $DESKTOP to $APPDIR..."
		cp -v "$DESKTOP" "$APPDIR"
	elif echo "$DESKTOP" | grep -q 'http'; then
		_echo "* Downloading $DESKTOP to $APPDIR..."
		_download "$APPDIR"/"${DESKTOP##*/}" "$DESKTOP"
	elif [ -n "$DESKTOP" ]; then
		_err_msg "$DESKTOP is NOT a valid path!"
		exit 1
	fi

	# make sure desktop entry ends with .desktop
	if [ ! -f "$APPDIR"/*.desktop ] && [ -f "$APPDIR"/*.desktop* ]; then
		filename="${DESKTOP##*/}"
		mv "$APPDIR"/*.desktop* "$APPDIR"/"${filename%.desktop*}".desktop
	fi

	DESKTOP_ENTRY=$(echo "$APPDIR"/*.desktop)
	if [ ! -f "$DESKTOP_ENTRY" ]; then
		_err_msg "ERROR: No top level .desktop file found in $APPDIR"
		_err_msg "Note there cannot be more than one .desktop file in that location"
		exit 1
	fi
}

_check_window_class() {
	set -- "$APPDIR"/*.desktop

	# do not bother if no desktop entry or class is declared already
	if [ ! -f "$1" ] || grep -q 'StartupWMClass=' "$1"; then
		return 0
	fi

	if [ -z "$STARTUPWMCLASS" ]; then
		_err_msg "WARNING: '$1' is missing StartupWMClass!"
		_err_msg "We will fix it using the name of the binary but this"
		_err_msg "may be wrong so please add the correct value if so"
		_err_msg "set STARTUPWMCLASS so I can set that instead"
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

_add_bwrap_wrapper() {
	cat <<-'EOF' > "$APPDIR"/bin/bwrap
	#!/bin/sh

	# AppImages crash when we bundle bwrap required by glycin loaders
	# This terrible hack makes us able to run the glycin loaders without bwrap
	# This is because glycin does not canonicalize the path to the glycin binaries

	# With webkit2gtk we get weird cannot find xdg-dbus-proxy errors only
	# in fedora besides other weird things that happen in other distros
	# https://github.com/VHSgunzo/sharun/issues/77

	while :; do case "$1" in
	        --) shift; break;;
	        --chdir|--seccomp|--dev|--tmpfs|--args) shift 2;;
	        --*bind*|--symlink|--setenv) shift 3;;
	        -*) shift;;
	        *) break ;;
	        esac
	done
	exec "$@"
	EOF
	chmod +x "$APPDIR"/bin/bwrap
}

_fix_cpython_ldconfig_mess() {
	# cpython runs ldconfig -p to determine library names, this is
	# super flawed because ldconfig -p is going to print host libraries
	# and not our bundled libraries, it also only works in glibc systems
	#
	# it also hardcodes /sbin/ldconfig and resets PATH variable
	# so we have to do a lot of patches here to fix this mess
	#
	# we will patch /sbin/ldconfig for _ldconfig to avoid conflicts, see:
	# https://github.com/pkgforge-dev/ghostty-appimage/issues/122

	set -- "$DST_LIB_DIR"/python*/ctypes/util.py
	ldconfig="$APPDIR"/bin/_ldconfig
	if [ -x "$ldconfig" ]; then
		return 0
	elif [ ! -f "$1" ]; then
		return 0 # exit without error if ctypes is not present
	fi
	pythonlib=$1

	# patch ctypes lib
	sed -i \
		-e 's|/sbin/ldconfig|_ldconfig|g' \
		-e 's|env={.*}||'                 \
		"$pythonlib"

	cat <<-'EOF' > "$ldconfig"
	#!/bin/sh

	# wrapper that makes ldconfig -p print our bundled libraries
	export LC_ALL=C
	export LANG=C
	# some distros don't include /sbin in PATH
	export PATH="$PATH:/usr/sbin:/sbin"

	if [ -z "$APPDIR" ]; then
	    APPDIR=$(cd "${0%/*}"/../ && echo "$PWD")
	fi

	_list_libs() {
	    echo "69420 libs found in cache \`/etc/ld.so.cache'"

	    case "$(uname -m)" in
	        aarch64) arch=AArch64;;
	        *)       arch=x86-64;;
	    esac

	    for f in "$APPDIR"/shared/lib*/*.so* "$APPDIR"/shared/lib*/*/*.so*; do
	        echo "	${f##*/} (libc6,$arch) => $f"
	    done

	    echo "Cache generated by: ldconfig (GNU libc) stable release version 2.42"
	}

	# lets try to use the real thing
	case "$1" in
	    -p|--print-cache)
	        _list_libs
	        ;;
	    *)
	        exec ldconfig "$@"
	        ;;
	esac
	EOF
	chmod +x "$ldconfig"

	_echo "* patched cpython /sbin/ldconfig for _ldconfig wrapper"

	# pysdl is even more broken
	set -- "$DST_LIB_DIR"/python*/site-packages/sdl3/__init__.py
	[ -f "$1" ] || return 0
	sed -i \
	  -e 's|if os.path.exists(path) and SDL|if SDL|' \
	  -e 's|binaryMap\[module\] =.*|binaryMap[module] = ctypes.CDLL(path)|' \
	  "$1"
	_echo "* fixed pysdl broken mess... this may not work always!"
}

_add_path_mapping_hardcoded() {
	if [ -x "$PATH_MAPPING_SCRIPT" ]; then
		return 0
	fi
	mkdir -p "${PATH_MAPPING_SCRIPT%/*}"
	cat <<-'EOF' > "$PATH_MAPPING_SCRIPT"
	#!/bin/sh

	# this script makes symnlinks to hardcoded random dirs that
	# were patched away by quick-sharun when hardcoded paths are
	# detected or when 'PATH_MAPPING_HARDCODED' is used

	_tmp_bin=""
	_tmp_lib=""
	_tmp_share=""

	export LC_ALL=C

	_symlink_error_msg="Failed to create a very important symlink in /tmp"
	if [ -n "$_tmp_bin" ] && ! ln -sfn "$APPDIR"/bin /tmp/"$_tmp_bin"; then
	    >&2 echo "$_symlink_error_msg"
	fi
	if [ -n "$_tmp_lib" ] && ! ln -sfn "$APPDIR"/lib /tmp/"$_tmp_lib"; then
	    >&2 echo "$_symlink_error_msg"
	fi
	if [ -n "$_tmp_share" ] && ! ln -sfn "$APPDIR"/share /tmp/"$_tmp_share"; then
	    >&2 echo "$_symlink_error_msg"
	fi
	EOF
	chmod +x "$PATH_MAPPING_SCRIPT"
	_echo "* Added $PATH_MAPPING_SCRIPT"
}

_patch_away_usr_bin_dir() {
	if ! grep -Eaoq -m 1 "/usr/bin" "$1"; then
		return 1
	fi

	sed -i -e "s|/usr/bin|/tmp/$_tmp_bin|g" "$1"

	_echo "* patched away /usr/bin from $1"
	_add_path_mapping_hardcoded || exit 1

	sed -i -e "s|_tmp_bin=.*|_tmp_bin=$_tmp_bin|g" "$PATH_MAPPING_SCRIPT"
}

_patch_away_usr_lib_dir() {
	if ! grep -Eaoq -m 1 "/usr/lib" "$1"; then
		return 1
	fi

	sed -i -e "s|/usr/lib|/tmp/$_tmp_lib|g" "$1"

	_echo "* patched away /usr/lib from $1"
	_add_path_mapping_hardcoded || exit 1

	sed -i -e "s|_tmp_lib=.*|_tmp_lib=$_tmp_lib|g" "$PATH_MAPPING_SCRIPT"
}

_patch_away_usr_share_dir() {
	if ! grep -Eaoq -m 1 "/usr/share" "$1"; then
		return 1
	fi

	sed -i -e "s|/usr/share|/tmp/$_tmp_share|g" "$1"

	_echo "* patched away /usr/share from $1"
	_add_path_mapping_hardcoded || exit 1

	sed -i -e "s|_tmp_share=.*|_tmp_share=$_tmp_share|g" "$PATH_MAPPING_SCRIPT"
}

_check_hardcoded_lib_dirs() {
	# check for hardcoded path to any other possibly bundled library dir
	set -- "$DST_LIB_DIR"/*
	for d do
		[ -d "$d" ] || continue
		d=${d##*/}
		# skip directories we already handle here or in sharun
		case "$d" in
			alsa-lib    |\
			dri         |\
			gbm         |\
			gconv       |\
			gdk-pixbuf* |\
			gio         |\
			gtk*        |\
			gstreamer*  |\
			gvfs        |\
			ImageMagick*|\
			imlib2      |\
			libproxy    |\
			locale      |\
			pipewire*   |\
			pulseaudio  |\
			qt*         |\
			spa*        |\
			vdpau       )
				continue
				;;
		esac

		for f in "$DST_LIB_DIR"/*.so* "$APPDIR"/shared/bin/*; do
			if [ ! -f "$f" ]; then
				continue
			elif grep -aoq -m 1 "$LIB_DIR"/"$d" "$f"; then
				_echo "* Detected hardcoded path to $LIB_DIR/$d in $f"
				_patch_away_usr_lib_dir "$f" || :
			fi
		done
	done
}

_check_hardcoded_data_dirs() {
	# first check for hardcoded path to /usr/share/fonts and copy if so
	src_fonts=/usr/share/fonts
	dst_fonts="$APPDIR"/share/fonts
	if grep -aoq -m 1 "$src_fonts" "$APPDIR"/shared/bin/*; then
		if [ -d "$src_fonts" ] && [ ! -d "$dst_fonts" ]; then
			mkdir -p "$dst_fonts"
			for d in "$src_fonts"/*; do
				if [ "${d##*/}" = "Adwaita" ]; then
					continue
				fi
				if [ -e "$d" ]; then
					cp -vr "$d" "$dst_fonts"
				fi
			done
		fi
	fi

	# now check if any of the bundled datadirs need to be patched
	set -- "$APPDIR"/share/*
	for d do
		[ -d "$d" ] || continue
		d=${d##*/}
		# skip directories we already handle here or in sharun
		case "$d" in
			alsa     |\
			drirc.d  |\
			file     |\
			glib-*   |\
			glvnd    |\
			icons    |\
			libdrm   |\
			libthai  |\
			locale   |\
			terminfo |\
			vulkan   |\
			X11      )
				continue
				;;
		esac

		for f in "$DST_LIB_DIR"/*.so* "$APPDIR"/shared/bin/*; do
			if [ ! -f "$f" ]; then
				continue
			elif grep -aoq -m 1 /usr/share/"$d" "$f"; then
				_echo "* Detected hardcoded path to /usr/share/$d in $f"
				_patch_away_usr_share_dir "$f" || :
			fi
		done
	done
}

_sort_env_file() {
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
}

_post_deployment_steps() {
	# these need to be done later because sharun may make shared/lib a symlink
	# to lib and if we make shared/lib first then it breaks sharun
	if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
		set -- "$LIB_DIR"/python*
		if [ -d "$1" ]; then
			cp -r "$1" "$DST_LIB_DIR"
		else
			_err_msg "ERROR: Cannot find python installation in $LIB_DIR"
			exit 1
		fi
		if [ "$DEBLOAT_SYS_PYTHON" = 1 ]; then
			(
				cd "$DST_LIB_DIR"/"${1##*/}"
				find ./ -type f -name '*.a' -delete || :
				for f in $(find ./ -type f -name '*.pyc' -print); do
					case "$f" in
						*/"$MAIN_BIN"*) :;;
						*) [ ! -f "$f" ] || rm -f "$f";;
					esac
				done
			)
		fi
	fi
	if [ "$DEPLOY_FLUTTER" = 1 ]; then
		if [ -z "$FLUTTER_LIB" ]; then
			_err_msg "Flutter deployment was forced but looks like the"
			_err_msg "the application does not link to libflutter at all"
			_err_msg "If you see this message please open a bug report!"
			exit 1
		fi

		# flutter apps need to have a relative lib and data directory
		# we need to find the directory that contains libapp.so
		if libapp=$(cd "$APPDIR"/bin \
		  && find ../shared/lib/ -type f -name 'libapp.so' -print -quit); then
			d=${libapp%/*}
			if [ ! -d "$APPDIR"/bin/"${d##*/}" ]; then
				ln -s "$d" "$APPDIR"/bin/"${d##*/}"
			fi
		else
			_err_msg "Cannot find libapp.so in $APPDIR"
			_err_msg "include it for flutter deployment to work"
		fi

		dst_flutter_dir="$APPDIR"/bin/data
		if [ ! -d "$dst_flutter_dir" ]; then
			if [ -z "$FLUTTER_DATA_DIR" ]; then
				d=${FLUTTER_LIB%/*.so*}
				# find data dir, we assume it is relative to
				# where libflutter*.so came from
				if [ -d "$d"/../data ]; then
					FLUTTER_DATA_DIR="$d"/../data
				elif [ -d "$d"/../../data ]; then
					FLUTTER_DATA_DIR="$d"/../../data
				else
					_err_msg "Cannot find data directory of $FLUTTER_LIB"
					_err_msg "Please set FLUTTER_DATA_DIR to its location"
					exit 1
				fi
			fi
			cp -rv "$FLUTTER_DATA_DIR" "$dst_flutter_dir"
			_echo "* Copied flutter data directory"
		fi
	fi
	if [ "$DEPLOY_IMAGEMAGICK" = 1 ]; then
		mkdir -p "$DST_LIB_DIR"  "$APPDIR"/etc
		cp -rv /etc/ImageMagick-* "$APPDIR"/etc

		# we can copy /usr/share/ImageMagick to the AppDir and set MAGICK_CONFIGURE_PATH
		# to include both the etc/ImageMagick and share/ImageMagick directory
		# but it is simpler to instead have all the config files in a single location
		# imagemagick will load them all regardless
		set -- /usr/share/ImageMagick-*/*.xml
		if [ -f "$1" ]; then
			cp -rv /usr/share/ImageMagick-*/*.xml "$APPDIR"/etc/ImageMagick*
		fi
		# there is also a configuration file in libdir
		set -- "$LIB_DIR"/ImageMagick-*/config*/configure.xml
		if [ -f "$1" ]; then
			cp -v "$1" "$APPDIR"/etc/ImageMagick*
		fi

		# MAGICK_HOME is all that needs to be set
		echo 'MAGICK_HOME=${SHARUN_DIR}' >> "$APPENV"
		# however MAGICK_HOME only works when compiled with a specific flag
		# we can still make this relocatable by setting these other env variables
		# which will always work even when not compiled with MAGICK_HOME support
		(
			# This method will not work with 32bit imagemagick
			# TODO: Add proper logic for this in lib4bin
			cd "$APPDIR"
			set -- shared/lib/ImageMagick-*/modules*/coders
			if [ -d "$1" ]; then
				echo "MAGICK_CODER_MODULE_PATH=\${SHARUN_DIR}/$1" >> "$APPENV"
			fi
			set -- shared/lib/ImageMagick-*/modules*/filters
			if [ -d "$1" ]; then
				# checking the code it seems that MAGICK_FILTER_MODULE_PATH
				# is NOT USED in the code and seems to be an error!!! the variable
				# that modules.c references is MAGICK_CODER_FILTER_PATH
				# we will still be set both just in case
				echo "MAGICK_CODER_FILTER_PATH=\${SHARUN_DIR}/$1" >> "$APPENV"
				echo "MAGICK_FILTER_MODULE_PATH=\${SHARUN_DIR}/$1" >> "$APPENV"
			fi
			set -- etc/ImageMagick*
			if [ -d "$1" ]; then
				echo "MAGICK_CONFIGURE_PATH=\${SHARUN_DIR}/$1" >> "$APPENV"
			fi
		)

		_echo "* Copied ImageMagick directories"
	fi
	if [ "$DEPLOY_GEGL" = 1 ]; then
		gegldir=$(echo "$LIB_DIR"/gegl-*)
		dst_gegldir=$DST_LIB_DIR/${gegldir##*/}
		if [ -d "$gegldir" ] && [ -d "$dst_gegldir" ]; then
			cp "$gegldir"/*.json "$dst_gegldir"
			_echo "* Copied gegl json files"
		fi
	fi
	if [ "$DEPLOY_QT" = 1 ]; then
		src_trans=/usr/share/$QT_DIR/translations
		dst_trans=$DST_LIB_DIR/$QT_DIR/translations
		if [ -d "$src_trans" ] && [ ! -d "$dst_trans" ]; then
			mkdir -p "${dst_trans%/*}"
			cp -r "$src_trans" "$dst_trans"
			rm -f "$dst_trans"/assistant*.qm
			rm -f "$dst_trans"/designer*.qm
			rm -f "$dst_trans"/linguist*.qm
		fi
		if [ -f "$TMPDIR"/libqgtk3.so ]; then
			d="$APPDIR"/lib/"$QT_DIR"/plugins/platformthemes
			mkdir -p "$d"
			mv "$TMPDIR"/libqgtk3.so "$d"
			"$APPDIR"/sharun -g 2>/dev/null || :
		fi
	fi
	if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
		_fix_cpython_ldconfig_mess
	fi
	# copy the entire hicolor icons dir
	# by default the hicolor icon theme ships no icons, this
	# means any present icon is likely needed by the application
	if [ -d /usr/share/icons/hicolor ]; then
		mkdir -p "$APPDIR"/share/icons
		cp -r /usr/share/icons/hicolor "$APPDIR"/share/icons
		_remove_empty_dirs "$APPDIR"/share/icons/hicolor
	fi

	# TODO upstream to sharun
	f=$APPDIR/share/alsa/alsa.conf
	if [ -f "$f" ]; then
		sed -i -e 's|"/etc/alsa/conf.d"|"/etc/alsa/conf.d"\n\t\t\t{ @func concat strings [ { @func getenv vars [ SHARUN_DIR ] default "" } "/share/alsa/alsa.conf.d" ] }|' "$f"
	fi
}

_handle_nested_bins() {
	# wrap any executable in lib with sharun
	for b in $(find "$DST_LIB_DIR"/ -type f ! -name '*.so*'); do
		if [ -x "$b" ] && [ -x "$APPDIR"/shared/bin/"${b##*/}" ]; then
			rm -f "$b"
			ln "$APPDIR"/sharun "$b"
			_echo "* Wrapped lib executable '$b' with sharun"
		fi
	done

	# do the same for possible nested binaries in bin
	for b in $(find "$APPDIR"/bin/*/ -type f ! -name '*.so*' 2>/dev/null); do
		if [ -x "$b" ] && [ -x "$APPDIR"/shared/bin/"${b##*/}" ]; then
			rm -f "$b"
			ln "$APPDIR"/sharun "$b"
			_echo "* Wrapped nested bin executable '$b' with sharun"
		fi
	done
}

# sometimes developers add stuff like /bin/sh or env as the Exec= key of the
# desktop entry, 99.99% of the time this is not wanted, so we have to error that
_check_main_bin() {
	if [ -z "$MAIN_BIN" ]; then
		MAIN_BIN=$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$DESKTOP_ENTRY" | tr -d "\"'")
		MAIN_BIN=${MAIN_BIN##*/}
		case "$MAIN_BIN" in
			env|sh|bash)
				_err_msg "Main binary is '$MAIN_BIN', it is unlikely you"
				_err_msg "are actually going to package '$MAIN_BIN'"
				_err_msg "as an appimage, bailing out..."
				_err_msg "set MAIN_BIN=$MAIN_BIN if you want to do this."
				exit 1
				;;
		esac
	fi

	if [ -f "$APPDIR"/bin/"$MAIN_BIN" ]; then
		return 0
	fi

	_err_msg "Main binary is set to '$MAIN_BIN', but this file is NOT present"
	_err_msg "This is the default binary to be launched in this application"
	_err_msg "Please make sure to bundle $MAIN_BIN"
	_err_msg "By default the main binary is taken from the top level desktop"
	_err_msg "entry in '$APPDIR', make sure to add the correct desktop entry"
	exit 1
}

_make_static_bin() (
	DST_DIR="$APPDIR"/bin
	while :; do case "$1" in
		--dst-dir)
			DST_DIR="$2"
			shift
			;;
		-*)
			_err_msg "ERROR: Unknown option: '$1'"
			exit 1
			;;
		'')
			break
			;;
		*)
			BIN_TO_DEPLOY="${BIN_TO_DEPLOY:+$BIN_TO_DEPLOY:}$1"
			shift
			;;
		esac
	done
	_IFS=$IFS
	IFS=:
	set -- $BIN_TO_DEPLOY
	IFS=$_IFS
	_echo "------------------------------------------------------------"
	mkdir -p "$DST_DIR"
	export DST_DIR
	for b do
		_echo "Packing $b as a static binary..."
		$XVFB_CMD "$TMPDIR"/sharun-aio l \
			--with-wrappe            \
			--wrappe-exec "${b##*/}" \
			"$b" || :
	done
	_echo "------------------------------------------------------------"
)

_make_appimage() {
	_echo "------------------------------------------------------------"
	_echo "Making AppImage..."
	_echo "------------------------------------------------------------"

	if [ ! -d "$APPDIR" ]; then
		_err_msg "ERROR: No $APPDIR directory found"
		_err_msg "Set APPDIR if you have it at another location"
		exit 1
	elif [ ! -f "$APPDIR"/AppRun ]; then
		_err_msg "ERROR: No $APPDIR/AppRun file found!"
		exit 1
	elif ! command -v zsyncmake 1>/dev/null; then
		_err_msg "ERROR: Missing dependency zsyncmake"
		exit 1
	fi
	chmod +x "$APPDIR"/AppRun
	_get_desktop
	_get_icon
	_sort_env_file

	_echo "------------------------------------------------------------"
	if [ -z "$UPINFO" ]; then
		echo "No update information given, trying to guess it..."
		if [ -n "$GITHUB_REPOSITORY" ]; then
			UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
			_echo "Guessed $UPINFO as the update information"
			_echo "It may be wrong so please set the UPINFO instead"
		else
			_err_msg "We were not able to guess the update information"
			_err_msg "Please add it if you will distribute the AppImage"
		fi
	fi
	_echo "------------------------------------------------------------"

	if [ "$DEVEL_RELEASE" = 1 ]; then
		if ! grep -q '^Name=.*Nightly' "$DESKTOP_ENTRY"; then
			>&2 echo "Adding Nightly to desktop entry name"
			sed -i -e 's/^\(Name=.*\)$/\1 Nightly/' "$DESKTOP_ENTRY"
		fi
		# also change UPINFO to use nightly tag
		if [ -n "$UPINFO" ]; then
			UPINFO=$(echo "$UPINFO" | sed 's/|latest|/|nightly|/')
		fi
	fi

	# get name of app from desktop entry and sanitize it
	APPNAME="${APPNAME:-$(awk -F'=' '/^Name=/{print $2; exit}' "$DESKTOP_ENTRY")}"
	APPNAME=$(printf '%s' "$APPNAME" | tr '[:space:]":><*|\?\r\n' '_')
	APPNAME=${APPNAME%_}

	# check for a ~/version file if VERSION is not set
	if [ -z "$VERSION" ] && [ -f "$HOME"/version ]; then
		if ! read -r VERSION < "$HOME"/version; then
			>&2 echo "ERROR: Failed to read ~/version file! Is it empty?"
			exit 1
		fi
	fi
	# sanitize VERSION
	if [ -n "$VERSION" ]; then
		VERSION=${VERSION#*:} # remove epoch from VERSION
		VERSION=$(printf '%s' "$VERSION" | tr '[:space:]":><*|\?\r\n' '_')
		VERSION=${VERSION%_}
	fi

	# add appimage info to desktop entry, first make sure to remove existing info
	sed -i \
		-e '/X-AppImage-Name/d'    \
		-e '/X-AppImage-Version/d' \
		-e '/X-AppImage-Arch/d'    \
		"$DESKTOP_ENTRY"
	echo ""                                       >> "$DESKTOP_ENTRY"
	echo "X-AppImage-Name=$APPNAME"               >> "$DESKTOP_ENTRY"
	echo "X-AppImage-Version=${VERSION:-UNKNOWN}" >> "$DESKTOP_ENTRY"
	echo "X-AppImage-Arch=$APPIMAGE_ARCH"         >> "$DESKTOP_ENTRY"

	if ! mkdir -p "$OUTPATH"; then
		_err_msg "ERROR: Cannot create output directory: '$OUTPATH'"
		exit 1
	fi
	if [ -z "$OUTNAME" ]; then
		if [ -n "$VERSION" ]; then
			OUTNAME="$APPNAME"-"$VERSION"-anylinux-"$ARCH".AppImage
		else
			OUTNAME="$APPNAME"-anylinux-"$ARCH".AppImage
			>&2 echo "WARNING: VERSION is not set"
			>&2 echo "WARNING: set it to include it in $OUTNAME"
		fi
	fi

	if command -v mkdwarfs 1>/dev/null; then
		DWARFS_CMD="$(command -v mkdwarfs)"
	elif [ ! -x "$DWARFS_CMD" ]; then
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

	if [ -n "$ADD_PERMA_ENV_VARS" ]; then
		while IFS= read -r VAR; do
			case "$VAR" in
				*=*) "$RUNTIME" --appimage-addenvs "$VAR";;
			esac
		done <<-EOF
		$ADD_PERMA_ENV_VARS
		EOF
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
		if ! _is_cmd xvfb-run pkill; then
			_err_msg "ERROR: OPTIMIZE_LAUNCH requires xvfb-run and pkill"
			exit 1
		fi

		tmpappimage="$TMPDIR"/.analyze

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
		sleep 3
		set -- --categorize=hotness --hotness-list="$DWARFSPROF" "$@"
	fi

	if ! "$DWARFS_CMD" "$@" -C $DWARFS_COMP --output "$OUTPATH"/"$OUTNAME"; then
		_err_msg "ERROR: Something went wrong making dwarfs image!"
		if [ -f "$DWARFSPROF" ]; then
			_err_msg "Found '$DWARFSPROF' file in '$APPDIR', may be causing issues:"
			_err_msg "------------------------------------------------------------"
			>&2 cat "$DWARFSPROF" || :
			_err_msg "------------------------------------------------------------"
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
	echo "X-AppImage-Name=$APPNAME"               >  "$OUTPATH"/appinfo
	echo "X-AppImage-Version=${VERSION:-UNKNOWN}" >> "$OUTPATH"/appinfo
	echo "X-AppImage-Arch=$APPIMAGE_ARCH"         >> "$OUTPATH"/appinfo

	_echo "------------------------------------------------------------"
	_echo "All done! AppImage at: $OUTPATH/$OUTNAME"
	_echo "------------------------------------------------------------"
	exit 0
}

case "$1" in
	--help)
		_help_msg
		;;
	--make-appimage)
		_make_appimage
		;;
	--test)
		shift
		_test_appimage "$@"
		;;
	--simple-test)
		shift
		_simple_test_appimage "$@"
		;;
	--make-static-bin)
		shift
		_get_sharun
		_make_static_bin "$@"
		exit 0
		;;
	'')
		_help_msg
		;;
esac

_sanity_check
_get_desktop
_get_icon

_echo "------------------------------------------------------------"
_echo "Starting deployment, checking if extra libraries need to be added..."
echo ""

_determine_what_to_deploy "$@"
_make_deployment_array

echo ""
_echo "Now jumping to sharun..."
_echo "------------------------------------------------------------"

_get_sharun
_deploy_libs "$@"
_check_always_software
_handle_bins_scripts

echo ""
_echo "------------------------------------------------------------"
echo ""

_check_main_bin
_map_paths_ld_preload_open
_map_paths_binary_patch
_add_anylinux_lib
_deploy_datadir
_deploy_locale
_check_window_class
_add_gtk_class_fix

echo ""
_echo "------------------------------------------------------------"
_echo "Finished deployment! Starting post deployment hooks..."
_echo "------------------------------------------------------------"
echo ""

set -- \
	"$DST_LIB_DIR"/*.so*       \
	"$DST_LIB_DIR"/*/*.so*     \
	"$DST_LIB_DIR"/*/*/*.so*   \
	"$DST_LIB_DIR"/*/*/*/*.so*

for lib do case "$lib" in
	*libgegl*)
		# GEGL_PATH is problematic so we avoiud it
		# patch the lib directly to load its plugins instead
		_patch_away_usr_lib_dir "$lib" || continue
		echo 'unset GEGL_PATH' >> "$APPENV"
		;;
	*libp11-kit.so*)
		_patch_away_usr_lib_dir "$lib" || :
		_patch_away_usr_share_dir "$lib" || :
		if [ -d /usr/share/p11-kit ] && [ ! -d "$APPDIR"/share/p11-kit ]; then
			cp -r /usr/share/p11-kit "$APPDIR"/share
		fi
		continue
		;;
	*p11-kit-trust.so*)
		# Because OpenSUSE had to ruin this, we will have to patch the
		# the certificates to a path in /tmp that we will later make
		# a symlink that points to the real host certs location

		# Originally we just patch to etc/ssl/certs/ca-certificates.crt
		# See https://github.com/kem-a/AppManager/issues/39

		# string has to be same length
		problem_path="/usr/share/ca-certificates/trust-source"
		ssl_path_fix="/tmp/.___host-certs/ca-certificates.crt"

		if grep -Eaoq -m 1 "$ssl_path_fix" "$lib"; then
			continue # all good nothing to fix
		elif grep -Eaoq -m 1 "$problem_path" "$lib"; then
			sed -i -e "s|$problem_path|$ssl_path_fix|g" "$lib"
		else
			continue # TODO add more possible problematic paths
		fi

		_add_p11kit_cert_hook

		_echo "* fixed path to /etc/ssl/certs in $lib"
		_patch_away_usr_share_dir "$lib" || continue
		;;
	*libgimpwidgets*)
		_patch_away_usr_share_dir "$lib" || continue
		;;
	*libmlt*.so*)
		_patch_away_usr_lib_dir "$lib" || continue
		_patch_away_usr_share_dir "$lib" || continue
		;;
	*libMangoHud*.so*)
		src_mangohud_layer=$(echo /usr/share/vulkan/implicit_layer.d/MangoHud*.json)
		dst_mangohud_layer="$APPDIR"/share/vulkan/implicit_layer.d/"${src_mangohud_layer##*/}"
		if [ -f "$src_mangohud_layer" ] && [ ! -f "$dst_mangohud_layer" ]; then
			mkdir -p "$APPDIR"/share/vulkan/implicit_layer.d
			cp -v "$src_mangohud_layer" "$dst_mangohud_layer"
			sed -i 's|/.*/mangohud/||' "$dst_mangohud_layer"

			if [ ! -f "$APPDIR"/bin/mangohud ] \
				&& command -v mangohud 1>/dev/null; then
				cp -v "$(command -v mangohud)" "$APPDIR"/bin
			fi

			sed -i \
				-e 's|/usr/.*/||'                         \
				-e '1a\export SHARUN_ALLOW_LD_PRELOAD=1'  \
				-e 's|#!.*|#!/bin/sh|'                    \
				"$APPDIR"/bin/mangohud || :

			_echo "Copied over mangohud layer and patched mangohud"
		fi
		;;
	*libwebkit*gtk*.so*)
		# sharun deploys webkit2gtk but with relative path mapping
		# the problem is that changes the working dir to the AppDir
		# We can instead use path-mapping-hardcoded which does not
		# have the changing of working directory issue

		# restore relative path mapping to /usr
		sed -i -e 's|\./\.//|/usr/|g' "$lib" || :

		# remove working dir change
		sed -i -e '/SHARUN_WORKING_DIR=${SHARUN_DIR}/d' "$APPENV" || :

		# now do better path map to the libs
		_patch_away_usr_lib_dir "$lib" || :
		_patch_away_usr_bin_dir "$lib" || :
		_add_bwrap_wrapper
		;;
	*libdecor*.so*)
		ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}fix-gnome-csd.src.hook"
		;;
	*libSDL*.so*)
		# make sure SDL does not attempt to use pipewire when not deployed
		if [ "$DEPLOY_PIPEWIRE" != 1 ] \
		  && ! grep -q 'SDL_AUDIODRIVER=' "$APPENV" 2>/dev/null; then
			echo 'SDL_AUDIODRIVER=pulseaudio' >> "$APPENV"
		fi

		# SDL may be bundled without libdecor since it maybe missing from the CI runner
		# or the application makes of GTK/Qt + SDL, in which case we do not need libdecor
		# at all, make sure SDL does not attempt to load libdecor in these cases
		if [ -f "$DST_LIB_DIR"/libdecor-0.so.0 ]; then
			continue
		elif grep -aoq -m 1 'libdecor-0.so.0' "$lib"; then
			sed -i -e 's|libdecor-0.so.0|fuck-gnome.so.X|g' "$lib"
		fi
		;;
	*/xpm.so)
		f=/usr/share/imlib2/rgb.txt
		if [ -f "$f" ]; then
			mkdir -p "$APPDIR"/share/imlib2
			cp -v "$f" "$APPDIR"/share/imlib2
			_patch_away_usr_share_dir "$lib" || continue
			_echo "Copied and patched imlib2 xpm loader"
		fi
		;;
	*/7z.so)
		cp -v "$lib" "$APPDIR"/bin
		;;
	esac
done

_post_deployment_steps
_check_hardcoded_lib_dirs
_check_hardcoded_data_dirs

# patch away any hardcoded path to /usr/share or /usr/lib in bins...
set -- "$APPDIR"/shared/bin/*
for bin do
	if p=$(grep -ao -m 1 '/usr/share/.*/' "$bin"); then
		_echo "* Detected hardcoded path to $p in $bin"
		_patch_away_usr_share_dir "$bin" || :
	fi
	if p=$(grep -ao -m 1 '/usr/lib/.*/' "$bin"); then
		_echo "* Detected hardcoded path to $p in $bin"
		_patch_away_usr_lib_dir "$bin" || :
	fi
done

# some libraries may need to look for a relative ../share directory
# normally this is for when they are located in /usr/lib
# however with sharun this structure is not present, instead
# we have the libraries inside `shared/lib` and `share` is one level
# further back, so we make a relative symlink to fix this issue
if [ ! -d "$APPDIR"/shared/share ]; then
	ln -s ../share "$APPDIR"/shared/share
fi

echo ""
_echo "------------------------------------------------------------"
echo ""

if [ -n "$ADD_HOOKS" ]; then
	old_ifs="$IFS"
	IFS=':'
	set -- $ADD_HOOKS
	IFS="$old_ifs"
	hook_dst="$APPDIR"/bin
	for hook do
		if [ -f "$hook_dst"/"$hook" ]; then
			continue
		elif [ "$APPIMAGE_ARCH" != 'x86_64' ] \
		  && echo "$hook" | grep -q 'x86.*64'; then
			continue # do not add x86-64 hooks in other arches
		elif _download "$hook_dst"/"$hook" "$HOOKSRC"/"$hook"; then
			_echo "* Added $hook"
		else
			_err_msg "ERROR: Failed to download $hook, valid link?"
			_err_msg "$HOOKSRC/$hook"
			exit 1
		fi
	done

	# always add notify wrapper when using hooks
	_download "$hook_dst"/notify "$NOTIFY_SOURCE"
	_echo "* Added notify wrapper"
fi

if [ ! -f "$APPDIR"/AppRun ]; then
	_download "$APPDIR"/AppRun "$APPRUN_SOURCE"
	_echo "* Added ${APPRUN_SOURCE##*/}"
fi

# Set APPIMAGE_ARCH and MAIN_BIN in AppRun
sed -i \
	-e "s|@MAIN_BIN@|$MAIN_BIN|"  \
	-e "s|@APPIMAGE_ARCH@|$APPIMAGE_ARCH|" \
	"$APPDIR"/AppRun

chmod +x "$APPDIR"/AppRun "$APPDIR"/bin/*.hook "$APPDIR"/bin/notify 2>/dev/null || :

# always make sure that AppDir/lib exists, sometimes lib4bin does not make it
# https://github.com/pkgforge-dev/Anylinux-AppImages/issues/269#issuecomment-3829584043
for d in lib lib32; do
	dir=$APPDIR/shared/$d
	symlink=$APPDIR/$d
	if [ ! -d "$symlink" ] && [ -d "$dir" ]; then
		ln -s shared/"$d" "$symlink"
	fi
done

# deploy directories
while read -r d; do
	if [ -d "$d" ]; then
		case "$d" in
			"$LIB_DIR"/*)
				if [ "$LIB32" = 1 ]; then
					dst_path="$APPDIR"/lib32/"${d##*$LIB_DIR/}"
				else
					dst_path="$APPDIR"/lib/"${d##*$LIB_DIR/}"
				fi
				;;
			*/share/*)
				dst_path="$APPDIR"/share/"${d##*/share/}"
				;;
			*/etc/*)
				dst_path="$APPDIR"/etc/"${d##*/etc/}"
				;;
			*/lib/*)
				dst_path="$APPDIR"/lib/"${d##*/lib/}"
				;;
			*/lib32/*)
				dst_path="$APPDIR"/lib32/"${d##*/lib32/}"
				;;
			*)
				_err_msg "Skipping deployment of $d"
				_err_msg "Valid directories to deploy are:"
				_err_msg "Any dir from: $LIB_DIR"
				_err_msg "Any dir with /lib/ in its path"
				_err_msg "Any dir with /share/ in its path"
				_err_msg "Any dir with /etc/ in its path"
				continue
				;;
		esac
		mkdir -p "${dst_path%/*}"
		if cp -Lrn "$d"/. "$dst_path"; then
			_echo "* Added $d to $dst_path"
		else
			# do not stop the script if the copy fails, because
			# since lib4bin skips directories automatically we do
			# not want CIs to fail because suddenly now we are
			# trying to copy some directory that we did not have
			# read access to that lib4bin was previously skipping
			_err_msg "Failed to add $d to $dst_path/${d##*/}"
		fi
	fi
done <<-EOF
$ADD_DIR
EOF

_handle_nested_bins

if [ -n "$ANYLINUX_DO_NOT_LOAD_LIBS" ]; then
	echo "ANYLINUX_DO_NOT_LOAD_LIBS=$ANYLINUX_DO_NOT_LOAD_LIBS:\${ANYLINUX_DO_NOT_LOAD_LIBS}" >> "$APPENV"
fi

# check if we have libjack.so in the AppImage, jack needs matching
# server and client library versions to work, instead we need to use
# pipewire-jack, which gives a libjack.so that does not have this limitation
libjackwarning="
------------------------------------------------------------
------------------------------------------------------------

WARNING: Detected libjack.so has been bundled in this application!
If this app is going to connect to a jack server it is not going to work!
jack needs matching library versions between clients and server to work!

The only solution is bundling libjack.so from pipewire-jack
package instead which does not have this issue.

NOTE: This is only a problem if the application has the option to connect
to a jack server, that is for example music players and music editing software
libjack.so can be bundled as linked dependency of another library like
ffmpeg and in that case this is not an issue.

------------------------------------------------------------
------------------------------------------------------------
"
set -- "$DST_LIB_DIR"/libjack.so*
if [ -f "$1" ]; then
	if ! ldd "$1" | grep -q 'libpipewire'; then
		_err_msg "$libjackwarning"
	fi
fi

# also warn when several common qt theme plugins are missing, we only do this for qt6
if [ -d "$DST_LIB_DIR"/qt6 ]; then
	for p in kvantum qtlxqt qt6ct; do
		set -- "$DST_LIB_DIR"/qt6/plugins/*/*$p*
		if [ ! -f "$1" ]; then
			_err_msg "------------------------------------------------------------"
			_err_msg "WARNING: Qt was deployed but there is no $p plugin!"
			_err_msg "This means the application will lack proper theme support!"
			_err_msg "Install the packages that provide theme support before deploying"
			_err_msg "In archlinux those are: qt6ct kvantum lxqt-qtplugin"
			_err_msg "------------------------------------------------------------"
		fi
	done
fi

echo ""
if [ "$OUTPUT_APPIMAGE" = 1 ]; then
	_make_appimage
else
	_sort_env_file
	_echo "------------------------------------------------------------"
	_echo "All done!"
	_echo "------------------------------------------------------------"
fi
