#!/bin/sh

# Demonstration that bundles vkcube (vulkan) and glxgears (opengl)

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
AUR="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/make-aur-package.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export ICON=DUMMY
export DESKTOP=DUMMY
export OUTPATH=./dist
export OUTNAME=vkcube+glxgears-demo-"$ARCH".AppImage
# there are no vulkan drivers for ppc64, ppc64le, loongarch64 and riscv64
# (neither in the repos nor in archlinux-pkgs-debloated), so vkcube cannot
# work there and glxgears becomes the default binary instead
export MAIN_BIN=vkcube
case "$ARCH" in
	ppc64|ppc64le|loongarch64|riscv64) export MAIN_BIN=glxgears;;
esac
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
	xorg-server-xvfb

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-mesa --prefer-nano libdecor-mini

#if [ "$ARCH" = 'x86_64' ]; then
#	# We are experimenting with adding vulkan-terakan
#	# This adds vulkan support for super old radeon gpus
#	# It hasn't been upstreamed to mesa so we have to build it
#	echo "Building vulkan-terakan aur package..."
#	echo "---------------------------------------------------------------"
#	wget --retry-connrefused --tries=30 "$AUR" -O ./make-aur-package.sh
#	chmod +x ./make-aur-package.sh
#	./make-aur-package.sh vulkan-terakan-git
#fi

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun /usr/bin/vkcube /usr/*/vkmark /usr/bin/glxgears /usr/bin/eglgears*

./quick-sharun --make-appimage

# becasue this app launches vkcube and there is no gpu in the CI, we have to
# install vkswrast, we do not normally bundle this since it is slow and has
# a massive dependency to llvm
# the other arches test glxgears instead, which uses the bundled llvmpipe
case "$ARCH" in
	x86_64|aarch64) pacman -S --noconfirm vulkan-swrast;;
esac

# test the final app
./quick-sharun --test ./dist/*.AppImage
