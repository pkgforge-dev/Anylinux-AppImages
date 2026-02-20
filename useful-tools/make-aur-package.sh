#!/bin/sh

# simple script that configures our archlinux container to build an AUR package
# USAGE: Pass the name of the AUR package to be built
# Additional pre-build commands can be passed in the PRE_BUILD_CMDS env variable
# each new command has to be line separated

set -e

ARCH=$(uname -m)

g='\033[0;32m'
y='\033[0;33m'
r='\033[1;31m'
o='\033[0m'
l="----------------------------------------------------------------------"
_info_msg() {
	printf "$g%s$o\n" "$l" "${*:-$l}" "$l"
}

_prepare() {
	for d in base-devel git; do
		if ! pacman -Q "$d" 2>/dev/null; then
			_info_msg "Adding build dependency: $d"
			pacman -S --noconfirm "$d"
		fi
	done

	if [ "$ARCH" = 'x86_64' ] && [ "$TARGET_V3_CPU" = 1 ]; then
		echo "$l"
		echo "Targetting x86-64-v3..."

		if ! grep -q 'march=x86-64-v3' /etc/makepkg.conf; then
			sed -i -e 's|march=x86-64|march=x86-64-v3|g' /etc/makepkg.conf
		fi
		sed -i \
			-e 's|-mno-omit-leaf-frame-pointer||' \
			-e 's|-fno-omit-frame-pointer||'      \
			-e 's|-fstack-clash-protection||'     \
			-e 's|-fcf-protection||'              \
			-e 's|-fexceptions||'                 \
			-e 's|-O2|-O3|g'                      \
			/etc/makepkg.conf

		echo "$l"
		grep -A5 -B5 '^CFLAGS=.*' /etc/makepkg.conf
		echo "$l"
	fi

	if ! grep -q 'EUID == 69' /usr/bin/makepkg; then
		# makepkg cannot not as root by default
		sed -i -e 's|EUID == 0|EUID == 69|g' /usr/bin/makepkg
		sed -i \
			-e 's|-O2|-O3|'                              \
			-e 's|MAKEFLAGS=.*|MAKEFLAGS="-j$(nproc)"|'  \
			-e 's|#MAKEFLAGS|MAKEFLAGS|'                 \
			/etc/makepkg.conf
		cat /etc/makepkg.conf
	fi

	# disable building debug packages by default
	# even artix doesn't do this nonsense
	sed -i -e 's| debug | !debug |g' /etc/makepkg.conf

	# always disable this nonsense that was recently added to makepkg
	sed -i \
		-e 's/(( ${#arch\[@\]} != $(printf "%s\\n" ${arch\[@\]} | sort -u | wc -l) ))/false/' \
		/usr/share/makepkg/lint_pkgbuild/arch.sh 2>/dev/null || :
}

_setup_chaotic_aur() {
	if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
		pacman-key --init
		pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
		pacman-key --lsign-key 3056513887B78AEB
		pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
		pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
		echo '[chaotic-aur]' >> /etc/pacman.conf
		echo 'Include = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf
	fi
}

_install_chaotic_aur_pkg() {
	_setup_chaotic_aur
	_info_msg "Adding Chaotic AUR packages: $*"
	# no -Syu here since it can remove the debloated packages
	pacman -Sy --noconfirm "$@"
	exit 0
}

_setup_archlinuxcn() {
	if ! grep -q '^\[archlinuxcn\]' /etc/pacman.conf; then
		echo '[archlinuxcn]' >> /etc/pacman.conf
		echo 'Server = https://repo.archlinuxcn.org/$arch' >> /etc/pacman.conf
		pacman -Sy --noconfirm
		pacman -S --noconfirm archlinuxcn-keyring
	fi
}

_install_archlinuxcn_pkg() {
	_setup_archlinuxcn
	_info_msg "Adding archlinuxcn packages: $*"
	# no -Syu here since it can remove the debloated packages
	pacman -Sy --noconfirm "$@"
	exit 0
}

_get_archlinux_pkgbuild() {
	git clone --depth 1 https://gitlab.archlinux.org/archlinux/packaging/packages/"$1" ./"$1"
	cd ./"$1"
}

_get_aur_pkgbuild() {
	git clone --depth 1 https://aur.archlinux.org/"$1" ./"$1"
	cd ./"$1"
}

_external_pkgbuild() {
	git clone --depth 1 "$1" ./"${1##*/}"
	cd ./"${1##*/}"
}

_local_pkgbuild() {
	if [ ! -f "$PWD"/PKGBUILD ]; then
		>&2 echo "ERROR: No PKGBUILD found in $PWD"
		exit 1
	fi
}

_configure_arch() {
	if ! grep -q "arch=.*$ARCH" ./PKGBUILD; then
		sed -i -e "s|x86_64|$ARCH|" ./PKGBUILD
	fi
}

_run_precmds() {
	if [ -n "$PRE_BUILD_CMDS" ]; then
		_info_msg "Running additional pre-build commands..."
		while IFS= read -r CMD; do
			if [ -n "$CMD" ]; then
				_info_msg "Running: $CMD"
				eval "$CMD"
			fi
		done <<-EOF
		$PRE_BUILD_CMDS
		EOF
	fi
}

_prepare

case "$1" in
	--chaotic-aur)   shift; _install_chaotic_aur_pkg "$@";;
	--archlinux-pkg) shift; _get_archlinux_pkgbuild "$@";;
	--archlinuxcn)   shift; _install_archlinuxcn_pkg "$@";;
	http*/*)         _external_pkgbuild "$@";;
	'')              _local_pkgbuild;;
	*)               _get_aur_pkgbuild "$@";;
esac

_configure_arch
_run_precmds

_info_msg "To build:"
cat ./PKGBUILD
_info_msg ""

_info_msg "Building package..."

# TODO: What do I need to do to not use skippgpcheck?
# gpg --recv-keys doesn't work
makepkg -fs --noconfirm --skippgpcheck

ls -la ./

_info_msg "Installing package..."
if [ "$OVERWRITE_CONFLICTS" = 1 ]; then
	yes | pacman -U ./*.pkg.tar.* --overwrite '*'
else
	yes | pacman -U ./*.pkg.tar.*
fi

_info_msg "All done!"
