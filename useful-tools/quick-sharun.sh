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

EXEC_WRAPPER=${EXEC_WRAPPER:-0}
EXEC_WRAPPER_SOURCE=${EXEC_WRAPPER_SOURCE:-https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/exec.c}

DEPLOY_QT=${DEPLOY_QT:-0}
DEPLOY_GTK=${DEPLOY_GTK:-0}
DEPLOY_OPENGL=${DEPLOY_OPENGL:-0}
DEPLOY_VULKAN=${DEPLOY_VULKAN:-0}
DEPLOY_PIPEWIRE=${DEPLOY_PIPEWIRE:-0}
DEPLOY_GSTREAMER=${DEPLOY_GSTREAMER:-0}
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
	export PYTHON_VER="${PYTHON_VER:-3.12}"
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

		# check linked libraries and enable each mode accordingly
		for lib in $(ldd "$bin" 2>/dev/null | awk '{print $1}'); do
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
				*libgstreamer*.so*)
					DEPLOY_GSTREAMER=1
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
	if [ "$DEPLOY_GSTREAMER" = 1 ]; then
		_echo "* Deploying gstreamer"
		set -- "$@" \
			"$LIB_DIR"/gstreamer*/* \
			"$LIB_DIR"/gstreamer*/*/*
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

	_echo "* EXEC_WRAPPER successfully added!"
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
	if [ "$PATH_MAPPING_RELATIVE" = 1 ]; then
		sed -i -e 's|/usr|././|g' "$APPDIR"/shared/bin/*
		echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}' >> "$APPDIR"/.env
		_echo "* Patched away /usr from binaries..."
		echo ""
	elif [ "$PATH_MAPPING_HARDCODED" = 1 ]; then
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
		set -- "$APPDIR"/bin/*
		for bin do
			[ -x "$bin" ] || continue
			bin="${bin##*/}"
			for datadir in /usr/local/share/* /usr/share/*; do
				if echo "${datadir##*/}" | grep -qi "$bin"; then
					mkdir -p "$APPDIR"/share
					_echo "* Adding datadir $datadir..."
					cp -vr "$datadir" "$APPDIR/share"
					break
				fi
			done
		done
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
			for f in "$APPDIR"/shared/bin/*; do
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

	# make sure there is no hardcoded path to /usr/share/icons in bins
	set -- "$APPDIR"/shared/bin/*
	for bin do
		if grep -Eaoq -m 1 "/usr/share/icons" "$bin"; then
			_patch_away_usr_share_dir "$bin" || true
		fi
	done
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

_add_exec_wrapper
_map_paths_ld_preload_open
_map_paths_binary_patch
_deploy_datadir
_deploy_locale
_deploy_icon_and_desktop
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
	libgegl*)
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
	esac
done

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
fi

set -- "$APPDIR"/bin/*.hook
if [ -f "$1" ] && [ ! -f "$APPDIR"/AppRun ]; then
	_download "$APPDIR"/AppRun "$HOOKSRC"/"$APPRUN"
	_echo "* Added $APPRUN..."
elif [ ! -f "$APPDIR"/AppRun ]; then
	ln -v "$APPDIR"/sharun "$APPDIR"/AppRun
	_echo "* Hardlinked $APPDIR/sharun as $APPDIR/AppRun..."
fi

chmod +x "$APPDIR"/AppRun "$APPDIR"/bin/*.hook 2>/dev/null || true

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

echo ""
_echo "------------------------------------------------------------"
_echo "All done!"
_echo "------------------------------------------------------------"
