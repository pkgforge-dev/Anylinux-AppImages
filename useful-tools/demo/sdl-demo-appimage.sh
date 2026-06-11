#!/bin/sh

# Demonstration that bundles a simple SDL2 application

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ICON=https://raw.githubusercontent.com/libsdl-org/SDL/refs/heads/main/VisualC-GDK/logos/Logo150x150.png
export DESKTOP=DUMMY
export OUTPATH=./dist
export OUTNAME=sdl2-demo-"$ARCH".AppImage
export DEPLOY_OPENGL=1
export MAIN_BIN=SDL-demo

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
	sdl2             \
	sdl2_ttf         \
	fontconfig       \
	ttf-dejavu       \
	wget             \
	xorg-server-xvfb \
	zsync

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-common --prefer-nano libdecor-mini

echo "Building SDL-demo..."
echo "---------------------------------------------------------------"
cat > SDL-demo.c << 'EOF'
#include <SDL.h>
#include <SDL_ttf.h>
#include <fontconfig/fontconfig.h>
#include <string.h>
#include <math.h>

static char *find_font(void) {
    FcInit();
    FcPattern *pat = FcNameParse((const FcChar8 *)"sans");
    FcConfigSubstitute(NULL, pat, FcMatchPattern);
    FcDefaultSubstitute(pat);
    FcResult res;
    FcPattern *match = FcFontMatch(NULL, pat, &res);
    FcPatternDestroy(pat);
    if (match) {
        FcChar8 *file;
        if (FcPatternGetString(match, FC_FILE, 0, &file) == FcResultMatch) {
            char *fp = strdup((char *)file);
            FcPatternDestroy(match);
            return fp;
        }
        FcPatternDestroy(match);
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    SDL_Window *win;
    SDL_Renderer *ren;
    TTF_Font *font;
    SDL_Surface *surf;
    SDL_Texture *tex;
    SDL_Color white = {255, 255, 255};
    SDL_Event ev;
    int frame = 0, running = 1;

    SDL_Init(SDL_INIT_VIDEO);
    TTF_Init();
    char *fp = find_font();
    font = TTF_OpenFont(fp, 67);
    free(fp);
    surf = TTF_RenderUTF8_Blended(font, "67", white);
    win = SDL_CreateWindow("SDL2 Demo", SDL_WINDOWPOS_UNDEFINED,
                           SDL_WINDOWPOS_UNDEFINED, 640, 480, SDL_WINDOW_SHOWN);
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    tex = SDL_CreateTextureFromSurface(ren, surf);
    SDL_FreeSurface(surf);

    while (running) {
        while (SDL_PollEvent(&ev))
            if (ev.type == SDL_QUIT) running = 0;

        int r = frame % 256, g = (frame * 2) % 256, b = (frame * 4) % 256;
        SDL_SetRenderDrawColor(ren, r, g, b, 255);
        SDL_RenderClear(ren);

        double c = cos(frame * 0.025);
        int tw, th;
        SDL_QueryTexture(tex, NULL, NULL, &tw, &th);
        int vw = fabs(c) * tw;
        if (vw > 0) {
            SDL_Rect dst = { (640 - vw) / 2, (480 - th) / 2, vw, th };
            SDL_RenderCopyEx(ren, tex, NULL, &dst, 0, NULL,
                             c < 0 ? SDL_FLIP_HORIZONTAL : SDL_FLIP_NONE);
        }

        SDL_RenderPresent(ren);
        SDL_Delay(16);
        frame++;
    }

    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    TTF_CloseFont(font);
    TTF_Quit();
    SDL_Quit();
    return 0;
}
EOF

cc -O2 -o SDL-demo SDL-demo.c $(pkg-config --cflags --libs sdl2 SDL2_ttf fontconfig) -lm

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun ./SDL-demo

./quick-sharun --make-appimage

# test the final app
./quick-sharun --test ./dist/*.AppImage
