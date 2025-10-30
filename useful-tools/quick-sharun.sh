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
HOOKSRC=${HOOKSRC:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/hooks}
LD_PRELOAD_OPEN=${LD_PRELOAD_OPEN:-https://github.com/fritzw/ld-preload-open.git}

EXEC_WRAPPER=${EXEC_WRAPPER:-0}
EXEC_WRAPPER_SOURCE=${EXEC_WRAPPER_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/exec.c}
LOCALE_FIX=${LOCALE_FIX:-0}
LOCALE_FIX_SOURCE=${LOCALE_FIX_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/lib/localefix.c}
SCRIPTS_SOURCE=${SCRIPTS_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/bin}

DEPLOY_OPENGL=${DEPLOY_OPENGL:-0}
DEPLOY_VULKAN=${DEPLOY_VULKAN:-0}
DEPLOY_DATADIR=${DEPLOY_DATADIR:-1}
DEPLOY_LOCALE=${DEPLOY_LOCALE:-0}

DEBLOAT_LOCALE=${DEBLOAT_LOCALE:-1}
LOCALE_DIR=${LOCALE_DIR:-/usr/share/locale}

# check if the _tmp_* vars have not be declared already
# likely to happen if this script run more than once
if [ -f "$APPDIR"/.env ]; then
	while IFS= read -r line; do
		case "$line" in
			_tmp_*) eval "$line";;
		esac
	done < "$APPDIR"/.env
fi

regex='A-Za-z0-9_=-'
_tmp_bin="${_tmp_bin:-$(tr -dc "$regex" < /dev/urandom | head -c 3)}"
_tmp_lib="${_tmp_lib:-$(tr -dc "$regex" < /dev/urandom | head -c 3)}"
_tmp_share="${_tmp_share:-$(tr -dc "$regex" < /dev/urandom | head -c 5)}"

# for sharun
export DST_DIR="$APPDIR"
export GEN_LIB_PATH=1
export HARD_LINKS=1
export WITH_HOOKS=1
export STRACE_MODE="${STRACE_MODE:-1}"
export VERBOSE=1

if [ "$DEPLOY_PYTHON" = 1 ]; then
	export WITH_PYTHON=1
	export PYTHON_VER="${PYTHON_VER:-3.13}"
fi

if [ -z "$NO_STRIP" ]; then
	export STRIP=1
fi

# github actions doesn't set USER
export USER="${USER:-USER}"

_echo() {
	printf '\033[1;92m%s\033[0m\n' " $*"
}

