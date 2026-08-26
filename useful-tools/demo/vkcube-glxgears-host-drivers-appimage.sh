#!/bin/sh

# Demonstration that bundles vkcube (vulkan) and glxgears (opengl)
# without shipping a single gpu driver, the drivers are loaded from
# the HOST system at runtime using with the help of cross-libc-dlopen
# https://github.com/pkgforge-dev/cross-libc-dlopen

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export CROSS_LIBC_DLOPEN_REPO="https://github.com/pkgforge-dev/cross-libc-dlopen.git"
export ICON=DUMMY
export DESKTOP=DUMMY
export OUTPATH=./dist
export OUTNAME=vkcube+glxgears-host-drivers-demo-"$ARCH".AppImage
export MAIN_BIN=vkcube
# ship zero gpu drivers, quick-sharun excludes everything the binaries
# merely dlopen at runtime (dri plugins, gallium, vulkan layers, etc)
# while libraries linked directly like libvulkan.so stay bundled
export USE_HOST_DRIVERS_EXPERIMENTAL=1
# vkmark is hardcoded to look in /usr/share/vkmark and /usr/lib/vkmark
export PATH_MAPPING='
	/usr/share/vkmark:${SHARUN_DIR}/share/vkmark
	/usr/lib/vkmark:${SHARUN_DIR}/lib/vkmark
'

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
	mesa-utils       \
	patchelf         \
	vkmark           \
	vulkan-tools     \
	wget             \
	xcb-util-wm      \
	xorg-server-xvfb \
	zsync

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-mesa --prefer-nano libdecor-mini

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun /usr/bin/vkcube /usr/*/vkmark /usr/bin/glxgears /usr/bin/eglgears*

./quick-sharun --make-appimage

# CI has no available gpu for the test
pacman -S --noconfirm vulkan-swrast

# test the final app
./quick-sharun --test ./dist/*.AppImage
