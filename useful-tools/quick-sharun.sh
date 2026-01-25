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
APPDIR=${APPDIR:-$PWD/AppDir}
APPENV=$APPDIR/.env
SHARUN_LINK=${SHARUN_LINK:-https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$ARCH-aio}
HOOKSRC=${HOOKSRC:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/hooks}
LD_PRELOAD_OPEN=${LD_PRELOAD_OPEN:-https://github.com/VHSgunzo/pathmap.git}

ANYLINUX_LIB=${ANYLINUX_LIB:-0}
ANYLINUX_LIB_SOURCE=${ANYLINUX_LIB_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/anylinux.c}
GTK_CLASS_FIX=${GTK_CLASS_FIX:-0}
GTK_CLASS_FIX_SOURCE=${GTK_CLASS_FIX_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/gtk-class-fix.c}
NOTIFY_SOURCE=${NOTIFY_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/bin/notify}
APPRUN_SOURCE=${APPRUN_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/bin/AppRun-generic}
URUNTIME2APPIMAGE_SOURCE=${URUNTIME2APPIMAGE_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/uruntime2appimage.sh}

DEPLOY_DATADIR=${DEPLOY_DATADIR:-1}
DEPLOY_LOCALE=${DEPLOY_LOCALE:-1}

DEBLOAT_LOCALE=${DEBLOAT_LOCALE:-1}
LOCALE_DIR=${LOCALE_DIR:-/usr/share/locale}
LOCALE_CHECK=${LOCALE_CHECK:-1}

DEPENDENCIES="
	awk
	cp
	find
	grep
	ldd
	mv
	rm
	strings
	tr
"

# keep this for backwards compat until all existing scripts have been updated
if [ "$EXEC_WRAPPER" = 1 ] || [ "$LOCALE_FIX" = 1 ]; then
	ANYLINUX_LIB=1
fi

# check if the _tmp_* vars have not be declared already
# likely to happen if this script run more than once
PATH_MAPPING_SCRIPT="$APPDIR"/bin/path-mapping-hardcoded.src.hook

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

if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
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

if [ "$DEPLOY_PYTHON" = 1 ]; then
	export WITH_PYTHON=1
	export PYTHON_VER="${PYTHON_VER:-3.13}"
fi

# github actions doesn't set USER and XDG_RUNTIME_DIR
# causing some apps crash when running xvfb-run
export USER="${LOGNAME:-${USER:-${USERNAME:-yomama}}}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

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
	"$DOWNLOAD_CMD" "$@"
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
	  DEPLOY_SYS_PYTHON   Set to 1 to deploy system Python. Will remove all pycache
	                 pycache files, set DEBLOAT_SYS_PYTHON to 0 to prevent this.
	  DEPLOY_PYTHON      Set to 1 to deploy UV Python (sharun feature).
	                 Set PYTHON_VER and PYTHON_PACKAGES for version and packages to add.

	  LIB_DIR          Set source library directory if autodetection fails.
	  NO_STRIP         Disable stripping binaries and libraries if set.
	  APPDIR           Destination AppDir (default: ./AppDir).
	  ANYLINUX_LIB     Preloads a library that unsets environment variables known to cause
	                   problems to child processes. Set to 0 to disable.

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

_sanity_check() {
	for d in $DEPENDENCIES; do
		_is_cmd "$d" || _err_msg "ERROR: Missing dependency '$d'!"
	done

	if [ "$ANYLINUX_LIB" = 1 ] && ! _is_cmd cc; then
		_err_msg "ERROR: Using ANYLINUX_LIB requires cc"
		exit 1
	elif [ "$GTK_CLASS_FIX" = 1 ] && ! _is_cmd gcc pkg-config; then
		_err_msg "ERROR: Using GTK_CLASS_FIX requires gcc and pkg-config"
		exit 1
	elif [ "$DEPLOY_PYTHON" = 1 ] && [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
		_err_msg "ERROR: DEPLOY_PYTHON and DEPLOY_SYS_PYTHON cannot be both enabled!"
		exit 1
	elif [ -z "$DESKTOP" ] && [ ! -f "$APPDIR"/*.desktop ]; then
		_err_msg "ERROR: No desktop entry in $APPDIR and DESKTOP is not set!"
		exit 1
	elif  [ -n "$PATH_MAPPING" ] && ! echo "$PATH_MAPPING" | grep -q 'SHARUN_DIR'; then
		_err_msg 'ERROR: PATH_MAPPING must contain unexpanded ${SHARUN_DIR} variable'
		_err_msg 'Example:'
		_err_msg "'PATH_MAPPING=/etc:\${SHARUN_DIR}/etc'"
		_err_msg 'NOTE: The braces in the variable are needed!'
		exit 1
	elif [ -z "$ICON" ] && [ ! -f "$APPDIR"/.DirIcon ]; then
		_err_msg "WARNING: No .DirIcon in $APPDIR and ICON is not set!"
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
}

_make_appimage() {
	_echo "------------------------------------------------------------"
	_echo "Making AppImage..."
	_echo "------------------------------------------------------------"
	_download "$TMPDIR"/uruntime2appimage.sh "$URUNTIME2APPIMAGE_SOURCE"
	chmod +x "$TMPDIR"/uruntime2appimage.sh
	exec "$TMPDIR"/uruntime2appimage.sh
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

_determine_what_to_deploy() {
	mkdir -p "$APPDIR"/share
	for bin do
		# ignore flags
		case "$bin" in
			--) break   ;;
			-*) continue;;
		esac

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
	if [ "$DEPLOY_PYTHON" = 1 ]; then
		_echo "* Deploying python $PYTHON_VER"
		if [ -n "$PYTHON_PACKAGES" ]; then
			old_ifs="$IFS"
			IFS=':'
			set -- $PYTHON_PACKAGES
			IFS="$old_ifs"
			for pypkg do
				_echo "* Deploying python package $pypkg"
				echo "$pypkg" >> "$TMPDIR"/requirements.txt
			done
			set -- --python-pkg "$TMPDIR"/requirements.txt
		fi
	fi
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
		DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
		DEPLOY_COMMON_LIBS=${DEPLOY_COMMON_LIBS:-1}

		# some distros have a qt dir rather than qt6 or qt5 dir
		if [ ! -d "$LIB_DIR"/"$QT_DIR" ]; then
			QT_DIR=qt
		fi
		_echo "* Deploying $QT_DIR"

		plugindir="$LIB_DIR"/"$QT_DIR"/plugins

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
			if ! qtwebenginebin=$(find "$LIB_DIR" -type f \
				-name 'QtWebEngineProcess' -print -quit 2>/dev/null); then
				_err_msg "Cannot find QtWebEngineProcess!"
				exit 1
			else
				set -- "$@" "$qtwebenginebin"
			fi
		fi

		if [ "$DEPLOY_QML" = 1 ]; then
			_echo "* Deploying qml"
			dst_qml="$APPDIR"/shared/lib/"$QT_DIR"
			mkdir -p "$dst_qml"
			cp -r "$LIB_DIR"/"$QT_DIR"/qml "$dst_qml"
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
		echo 'GSETTINGS_BACKEND=keyfile' >> "$APPENV"

		case "$GTK_DIR" in
			*4*) DEPLOY_OPENGL=${DEPLOY_OPENGL:-1};;
		esac

		if [ "$DEPLOY_WEBKIT2GTK" = 1 ]; then
			_echo "* Deploying webkit2gtk"
			DEPLOY_OPENGL=${DEPLOY_OPENGL:-1}
			DEPLOY_P11KIT=${DEPLOY_P11KIT:-1}
			set -- "$@" "$LIB_DIR"/libnss_mdns*minimal.so*
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
				if [ -x "$f" ]; then
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
				# gstvulkan pulls vulkan, remove unless vulkan is deployed
				if [ "$DEPLOY_VULKAN" != 1 ]; then
					rm -f "$GST_DIR"/*gstvulkan*
				fi
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
			set -- "$@" "$LIB_DIR"/libheif/plugins/*
		elif [ -d "$LIB_DIR"/libheif ]; then
			set -- "$@" "$LIB_DIR"/libheif/*
		fi
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
		mkdir -p "$APPDIR"/bin
		cp -r "$DOTNET_DIR"/shared "$APPDIR"/bin
		cp -r "$DOTNET_DIR"/host   "$APPDIR"/bin
	fi
	# these are needed by several toolkits
	if [ "$DEPLOY_COMMON_LIBS" = 1 ]; then
		set -- "$@" \
			"$LIB_DIR"/libXi.so*             \
			"$LIB_DIR"/libXcursor.so*        \
			"$LIB_DIR"/libxcb-dri*.so*       \
			"$LIB_DIR"/libxcb-glx.so*        \
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
							if [ -x "$f" ]; then
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

	if [ -n "$PYTHON_PACKAGES" ]; then
		STRACE_MODE=0
	fi
	$XVFB_CMD "$TMPDIR"/sharun-aio l "$@"

	# strace the individual python pacakges
	if [ -n "$PYTHON_PACKAGES" ]; then
		# if not unsetlib4bin will replace the top level sharun
		# with a hardlink to python breaking everything
		unset  WITH_PYTHON PYTHON_VER

		old_ifs="$IFS"
		IFS=':'
		set -- $PYTHON_PACKAGES
		IFS="$old_ifs"

		for pypkg do
			pybin="$APPDIR"/bin/"$pypkg"
			[ -e "$pybin" ] || continue
			_echo "Running strace on python package $pypkg..."
			$XVFB_CMD "$TMPDIR"/sharun-aio l \
				--strace-mode  "$APPDIR"/sharun -- "$pybin"
		done
	fi
}

_handle_bins_scripts() {
	# check for gstreamer binaries these need to be in the gstreamer libdir
	# since sharun will set the following vars to that location:
	# GST_PLUGIN_PATH
	# GST_PLUGIN_SYSTEM_PATH
	# GST_PLUGIN_SYSTEM_PATH_1_0
	# GST_PLUGIN_SCANNER
	set -- "$APPDIR"/shared/lib/gstreamer-*
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
		src_res=/usr/share/"$QT_DIR"/resources
		dst_res="$APPDIR"/shared/lib/"$QT_DIR"/resources
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
	if [ "$ANYLINUX_LIB" != 1 ]; then
		return 0
	fi

	_echo "* Building anylinux.so..."
	_download "$APPDIR"/.anylinux.c "$ANYLINUX_LIB_SOURCE"
	cc -shared -fPIC "$APPDIR"/.anylinux.c -o "$APPDIR"/shared/lib/anylinux.so
	echo "anylinux.so" >> "$APPDIR"/.preload

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
	if [ "$GTK_CLASS_FIX" != 1 ]; then
		return 0
	elif [ ! -f "$APPDIR"/*.desktop ]; then
		_err_msg "ERROR: Using GTK_CLASS_FIX requires a desktop entry in $APPDIR"
	fi

	_echo "* Building gtk-class-fix.so"
	_download "$APPDIR"/.gtk-class-fix.c "$GTK_CLASS_FIX_SOURCE"
	gcc -shared -fPIC "$APPDIR"/.gtk-class-fix.c \
		-o "$APPDIR"/shared/lib/gtk-class-fix.so \
		$(pkg-config --cflags --libs glib-2.0 gio-2.0 gobject-2.0) -ldl

	# _check_window_class will make sure StartupWMClass is added to desktop entry

	# for this to work in wayland, the class needs to have one dot in its name
	if ! grep -q 'StartupWMClass=.*\..*' "$APPDIR"/*.desktop; then
		sed -i -e 's/\(StartupWMClass=.*\)/\1.anylinux/' "$APPDIR"/*.desktop
	fi

	class=$(awk -F'=| ' '/^StartupWMClass=/{print $2; exit}' "$APPDIR"/*.desktop)

	echo "GTK_WINDOW_CLASS=$class"  >> "$APPDIR"/.env
	echo "gtk-class-fix.so"         >> "$APPDIR"/.preload
	_echo "* gtk-class-fix.so successfully added!"
}

_add_locale_check() {
	loc_check_bin="$APPDIR"/bin/locale-check
	if [ "$LOCALE_CHECK" != 1 ] || [ -x "$loc_check_bin" ]; then
		return 0
	fi

	cat <<-'EOF' > "$APPDIR"/.locale-check.c
	#include <locale.h>
	int main(void) { return setlocale(LC_ALL, "") ? 0 : 1; }
	EOF
	if cc -Os -static -o "$loc_check_bin" "$APPDIR"/.locale-check.c; then
		chmod +x "$loc_check_bin"
		_echo "* locale-check successfully added!"
	else
		# do not stop the CI if this fails
		_err_msg "Could not add locale-check"
	fi
}

_add_certs_check() {
	cert_check="$APPDIR"/bin/check-ca-certs.src.hook
	if [ -f "$cert_check" ]; then
		return 0
	fi

	cat <<-'EOF' > "$cert_check"
	#!/bin/sh
	if [ ! -f /etc/ssl/certs/ca-certificates.crt ]; then
	    _possible_certs='
	      /etc/pki/tls/cert.pem
	      /etc/pki/tls/cacert.pem
	      /etc/ssl/cert.pem
	    '
	    for c in $_possible_certs; do
	        if [ -f "$c" ]; then
	            REQUESTS_CA_BUNDLE=${REQUESTS_CA_BUNDLE:-$c}
	            CURL_CA_BUNDLE=${CURL_CA_BUNDLE:-$c}
	            SSL_CERT_FILE=${SSL_CERT_FILE:-$c}
	            export REQUESTS_CA_BUNDLE CURL_CA_BUNDLE SSL_CERT_FILE
	            break
	        fi
	    done
	    [ -f "$c" ] || >&2 echo "WARNING: Cannot find CA Certificates in '/etc'!"
	fi
	EOF
	chmod +x "$cert_check"
}

_map_paths_ld_preload_open() {
	# format new line entries in PATH_MAPPING into comma separated
	# entries for sharun, pathmap accepts new lines in the variable
	# but the .env library used by sharun does not
	if [ -n "$PATH_MAPPING" ] && [ ! -f "$APPDIR"/shared/lib/path-mapping.so ]; then
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

		mv -v "$TMPDIR"/ld-preload-open/path-mapping.so "$APPDIR"/shared/lib
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
		path2="$APPDIR"/lib
		for f do
			file=$(find -L "$path1" "$path2" -type f -name "$f")
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
					icons       |\
					info        |\
					java        |\
					locale      |\
					man         |\
					misc        |\
					pipewire    |\
					pixmaps     |\
					qt          |\
					qt4         |\
					qt5         |\
					qt6         |\
					qt7         |\
					ss          |\
					themes      |\
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
			find "$APPDIR"/share/locale "$@" -type f -delete
			_remove_empty_dirs "$APPDIR"/share/locale
		fi
		echo ""
	fi
}

_deploy_icon_and_desktop() {
	if [ "$DESKTOP" = "DUMMY" ]; then
		if [ -n "$MAIN_BIN" ]; then
			f=${MAIN_BIN##*/}
		else
			# use the first binary name in shared/bin as filename
			set -- "$APPDIR"/shared/bin/*
			[ -f "$1" ] || exit 1
			f=${1##*/}
		fi
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

	if [ "$ICON" = "DUMMY" ]; then
		if [ -n "$MAIN_BIN" ]; then
			f=${MAIN_BIN##*/}
		else
			# use the first binary name in shared/bin as filename
			set -- "$APPDIR"/shared/bin/*
			[ -f "$1" ] || exit 1
			f=${1##*/}
		fi
		_echo "* Adding dummy $f icon to $APPDIR..."
		:> "$APPDIR"/"$f".png
		:> "$APPDIR"/.DirIcon
	elif [ -f "$ICON" ]; then
		_echo "* Adding $ICON to $APPDIR..."
		cp -v "$ICON" "$APPDIR"
	elif echo "$ICON" | grep -q 'http'; then
		_echo "* Downloading $ICON to $APPDIR..."
		_download "$APPDIR"/"${ICON##*/}" "$ICON"
	elif [ -n "$ICON" ]; then
		_err_msg "$ICON is NOT a valid path!"
		exit 1
	fi

	# copy the entire hicolor icons dir
	# by default the hicolor icon theme ships no icons, this
	# means any present icon is likely needed by the application
	if [ -d /usr/share/icons/hicolor ]; then
		mkdir -p "$APPDIR"/share/icons
		cp -r /usr/share/icons/hicolor "$APPDIR"/share/icons
		_remove_empty_dirs "$APPDIR"/share/icons/hicolor
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
	mkdir -p "$APPDIR"/bin
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

	set -- "$APPDIR"/shared/lib/python*/ctypes/util.py
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

	    for f in "$APPDIR"/shared/lib/*.so* "$APPDIR"/shared/lib/*/*.so*; do
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

	if ! command -v ln 1>/dev/null; then
	    >&2 echo "path-mapping-hardcoded: ERROR we cannot make symlinks"
	    >&2 echo "because command 'ln' is missing from the system! Aborting..."
	    exit 1
	fi

	if [ -n "$_tmp_bin" ]; then
	    ln -sfn "$APPDIR"/bin /tmp/"$_tmp_bin"
	fi
	if [ -n "$_tmp_lib" ]; then
	    ln -sfn "$APPDIR"/lib /tmp/"$_tmp_lib"
	fi
	if [ -n "$_tmp_share" ]; then
	    ln -sfn "$APPDIR"/share /tmp/"$_tmp_share"
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

# sometimes developers add stuff like /bin/sh or env as the Exec= key of the
# desktop entry, 99.99% of the time this is not wanted, so we have to error that
_check_main_bin_name() {
	MAIN_BIN=${MAIN_BIN##*/}
	case "$MAIN_BIN" in
		env|sh|bash)
			_err_msg "ERROR: determined $MAIN_BIN as the main binary"
			_err_msg "by reading the Exec= key in the desktop entry"
			_err_msg "it is unlikely you are actually going to package"
			_err_msg "a shell or env into an appimage, bailing out..."
			_err_msg "Set the MAIN_BIN variable to $MAIN_BIN if you"
			_err_msg "intend to actually make an appimage of such binary"
			exit 1
			;;
		*)
			return 0
			;;
	esac
}

_determine_main_bin() {
	if [ -z "$MAIN_BIN" ]; then
		MAIN_BIN=$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$APPDIR"/*.desktop)
		_check_main_bin_name
	fi

	# get basename of binary only
	MAIN_BIN=${MAIN_BIN##*/}

	if [ -f "$APPDIR"/bin/"$MAIN_BIN" ]; then
		return 0
	fi

	_err_msg "MAIN_BIN is set to '$MAIN_BIN', but this file is NOT present"
	_err_msg "This is the default binary to be launched in this application"
	_err_msg "Please make sure to bundle $MAIN_BIN"
	_err_msg "By default the main binary is taken from the top level"
	_err_msg "desktop entry in '$APPDIR', make sure to add the correct"
	_err_msg "desktop entry, if you are using DESKTOP=DUMMY, make sure to"
	_err_msg "specify the correct binary name in the MAIN_BIN env variable"
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


case "$1" in
	--help)
		_help_msg
		;;
	--make-appimage)
		_make_appimage
		;;
	--make-static-bin)
		shift
		_get_sharun
		_make_static_bin "$@"
		exit 0
		;;
	'')
		if [ -z "$PYTHON_PACKAGES" ]; then
			_help_msg
		fi
		;;