_err_msg(){
	>&2 printf '\033[1;31m%s\033[0m\n' " $*"
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
	ADD_HOOKS        List of hooks (colon-separated) to deploy with the application.
	DESKTOP          Path or URL to a .desktop file to include.
	ICON             Path or URL to an icon file to include.
	DEPLOY_QT        Set to 1 to force deployment of Qt.
	DEPLOY_GTK       Set to 1 to force deployment of GTK.
	DEPLOY_OPENGL    Set to 1 to force deployment of OpenGL.
	DEPLOY_VULKAN    Set to 1 to force deployment of Vulkan.
	DEPLOY_PIPEWIRE  Set to 1 to force deployment of Pipewire.
	DEPLOY_GSTREAMER Set to 1 to force deployment of GStreamer.
	DEPLOY_LOCALE    Set to 1 to deploy locale data.
	DEPLOY_PYTHON    Set to 1 to deploy Python.
	                 Set PYTHON_VER and PYTHON_PACKAGES for version and packages to add.
	LIB_DIR          Set source library directory if autodetection fails.
	NO_STRIP         Disable stripping binaries and libraries if set.
	APPDIR           Destination AppDir (default: ./AppDir).
	APPRUN           AppRun to use (default: AppRun-generic). Only needed for hooks.
	EXEC_WRAPPER     Preloads a library that unsets environment variables known to cause
	                 problems to child processes. Not needed if the app will just use
	                 xdg-open to spawn child proceeses since in that case sharun has
	                 a wrapper for xdg-open that handles that.

	NOTE:
	Several of these options get turned on automatically based on what is being deployed.

	EXAMPLES:
	DEPLOY_OPENGL=1 ./quick-sharun.sh /path/to/myapp
	DESKTOP=/path/to/app.desktop ICON=/path/to/icon.png ./quick-sharun.sh /path/to/myapp
	ADD_HOOKS="self-updater.bg.hook:fix-namespaces.hook" ./quick-sharun.sh /path/to/myapp

	SEE ALSO:
	sharun (https://github.com/VHSgunzo/sharun)
	EOF
}

if [ -z "$1" ] && [ -z "$PYTHON_PACKAGES" ]; then
	_help_msg
	exit 1
elif [ "$1" = "--help" ]; then
	_help_msg
	exit 0
fi

if [ -e "$1" ] && [ "$2" = "--" ]; then
	STRACE_ARGS_PROVIDED=1
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

_remove_empty_dirs() {
	find "$1" -type d \
	  -exec rmdir -p --ignore-fail-on-non-empty {} + 2>/dev/null || true
}

_determine_what_to_deploy() {
	mkdir -p "$APPDIR"
	for bin do
		# ignore flags
		case "$bin" in
			--) break   ;;
			-*) continue;;
		esac

		# some apps may dlopen pulseaudio instead of linking directly
		if grep -aoq -m 1 'libpulse.so' "$bin"; then
			DEPLOY_PULSE=${DEPLOY_PULSE:-1}
		fi

		# check linked libraries and enable each mode accordingly
		NEEDED_LIBS="$(ldd "$bin" 2>/dev/null | awk '{print $1}') $NEEDED_LIBS"
		for lib in $NEEDED_LIBS; do
			case "$lib" in
				*libQt5Core.so*)
					DEPLOY_QT=${DEPLOY_QT:-1}
					QT_DIR=qt5
					;;
				*libQt6Core.so*)
					DEPLOY_QT=${DEPLOY_QT:-1}
					QT_DIR=qt6
					;;
				*libQt*Qml*.so*)
					DEPLOY_QML=${DEPLOY_QML:-1}
					;;
				*libQt*WebEngineCore.so*)
					DEPLOY_QT_WEB_ENGINE=${DEPLOY_QT_WEB_ENGINEL:-1}
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
					DEPLOY_GTK=${DEPLOY_GDK:-1}
					;;
				*libglycin*.so*)
					DEPLOY_GLYCIN=${DEPLOY_GLYCIN:-1}
					;;
				*libSDL*.so*)
					DEPLOY_SDL=${DEPLOY_SDL:-1}
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
		# some distros have a qt dir rather than qt6 or qt5 dir
		if [ ! -d "$LIB_DIR"/"$QT_DIR" ]; then
			QT_DIR=qt
		fi
		_echo "* Deploying $QT_DIR"

		plugindir="$LIB_DIR"/"$QT_DIR"/plugins

		for lib in $NEEDED_LIBS; do
			case "$lib" in
				*libQt*Gui.so*)
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
		DEPLOY_GDK=1
		set -- "$@" \
			"$LIB_DIR"/"$GTK_DIR"/*/immodules/*   \
			"$LIB_DIR"/gvfs/libgvfscommon.so      \
			"$LIB_DIR"/gio/modules/libgvfsdbus.so \
			"$LIB_DIR"/gio/modules/libdconfsettings.so
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
		set -- "$@" \
			"$LIB_DIR"/libSDL*.so*           \
			"$LIB_DIR"/libudev.so*           \
			"$LIB_DIR"/libXcursor.so*        \
			"$LIB_DIR"/libXext.so*           \
			"$LIB_DIR"/libXi.so*             \
			"$LIB_DIR"/libXfixes.so*         \
			"$LIB_DIR"/libXrandr.so*         \
			"$LIB_DIR"/libXss.so*            \
			"$LIB_DIR"/libX11-xcb.so*        \
			"$LIB_DIR"/libwayland-client.so* \
			"$LIB_DIR"/libwayland-egl.so*    \
			"$LIB_DIR"/libwayland-cursor.so*
	fi
	if [ "$DEPLOY_GLYCIN" = 1 ]; then
		_echo "* Deploying glycin"
		set -- "$@" "$LIB_DIR"/glycin-loaders/*/*
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
		set -- "$@" "$LIB_DIR"/libpulse.so*
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
		set -- "$@" \
			"$(command -v magick || true)"  \
			"$(command -v convert || true)" \
			"$LIB_DIR"/libMagick*.so*
	fi

	if [ "$DEPLOY_GEGL" = 1 ]; then
		_echo "* Deploying gegl"
		set -- "$@" "$LIB_DIR"/gegl-*/*
	fi

	if [ "$DEPLOY_BABL" = 1 ]; then
		_echo "* Deploying babl"
		set -- "$@" "$LIB_DIR"/babl-*/*
	fi

	if [ "$DEPLOY_LIBHEIF" = 1 ]; then
		_echo "* Deploying libheif"

		# TODO remove the .env parts once sharun sets this automatically
		if [ -d "$LIB_DIR"/libheif/plugins ]; then
			set -- "$@" "$LIB_DIR"/libheif/plugins/*
			echo 'LIBHEIF_PLUGIN_PATH=${SHARUN_DIR}/lib/libheif/plugins' >> "$APPDIR"/.env
		elif [ -d "$LIB_DIR"/libheif ]; then
			set -- "$@" "$LIB_DIR"/libheif/*
			echo 'LIBHEIF_PLUGIN_PATH=${SHARUN_DIR}/lib/libheif' >> "$APPDIR"/.env
		fi
	fi

	if [ "$DEPLOY_P11KIT" = 1 ]; then
		_echo "* Deploying p11kit"
		set -- "$@" "$LIB_DIR"/pkcs11/*
	fi

	TO_DEPLOY_ARRAY=$(_save_array "$@")
}

_get_sharun() {
	if [ ! -x "$TMPDIR"/sharun-aio ]; then
		_echo "Downloading sharun..."
		_download "$TMPDIR"/sharun-aio "$SHARUN_LINK"
		chmod +x "$TMPDIR"/sharun-aio
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

_handle_helper_bins() {
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
		cp -r /usr/share/qt*/resources    "$APPDIR"/lib/qt*
		cp -r /usr/share/qt*/translations "$APPDIR"/lib/qt*
	fi

	# TODO add more instances of helper bins
}

