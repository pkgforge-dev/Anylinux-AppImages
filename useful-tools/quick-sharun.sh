#!/bin/sh

# wrapper script for sharun that simplifies deployment to simple one liners
# Will try to detect and force deployment of GTK, QT, OpenGL, etc
# You can also force their deployment by setting the respective env variables
# for example set DEPLOY_OPENGL=1 to force opengl to be deployed

# Set ADD_HOOKS var to deploy the several hooks of this repository
# Example: ADD_HOOKS="self-updater.hook:fix-namespaces.hook" ./quick-sharun.sh
# Using the hooks automatically downloads a generic AppRun if no AppRun is present

# Set DESKTOP and ICON to the path of top level .desktop and icon to deploy them

set -e

if [ "$QUICK_SHARUN_DEBUG" = 1 ]; then
	set -x
fi

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
OPTIMIZE_LAUNCH=${OPTIMIZE_LAUNCH:-0}

APPIMAGETOOL_LINK=${APPIMAGETOOL_LINK:-https://github.com/pkgforge-dev/appimagetool/releases/latest/download/appimagetool-$APPIMAGE_ARCH-linux}
APPIMAGETOOL=${APPIMAGETOOL:-$TMPDIR/appimagetool}

ANYLINUX_LIB=${ANYLINUX_LIB:-1}
ANYLINUX_LIB_SOURCE=${ANYLINUX_LIB_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/anylinux.c}
GTK_CLASS_FIX=${GTK_CLASS_FIX:-0}
GTK_CLASS_FIX_SOURCE=${GTK_CLASS_FIX_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/gtk-class-fix.c}

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
PATH_MAPPING_SCRIPT="$APPDIR"/bin/01-path-mapping-hardcoded.hook

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
export STRACE_MODE=${STRACE_MODE:-1}
export WRAPPE_CLVL=${WRAPPE_CLVL:-15}
export WITH_HOOKS=0
export STRIP=0

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
	  ADD_HOOKS="self-updater.hook:fix-namespaces.hook" ./quick-sharun.sh /path/to/myapp

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

_is_bun_binary() {
	grep -aq -m1 '__bun_' "$1"
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
				*libgtk-x11-*.so*)
					DEPLOY_GTK=${DEPLOY_GTK:-1}
					GTK_DIR=gtk-2.0
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
					# glycin-ng needs no special handling
					# it works out of the box
					case " $NEEDED_LIBS " in
						*"libglycin_ng.so"*)
							DEPLOY_GLYCIN=0
							continue
							;;
						*)
							DEPLOY_GLYCIN=${DEPLOY_GLYCIN:-1}
							GTK_CLASS_FIX=1
							GNOME_GLYCIN=1
							;;
					esac
					;;
				*libwebkit*gtk-*.so*)
					DEPLOY_WEBKIT2GTK=${DEPLOY_WEBKIT2GTK:-1}
					_webkit_dir=${lib##*/}          # get basename
					_webkit_dir=${_webkit_dir#lib}  # strip lib
					_webkit_dir=${_webkit_dir%.so*} # strip .so
					WEBKIT2GTK_DIR=${WEBKIT2GTK_DIR:-${lib%/*}/$_webkit_dir}
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
				*libgs.so*)
					DEPLOY_GHOSTSCRIPT=${DEPLOY_GHOSTSCRIPT:-1}
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
			if b=$(command -v bwrap);  then set -- "$@" "$b"; fi
			if b=$(command -v xdg-dbus-proxy);  then set -- "$@" "$b"; fi
			if [ ! -d "$WEBKIT2GTK_DIR" ]; then
				_err_msg "Unable to find $WEBKIT2GTK_DIR directory"
				_err_msg "Please set the WEBKIT2GTK_DIR variable to its location"
				exit 1
			fi
			ADD_DIR="
				$ADD_DIR
				$WEBKIT2GTK_DIR
			"
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
		_echo "* Deploying GNOME glycin"
		set -- "$@" "$LIB_DIR"/glycin-loaders/*/*
		if b=$(command -v bwrap);  then set -- "$@" "$b"; fi
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
		# electron bundled libs always need to load first
		# for example libcef.so may need to read a icudtl.dat next to it
		echo 'SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}' >> "$APPENV"
	fi
	if [ "$DEPLOY_OPENGL" = 1 ] || [ "$DEPLOY_VULKAN" = 1 ]; then
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}
		set -- "$@" \
			"$LIB_DIR"/dri/*           \
			"$LIB_DIR"/gbm/*           \
			"$LIB_DIR"/vdpau/*         \
			"$LIB_DIR"/libgbm.so*      \
			"$LIB_DIR"/libvdpau.so*    \
			"$LIB_DIR"/libpci.so*      \
			"$LIB_DIR"/libva.so*       \
			"$LIB_DIR"/libva-*.so*     \
			"$LIB_DIR"/libdrm*.so*     \
			"$LIB_DIR"/libxcb-dri*.so* \
			"$LIB_DIR"/libxcb-glx.so*  \
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
			ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}vulkan-check.hook"
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
	if [ "$DEPLOY_GHOSTSCRIPT" = 1 ]; then
		_echo "* Deploying ghostscript"
		set -- "$@" "$LIB_DIR"/libgs.so*
		if b=$(command -v gs); then set -- "$@" "$b"; fi
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
			"$LIB_DIR"/libxcb-ewmh.so*       \
			"$LIB_DIR"/libxcb-icccm.so*      \
			"$LIB_DIR"/libxkbcommon.so*      \
			"$LIB_DIR"/libxkbcommon-x11.so*  \
			"$LIB_DIR"/libXext.so*           \
			"$LIB_DIR"/libXfixes.so*         \
			"$LIB_DIR"/libXinerama.so*       \
			"$LIB_DIR"/libXrandr.so*         \
			"$LIB_DIR"/libXss.so*            \
			"$LIB_DIR"/libX11-xcb.so*        \
			"$LIB_DIR"/libwayland-egl.so*    \
			"$LIB_DIR"/libwayland-cursor.so* \
			"$LIB_DIR"/libwayland-client.so* \
			"$LIB_DIR"/libnss_mymachines.so* \
			"$LIB_DIR"/libnss_resolve.so*    \
			"$LIB_DIR"/libnss_files.so*      \
			"$LIB_DIR"/libnss_dns.so*
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
					"$d"/*          \
					"$d"/*/*        \
					"$d"/*/*/*      \
					"$d"/*/*/*/*    \
					"$d"/*/*/*/*/*  \
					"$d"/*/*/*/*/*/*; do

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

_fix_broken_symlinks() {
	# lib4bin sometimes leaves broken library symlink, technical debt is getting big...
	find "$DST_LIB_DIR"/ -xtype l -name '*.so*' | while IFS="" read -r broken_link; do
		if [ -n "$broken_link" ]; then
			_err_msg "Broken library symlinks detected in '$broken_link'!"
			_err_msg "Attempting to fix..."

			if link_path=$(readlink -f "$broken_link"); then
				# attempt to find the missing lib at dest first, then host
				for p in "$DST_LIB_DIR" "$LIB_DIR"; do

					i=$(find "$p"/ -name "${link_path##*/}" -print -quit) || :
					if [ -f "$i" ]; then
						rm -f "$broken_link"
						cp -Lv "$i" "$broken_link"
						break
					fi
				done

				if [ -f "$broken_link" ]; then
					_echo "Fixed broken library symlink"
				else
					_err_msg "Failed to fix broken library symlink!"
				fi
			fi
		fi
	done
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
	elif [ "$ANYLINUX_LIB" != 1 ]; then
		_err_msg "ERROR: GTK_CLASS_FIX requires ANYLINUX_LIB=1"
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
	cert_check="$APPDIR"/bin/01-check-ca-certs.hook
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
	  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
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
					clang       |\
					dbus-1      |\
					defaults    |\
					doc         |\
					dotnet      |\
					drirc.d     |\
					et          |\
					factory     |\
					file        |\
					fish        |\
					fonts       |\
					fontconfig  |\
					ghostscript |\
					git         |\
					glib-*      |\
					glvnd       |\
					glycin*     |\
					gtk-doc     |\
					gtksource*  |\
					gvfs        |\
					help        |\
					i18n        |\
					icons       |\
					info        |\
					java        |\
					libdrm      |\
					libthai     |\
					locale      |\
					man         |\
					misc        |\
					mime        |\
					model       |\
					p11-kit     |\
					pipewire    |\
					pixmaps     |\
					qt          |\
					qt4         |\
					qt5         |\
					qt6         |\
					qt7         |\
					ss          |\
					swift       |\
					systemd     |\
					tabset      |\
					terminfo    |\
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
	cfile=$APPDIR/.anylinux-bwrap-wrapper.c
	target=$APPDIR/bin/bwrap
	realbwrap=$APPDIR/bin/bwrap.wrapped


	if [ -f "$realbwrap" ]; then
		return 0 # We wrapped it already
	elif [ -f "$target" ]; then
		# rename the real bwrap
		mv "$target" "$realbwrap"
		# rename the real binary as well
		mv "$APPDIR"/shared/bin/"${target##*/}" "$APPDIR"/shared/bin/"${realbwrap##*/}"
	else
		# this should never happen, we are gonna exit without error however
		# since maybe older versions of webkit2gtk can be installed without bwrap?
		_err_msg "Something went very wrong here because bwrap was not deployed"
		return 0
	fi

	cat <<-'EOF' > "$cfile"
	/*
	 * anylinux-bwrap-wrapper — intercepts bubblewrap to inject essential bind mounts
	 *                     and remap hardcoded paths inside the sandbox.
	 *
	 * Many applications sandbox themselves via bwrap (e.g. WebKitGTK) but dont
	 * account for AppImage paths. Symlinks created by quick-sharun in /tmp become
	 * unresolvable inside the sandbox. This wrapper injects:
	 *   --bind $APPDIR $APPDIR   so the AppImage mount is visible inside
	 *   --bind /tmp /tmp         so sharun's /tmp symlinks stay valid
	 *   --setenv SHARUN_DIR ...  so child processes know the symlink prefix
	 *   --setenv APPDIR ...      so the AppDir path survives into the sandbox
	 *   --setenv PATH ...        so binaries in $APPDIR/bin get executed always
	 *   --proc /proc             so that sharun can read /proc/self/exe and work
	 *
	 * It also rewrites hardcoded command paths (e.g. /usr/bin/xdg-dbus-proxy) to
	 * their AppDir equivalents when found, so the AppImage's bundled binaries are
	 * used instead of the host.
	 *
	 * Two codepaths: "--args N" (options passed through a pipe) and plain argv.
	 */

	#define _GNU_SOURCE
	#include <errno.h>
	#include <fcntl.h>
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <unistd.h>
	#include <limits.h>

	/* ---- Option tables ------------------------------------------------ */
	/*
	 * bwrap options and how many trailing arguments they consume.
	 * Used by find_cmd_idx() to skip over values and not mistake them
	 * for the command to execute.
	 */
	static int opt_arg_count(const char *arg)
	{
	    static const struct { const char *name; int n; } table[] = {
	        { "--overlay",           3 },  /* RWSRC WORKDIR DEST */
	        { "--bind",              2 }, { "--ro-bind",          2 },
	        { "--bind-try",          2 }, { "--ro-bind-try",      2 },
	        { "--dev-bind",          2 }, { "--dev-bind-try",     2 },
	        { "--bind-data",         2 }, { "--ro-bind-data",     2 },
	        { "--file",              2 }, { "--ro-file",          2 },
	        { "--dev-mknod",         2 }, { "--symlink",          2 },
	        { "--chmod",             2 }, { "--bind-fd",          2 },
	        { "--ro-bind-fd",        2 }, { "--setenv",           2 },
	        { "--tmpfs",             1 }, { "--proc",             1 },
	        { "--dev",               1 }, { "--devpts",           1 },
	        { "--mqueue",            1 }, { "--hostname",         1 },
	        { "--seccomp",           1 }, { "--block-fd",         1 },
	        { "--userns",            1 }, { "--uid",              1 },
	        { "--gid",               1 }, { "--chdir",            1 },
	        { "--unsetenv",          1 }, { "--lock-file",        1 },
	        { "--sync-fd",           1 }, { "--info-fd",          1 },
	        { "--json-status-fd",    1 }, { "--add-seccomp-fd",   1 },
	        { "--add-feature",       1 }, { "--args",             1 },
	        { "--dir",               1 }, { "--remount-ro",       1 },
	        { "--perms",             1 }, { "--size",             1 },
	        { "--argv0",             1 }, { "--overlay-src",      1 },
	        { "--tmp-overlay",       1 }, { "--ro-overlay",       1 },
	        { "--exec-label",        1 }, { "--file-label",       1 },
	        { "--userns-block-fd",   1 }, { "--pidns",            1 },
	        { NULL, 0 }
	    };
	    for (int i = 0; table[i].name; i++)
	        if (strcmp(arg, table[i].name) == 0) return table[i].n;
	    return 0;
	}

	/* ---- Helpers ------------------------------------------------------ */

	/* Split a NUL-separated buffer into a null-terminated string array. */
	static int parse_content(const char *buf, size_t len, char ***out)
	{
	    int cap = 64, n = 0;
	    char **arr = calloc(cap, sizeof(char *));
	    if (!arr) return -1;

	    for (size_t i = 0, start = 0; i <= len; i++) {
	        if (i == len || buf[i] == '\0') {
	            size_t slen = i - start;
	            if (slen == 0) { start = i + 1; continue; }
	            if (n >= cap) {
	                cap *= 2;
	                char **tmp = realloc(arr, cap * sizeof(char *));
	                if (!tmp) { for (int k = 0; k < n; k++) free(arr[k]); free(arr); return -1; }
	                arr = tmp;
	            }
	            char *s = malloc(slen + 1);
	            memcpy(s, buf + start, slen);
	            s[slen] = '\0';
	            arr[n++] = s;
	            start = i + 1;
	        }
	    }
	    *out = arr;
	    return n;
	}

	/* Read all data from a file descriptor until EOF. */
	static char *read_fd(int fd, size_t *out_len)
	{
	    size_t cap = 4096, len = 0;
	    char *buf = malloc(cap);
	    if (!buf) return NULL;
	    ssize_t n;
	    while ((n = read(fd, buf + len, cap - len)) > 0) {
	        len += n;
	        if (len == cap) {
	            cap *= 2;
	            char *tmp = realloc(buf, cap);
	            if (!tmp) { free(buf); return NULL; }
	            buf = tmp;
	        }
	    }
	    if (n < 0) { free(buf); return NULL; }
	    buf[len] = '\0';
	    *out_len = len;
	    return buf;
	}

	/* Serialize a string array as NUL-separated bytes into a new pipe; return the read fd. */
	static int serialize_to_pipe(char **args, int n)
	{
	    size_t len = 0;
	    for (int i = 0; i < n; i++) len += strlen(args[i]) + 1;

	    char *buf = malloc(len);
	    if (!buf) return -1;
	    size_t pos = 0;
	    for (int i = 0; i < n; i++) {
	        size_t sl = strlen(args[i]);
	        memcpy(buf + pos, args[i], sl);
	        pos += sl;
	        buf[pos++] = '\0';
	    }

	    int fds[2];
	    if (pipe(fds) != 0) { free(buf); return -1; }
	    fcntl(fds[1], F_SETFD, FD_CLOEXEC); /* write end only */
	    size_t off = 0;
	    while (off < len) {
	        ssize_t w = write(fds[1], buf + off, len - off);
	        if (w <= 0) break;
	        off += w;
	    }
	    close(fds[1]);
	    free(buf);
	    return fds[0];
	}

	/*
	 * Walk bwrap args to find where the command starts.
	 * Returns the index of "--" or the first non-option item,
	 * or n if all items are options.
	 */
	static int find_cmd_idx(char **args, int n)
	{
	    for (int i = 0; i < n; i++) {
	        if (strcmp(args[i], "--") == 0) return i;
	        if (args[i][0] == '-') { i += opt_arg_count(args[i]); continue; }
	        return i;
	    }
	    return n;
	}

	/*
	 * Build the array of --bind/--setenv options we inject into bwrap.
	 * Returns the count of items placed in *out, or -1 on failure.
	 */
	static int build_injections(const char *appdir, const char *sharun_dir,
	                            const char *path, char ***out)
	{
	    struct { const char *flag, *a, *b; } entries[] = {
	        { "--proc",   "/proc",    NULL      },  /* sharun needs /proc for /proc/self/exe to resolve symlinks */
	        { "--bind",   appdir,     appdir     },  /* AppDir visible inside */
	        { "--bind",   "/tmp",     "/tmp"     },  /* must follow webkit's --tmpfs /tmp */
	        { "--setenv", "SHARUN_DIR", sharun_dir },
	        { "--setenv", "APPDIR",   appdir     },
	        { "--setenv", "PATH",     path       },
	    };
	    int nentries = (int)(sizeof(entries) / sizeof(entries[0]));

	    /* Count how many slots we need (skip entries with NULL values for 'a') */
	    int cap = 0;
	    for (int i = 0; i < nentries; i++) {
	        if (!entries[i].a) continue;
	        cap += entries[i].b ? 3 : 2;
	    }

	    char **arr = calloc(cap + 1, sizeof(char *));
	    if (!arr) return -1;

	    int j = 0;
	    for (int i = 0; i < nentries; i++) {
	        if (!entries[i].a) continue;
	        arr[j++] = strdup(entries[i].flag);
	        arr[j++] = strdup(entries[i].a);
	        if (entries[i].b)
	            arr[j++] = strdup(entries[i].b);
	    }
	    arr[j] = NULL;
	    *out = arr;
	    return j;
	}

	/*
	 * Try execvp of bwrap.wrapped, falling back to the same directory
	 * as this wrapper (shared/bin/).
	 */
	static void exec_binary(char **argv)
	{
	    execvp("bwrap.wrapped", argv);
	    char self[PATH_MAX];
	    ssize_t len = readlink("/proc/self/exe", self, sizeof(self) - 1);
	    if (len > 0 && (size_t)len < sizeof(self) - 14) {
	        self[len] = '\0';
	        char *slash = strrchr(self, '/');
	        if (slash) {
	            *slash = '\0';
	            char path[PATH_MAX + 16];
	            snprintf(path, sizeof(path), "%s/bwrap.wrapped", self);
	            execv(path, argv);
	        }
	    }
	    fprintf(stderr, "anylinux-bwrap-wrapper: failed to exec bwrap.wrapped: %s\n",
	            strerror(errno));
	    _exit(1);
	}

	/*
	 * If a path looks like a hardcoded system binary, check whether the AppDir
	 * ships it. Returns a malloc'd AppDir path, or NULL if no match found.
	 */
	static char *try_remap_path(const char *path, const char *appdir)
	{
	    if (!appdir || !path || path[0] != '/') return NULL;
	    const char *base = strrchr(path, '/');
	    if (!base || !base[1]) return NULL;
	    base++;

	    char buf[PATH_MAX];
	    const char *dirs[] = { "bin", "lib", "libexec", NULL };
	    for (int i = 0; dirs[i]; i++) {
	        snprintf(buf, sizeof(buf), "%s/%s/%s", appdir, dirs[i], base);
	        if (access(buf, X_OK) == 0) return strdup(buf);
	    }
	    return NULL;
	}

	/*
	 * Scan exec argv for the command and replace it with an AppDir equivalent
	 * when one exists (e.g. /usr/bin/xdg-dbus-proxy → $APPDIR/bin/xdg-dbus-proxy).
	 */
	static void remap_argv_command(char **new_argv, const char *appdir)
	{
	    if (!appdir) return;
	    for (int i = 1; new_argv[i]; i++) {
	        if (strcmp(new_argv[i], "--") == 0) {
	            if (new_argv[i + 1]) {
	                char *r = try_remap_path(new_argv[i + 1], appdir);
	                if (r) { free(new_argv[i + 1]); new_argv[i + 1] = r; }
	            }
	            return;
	        }
	        if (new_argv[i][0] == '-') { i += opt_arg_count(new_argv[i]); continue; }
	        char *r = try_remap_path(new_argv[i], appdir);
	        if (r) { free(new_argv[i]); new_argv[i] = r; }
	        return;
	    }
	}

	/* ---- Main --------------------------------------------------------- */

	int main(int argc, char *argv[])
	{
	    const char *appdir     = getenv("APPDIR");
	    const char *sharun_dir = getenv("SHARUN_DIR");
	    const char *path       = getenv("PATH");

	    if (argc < 2) {
	        fprintf(stderr, "Usage: anylinux-bwrap-wrapper [bwrap options...]\n");
	        return 1;
	    }

	    /* Build the options we will inject */
	    char **injections;
	    int inject_count = build_injections(appdir, sharun_dir, path, &injections);
	    if (inject_count < 0) {
	        fprintf(stderr, "anylinux-bwrap-wrapper: malloc failed\n");
	        return 1;
	    }

	    /*
	     * Check if this is a "--args N" invocation (webkit passes its
	     * complex option list through a pipe). If so, the options are
	     * in the pipe and argv just holds --args N -- <command>.
	     * We must rewrite the pipe content with our binds appended.
	     */
	    int args_fd = -1, args_idx = -1;
	    for (int i = 1; i < argc; i++) {
	        if (strcmp(argv[i], "--args") == 0 && i + 1 < argc) {
	            args_fd = atoi(argv[i + 1]);
	            args_idx = i;
	            break;
	        }
	    }

	    if (args_fd >= 0) {
	        /* ---- --args N path ---- */

	        /* Read the NUL-separated options from the fd */
	        size_t content_len;
	        char *content = read_fd(args_fd, &content_len);
	        if (!content) {
	            fprintf(stderr, "anylinux-bwrap-wrapper: failed to read --args fd %d\n", args_fd);
	            return 1;
	        }
	        close(args_fd);

	        char **fd_args;
	        int n = parse_content(content, content_len, &fd_args);
	        free(content);
	        if (n < 0) {
	            fprintf(stderr, "anylinux-bwrap-wrapper: parse_content failed\n");
	            return 1;
	        }

	        /*
	         * Find where the command begins. Items before cmd_idx are
	         * bwrap options and go (with injections appended) to a new
	         * pipe. Items at/after cmd_idx (-- / command / args) go to
	         * the exec argv instead.
	         */
	        int cmd_idx = find_cmd_idx(fd_args, n);
	        int opts_seccomp = 0;
	        for (int i = 0; i < cmd_idx; i++) {
	            if (strcmp(fd_args[i], "--seccomp") == 0) {
	                opts_seccomp++;
	                i++;
	            }
	        }

	        /* Build options array (original options minus --seccomp plus injections) */
	        int opt_n = cmd_idx - 2 * opts_seccomp;
	        int total_opt_n = opt_n + inject_count;
	        char **opt_args = calloc(total_opt_n + 1, sizeof(char *));
	        if (!opt_args) return 1;
	        int oi = 0;
	        for (int i = 0; i < cmd_idx; i++) {
	            if (strcmp(fd_args[i], "--seccomp") == 0) {
	                i++; /* skip fd number */
	                continue;
	            }
	            opt_args[oi++] = fd_args[i];
	        }
	        for (int i = 0; i < inject_count; i++)
	            opt_args[oi++] = injections[i];
	        opt_args[total_opt_n] = NULL;

	        int new_fd = serialize_to_pipe(opt_args, total_opt_n);
	        free(opt_args);
	        if (new_fd < 0) {
	            fprintf(stderr, "anylinux-bwrap-wrapper: pipe failed\n");
	            return 1;
	        }

	        /*
	         * Build exec argv:
	         *   bwrap.wrapped --args NEWFD [original argv minus --args N] [fd command]
	         */
	        int new_argc = argc + (n - cmd_idx);
	        char **new_argv = calloc(new_argc + 1, sizeof(char *));
	        if (!new_argv) return 1;

	        char fd_str[32];
	        snprintf(fd_str, sizeof(fd_str), "%d", new_fd);

	        new_argv[0] = "bwrap.wrapped";
	        int j = 1;
	        for (int i = 1; i < argc; i++) {
	            if (i == args_idx) {
	                new_argv[j++] = strdup("--args");
	                new_argv[j++] = strdup(fd_str);
	                i++; /* skip the old fd number */
	            } else {
	                new_argv[j++] = strdup(argv[i]);
	            }
	        }
	        for (int i = cmd_idx; i < n; i++)
	            new_argv[j++] = fd_args[i];
	        new_argv[j] = NULL;

	        remap_argv_command(new_argv, appdir);
	        exec_binary(new_argv);
	        /* not reached */
	    }

	    /* ---- Direct argv path (no --args) ---- */

	    /* Build argv without --seccomp N (this blocks lstat and breaks sharun) */
	    int st_argc = 0;
	    char **st_argv = calloc(argc + 1, sizeof(char *));
	    if (!st_argv) return 1;
	    st_argv[st_argc++] = argv[0];
	    for (int i = 1; i < argc; i++) {
	        if (strcmp(argv[i], "--seccomp") == 0) {
	            i++; /* skip fd number */
	            continue;
	        }
	        st_argv[st_argc++] = argv[i];
	    }
	    st_argv[st_argc] = NULL;

	    /*
	     * Find where to insert our binds in the stripped argv:
	     * before "--" or before the first non-option argument (the command).
	     */
	    int insert_at = 1 + find_cmd_idx(st_argv + 1, st_argc - 1);

	    /* Build exec argv with injections inserted at insert_at */
	    int new_argc = st_argc + inject_count;
	    char **new_argv = calloc(new_argc + 1, sizeof(char *));
	    if (!new_argv) return 1;

	    new_argv[0] = "bwrap.wrapped";
	    int j = 1;
	    for (int i = 1; i < st_argc; i++) {
	        if (i == insert_at) {
	            for (int k = 0; k < inject_count; k++)
	                new_argv[j++] = injections[k];
	        }
	        new_argv[j++] = strdup(st_argv[i]);
	    }
	    /* If no suitable insertion point was found, tack on at the end */
	    if (insert_at == st_argc) {
	        for (int k = 0; k < inject_count; k++)
	            new_argv[j++] = injections[k];
	    }
	    new_argv[j] = NULL;

	    free(st_argv);

	    remap_argv_command(new_argv, appdir);
	    exec_binary(new_argv);
	    return 1;
	}
	EOF

	cc -Wall -Wextra -O2 -o "$APPDIR"/shared/bin/"${target##*/}" "$cfile"
	ln "$APPDIR"/sharun "$target"
	chmod +x "$target"
	_echo "* added bwrap wrapper!"
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

	# This python library ships a certificate with no way to override!
	# https://github.com/certifi/python-certifi/issues/271
	# https://github.com/certifi/python-certifi/issues/200
	#
	# some distros replace it with a symlink to the host certs, we have to
	# make sure to ship the actual certificate since there is no override...
	#
	set -- "$DST_LIB_DIR"/python*/site-packages/certifi/cacert.pem
	if [ -L "$1" ] && c=$(readlink -f "$1"); then
		rm -f "$1"
		cp "$c" "$1"
	fi

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
	if [ -f "$PATH_MAPPING_SCRIPT" ]; then
		return 0
	fi
	cat <<-'EOF' > "$PATH_MAPPING_SCRIPT"
	#!/bin/sh

	# this script makes symnlinks to hardcoded random dirs that
	# were patched away by quick-sharun when hardcoded paths are
	# detected or when 'PATH_MAPPING_HARDCODED' is used

	_tmp_bin=""
	_tmp_lib=""
	_tmp_share=""

	if [ -n "$_tmp_bin" ]; then
	        LC_ALL=C ln -sfn "$APPDIR"/bin /tmp/"$_tmp_bin" || :
	fi
	if [ -n "$_tmp_lib" ]; then
	        LC_ALL=C ln -sfn "$APPDIR"/lib /tmp/"$_tmp_lib" || :
	fi
	if [ -n "$_tmp_share" ]; then
	        LC_ALL=C ln -sfn "$APPDIR"/share /tmp/"$_tmp_share" || :
	fi
	EOF
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
			pipewire*|\
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
	# also deduplicate since the same var may be set multiple times
	if [ -f "$APPDIR"/.env ]; then
		sorted_env="$(LC_ALL=C awk '
			{
				if ($0 ~ /^unset/) {
					unset_array[++u] = $0
				} else {
					if (!seen[$0]++) print
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

	"$APPDIR"/sharun -g || :

	# on debian some libs may hardcode paths like /usr/lib/x86_64-linux-gnu
	# make a compat symlink so patched paths resolve to bundled libs
	d=$APPIMAGE_ARCH-linux-gnu
	case "$LIB_DIR" in
		*/"$d"*)
			( cd "$DST_LIB_DIR" && ln -s . "$d" 2>/dev/null || : )
			;;
	esac
}

_strip_bins_and_libs() {
	if [ "$NO_STRIP" = 1 ]; then
		return 0
	elif ! _is_cmd strip; then
		_err_msg "Skipping strip since 'strip' is NOT installed!"
		sleep 5
		return 0
	fi

	if [ "$NO_STRIP" != 'libraries' ]; then
		find "$APPDIR" -type f -name '*.so*' \
			-exec strip -s -R .comment --strip-unneeded {} \; || :
		_echo "* stripped libraries"
	fi

	if [ "$NO_STRIP" != 'binaries' ]; then
		while IFS="" read -r f; do
			if [ ! -x "$f" ]; then
				continue
			elif _is_bun_binary "$f"; then
				continue # bun binaries are delicate
			fi
			case "$f" in
				*/python*) continue;; # python binaries break
			esac
			strip -s -R .comment --strip-unneeded "$f" || :
		done <<-EOF
		$(find "$APPDIR"/shared/bin/ "$APPDIR"/lib*/ -type f)
		EOF
		_echo "* stripped binaries"
	fi
}

# lib4bin sometimes leaves duplicates of libraries instead of making the proper symlink
_deduplicate_libs() {
	find "$APPDIR"/lib/ -name '*.so.*' -type f | while IFS="" read -r lib; do
		_lib_dirname=${lib%/*}
		_lib_basename=${lib##*/}
		_target_lib=$_lib_basename
		_count=0
		while [ "$_count" -lt 5 ]; do
			_shorter_name=${_lib_basename%.*}
			if [ "$_shorter_name" = "$_lib_basename" ]; then
				break
			fi
			# now check if there is a similar name lib with shoter name
			_duplicate_lib=$_lib_dirname/$_shorter_name
			if [ -f "$_duplicate_lib" ] && [ ! -L "$_duplicate_lib" ]; then
				if cmp -s "$_duplicate_lib" "$lib"; then
					(
						cd "$_lib_dirname"
						ln -svf "$_target_lib" "$_shorter_name"
					)
				fi
			fi
			_lib_basename=$_shorter_name
			_count=$((_count + 1))
		done
	done
}

_add_apprun() {
	f=$APPDIR/AppRun
	if [ -f "$f" ]; then
		return 0
	fi
	_echo "Adding '$f'..."
	cat <<-'EOF' > "$f"
	#!/bin/sh

	# Example AppRun for using the hooks of this repository.
	# NOTE: It is meant to be used with sharun which uses a top level bin dir

	if [ "$APPRUN_DEBUG" = 1 ]; then
	        set -x
	fi

	set -e

	APPDIR=$(cd "${0%/*}" && echo "$PWD")
	MAIN_BIN=@MAIN_BIN@
	ARG0="${ARGV0:-$0}"

	unset ARGV0

	export APPIMAGE_ARCH=@APPIMAGE_ARCH@
	export HOSTPATH=$PATH
	export PATH=$APPDIR/bin:$PATH
	export ARG0 APPDIR PATH

	# Allow users to set env variables for specific AppImage
	# This feature only works with the uruntime
	if [ "$1" = '--appimage-add-env' ]; then
	        shift
	        for v do
	            echo "$v" >> "$APPIMAGE".env
	            >&2 echo "Added '$v' to $APPIMAGE.env"
	        done
	        exit 0
	fi

	__fedora_cert=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
	if [ ! -f /etc/ssl/certs/ca-certificates.crt ] && [ -f "$__fedora_cert" ]; then
	        CURL_CA_BUNDLE=${CURL_CA_BUNDLE:-$__fedora_cert}
	        REQUESTS_CA_BUNDLE=${REQUESTS_CA_BUNDLE:-$__fedora_cert}
	        SSL_CERT_FILE=${SSL_CERT_FILE:-$__fedora_cert}
	        export CURL_CA_BUNDLE REQUESTS_CA_BUNDLE SSL_CERT_FILE
	fi

	if [ -f "$APPDIR"/AppRun.lib ]; then
	        . "$APPDIR"/AppRun.lib
	        for hook in "$APPDIR"/bin/*.hook; do
	            [ -e "$hook" ] || continue
	            . "$hook"
	        done
	fi

	# Check if ARG0 matches a binary, fallback to $1, then binary in .desktop
	if [ -f "$APPDIR"/bin/"${ARG0##*/}" ]; then
	        TO_LAUNCH=$APPDIR/bin/${ARG0##*/}
	elif [ -f "$APPDIR"/bin/"$1" ]; then
	        TO_LAUNCH=$APPDIR/bin/$1
	        shift
	else
	        TO_LAUNCH=$APPDIR/bin/$MAIN_BIN
	fi

	set -- "$TO_LAUNCH" "$@"

	# If LD_DEBUG=libs is set outside the AppImage the output is not helpful
	# because it will include the libs of sh, grep, cat, etc from the hooks
	# with this var we can set LD_DEBUG=libs for the bundled application only
	if [ "$APPIMAGE_DEBUG" = 1 ]; then
	        cat /etc/os-release >"$PWD"/"${APPIMAGE##*/}"-debug.log || :
	        export LD_DEBUG=libs
	        export VK_LOADER_DEBUG=all
			export LIBGL_DEBUG=verbose
			export EGL_LOG_LEVEL=debug
	        export LC_ALL=C
	        export SHARUN_PRINTENV=1
	        "$@" 2>>"$PWD"/"${APPIMAGE##*/}"-debug.log || :
	        >&2 echo "Debug log at: '$PWD/${APPIMAGE##*/}-debug.log'"
	else
	        exec "$@"
	fi
	EOF

	chmod +x "$f"

	sed -i \
		-e "s|@MAIN_BIN@|$MAIN_BIN|"  \
		-e "s|@APPIMAGE_ARCH@|$APPIMAGE_ARCH|" \
		"$f"

	_echo "* Added $f"
}

_add_hooks_library() {
	f=$APPDIR/AppRun.lib
	if [ -f "$f" ]; then
		return 0
	fi
	_echo "Adding '$f'..."
	cat <<-'EOF' > "$f"
	#!/bin/sh

	HOST_HOME=${REAL_HOME:-$HOME}
	HOST_XDG_CONFIG_HOME=${REAL_XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOST_HOME/.config}}
	HOST_XDG_DATA_HOME=${REAL_XDG_DATA_HOME:-${XDG_DATA_HOME:-$HOST_HOME/.local/share}}
	HOST_XDG_CACHE_HOME=${REAL_XDG_CACHE_HOME:-${XDG_CACHE_HOME:-$HOST_HOME/.cache}}
	HOST_XDG_STATE_HOME=${REAL_XDG_STATE_HOME:-${XDG_STATE_HOME:-$HOST_HOME/.local/state}}

	export HOST_HOME HOST_XDG_CONFIG_HOME HOST_XDG_DATA_HOME HOST_XDG_CACHE_HOME HOST_XDG_STATE_HOME

	BINDIR=${XDG_BIN_HOME:-~/.local/bin}
	DATADIR=${XDG_DATA_HOME:-~/.local/share}
	CONFIGDIR=${XDG_CONFIG_HOME:-~/.config}
	CACHEDIR=${XDG_CACHE_HOME:-~/.cache}
	STATEDIR=${XDG_STATE_HOME:-~/.local/state}

	# always change XDG_CACHE_HOME to our own dedicated location
	# using the host XDG_CACHE_HOME has been a source of issues
	# See: https://github.com/pkgforge-dev/Anylinux-AppImages/issues/657
	if [ "$USE_HOST_XDG_CACHE_HOME" != 1 ] && [ -n "$APPIMAGE" ]; then
	        case "$XDG_CACHE_HOME" in
	                *"$APPIMAGE"*) # make sure we are not using the portable cache first
	                        :
	                        ;;
	                *)
	                        _cache_dir=$CACHEDIR/AppImage-Cache
	                        if [ -d "$_cache_dir" ] || mkdir -p "$_cache_dir" 2>/dev/null; then
	                                export XDG_CACHE_HOME="$_cache_dir"
	                        fi
	                        ;;
	        esac
	fi

	err_msg(){
	        >&2 printf '\033[1;31m%s\033[0m\n' " $*"
	}

	is_cmd() {
	        if [ "$1" = '--any' ]; then
	                shift
	                for cmd do
	                        if command -v "$cmd" 1>/dev/null; then
	                                return 0
	                        fi
	                done
	                return 1
	        else
	                for cmd do
	                        command -v "$cmd" 1>/dev/null || return 1
	                done
	        fi
	        return 0
	}

	run_gui_sudo() {
	        if   [ "$(id -u)" = 0 ];               then _sudocmd=""
	        elif _sudocmd=$(command -v pkexec);    then :
	        elif _sudocmd=$(command -v lxqt-sudo); then :
	        elif _sudocmd=$(command -v run0);      then set -- --via-shell "$@"
	        fi
	        if [ "$1" = --check ]; then
	                [ -n "$_sudocmd" ] || [ "$(id -u)" = 0 ] || return 1
	                return 0
	        else
	                if [ -z "$_sudocmd" ] && [ "$(id -u)" != 0 ]; then
	                        err_msg "We need 'pkexec' or 'lxqt-sudo' or 'run0' to perform this operation"
	                        return 1
	                fi
	        fi
	        $_sudocmd "$@"
	}

	download() {
	        if   _download_cmd=$(command -v wget); then set -- -O "$@"
	        elif _download_cmd=$(command -v curl); then set -- -Lo "$@"
	        else
	                err_msg "We need 'wget' or 'curl' to download $1"
	                return 1
	        fi
	        log=${TMPDIR:-/tmp}/._download.log
	        if ! "$_download_cmd" "$@" 2>"$log"; then
	                cat "$log"
	                err_msg "Download failed!"
	                return 1
	        fi
	        rm -f "$log"
	}


	# the following function are used by notify

	# display functions, these might return non 0 depending on user input
	_display_info() {
	        set -- "INFO: $*"
	        if   is_cmd kdialog;   then kdialog --msgbox "$*"
	        elif is_cmd qarma;     then qarma --info --text "$*"
	        elif is_cmd yad;       then yad --info --text "$*"
	        elif is_cmd zenity;    then zenity --info --text "$*"
	        elif is_cmd gxmessage; then gxmessage -center "$*"
	        elif is_cmd xmessage;  then xmessage -center "$*"
	        else _notification=0   _display_with_host_term "$*"
	        fi
	}

	_display_error() {
	        set -- "ERROR: $*"
	        if   is_cmd kdialog;   then kdialog --error "$*"
	        elif is_cmd qarma;     then qarma --error --text "$*"
	        elif is_cmd yad;       then yad --error --text "$*"
	        elif is_cmd zenity;    then zenity --error --text "$*"
	        elif is_cmd gxmessage; then gxmessage -center "$*"
	        elif is_cmd xmessage;  then xmessage -center "$*"
	        else _notification=0   _display_with_host_term "$*"
	        fi
	}

	_display_warning() {
	        set -- "WARNING: $*"
	        if   is_cmd kdialog;   then kdialog --sorry "$*"
	        elif is_cmd qarma;     then qarma --warning --text "$*"
	        elif is_cmd yad;       then yad --warning --text "$*"
	        elif is_cmd zenity;    then zenity --warning --text "$*"
	        elif is_cmd gxmessage; then gxmessage -center "$*"
	        elif is_cmd xmessage;  then xmessage -center "$*"
	        else _notification=0    _display_with_host_term "$*"
	        fi
	}

	_display_question() {
	        set -- "QUESTION: $*"
	        if   is_cmd kdialog;   then kdialog --yesno "$*"
	        elif is_cmd qarma;     then qarma --question --text "$*"
	        elif is_cmd yad;       then yad --question --text "$*"
	        elif is_cmd zenity;    then zenity --question --text "$*"
	        elif is_cmd gxmessage; then gxmessage -center -buttons "Yes:0,No:1" "$*"
	        elif is_cmd xmessage;  then xmessage -center -buttons "Yes:0,No:1" "$*"
	        else _notification=0    _display_with_host_term "$*"
	        fi
	}

	# notify functions, these will always return 0 unless there are no deps
	_notify_info() {
	        set -- "INFO: $*"
	        if   is_cmd notify-send; then notify-send "$*" || :
	        elif is_cmd qarma;       then qarma --info --text "$*" || :
	        elif is_cmd kdialog;     then kdialog --passivepopup "$*" || :
	        elif is_cmd yad;         then yad --window-type=notification --text "$*" || :
	        elif is_cmd zenity;      then zenity --info --text "$*" || :
	        elif is_cmd xmessage;    then xmessage -center "$*" || :
	        elif is_cmd gxmessage;   then gxmessage -center "$*" || :
	        else _notification=1     _display_with_host_term "$*"
	        fi
	}

	_notify_error() {
	        set -- "ERROR: $*"
	        if   is_cmd notify-send; then notify-send -u critical "$*" || :
	        elif is_cmd kdialog;     then kdialog --error "$*" || :
	        elif is_cmd qarma;       then qarma --error --text "$*" || :
	        elif is_cmd yad;         then yad --window-type=notification --text "$*" || :
	        elif is_cmd zenity;      then zenity --error --text "$*" || :
	        elif is_cmd xmessage;    then xmessage -center "$*" || :
	        elif is_cmd gxmessage;   then gxmessage -center "$*" || :
	        else _notification=1     _display_with_host_term "$*"
	        fi
	}

	_notify_warning() {
	        set -- "WARNING: $*"
	        if   is_cmd notify-send; then notify-send -u critical "$*" || :
	        elif is_cmd kdialog;     then kdialog --sorry "$*" || :
	        elif is_cmd qarma;       then qarma --warning --text "$*" || :
	        elif is_cmd yad;         then yad --window-type=notification --text "$*" || :
	        elif is_cmd zenity;      then zenity --warning --text "$*" || :
	        elif is_cmd gxmessage;   then gxmessage -center "$*" || :
	        elif is_cmd xmessage;    then xmessage -center "$*" || :
	        else _notification=1     _display_with_host_term "$*"
	        fi
	}

	# extreme measure
	_display_with_host_term() {
	        _message=$*
	        _tmpfile=${TMPDIR:-/tmp}/.${0##*/}-no-gui-fallback

	        cmd_notification="echo '$_message'; read yn"
	        cmd_display="
	                trap 'echo 0 > \"$_tmpfile\"; exit' HUP TERM
	                echo '$_message'
	                printf '\n%s''   (Yes/No)?: ';
	                while :; do
	                        read yn
	                        case \$yn in
	                                Y*|y*) echo 1 > '$_tmpfile'; break;;
	                                N*|n*) echo 0 > '$_tmpfile'; break;;
	                                *)     echo 'Please type Yes or No' ;;
	                        esac
	                done
	        "

	        if [ "$_notification" = 1 ]; then
	                tcmd="$cmd_notification"
	        else
	                tcmd="$cmd_display"
	        fi

	        # normal terminals
	        if   is_cmd alacritty;  then alacritty  -e sh -c "$tcmd" &
	        elif is_cmd wezterm;    then wezterm    -e sh -c "$tcmd" &
	        elif is_cmd konsole;    then konsole    -e sh -c "$tcmd" &
	        elif is_cmd lxterminal; then lxterminal -e sh -c "$tcmd" &
	        elif is_cmd kitty;      then kitty      -e sh -c "$tcmd" &
	        elif is_cmd urxvt;      then urxvt      -e sh -c "$tcmd" &
	        elif is_cmd xterm;      then xterm      -e sh -c "$tcmd" &
	        # mmmm
	        elif is_cmd gnome-terminal; then gnome-terminal -- sh -c "$tcmd" &
	        # these need extra quotes for some reason
	        elif is_cmd ptyxis;         then ptyxis         -x "sh -c \"$tcmd\"" &
	        elif is_cmd qterminal;      then qterminal      -e "sh -c \"$tcmd\"" &
	        elif is_cmd mate-terminal;  then mate-terminal  -e "sh -c \"$tcmd\"" &
	        elif is_cmd xfce4-terminal; then xfce4-terminal -e "sh -c \"$tcmd\"" &
	        else
	                err_msg "Cannot find suitable binary to perform operation!"
	                return 127
	        fi

	        if [ "$_notification" = 1 ]; then
	                return 0
	        fi

	        _elapsed=0
	        _timeout=150  # 15 seconds
	        while :; do
	                if [ -f "$_tmpfile" ] || [ "$_elapsed" -ge "$_timeout" ]; then
	                        break
	                fi
	                sleep 0.1
	                _elapsed=$(( _elapsed + 1 ))
	        done

	        read -r _reply < "$_tmpfile"
	        rm -f "$_tmpfile"

	        if [ "$_reply" = "1" ]; then
	                return 0
	        else
	                return 1
	        fi
	}

	notify() {
	        case "$1" in
	                --display-info|-di)     shift; _display_info     "$@";;
	                --display-error|-de)    shift; _display_error    "$@";;
	                --display-warning|-dw)  shift; _display_warning  "$@";;
	                --display-question|-dq) shift; _display_question "$@";;
	                --notify-info|-ni)      shift; _notify_info      "$@";;
	                --notify-error|-ne)     shift; _notify_error     "$@";;
	                --notify-warning|-nw)   shift; _notify_warning   "$@";;
	                # act as notify-send ARG wrapper when no flag is given
	                *) _notify_info "$@";;
	        esac
	}
	EOF
	chmod +x "$f"
	_echo "* Added $f"
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

	if ! mkdir -p "$OUTPATH"; then
		_err_msg "ERROR: Cannot create output directory: '$OUTPATH'"
		exit 1
	fi

	if [ ! -x "$APPIMAGETOOL" ]; then
		_echo "Downloading appimagetool from $APPIMAGETOOL_LINK"
		_download "$APPIMAGETOOL" "$APPIMAGETOOL_LINK"
		chmod +x "$APPIMAGETOOL"
	fi

	_echo "------------------------------------------------------------"
	_echo "Making AppImage..."
	_echo "------------------------------------------------------------"

	if ! "$APPIMAGETOOL"; then
		_err_msg "ERROR: Something went wrong making the AppImage!"
		exit 1
	fi

	set -- "$OUTPATH"/*.AppImage
	if [ ! -f "$1" ]; then
		_err_msg "ERROR: No AppImage was produced??"
		exit 1
	else
		chmod +x "$1"
	fi

	_echo "------------------------------------------------------------"
	_echo "All done! AppImage at: $1"
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
_fix_broken_symlinks
_check_always_software
_handle_bins_scripts

echo ""
_echo "------------------------------------------------------------"
echo ""

_check_main_bin
_map_paths_ld_preload_open
_map_paths_binary_patch
_add_anylinux_lib
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
	*/gio/modules/*.so*)
		src_gio_cache=$LIB_DIR/gio/modules/giomodule.cache
		dst_gio_cache=$DST_LIB_DIR/gio/modules/giomodule.cache
		if [ -f "$src_gio_cache" ] && [ ! -f "$dst_gio_cache" ]; then
			cp -v "$src_gio_cache" "$dst_gio_cache"
			_echo "* added $src_gio_cache"
		fi
		;;
	*/libgio-*.so*)
		f=$APPDIR/bin/gio-launch-desktop
		if [ ! -x "$f" ]; then
			cat <<-'EOF' > "$f"
			#!/bin/sh
			export GIO_LAUNCHED_DESKTOP_FILE_PID=$$
			exec "$@"
			EOF
			chmod +x "$f"
			_echo "* added $f wrapper"
		fi
		;;
	*/libglib-*.so*)
		_glibver=$(echo "$lib" | awk -F'-' '{print $NF}' | sed "s|\.so.*||")
		src_glib_schema_dir=/usr/share/glib-$_glibver/schemas
		dst_glib_schema_dir=$APPDIR/share/glib-$_glibver/schemas
		if [ -d "$src_glib_schema_dir" ] && [ ! -d "$dst_glib_schema_dir" ]; then
			mkdir -p "$dst_glib_schema_dir"
			cp -r "$src_glib_schema_dir"/* "$dst_glib_schema_dir"
			_echo "* added $src_glib_schema_dir"
		fi

		# apps may crash when the host has no mime database
		src_mime_dir=/usr/share/mime
		dst_mime_dir=$APPDIR/share/mime
		if [ -d "$src_mime_dir" ] && [ ! -d "$dst_mime_dir" ]; then
			cp -r "$src_mime_dir" "$dst_mime_dir"
			rm -rf "$dst_mime_dir"/packages # bloat
			_echo "* added $src_mime_dir"
		fi
		;;
	*/gdk-pixbuf-*/*/loaders/*.so*)
		src_gdkpixbuf_cache=$(echo "$LIB_DIR"/gdk-pixbuf-*/*/loaders.cache)
		dst_gdkpixbuf_cache=${lib%/*}.cache
		if [ -f "$src_gdkpixbuf_cache" ] && [ ! -f "$dst_gdkpixbuf_cache" ]; then
			cp -v "$src_gdkpixbuf_cache" "$dst_gdkpixbuf_cache"
			sed -i -e 's|/usr/lib/.*/loaders/||g' "$dst_gdkpixbuf_cache"
			_echo "* added $src_gdkpixbuf_cache"
		fi
		;;
	*/gtk-*/*/immodules/*.so)
		_gtkver=$(echo "$lib" | tr '/' '\n' | grep '^gtk-')
		src_gtk_immodule_cache=$(echo "$LIB_DIR"/"$_gtkver"/*/immodules.cache)
		dst_gtk_immodule_cache=${lib%/*}.cache
		if [ -f "$src_gtk_immodule_cache" ] && [ ! -f "$dst_gtk_immodule_cache" ]; then
			cp -v "$src_gtk_immodule_cache" "$dst_gtk_immodule_cache"
			sed -i -e 's|/usr/lib/.*/immodules/||g' "$dst_gtk_immodule_cache"
			_echo "* added $src_gtk_immodule_cache"
		fi
		;;
	*/libglycin*.so*)
		if [ "$GNOME_GLYCIN" != 1 ]; then
			continue # only GNOME glycin needs handling
		fi
		_add_bwrap_wrapper
		src_glycin_conf_dir=/usr/share/glycin-loaders
		dst_glycin_conf_dir=$APPDIR/share/glycin-loaders
		if [ -d "$src_glycin_conf_dir" ] && [ ! -d "$dst_glycin_conf_dir" ]; then
			cp -r "$src_glycin_conf_dir" "$dst_glycin_conf_dir"
			sed -i -e 's|/usr/lib.*/||g' "$dst_glycin_conf_dir"/*/*/*.conf
			_echo "* added $src_glycin_conf_dir"
		fi
		;;
	*/libgtksourceview-*.so*)
		_gtk_srcview_ver=$(echo "$lib" |  awk -F'-' '{print $NF}' | sed "s|\.so.*||")
		src_gtk_srcview_dir=/usr/share/gtksourceview-$_gtk_srcview_ver
		dst_gtk_srcview_dir=$APPDIR/share/gtksourceview-$_gtk_srcview_ver
		if [ -d "$src_gtk_srcview_dir" ] && [ ! -d "$dst_gtk_srcview_dir" ]; then
			cp -r "$src_gtk_srcview_dir" "$dst_gtk_srcview_dir"
			_echo "* added $src_gtk_srcview_dir"
		fi
		;;
	*/libfontconfig.so*)
		src_fontconfig_config=/etc/fonts/fonts.conf
		dst_fontconfig_config=$APPDIR/etc/fonts/fonts.conf
		if [ -f "$src_fontconfig_config" ] && [ ! -f "$dst_fontconfig_config" ]; then
			mkdir -p "${dst_fontconfig_config%/*}"
			cp -v "$src_fontconfig_config" "$dst_fontconfig_config"
			_echo "* added $src_fontconfig_config"
		fi
		;;
	*/libfolks*.so*)
		src_folks_dir=$LIB_DIR/folks
		dst_folks_dir=$DST_LIB_DIR/folks
		if [ -d "$src_folks_dir" ] && [ ! -d "$dst_folks_dir" ]; then
			cp -r "$src_folks_dir" "$dst_folks_dir"
			_echo "* added $src_folks_dir"
		fi
		;;
	*/libthai*.so*)
		src_libthai_dir=/usr/share/libthai
		dst_libthai_dir=$APPDIR/share/libthai
		if [ -d "$src_libthai_dir" ] && [ ! -d "$dst_libthai_dir" ]; then
			cp -r "$src_libthai_dir" "$dst_libthai_dir"
			_echo "* added $src_libthai_dir"
		fi
		;;
	*/libasound*.so*)
		src_alsaconf_dir=/usr/share/alsa
		dst_alsaconf_dir=$APPDIR/share/alsa
		if [ -d "$src_alsaconf_dir" ] && [ ! -d "$dst_alsaconf_dir" ]; then
			cp -r "$src_alsaconf_dir" "$dst_alsaconf_dir"
			_echo "* added $src_alsaconf_dir"
		fi
		# Adding alsa config dir is not enough, the file is harcoded
		# to load additional files on the host
		f=$APPDIR/share/alsa/alsa.conf
		if [ -f "$f" ] && ! grep -q 'SHARUN_DIR' "$f"; then
			sed -i -e \
			  's|"/etc/alsa/conf.d"|"/etc/alsa/conf.d"\n\t\t\t{ @func concat strings [ { @func getenv vars [ SHARUN_DIR ] default "" } "/share/alsa/alsa.conf.d" ] }|' \
			  "$f"
		fi
		;;
	*/libxkbcommon*.so*)
		src_xkb_dir=/usr/share/X11/xkb
		dst_xkb_dir=$APPDIR/share/X11/xkb
		if [ -d "$src_xkb_dir" ] && [ ! -d "$dst_xkb_dir" ]; then
			mkdir -p "$dst_xkb_dir"
			cp -r "$src_xkb_dir"/* "$dst_xkb_dir"
			_echo "* added $src_xkb_dir"
		fi
		;;
	*/libX11.so*)
		src_xlocale_dir=/usr/share/X11/locale
		dst_xlocale_dir=$APPDIR/share/X11/locale
		if [ -d "$src_xlocale_dir" ] && [ ! -d "$dst_xlocale_dir" ]; then
			mkdir -p "$dst_xlocale_dir"
			cp -r "$src_xlocale_dir"/* "$dst_xlocale_dir"
			_echo "* added $src_xlocale_dir"
		fi
		;;
	*/libgbm.so*) # This hook should never be hit since OpenGL deployment already handles this
		src_gbm_backends_dir=$LIB_DIR/gbm
		dst_gbm_backends_dir=$DST_LIB_DIR/gbm
		if [ -d "$src_gbm_backends_dir" ] && [ ! -d "$dst_gbm_backends_dir" ]; then
			cp -r "$src_gbm_backends_dir" "$dst_gbm_backends_dir"
			_echo "* added $src_gbm_backends_dir"
		fi
		;;
	*/libEGL_mesa.so*)
		src_glvnd_dir=/usr/share/glvnd/egl_vendor.d
		dst_glvnd_dir=$APPDIR/share/glvnd/egl_vendor.d
		if [ -d "$src_glvnd_dir" ] && [ ! -d "$dst_glvnd_dir" ]; then
			mkdir -p "$dst_glvnd_dir"
			cp -v "$src_glvnd_dir"/*.json "$dst_glvnd_dir"
			sed -i -e 's|/usr/lib.*/||g' "$dst_glvnd_dir"/*.json
			_echo "* added $src_glvnd_dir"
		fi

		src_drirc_dir=/usr/share/drirc.d
		dst_drirc_dir=$APPDIR/share/drirc.d
		if [ -d "$src_drirc_dir" ] && [ ! -d "$dst_drirc_dir" ]; then
			cp -r "$src_drirc_dir" "$dst_drirc_dir"
			_echo "* added $src_drirc_dir"
		fi
		;;
	*/libdrm_amdgpu.so*)
		src_libdrm_dir=/usr/share/libdrm
		dst_libdrm_dir=$APPDIR/share/libdrm
		if [ -d "$src_libdrm_dir" ] && [ ! -d "$dst_libdrm_dir" ]; then
			cp -r "$src_libdrm_dir" "$dst_libdrm_dir"
			_echo "* added $src_libdrm_dir"
		fi
		;;
	*/libvulkan.so*)
		src_vulkan_dir=/usr/share/vulkan/icd.d
		dst_vulkan_dir=$APPDIR/share/vulkan/icd.d
		if [ -d "$src_vulkan_dir" ] && [ ! -d "$dst_vulkan_dir" ]; then
			mkdir -p "$dst_vulkan_dir"
			cp -v "$src_vulkan_dir"/*.json "$dst_vulkan_dir"
			sed -i -e 's|/usr/lib.*/||g' "$dst_vulkan_dir"/*.json
			_echo "* added $src_vulkan_dir"
		fi
		;;
	*/libVkLayer*.so*)
		# find vulkan layer icd file
		src_vklayer_icd=$(grep -r "${lib##*/}" /usr/share/vulkan/* | awk -F':' '{print $1; exit}')
		dst_vklayer_icd=$APPDIR/${src_vklayer_icd#/usr/}
		if [ -f "$src_vklayer_icd" ] && [ ! -f "$dst_vklayer_icd" ]; then
			mkdir -p "${dst_vklayer_icd%/*}"
			cp -vL "$src_vklayer_icd" "$dst_vklayer_icd"
			sed -i -e 's|/usr/lib.*/||g' "$dst_vklayer_icd"
			_echo "* added vulkan layer icd: $src_vklayer_icd"
		fi
		;;
	# this hook is a common false positive
	# because a lot of applications execute commands thru the system shell
	# and that often links to this library, causing overdeployment of terminfo files
	*/libncursesw.so*|*/libcursesw.so*|*/libcurses.so*)
		src_terminfo_dir=/usr/share/terminfo
		dst_terminfo_dir=$APPDIR/share/terminfo
		if [ -d "$src_terminfo_dir" ] && [ ! -d "$dst_terminfo_dir" ]; then
			cp -r "$src_terminfo_dir" "$dst_terminfo_dir"
			_echo "* added $src_terminfo_dir"
		fi

		src_tabset_dir=/usr/share/tabset
		dst_tabset_dir=$APPDIR/share/tabset
		if [ -d "$src_tabset_dir" ] && [ ! -d "$dst_tabset_dir" ]; then
			cp -r "$src_tabset_dir" "$dst_tabset_dir"
			_echo "* added $src_tabset_dir"
		fi
		;;
	*/qt*/plugins/*.so)
		f=$APPDIR/bin/qt.conf
		if [ ! -f "$f" ]; then
			_qtdir=${lib#$DST_LIB_DIR/} # leaves qt*
			_qtdir=${_qtdir%%/*}        # gets basename
			_libdir=${DST_LIB_DIR##*/}  # libdir basename (lib or lib32)
			cat <<-EOF > "$f"
			[Paths]
			Prefix = ../$_libdir/$_qtdir
			Plugins = plugins
			Imports = qml
			Qml2Imports = qml
			EOF
			_echo "* added $f "
		fi

		# move the gtk3 plugin back into the AppDir
		if [ -f "$TMPDIR"/libqgtk3.so ]; then
			d=$DST_LIB_DIR/$QT_DIR/plugins/platformthemes
			mkdir -p "$d"
			mv "$TMPDIR"/libqgtk3.so "$d"
		fi

		# deploy translation files
		src_qt_trans=/usr/share/$QT_DIR/translations
		dst_qt_trans=$DST_LIB_DIR/$QT_DIR/translations
		if [ -d "$src_qt_trans" ] && [ ! -d "$dst_qt_trans" ]; then
			mkdir -p "${dst_qt_trans%/*}"
			# debloat a bit since we don't need all of them
			cp -r "$src_qt_trans" "$dst_qt_trans"
			rm -f "$dst_qt_trans"/assistant*.qm
			rm -f "$dst_qt_trans"/designer*.qm
			rm -f "$dst_qt_trans"/linguist*.qm
			_echo "* added $src_qt_trans"
		fi
		;;
	*/libgs.so*)
		src_gs_dir=/usr/share/ghostscript
		dst_gs_dir=$APPDIR/share/ghostscript
		if [ -d "$src_gs_dir" ] && [ ! -d "$dst_gs_dir" ]; then
			cp -r "$src_gs_dir" "$dst_gs_dir"
			(
			  cd "$dst_gs_dir"
			  d=$(echo ./*/Resource/Init)
			  if [ -d "$d" ]; then
			  	echo "GS_LIB=\${SHARUN_DIR}/share/ghostscript/${d#./}" >> "$APPENV"
			  else
			  	echo 'GS_LIB=${SHARUN_DIR}/share/ghostscript/Resource/Init' >> "$APPENV"
			  fi
			)
			_echo "* added $src_gs_dir"
		fi
		;;
	*/libmagic.so*)
		# sharun only checks for $SHARUN_DIR/share/file/misc/magic.mgc
		# but on ubuntu for example, the file is located in /usr/share/file/magic.mgc
		# so we need to find the magic.mgc file and copy it to dst
		src_magic_file=$(find -L /usr/share/file -type f -name magic.mgc -print -quit) || :
		dst_magic_file=$APPDIR/share/file/misc/magic.mgc
		if [ -f "$src_magic_file" ] && [ ! -f "$dst_magic_file" ]; then
			mkdir -p "${dst_magic_file%/*}"
			cp -vL "$src_magic_file" "$dst_magic_file"
			_echo "* added $src_magic_file"
		fi
		;;
	*/libgirepository-*.so*)
		_girver=$(echo "$lib" | awk -F'-' '{print $NF}' | sed "s|\.so.*||")
		src_girepository_dir=$LIB_DIR/girepository-$_girver
		dst_girepository_dir=$DST_LIB_DIR/girepository-$_girver
		if [ -d "$src_girepository_dir" ] && [ ! -d "$dst_girepository_dir" ]; then
			cp -r "$src_girepository_dir" "$dst_girepository_dir"
			_echo "* added $src_girepository_dir"

			# there might be more .typelib files around, we need to copy them
			_typelibfiles=$(find "$LIB_DIR"/*/* -type f -name '*.typelib' 2>/dev/null \
			  | grep -v "$src_girepository_dir" | grep girepository-"$_girver"
			 ) || :
			for f in $_typelibfiles; do
				[ -f "$f" ] || continue
				cp -v "$f" "$dst_girepository_dir"
			done
			if [ -n "$_typelibfiles" ]; then
				_echo "* added additional .typelib files"
			fi
		fi
		;;
	*/gconv/*.so)
		src_gconvm_file=$LIB_DIR/gconv/gconv-modules
		dst_gconvm_file=$DST_LIB_DIR/gconv/gconv-modules
		if [ -f "$src_gconvm_file" ] && [ ! -f "$dst_gconvm_file" ]; then
			mkdir -p "${dst_gconvm_file%/*}"
			cp -v "$src_gconvm_file" "$dst_gconvm_file"
			_echo "* added $src_gconvm_file"
		fi
		;;
	*/libc.so*)
		src_c_locale_dir=/usr/lib/locale/C.utf8
		dst_c_locale_dir=$DST_LIB_DIR/locale/C.utf8
		mkdir -p "$DST_LIB_DIR"/locale
		if [ -d "$src_c_locale_dir" ] && [ ! -d "$dst_c_locale_dir" ]; then
			cp -r "$src_c_locale_dir" "$dst_c_locale_dir"
			_echo "* added C.UTF-8 locale"
		fi
		# C.UTF-8 is not enough, some apps may crash when this locale is used
		# so we need to ship en_US.UTF-8 so we can guarantee applications
		# will launch in systems without glibc locales like alpine linux
		#
		# Because distros use a locale-archive these days, we have to compile it
		#
		dst_en_locale_dir=$DST_LIB_DIR/locale/en_US.utf8
		if [ ! -d "$dst_en_locale_dir" ] && _is_cmd localedef; then
			mkdir -p /tmp/usr/lib/locale
			localedef --prefix /tmp --no-archive -i en_US -f UTF-8 en_US.UTF-8 || :
			if cp -r /tmp/usr/lib/locale/en_US.utf8 "$DST_LIB_DIR"/locale; then
				_echo "* added en_US.UTF-8 locale"
			fi
		fi
		;;
	*/libgegl*.so*)
		src_gegl_dir=$(echo "$LIB_DIR"/gegl-*)
		dst_gegl_dir=$DST_LIB_DIR/${src_gegl_dir##*/}
		if [ -d "$src_gegl_dir" ] && [ -d "$dst_gegl_dir" ]; then
			if cp "$src_gegl_dir"/*.json "$dst_gegl_dir"; then
				_echo "* added $src_gegl_dir .json files"
			fi
		fi
		# GEGL_PATH is problematic so we avoid it
		# patch the lib directly to load its plugins instead
		_patch_away_usr_lib_dir "$lib" || continue
		echo 'unset GEGL_PATH' >> "$APPENV"
		;;
	*/libMagick*.so*)
		src_magick_config_dir=$(echo /etc/ImageMagick*)
		dst_magick_config_dir=$APPDIR/etc/${src_magick_config_dir##*/}
		if [ -d "$src_magick_config_dir" ] && [ ! -d "$dst_magick_config_dir" ]; then
			mkdir -p "$dst_magick_config_dir"
			(
			  # imagemagick has a ton of .xml config files that need
			  # to be added, they can all be copied to one location
			  set -- \
			  	/usr/share/ImageMagick*/*  \
			  	"$src_magick_config_dir"/* \
			  	"$LIB_DIR"/ImageMagick*/config*/*.xml
			  for f do
			  	if [ -f "$f" ]; then
			  		_copy=1
			  		cp "$f" "$dst_magick_config_dir"
			  	fi
			  done
			  if [ "$_copy" = 1 ]; then
			  	_echo "* added ImageMagick config files..."
			  fi
			  # MAGICK_HOME is all that needs to be set
			  echo 'MAGICK_HOME=${SHARUN_DIR}' >> "$APPENV"
			  # however MAGICK_HOME only works when compiled with a specific flag
			  # we can still make this relocatable by setting these other env variables
			  # which will always work even when not compiled with MAGICK_HOME support
			  cd "$APPDIR"
			  set -- shared/lib*/ImageMagick-*/modules*/coders
			  if [ -d "$1" ]; then
			  	echo "MAGICK_CODER_MODULE_PATH=\${SHARUN_DIR}/$1" >> "$APPENV"
			  fi
			  set -- shared/lib*/ImageMagick-*/modules*/filters
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
		fi
		;;
	*/libp11-kit.so*)
		src_p11kit_config_dir=/usr/share/p11-kit
		dst_p11kit_config_dir=$APPDIR/share/p11-kit
		if [ -d "$src_p11kit_config_dir" ] && [ ! -d "$dst_p11kit_config_dir" ]; then
			cp -r "$src_p11kit_config_dir" "$dst_p11kit_config_dir"
			_echo "* added $src_p11kit_config_dir"
		fi
		_patch_away_usr_lib_dir   "$lib" || :
		_patch_away_usr_share_dir "$lib" || :
		;;
	*/p11-kit-trust.so*)
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
	*/libcrypto.so*)
		# Apps may fail to connect to internet if they use the host ssl config
		# see: https://github.com/pkgforge-dev/Viber-AppImage-Enhanced/issues/16

		# make a minimal ssl config instead of copying the hosts
		dst_ssl_conf=$APPDIR/etc/ssl/openssl.cnf
		if [ ! -f "$dst_ssl_conf" ]; then
			mkdir -p "${dst_ssl_conf%/*}"
			cat <<-'EOF' > "$dst_ssl_conf"
			[openssl_conf]
			openssl_conf = openssl_init

			[openssl_init]
			providers = provider_sect

			[provider_sect]
			default = default_sect

			[default_sect]
			activate = 1
			EOF
			echo 'OPENSSL_CONF=${SHARUN_DIR}/etc/ssl/openssl.cnf' >> "$APPENV"
			_echo "* added minimal ssl config"
		fi
		;;
	*/libgimpwidgets*)
		_patch_away_usr_share_dir "$lib" || continue
		;;
	*/libmlt*.so*)
		src_mlt_data_dir=$(echo /usr/share/mlt-*)
		dst_mlt_data_dir=$APPDIR/share/${src_mlt_data_dir##*/}

		if [ -d "$src_mlt_data_dir" ] && [ ! -d "$dst_mlt_data_dir" ]; then
			cp -r "$src_mlt_data_dir" "$dst_mlt_data_dir"
			_echo "* added $src_mlt_data_dir"
		fi
		if [ -d "$dst_mlt_data_dir"/profiles ]; then
			echo "MLT_PROFILES_PATH=\${SHARUN_DIR}/share/${dst_mlt_data_dir##*/}/profiles" >> "$APPENV"
		fi
		if [ -d "$dst_mlt_data_dir"/presets ]; then
			echo "MLT_PRESETS_PATH=\${SHARUN_DIR}/share/${dst_mlt_data_dir##*/}/presets"   >> "$APPENV"
		fi

		dst_mlt_lib_dir=$(echo "$DST_LIB_DIR"/mlt-*)
		if [ -d "$dst_mlt_lib_dir" ]; then
			echo "MLT_REPOSITORY=\${SHARUN_DIR}/lib/${dst_mlt_lib_dir##*/}" >> "$APPENV"
		fi
		;;
	*/frei0r-*/*.so*)
		d=${lib%/*}
		d=${d##*/}
		echo "FREI0R_PATH=\${SHARUN_DIR}/lib/$d" >> "$APPENV"
		;;
	*/ladspa/*.so*)
		echo 'LADSPA_PATH=${SHARUN_DIR}/lib/ladspa' >> "$APPENV"
		;;
	*/libMangoHud*.so*)
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
	*/libwebkit*gtk-*.so*)
		_add_bwrap_wrapper
		# now do better path map to the libs
		_patch_away_usr_lib_dir "$lib" || :
		_patch_away_usr_bin_dir "$lib" || :

		# check if webkit2gtk was compiled relocatable
		if grep -aq -m 1 'WEBKIT_EXEC_PATH' "$lib" \
		  && ! grep -q WEBKIT_EXEC_PATH "$APPENV"; then
			(
			  set -- "$APPDIR"/bin/WebKit*
			  if [ -f "$1" ]; then
			  	echo 'WEBKIT_EXEC_PATH=${SHARUN_DIR}/bin' >> "$APPENV"
			  fi
			)
		fi
		;;
	*/libwebkit*gtkinjectedbundle.so*)
		# WEBKIT_INJECTED_BUNDLE_PATH always works
		# It is not guarded behind a compiled flag unlike WEBKIT_EXEC_PATH
		if ! grep -q 'WEBKIT_INJECTED_BUNDLE_PATH' "$APPENV"; then
			cp -v "$lib" "$APPDIR"/bin
			echo 'WEBKIT_INJECTED_BUNDLE_PATH=${SHARUN_DIR}/bin' >> "$APPENV"
		fi
		;;
	*/libdecor*.so*)
		ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}fix-gnome-csd.hook"
		;;
	*/libSDL*.so*)
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
		# the 7z binaries need the lib next to them
		cp -v "$lib" "$APPDIR"/bin
		;;
	*/libpipewire-*.so*)
		src_pipewire_config_dir=/usr/share/pipewire
		dst_pipewire_config_dir=$APPDIR/share/pipewire
		if [ -d "$src_pipewire_config_dir" ] && [ ! -d "$dst_pipewire_config_dir" ]; then
			cp -r "$src_pipewire_config_dir" "$dst_pipewire_config_dir"

			cat <<-'EOF' > "$APPDIR"/bin/01-pipewire-config.hook
			_pipewire_dir=$APPDIR/share/pipewire
			if [ ! -d /usr/share/pipewire ] && [ -d "$_pipewire_dir" ]; then
				export PIPEWIRE_CONFIG_DIR="$_pipewire_dir"
			fi
			EOF
		fi
		;;
	*/libtesseract.so*)
		src_tess_data_dir=/usr/share/tessdata
		dst_tess_data_dir=$APPDIR/share/tessdata
		if [ -d "$src_tess_data_dir" ] && [ ! -d "$dst_tess_data_dir" ]; then
			cp -r "$src_tess_data_dir" "$dst_tess_data_dir"
			_echo "* added $src_tess_data_dir"
		fi
		;;
	esac