esac

_sanity_check

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
_handle_bins_scripts

echo ""
_echo "------------------------------------------------------------"
echo ""

_deploy_icon_and_desktop
_determine_main_bin
_map_paths_ld_preload_open
_map_paths_binary_patch
_add_anylinux_lib
_add_locale_check
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
	"$APPDIR"/shared/lib/*.so*       \
	"$APPDIR"/shared/lib/*/*.so*     \
	"$APPDIR"/shared/lib/*/*/*.so*   \
	"$APPDIR"/shared/lib/*/*/*/*.so*

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
		# good path that library should have
		ssl_path="/etc/ssl/certs/ca-certificates.crt"

		# string has to be same length
		problem_path="/usr/share/ca-certificates/trust-source"
		ssl_path_fix="/etc/ssl/certs//////ca-certificates.crt"

		if grep -Eaoq -m 1 "$ssl_path" "$lib"; then
			continue # all good nothing to fix
		elif grep -Eaoq -m 1 "$problem_path" "$lib"; then
			sed -i -e "s|$problem_path|$ssl_path_fix|g" "$lib"
		else
			continue # TODO add more possible problematic paths
		fi

		_echo "* fixed path to /etc/ssl/certs in $lib"
		_patch_away_usr_share_dir "$lib" || continue
		;;
	*libgimpwidgets*)
		_patch_away_usr_share_dir "$lib" || continue
		;;
	*libMagick*.so*)
		# MAGICK_HOME only works on portable builds of imagemagick
		# so we will have to patch it manually instead
		_patch_away_usr_lib_dir "$lib" || continue
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
	*libssl*.so*)
		_add_certs_check
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
		if [ -f "$APPDIR"/shared/lib/libdecor-0.so.0 ]; then
			continue
		elif grep -aoq -m 1 'libdecor-0.so.0' "$lib"; then
			sed -i -e 's|libdecor-0.so.0|fuck-gnome.so.X|g' "$lib"
		fi
		;;
	esac
done

# check for hardcoded path to any other possibly bundled library dir
topleveldirs=$(find "$APPDIR"/shared/lib/ -maxdepth 1  -type d | sed 's|/.*/||')
for dir in $topleveldirs; do
	# skip directories we already handle here on in sharun
	case "$dir" in
		alsa-lib   |\
		dri        |\
		gbm        |\
		gconv      |\
		gdk-pixbuf*|\
		gio        |\
		gtk*       |\
		gstreamer* |\
		gvfs       |\
		libproxy   |\
		locale     |\
		pipewire*  |\
		pulseaudio |\
		qt*        |\
		spa*       |\
		vdpau      )
			continue
			;;
	esac

	for f in "$APPDIR"/shared/lib/*.so* "$APPDIR"/shared/bin/*; do
		if [ ! -f "$f" ]; then
			continue
		elif grep -aoq -m 1 "$LIB_DIR"/"$dir" "$f"; then
			_echo "* Detected hardcoded path to $LIB_DIR/$dir in $f"
			_patch_away_usr_lib_dir "$f" || :
		fi
	done
done

# make sure there is no hardcoded path to /usr/share/... in bins
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

# these need to be done later because sharun may make shared/lib a symlink to lib
# and if we make shared/lib first then it breaks sharun
if [ "$DEPLOY_SYS_PYTHON" = 1 ]; then
	set -- "$LIB_DIR"/python*
	if [ -d "$1" ]; then
		cp -r "$1" "$APPDIR"/shared/lib
	else
		_err_msg "ERROR: Cannot find python installation in $LIB_DIR"
		exit 1
	fi
	if [ "$DEBLOAT_SYS_PYTHON" = 1 ]; then
		(
			cd "$APPDIR"/shared/lib/"${1##*/}"
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
	mkdir -p "$APPDIR"/shared/lib  "$APPDIR"/etc
	cp -r "$LIB_DIR"/ImageMagick-* "$APPDIR"/shared/lib
	cp -r /etc/ImageMagick-*       "$APPDIR"/etc/ImageMagick
	echo 'MAGICK_HOME=${SHARUN_DIR}' >> "$APPENV"
	echo 'MAGICK_CONFIGURE_PATH=${SHARUN_DIR}/etc/ImageMagick' >> "$APPENV"
	_echo "* Copied ImageMagick directories"
