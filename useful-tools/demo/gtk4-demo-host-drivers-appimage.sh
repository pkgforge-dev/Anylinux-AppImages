#!/bin/sh

# Demonstration that bundles gtk4 demo app
# without shipping a single gpu driver, the drivers are loaded from
# the HOST system at runtime with the help of cross-libc-dlopen
# https://github.com/pkgforge-dev/cross-libc-dlopen

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ICON=/usr/share/icons/hicolor/scalable/apps/org.gtk.Demo4.svg
export DESKTOP=/usr/share/applications/org.gtk.Demo4.desktop
export OUTPATH=./dist
export OUTNAME=gtk4-demo-host-drivers-"$ARCH".AppImage
export STARTUPWMCLASS=fuck.gnome
export GTK_CLASS_FIX=1
# ship zero gpu drivers, quick-sharun excludes everything the binaries
# merely dlopen at runtime (dri plugins, gallium, vulkan layers, etc)
# while libraries linked directly like libvulkan.so stay bundled
export USE_HOST_DRIVERS_EXPERIMENTAL=1

pacman -Syu --noconfirm \
	base-devel       \
	git              \
	gtk4-demos       \
	libxcb           \
	libxcursor       \
	libxi            \
	libxkbcommon     \
	libxkbcommon-x11 \
	libxrandr        \
	libxtst          \
	patchelf         \
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
./quick-sharun /usr/bin/gtk4-demo*

./quick-sharun --make-appimage

# test the final app
./quick-sharun --test ./dist/*.AppImage
