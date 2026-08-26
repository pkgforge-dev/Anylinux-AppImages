#!/bin/sh

# Demonstration that bundles a simple Qt6 app that interacts with dbus
# without shipping a single gpu driver, the drivers are loaded from
# the HOST system at runtime with the help of cross-libc-dlopen
# https://github.com/pkgforge-dev/cross-libc-dlopen

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ICON=/usr/share/doc/qt6/global/template/images/Qt-logo.png
export DESKTOP=DUMMY
export MAIN_BIN=qdbusviewer6
export OUTPATH=./dist
export OUTNAME=Qt6+dbus-demo-host-drivers-"$ARCH".AppImage
# ship zero gpu drivers, quick-sharun excludes everything the binaries
# merely dlopen at runtime (dri plugins, gallium, vulkan layers, etc)
# while libraries linked directly like libvulkan.so stay bundled
export USE_HOST_DRIVERS_EXPERIMENTAL=1

pacman -Syu --noconfirm \
	base-devel       \
	git              \
	kvantum          \
	libxcb           \
	libxcursor       \
	libxi            \
	libxkbcommon     \
	libxkbcommon-x11 \
	libxrandr        \
	libxtst          \
	lxqt-qtplugin    \
	patchelf         \
	qt6ct            \
	qt6-tools        \
	wget             \
	xorg-server-xvfb \
	zsync

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-common --prefer-nano

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun /usr/bin/qdbusviewer6

./quick-sharun --make-appimage

# test the final app
./quick-sharun --test ./dist/*.AppImage
