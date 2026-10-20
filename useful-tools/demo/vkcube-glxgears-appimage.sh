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
# BE ppc64 predates vulkan, so glxgears is the default binary there
export MAIN_BIN=vkcube
case "$ARCH" in
	ppc64) export MAIN_BIN=glxgears;;
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
#
# on riscv64, loongarch64, ppc64 and ppc64le the debloated mesa still ships
# the files that upstream now splits into vulkan-mesa-implicit-layers, which
# vulkan-swrast depends on, so the transaction collides with its own mesa
pacman -S --noconfirm \
	--overwrite '/usr/lib/libVkLayer_MESA_*' \
	--overwrite '/usr/share/vulkan/implicit_layer.d/*' \
	vulkan-swrast

# test the final app
./quick-sharun --test ./dist/*.AppImage