done

_deploy_datadir
_deploy_locale
_post_deployment_steps
_deduplicate_libs
_strip_bins_and_libs
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
		# hooks used to be executed differently depending on the suffix
		# this was dropped and now all hooks are sourced
		# remove old suffixes so that we don't break existing scripts
		hook=${hook%.bg.hook}
		hook=${hook%.src.hook}
		# also remove .hook before adding it again
		# this allows declaring a hook without the suffix in ADD_HOOKS
		hook=${hook%.hook}
		hook=${hook}.hook

		if [ -f "$hook_dst"/"$hook" ]; then
			continue
		elif _download "$hook_dst"/"$hook" "$HOOKSRC"/"$hook"; then
			_echo "* Added $hook"
		else
			_err_msg "ERROR: Failed to download $hook, valid link?"
			_err_msg "$HOOKSRC/$hook"
			exit 1
		fi
	done
fi

_add_hooks_library
_add_apprun

chmod +x "$APPDIR"/AppRun || :

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
			"$APPDIR"/*|./"${APPDIR##*/}"/*|"${APPDIR##*/}"/*)
				_err_msg "Skipping deployment of $d (already in '$APPDIR')"
				continue
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

# suggest people to use glycin-ng instead
if [ "$GNOME_GLYCIN" = 1 ]; then
	_err_msg "------------------------------------------------------------"
	_err_msg "WARNING: GNOME glycin has been deployed!"
	_echo "There is a much better alternative called glycin-ng, features include:"
	_echo "* 5 times smaller!"
	_echo "* No bwrap dependency (uses landlock for sandbox instead)"
	_echo "* No dbus dependency"
	_echo "https://github.com/QaidVoid/glycin-ng"
	_err_msg "------------------------------------------------------------"
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
