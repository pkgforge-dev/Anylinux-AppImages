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

# check for basic build dependencies
for d in base-devel git; do
	if ! pacman -Q "$d" 2>/dev/null; then
		_info_msg "Adding build dependency: $d"
		pacman -Syu --noconfirm "$d"
	fi
done

# makepkg does not run when root
sed -i -e 's|EUID == 0|EUID == 69|g' /usr/bin/makepkg
sed -i \
	-e 's|-O2|-O3|'                              \
	-e 's|MAKEFLAGS=.*|MAKEFLAGS="-j$(nproc)"|'  \
	-e 's|#MAKEFLAGS|MAKEFLAGS|'                 \
	/etc/makepkg.conf
cat /etc/makepkg.conf

if [ "$1" = '--chaotic-aur' ]; then
	shift
	pacman-key --init
	pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	pacman-key --lsign-key 3056513887B78AEB
	pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
	pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
	echo '[chaotic-aur]' >> /etc/pacman.conf
	echo 'Include = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf
	_info_msg "Adding Chaotic AUR packages: $*"
	pacman -Sy --noconfirm "$@"
	exit 0
elif [ "$1" = '--archlinux-pkg' ]; then
	shift
	git clone --depth 1 https://gitlab.archlinux.org/archlinux/packaging/packages/"$1" ./"$1"
else
	git clone --depth 1 https://aur.archlinux.org/"$1" ./"$1"
fi
cd ./"$1"

if ! grep =q "arch=.*$ARCH" ./PKGBUILD; then
	sed -i -e "s|x86_64|$ARCH|" ./PKGBUILD
fi

# Run extra commands from env var
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
	pacman --noconfirm -U ./*.pkg.tar.* --overwrite '*'
else
	pacman --noconfirm -U ./*.pkg.tar.*
fi

_info_msg "All done!"