fi
if [ "$DEPLOY_GEGL" = 1 ]; then
	gegldir=$(echo "$LIB_DIR"/gegl-*)
	dst_gegldir="$APPDIR"/shared/lib/"${gegldir##*/}"
	if [ -d "$gegldir" ] && [ -d "$dst_gegldir" ]; then
		cp "$gegldir"/*.json "$dst_gegldir"
		_echo "* Copied gegl json files"
	fi
fi
if [ "$DEPLOY_QT" = 1 ]; then
	src_trans=/usr/share/"$QT_DIR"/translations
	dst_trans="$APPDIR"/shared/lib/"$QT_DIR"/translations
	if [ -d "$src_trans" ] && [ ! -d "$dst_trans" ]; then
		mkdir -p "${dst_trans%/*}"
		cp -r "$src_trans" "$dst_trans"
		rm -f "$dst_trans"/assistant*.qm
		rm -f "$dst_trans"/designer*.qm
	fi
	if [ -f "$TMPDIR"/libqgtk3.so ]; then
		d="$APPDIR"/lib/"$QT_DIR"/plugins/platformthemes
		mkdir -p "$d"
		mv "$TMPDIR"/libqgtk3.so "$d"
		"$APPDIR"/sharun -g 2>/dev/null || :
	fi
fi
if [ "$DEPLOY_SYS_PYTHON" = 1 ] || [ "$DEPLOY_PYTHON" = 1 ]; then
	_fix_cpython_ldconfig_mess
fi

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
		elif [ "$ARCH" != 'x86_64' ] \
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
	-e "s|@APPIMAGE_ARCH@|$ARCH|" \
	"$APPDIR"/AppRun

chmod +x "$APPDIR"/AppRun "$APPDIR"/bin/*.hook "$APPDIR"/bin/notify 2>/dev/null || :

# deploy directories
while read -r d; do
	if [ -d "$d" ]; then
		case "$d" in
			"$LIB_DIR"/*)
				dst_path="$APPDIR"/lib/"${d##*$LIB_DIR/}"
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

# wrap any executable in lib with sharun
for b in $(find "$APPDIR"/shared/lib/ -type f ! -name '*.so*'); do
	if [ -x "$b" ] && [ -x "$APPDIR"/shared/bin/"${b##*/}" ]; then
		rm -f "$b"
		ln "$APPDIR"/sharun "$b"
		_echo "* Wrapped lib executable '$b' with sharun"
	fi
done

# do the same for possible nested binaries in bin
for b in $(find "$APPDIR"/bin/*/ -type f ! -name '*.so*'); do
	if [ -x "$b" ] && [ -x "$APPDIR"/shared/bin/"${b##*/}" ]; then
		rm -f "$b"
		ln "$APPDIR"/sharun "$b"
		_echo "* Wrapped nested bin executable '$b' with sharun"
	fi
done

# make sure the .env has all the "unset" last, due to a bug in the dotenv
# library used by sharun all the unsets have to be declared last in the .env
if [ -f "$APPENV" ]; then
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
		}' "$APPENV"
	)"
	echo "$sorted_env" > "$APPENV"
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
set -- "$APPDIR"/shared/lib/libjack.so*
if [ -f "$1" ]; then
	if ! ldd "$1" | grep -q 'libpipewire'; then
		_err_msg "$libjackwarning"
	fi
fi

echo ""
if [ "$OUTPUT_APPIMAGE" = 1 ]; then
	_make_appimage
else
	_echo "------------------------------------------------------------"
	_echo "All done!"
	_echo "------------------------------------------------------------"
fi
