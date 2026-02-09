#!/bin/sh

# Demonstration that bundles a simple Qt6 app that interacts with dbus

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ANYLINUX_LIB=1
export ICON=/usr/share/doc/qt6/global/template/images/Qt-logo.png
export DESKTOP=DUMMY
export MAIN_BIN=qdbusviewer6
export OUTPATH=./dist
export OUTNAME=Qt6+dbus-demo-"$ARCH".AppImage

pacman -Syu --noconfirm \
	base-devel       \
	curl             \
	git              \
	libxcb           \
	libxcursor       \
	libxi            \
	libxkbcommon     \
	libxkbcommon-x11 \
	libxrandr        \
	libxtst          \
	mesa-utils       \
	qt6-tools        \
	vulkan-tools     \
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