_add_exec_wrapper() {
	if [ "$EXEC_WRAPPER" != 1 ]; then
		return 0
	fi

	if ! command -v cc 1>/dev/null; then
		_err_msg "ERROR: Using EXEC_WRAPPER requires cc"
		exit 1
	fi

	_echo "* Building exec.so..."
	_download "$TMPDIR"/exec.c "$EXEC_WRAPPER_SOURCE"
	cc -shared -fPIC "$TMPDIR"/exec.c -o "$APPDIR"/lib/exec.so
	echo "exec.so" >> "$APPDIR"/.preload

	# remove xdg-open wrapper not needed when exec.so is in use
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

	_echo "* EXEC_WRAPPER successfully added!"
}

_add_locale_fix() {
	if [ "$LOCALE_FIX" != 1 ]; then
		return 0
	fi

	if ! command -v cc 1>/dev/null; then
		_err_msg "ERROR: Using LOCALE_FIX requires cc"
		exit 1
	fi

	_echo "* Building localefix.so..."
	_download "$TMPDIR"/localefix.c "$LOCALE_FIX_SOURCE"
	cc -shared -fPIC "$TMPDIR"/localefix.c -o "$APPDIR"/lib/localefix.so
	echo "localefix.so" >> "$APPDIR"/.preload

	_echo "* LOCALE_FIX successfully added!"
}

