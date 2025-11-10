#!/bin/sh

# simple script that configures our archlinux container to build an AUR package
# USAGE: Pass the name of the AUR package to be built
# Additional pre-build commands can be passed in the PRE_BUILD_CMDS env variable
# each new command has to be line separated

set -e

ARCH=$(uname -m)

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
	echo "Adding Chaotic AUR packages: $*"
	echo "----------------------------------------------------------------------"
	pacman -Syu --noconfirm "$@"
	exit 0
fi

git clone --depth 1 https://aur.archlinux.org/"$1" ./"$1"
cd ./"$1"

sed -i -e "s|x86_64|$ARCH|" ./PKGBUILD

# Run extra commands from env var
if [ -n "$PRE_BUILD_CMDS" ]; then
	echo "Running additional pre-build commands..."
	echo "----------------------------------------------------------------------"
	while IFS= read -r CMD; do
		if [ -n "$CMD" ]; then
			echo "Running $CMD"
			eval "$CMD"
		fi
	done <<-EOF
	$PRE_BUILD_CMDS
	EOF
	echo "----------------------------------------------------------------------"
fi

echo "To build:"
echo "----------------------------------------------------------------------"
cat ./PKGBUILD
echo "----------------------------------------------------------------------"

echo "Building package..."
echo "----------------------------------------------------------------------"
makepkg -fs --noconfirm
ls -la ./

echo "Installing package..."
echo "----------------------------------------------------------------------"
pacman --noconfirm -U ./*.pkg.tar.*

echo "All done!"
echo "----------------------------------------------------------------------"
echo "----------------------------------------------------------------------"

