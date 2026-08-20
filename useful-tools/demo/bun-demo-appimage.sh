#!/bin/sh

# Demonstration that compiles a JavaScript GUI application into a
# standalone Linux binary with 'bun build --compile' and bundles it
# SDL2 is loaded at runtime straight from JS via bun's FFI
# https://bun.com/docs/bundler/executables
# https://bun.com/docs/api/ffi

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ICON=https://raw.githubusercontent.com/oven-sh/bun/main/docs/logo/bun.png
export DESKTOP=DUMMY
export OUTPATH=./dist
export OUTNAME=bun-demo-"$ARCH".AppImage
export MAIN_BIN=bun-demo
export DEPLOY_SDL=1
export DEPLOY_OPENGL=1

# bun is not in ALARM, so always take it from upstream releases
case "$ARCH" in
	x86_64)  BUN_ARCH=x64 ;;
	aarch64) BUN_ARCH=aarch64 ;;
	*) echo "ERROR: unsupported architecture: $ARCH"; exit 1 ;;
esac

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
	patchelf         \
	sdl2             \
	sdl2_ttf         \
	ttf-dejavu       \
	unzip            \
	wget             \
	xorg-server-xvfb \
	zsync

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-common --prefer-nano libdecor-mini

echo "Downloading bun from upstream releases..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 \
	"https://github.com/oven-sh/bun/releases/latest/download/bun-linux-$BUN_ARCH.zip"
unzip -q "bun-linux-$BUN_ARCH.zip"
install -Dm755 "bun-linux-$BUN_ARCH/bun" /usr/local/bin/bun

echo "Writing the demo application..."
echo "---------------------------------------------------------------"
cat > main.js << 'EOF'
// Renders an animated SDL2 window straight from JavaScript
// using bun's FFI, no native addons or bindings needed
import { dlopen, FFIType } from "bun:ffi";
// the font is embedded into the compiled binary by bun
import fontFile from "/usr/share/fonts/TTF/DejaVuSans.ttf" with { type: "file" };
import os from "node:os";

const T = FFIType;
const SDL = dlopen("libSDL2-2.0.so.0", {
	SDL_Init:                    { args: [T.u32],                 returns: T.i32 },
	SDL_CreateWindow:            { args: [T.cstring, T.i32, T.i32, T.i32, T.i32, T.u32], returns: T.pointer },
	SDL_CreateRenderer:          { args: [T.pointer, T.i32, T.u32], returns: T.pointer },
	SDL_CreateTextureFromSurface:{ args: [T.pointer, T.pointer],  returns: T.pointer },
	SDL_DestroyTexture:          { args: [T.pointer],             returns: T.void },
	SDL_FreeSurface:             { args: [T.pointer],             returns: T.void },
	SDL_SetRenderDrawColor:      { args: [T.pointer, T.u8, T.u8, T.u8, T.u8], returns: T.i32 },
	SDL_RenderClear:             { args: [T.pointer],             returns: T.i32 },
	SDL_RenderCopy:             { args: [T.pointer, T.pointer, T.pointer, T.pointer], returns: T.i32 },
	SDL_RenderPresent:           { args: [T.pointer],             returns: T.void },
	SDL_PollEvent:               { args: [T.pointer],             returns: T.i32 },
	SDL_Delay:                   { args: [T.u32],                 returns: T.void },
	SDL_Quit:                    { args: [],                      returns: T.void },
}).symbols;

const TTF = dlopen("libSDL2_ttf-2.0.so.0", {
	TTF_Init:               { args: [],                    returns: T.i32 },
	TTF_OpenFont:           { args: [T.cstring, T.i32],    returns: T.pointer },
	TTF_RenderUTF8_Blended: { args: [T.pointer, T.cstring, T.u32], returns: T.pointer },
	TTF_CloseFont:          { args: [T.pointer],           returns: T.void },
	TTF_Quit:               { args: [],                    returns: T.void },
}).symbols;