_map_paths_ld_preload_open() {
	case "$PATH_MAPPING" in
		*'${SHARUN_DIR}'*) true    ;;
		'')                return 0;;
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
}

_map_paths_binary_patch() {
	if [ "$PATH_MAPPING_HARDCODED" = 1 ]; then
		set -- "$APPDIR"/shared/bin/*
		for bin do
			_patch_away_usr_bin_dir   "$bin"
			_patch_away_usr_lib_dir   "$bin"
			_patch_away_usr_share_dir "$bin"
		done
	fi
}

_deploy_datadir() {
	if [ "$DEPLOY_DATADIR" = 1 ]; then
		# deploy application data files
		mkdir -p "$APPDIR"/share

		# find if there is a datadir that matches bundled binary name
		set -- "$APPDIR"/bin/*
		for bin do
			[ -x "$bin" ] || continue
			bin="${bin##*/}"
			for datadir in /usr/local/share/* /usr/share/*; do
				if echo "${datadir##*/}" | grep -qi "$bin"; then
					_echo "* Adding datadir $datadir..."
					cp -vr "$datadir" "$APPDIR/share"
					break
				fi
			done
		done

		set -- "$APPDIR"/*.desktop

		# Some apps have a datadir that does not match the binary name
		# in that case we need to get it by reading the binary
		if [ -f "$1" ] && command -v strings 1>/dev/null; then

			bin=$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$1")
			possible_dirs=$(
				strings "$APPDIR"/shared/bin/"$bin" \
				  | grep -v '[;:,.(){}?<>*]' \
				  | tr '/' '\n'
			)

			for datadir in $possible_dirs; do
				# skip dirs not wanted or handled by sharun
				case "$datadir" in
					alsa    |\
					awk     |\
					bash    |\
					dbus-1  |\
					defaults|\
					doc     |\
					file    |\
					fonts   |\
					glvnd   |\
					gvfs    |\
					help    |\
					icons   |\
					info    |\
					java    |\
					man     |\
					pipewire|\
					pixmaps |\
					qt      |\
					qt4     |\
					qt5     |\
					qt6     |\
					qt7     |\
					themes  |\
					vulkan  |\
					wayland |\
					X11     |\
					xcb     |\
					zsh     )
						continue
						;;
				esac

				for path in /usr/local/share /usr/share; do

					src_datadir="$path"/"$datadir"
					dst_datadir="$APPDIR"/share/"$datadir"

					if [ -d "$src_datadir" ] \
						&& [ ! -d  "$dst_datadir" ]; then
						_echo "* Adding datadir $src_datadir..."
						cp -vr "$src_datadir" "$dst_datadir"
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
					cp -v "$f" "$dst_dbus_dir"
					;;
			esac
		done
		sed -i -e 's|/usr/.*/||g' "$dst_dbus_dir"/* 2>/dev/null || :
	fi
}

_deploy_locale() {
	set -- "$APPDIR"/shared/bin/*
	for bin do
		if grep -Eaoq -m 1 "/usr/share/locale" "$bin"; then
			DEPLOY_LOCALE=1
			_patch_away_usr_share_dir "$bin" || true
		fi
	done

	if [ "$DEPLOY_LOCALE" = 1 ]; then
		mkdir -p "$APPDIR"/share
		_echo "* Adding locales..."
		cp -r "$LOCALE_DIR" "$APPDIR"/share
		if [ "$DEBLOAT_LOCALE" = 1 ]; then
			_echo "* Removing unneeded locales..."
			set -- \
			! -name '*gtk*30.mo'   \
			! -name '*gtk*40.mo'   \
			! -name '*gst-plugin*' \
			! -name '*gstreamer*'
			for f in "$APPDIR"/shared/bin/* "$APPDIR"/bin/*; do
				f=${f##*/}
				set -- "$@" ! -name "*$f*"
			done
			find "$APPDIR"/share/locale "$@" -type f -delete
			_remove_empty_dirs "$APPDIR"/share/locale
		fi
		echo ""
	fi
}

