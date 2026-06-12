#!/bin/sh

# Demonstration that bundles gtk2 demo app from gtk2-ng

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
AUR="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/make-aur-package.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ICON=https://git.devuan.org/Daemonratte/gtk2-ng/raw/branch/master/demos/gtk-demo/gtk2-ng-256.png
export DESKTOP=DUMMY
export OUTPATH=./dist
export OUTNAME=gtk2-ng-demo-"$ARCH".AppImage
export MAIN_BIN=gtk-demo

pacman -Syu --noconfirm \
	base-devel       \
	git              \
	libxcb           \
	libxcursor       \
	libxi            \
	libxkbcommon     \
	libxkbcommon-x11 \
	libxrandr        \
	libxtst          \
	wget             \
	xorg-server-xvfb \
	zsync

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-common --prefer-nano gtk2-mini ! gtk3 ! gtk4

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun /usr/bin/gtk-demo* /usr/share/gtk-2.0/demo

./quick-sharun --make-appimage

# test the final app
./quick-sharun --test ./dist/*.AppImage