// bun:ffi cannot dereference pointers, this is the standard trick
// to read a C struct: memcpy it into a JS ArrayBuffer
const memcpy = dlopen("libc.so.6", {
	memcpy: { args: [T.pointer, T.pointer, T.usize], returns: T.pointer },
}).symbols.memcpy;

const readI32 = (ptr, offset) => {
	const buf = new ArrayBuffer(4);
	memcpy(buf, ptr + offset, 4);
	return new DataView(buf).getInt32(0, true);
};

// embedded files live in the virtual $bunfs filesystem which native
// code cannot see, so the font is extracted to the real filesystem
const fontPath = `${os.tmpdir()}/bun-demo-font.ttf`;
if (!await Bun.file(fontPath).exists()) {
	await Bun.write(fontPath, Bun.file(fontFile));
}

// SDL_Init(SDL_INIT_VIDEO)
if (SDL.SDL_Init(0x20) !== 0) {
	throw new Error("SDL_Init failed");
}
if (TTF.TTF_Init() !== 0) {
	throw new Error("TTF_Init failed");
}

const SDL_WINDOWPOS_UNDEFINED = 0x1fff0000;
const win = SDL.SDL_CreateWindow(
	"bun SDL2 Demo - Anylinux AppImages",
	SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 640, 480, 0x4,
);
// prefer a GPU renderer, fall back to software rendering (eg. in CI)
let ren = SDL.SDL_CreateRenderer(win, -1, 0x2);
if (ren === 0) {
	ren = SDL.SDL_CreateRenderer(win, -1, 0x1);
}

const font = TTF.TTF_OpenFont(fontPath, 67);
const surf = TTF.TTF_RenderUTF8_Blended(font, "67", 0xffffffff);
const tex  = SDL.SDL_CreateTextureFromSurface(ren, surf);
const tw = readI32(surf, 16); // SDL_Surface.w
const th = readI32(surf, 20); // SDL_Surface.h
SDL.SDL_FreeSurface(surf);

console.log(
	`[bun-demo] bun ${Bun.version} (${process.arch}) rendering ` +
	`'67' as a ${tw}x${th} SDL2 texture`
);

// SDL_Event is a union, 56 bytes is enough for SDL2
const event = new Uint32Array(128 / 4);
const eventPtr = new Uint8Array(event.buffer);

// SDL_Rect { int x, y, w, h }
const rect = new DataView(new ArrayBuffer(16));
const rectPtr = new Uint8Array(rect.buffer);
const setRect = (x, y, w, h) => {
	rect.setInt32(0, x, true);
	rect.setInt32(4, y, true);
	rect.setInt32(8, w, true);
	rect.setInt32(12, h, true);
};

// DVD-screensaver style bouncing '67' on a color cycling background
let x = 0, y = 0, dx = 3, dy = 2;

outer: for (let frame = 0; ; frame++) {
	// SDL_PollEvent writes into the event buffer, type is the first Uint32
	while (SDL.SDL_PollEvent(eventPtr) !== 0) {
		if (event[0] === 0x100) break outer; // SDL_QUIT
	}

	SDL.SDL_SetRenderDrawColor(ren, frame % 256, (frame * 2) % 256, (frame * 4) % 256, 255);
	SDL.SDL_RenderClear(ren);

	x += dx;
	y += dy;
	if (x < 0 || x > 640 - tw) dx = -dx;
	if (y < 0 || y > 480 - th) dy = -dy;

	setRect(x, y, tw, th);
	SDL.SDL_RenderCopy(ren, tex, 0, rectPtr);

	SDL.SDL_RenderPresent(ren);
	SDL.SDL_Delay(16);
}

SDL.SDL_DestroyTexture(tex);
TTF.TTF_CloseFont(font);
TTF.TTF_Quit();
SDL.SDL_Quit();
EOF

echo "Compiling with bun..."
echo "---------------------------------------------------------------"
bun build --compile --minify --outfile bun-demo main.js

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun ./bun-demo

./quick-sharun --make-appimage

# test the final app
./quick-sharun --test ./dist/*.AppImage