_deploy_icon_and_desktop() {
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

	# copy the entire hicolor icons dir and remove unneeded icons
	if [ -d /usr/share/icons/hicolor ]; then
		mkdir -p "$APPDIR"/share/icons
		cp -r /usr/share/icons/hicolor "$APPDIR"/share/icons

		set --
		for f in "$APPDIR"/shared/bin/*; do
			f=${f##*/}
			set -- ! -name "*$f*" "$@"
		done

		# also include names of top level .desktop and icon
		if [ -n "$DESKTOP" ]; then
			DESKTOP=${DESKTOP##*/}
			DESKTOP=${DESKTOP%.desktop}
			set -- ! -name "*$DESKTOP*" "$@"
		fi

		if [ -n "$ICON" ]; then
			ICON=${ICON##*/}
			ICON=${ICON%.png}
			ICON=${ICON%.svg}
			set -- ! -name "*$ICON*" "$@"
		fi

		find "$APPDIR"/share/icons/hicolor "$@" -type f -delete
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

_patch_away_usr_bin_dir() {
	# do not patch if PATH_MAPPING already covers this
	case "$PATH_MAPPING" in
		*/usr/bin*) return 1;;
	esac

	if ! grep -Eaoq -m 1 "/usr/bin" "$1"; then
		return 1
	fi

	sed -i -e "s|/usr/bin|/tmp/$_tmp_bin|g" "$1"
	if ! grep -q "_tmp_bin='$_tmp_bin'" "$APPDIR"/.env 2>/dev/null; then
		echo "_tmp_bin='$_tmp_bin'" >> "$APPDIR"/.env
	fi

	_echo "* patched away /usr/bin from $1"
	ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}path-mapping-hardcoded.hook"
}

_patch_away_usr_lib_dir() {
	# do not patch if PATH_MAPPING already covers this
	case "$PATH_MAPPING" in
		*/usr/lib*) return 1;;
	esac

	if ! grep -Eaoq -m 1 "/usr/lib" "$1"; then
		return 1
	fi

	sed -i -e "s|/usr/lib|/tmp/$_tmp_lib|g" "$1"
	if ! grep -q "_tmp_lib='$_tmp_lib'" "$APPDIR"/.env 2>/dev/null; then
		echo "_tmp_lib='$_tmp_lib'" >> "$APPDIR"/.env
	fi

	_echo "* patched away /usr/lib from $1"
	ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}path-mapping-hardcoded.hook"
}

_patch_away_usr_share_dir() {
	# do not patch if PATH_MAPPING already covers this
	case "$PATH_MAPPING" in
		*/usr/share*) return 1;;
	esac

	if ! grep -Eaoq -m 1 "/usr/share" "$1"; then
		return 1
	fi

	sed -i -e "s|/usr/share|/tmp/$_tmp_share|g" "$1"
	if ! grep -q "_tmp_share='$_tmp_share'" "$APPDIR"/.env 2>/dev/null; then
		echo "_tmp_share='$_tmp_share'" >> "$APPDIR"/.env
	fi

	_echo "* patched away /usr/share from $1"
	ADD_HOOKS="${ADD_HOOKS:+$ADD_HOOKS:}path-mapping-hardcoded.hook"
}

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
_handle_helper_bins

echo ""
_echo "------------------------------------------------------------"
echo ""

_map_paths_ld_preload_open
_map_paths_binary_patch
_add_exec_wrapper
_add_locale_fix
_deploy_icon_and_desktop
_deploy_datadir
_deploy_locale
_check_window_class

echo ""
_echo "------------------------------------------------------------"
_echo "Finished deployment! Starting post deployment hooks..."
_echo "------------------------------------------------------------"
echo ""

