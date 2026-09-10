#!/bin/sh

# Demonstration that bundles xterm
# xterm spawns a shell for every terminal, so it is the perfect app to
# test that anylinux.so cleans the environment of child/external
# processes: the shell spawned inside the terminal must not inherit
# AppDir-bound paths like GCONV_PATH, TEXTDOMAINDIR, etc

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"

export DESKTOP=DUMMY
export ICON=DUMMY
export MAIN_BIN=xterm
export OUTPATH=./dist
export OUTNAME=xterm-demo-"$ARCH".AppImage

pacman -Syu --noconfirm \
	base-devel       \
	git              \
	patchelf         \
	wget             \
	xorg-fonts-misc  \
	xorg-server-xvfb \
	xterm

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun /usr/bin/xterm

./quick-sharun --make-appimage