set -- \
	"$APPDIR"/lib/*.so*       \
	"$APPDIR"/lib/*/*.so*     \
	"$APPDIR"/lib/*/*/*.so*   \
	"$APPDIR"/lib/*/*/*/*.so*

for lib do case "$lib" in
	*libgegl*)
		# GEGL_PATH is problematic so we avoiud it
		# patch the lib directly to load its plugins instead
		_patch_away_usr_lib_dir "$lib" || continue
		echo 'unset GEGL_PATH' >> "$APPDIR"/.env
		;;
	*libp11-kit.so*)
		_patch_away_usr_lib_dir "$lib" || continue
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
	esac
done

# make sure there is no hardcoded path to /usr/share/... in bins
set -- "$APPDIR"/shared/bin/*
for bin do
	if grep -aoq -m 1 '/usr/share/.*/' "$bin"; then
		_patch_away_usr_share_dir "$bin" || true
	fi
	if grep -aoq -m 1 '/usr/lib/.*/' "$bin"; then
		_patch_away_usr_lib_dir "$bin" || true
	fi
done

if [ "$DEPLOY_GLYCIN" = 1 ] && [ ! -x "$APPDIR"/bin/bwrap ]; then
	cat <<-'EOF' > "$APPDIR"/bin/bwrap
	#!/bin/sh

	# AppImages crash when we bundle bwrap required by glycin loaders
	# This terrible hack makes us able to run the glycin loaders without bwrap

	while :; do case "$1" in
	        --) shift; break;;
	        --chdir|--seccomp|--dev|--tmpfs) shift 2;;
	        --*bind*|--symlink|--setenv) shift 3;;
	        -*) shift;;
	        *) break ;;
	        esac
	done
	exec "$@"
	EOF
	chmod +x "$APPDIR"/bin/bwrap
	_echo "* added bwrap wrapper for glycin loaders"
fi

# these need to be done later because sharun may make shared/lib a symlink to lib
# and if we make shared/lib first then it breaks sharun
if [ "$DEPLOY_IMAGEMAGICK" = 1 ]; then
	mkdir -p "$APPDIR"/shared/lib  "$APPDIR"/etc
	cp -r "$LIB_DIR"/ImageMagick-* "$APPDIR"/shared/lib
	cp -r /etc/ImageMagick-*       "$APPDIR"/etc/ImageMagick
	echo 'MAGICK_HOME=${SHARUN_DIR}' >> "$APPDIR"/.env
	echo 'MAGICK_CONFIGURE_PATH=${SHARUN_DIR}/etc/ImageMagick' >> "$APPDIR"/.env
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
		elif _download "$hook_dst"/"$hook" "$HOOKSRC"/"$hook"; then
			_echo "* Added $hook"
		else
			_err_msg "ERROR: Failed to download $hook, valid link?"
			_err_msg "$HOOKSRC/$hook"
			exit 1
		fi
	done

	# always add notify wrapper when using hooks
	_download "$hook_dst"/notify "$SCRIPTS_SOURCE"/notify
	_echo "* Added notify wrapper"
fi

if [ ! -f "$APPDIR"/AppRun ]; then
	_download "$APPDIR"/AppRun "$SCRIPTS_SOURCE"/"$APPRUN"
	_echo "* Added $APPRUN..."
fi

# Set APPIMAGE_ARCH and MAIN_BIN in AppRun
MAIN_BIN=$(awk -F'=| ' '/^Exec=/{print $2; exit}' "$APPDIR"/*.desktop)
MAIN_BIN=${MAIN_BIN##*/}
sed -i \
	-e "s|@MAIN_BIN@|$MAIN_BIN|"  \
	-e "s|@APPIMAGE_ARCH@|$ARCH|" \
	"$APPDIR"/AppRun

chmod +x "$APPDIR"/AppRun "$APPDIR"/bin/*.hook "$APPDIR"/bin/notify 2>/dev/null || :

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
set -- "$APPDIR"/lib/libjack.so*
if [ -f "$1" ] && command -v ldd 1>/dev/null; then
	if ! ldd "$1" | grep -q 'libpipewire'; then
		_err_msg "$libjackwarning"
	fi
fi

echo ""
_echo "------------------------------------------------------------"
_echo "All done!"
_echo "------------------------------------------------------------"
