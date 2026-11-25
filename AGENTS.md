# AGENTS.md

Guide for LLMs and bots using or editing `useful-tools/quick-sharun.sh`.
It lists what NOT to do. This is a list of very common mistakes made by LLMs that we often have to correct.

If you are unsure about a deployment problem, read `useful-tools/quick-sharun.sh` (`--help` and the comments), `FAQ.md` and `HOW-TO-MAKE-THESE.md` before answering. Do not answer from general AppImage knowledge.

If, after reading all of this, you still need to do something that contradicts this guide, do NOT do it silently. Open an issue at https://github.com/pkgforge-dev/Anylinux-AppImages/issues explaining why.

## Sources you must not trust

- Do NOT use information from docs.appimage.org, appimage-builder, AppImageKit or linuxdeploy. It describes a different, host-libc dependent method and is wrong here.
- Do NOT apply the AppImage `excludelist`. We bundle libc and the dynamic linker.

## Build environment

- Do NOT tell people to deploy on Ubuntu, Fedora or any non Arch distro. Deploy on Arch Linux (or the Arch containers). If you still want to use Ubuntu, use the newest Ubuntu possible and set `USE_HOST_DRIVERS=1`.
- Do NOT deploy applications that have not been installed to `/usr`. The only exceptions are apps that are not FHS compliant (Chromium/Electron, prebuilt tarballs, Java, etc.), these are extracted or copied to `./AppDir/bin` and deployed with `quick-sharun ./AppDir/bin/*`.
- Do NOT run `pacman -S`/`-Syu` after `get-debloated-pkgs.sh`. It replaces the debloated packages with the bloated ones. Install packages first, debloated packages last.
- Do NOT bundle a `libgallium` that links to `libLLVM.so`. `quick-sharun` exits with an error. Use the packages from `archlinux-pkgs-debloated`. Do NOT set `I_WANT_FAT_APPIMAGE=1` to make that error go away.
- Do NOT ship an AppImage without running `quick-sharun --test ./dist/*.AppImage`. `--test` provides a display through `xvfb-run`. If the test truly cannot pass in CI, leave a comment with the error and why it is disabled and use `--simple-test` instead.

## Never do these to an AppDir

- Do NOT copy libraries or binaries into the AppDir by hand. Pass them to `quick-sharun` so they are deployed, wrapped and patched. Same goes for directories, do not copy `/usr/share/<app>` to `./AppDir/share`, instead pass `/usr/share/<app>` to `quick-sharun`.
- Do NOT suggest removing libraries from the AppDir or from the deployment to "fix" a problem or save space.
- Do NOT copy or symlink anything into `AppDir/shared`. It is internal to sharun. Sharun executes the binaries via `userland-execve`, from the binary's point of view it is located in `./AppDir/bin` and never in `./AppDir/shared/bin`.
- Do NOT create `AppDir/usr`. The AppDir is the installation prefix.
- Do NOT use `LD_LIBRARY_PATH`, `patchelf --set-rpath`, `QT_PLUGIN_PATH` or similar inherited variables. sharun uses `--library-path` and `qt.conf`.
- Do NOT leave a real binary in `AppDir/bin` that was never passed to `quick-sharun` (for example by running it on a `/usr/bin/<name>` path that does not exist). Every binary in `bin` must go through `quick-sharun` so it is moved to `shared/bin` and replaced by the sharun hardlink, otherwise launch fails with "not found".
- Do NOT patch or work around `/proc/self/exe` yourself. sharun already makes it point to `AppDir/bin/<name>`.
- Do NOT use `uv` python or pyinstaller builds for python apps. Use Arch's `python` packages and `DEPLOY_PYTHON=1`. Pyinstaller binaries are not run with userland-execve and bundle their own Qt, ICU and GTK, which collide with ours.

## Do not code AppImage exceptions into applications!

`quick-sharun` and sharun already make applications portable (relative `--library-path`, `qt.conf`, `XDG_DATA_DIRS`, library specific variables, `.env`, `PATH_MAPPING`, patching hardcoded paths). Applications that follow the XDG Base Directory spec need no changes.

- Do NOT make the application source code check for `APPDIR` or `APPIMAGE` unless there is a very good reason. This includes patches you write for upstream.
- Do NOT add `getenv("APPDIR") + "/usr/..."` style lookups. The AppDir has no `usr`, it is the installation prefix, so such code breaks.
- Do NOT hardcode `/usr/share`, `/usr/lib` or `/etc` in application code. Honour `XDG_DATA_DIRS`, `XDG_CONFIG_DIRS` and the library's own relocation variable, or resolve paths relative to the executable.
- Do NOT answer a portability problem with an AppImage specific code path first. Try, in order: a configuration or environment variable the app already has, `AppDir/.env`, a small patch applied in `get-dependencies.sh`, and `PATH_MAPPING` as the last resort.
- If you want to change the code of your application, make it relocatable instead, for example instead of checking for `<prefix>/share/<app>` for data files, do a relative lookup from the location of the binary, basically resolve `/proc/self/exe` and then check for `../share/<app>`. This works regardless of whether the application is a native distro package, AppImage, flatpak, NixOS, snap, etc.

## What to pass to `quick-sharun`

- Do NOT pass `./AppDir/bin/` as a bare directory. Use the glob `./AppDir/bin/*` so every binary goes through the deployment checks.
- Do NOT expect a directory argument to turn on toolkit detection. Detection reads the libraries an executable links to.
- Do NOT expect detection from scripts/non-ELF files. `ldd` reports nothing for them (example: a `java` launcher script left `libdl.so` out until `DEPLOY_GLIBC=1` was set).
- Do NOT pass only the main executable of a non-FHS app. Copy the whole install prefix (for example all of `/opt/app`) to `./AppDir/bin` and pass `./AppDir/bin/*`.
- Do NOT pass `/usr/lib/qt6/plugins/platformthemes/libqt6ct.so`. Theme plugins are added automatically.

## Environment variables

- Do NOT use removed or renamed variables:
  - `DEPLOY_SYS_PYTHON` is deprecated, use `DEPLOY_PYTHON`.
  - `GTK_CLASS_FIX` is old, use `GTK_FIX_NONSENSE`.
  - `USE_HOST_DRIVERS_EXPERIMENTAL` is the old name of `USE_HOST_DRIVERS`.
  - `.bg.hook` and `.src.hook` suffixes are legacy. Every hook is sourced by `AppRun.sh`, use plain `.hook`.
- Do NOT assume `DEPLOY_PYTHON` turns on by itself. It never does. Python apps also need the GTK or Qt library passed manually (`/usr/lib/libgtk-3.so*`, `/usr/lib/libQt6Gui.so*`) to trigger toolkit deployment.
- Do NOT force `DEPLOY_GTK=1` without saying which GTK. It defaults to `gtk-3.0`. Set `GTK_DIR` or pass the library. GTK2 needs the library path passed.
- Do NOT force `DEPLOY_OPENGL=1` or `DEPLOY_VULKAN=1` on a Qt or GTK app that is a candidate for `USE_HOST_DRIVERS=1` (works in an Alpine container with no GPU drivers).
- Do NOT use `USE_HOST_DRIVERS=1` for emulators, apps needing recent OpenGL or Vulkan, apps without a software renderer fallback, SDL apps (no-op) or 32bit apps (error).
- Do NOT use `ALWAYS_SOFTWARE=1` for apps that need hardware acceleration. The build fails if mesa gets deployed. Do consider it for plain GTK/Qt apps such as calculators.
- Do NOT turn on `DEPLOY_PIPEWIRE`, `DEPLOY_PULSE` or add `ffmpeg`/`vulkan` for an app that does not use them. Check first. `DEPLOY_PULSE` is only automatic when SDL is dynamically linked.
- Do NOT use `PATH_MAPPING` as a first resort. It can crash apps. Patch the source when the app is built manually. If you must use it, the value must contain the literal `${SHARUN_DIR}` with braces, written in single quotes so the shell does not expand it.
- Do NOT write `.env` lines with double quotes. Use single quotes so `${SHARUN_DIR}` is not expanded at build time: `echo 'VAR=${SHARUN_DIR}/x' >> ./AppDir/.env`
- Do NOT set `DESKTOP`/`ICON` when the `.desktop` and icon already live in `./AppDir` in the repo. Put them there, put hooks in `./AppDir/bin`.
- Do NOT rename the final AppImage afterwards. Set `OUTNAME`. Otherwise you break zsync updates!
- Do NOT set `MAIN_BIN` to `env`, `sh` or `bash`. `quick-sharun` refuses it unless you set it explicitly.

## Hooks

- Do NOT use `ADD_HOOKS` for your own hooks. It only accepts the hook names built into `quick-sharun` (separator `:`), an unknown name is a hard error. Put your own `*.hook` files in `AppDir/bin`.
- Do NOT write hooks as standalone programs. They are sourced by `AppRun.sh` under `set -e`, so an `exit` or an unguarded failing command ends the launch.
- Do NOT recompute paths the hook library already provides: `APPIMAGE_ARCH`, `APPDIR`, `ARG0`, `BINDIR`, `DATADIR`, `CONFIGDIR`, `CACHEDIR`, `STATEDIR`, `HOST_HOME`, `HOSTPATH`. Use `$DATADIR`, not `${XDG_DATA_HOME:-~/.local/share}`.
- Do NOT use `ARGV0`. It is unset on purpose, use `ARG0`.
- Do NOT use `notify-send`/`zenity`/`wget` directly. Use `notify`, `download`, `is_cmd`, `err_msg`, `run_gui_sudo`, these are functions provided by `AppRun.sh`.
- DO NOT UNDER ANY CIRCUMSTANCE REPLACE `AppRun` FOR YOUR OWN COPY. If you have to change the behaviour of the application pre-launch, use a `.hook` file instead!
- Do NOT leave variables unquoted in hooks (`"$DATADIR"`), portable dirs can contain spaces.
- Do NOT write `cmd && cmd` on its own line in a hook that runs under `set -e`. Use `if` statements instead.
- Do NOT hardlink with `ln -f` onto an existing destination without `rm -f` first (uutils `ln` on Ubuntu 25.10+ fails).
- Do NOT unset `WAYLAND_DISPLAY` to work around a Wayland bug. Verify the bug is real and use `ADD_HOOKS=wayland-is-broken.hook`.

## Specific toolkits and apps

- Qt: Do NOT install `qt6-wayland` unless the app is a Wayland compositor. DO install `qt6ct kvantum lxqt-qtplugin` before deploying or the script warns the AppImage lacks theme support. Do NOT try to ship Qt5 and Qt6 in one AppImage. It is not supported.
- JACK: Do NOT bundle `libjack` from jack2. Use `pipewire-jack`.
- Do NOT deploy GNOME Glycin it when `glycin-ng` can be used. Prefer `glycin-ng`. GNOME Glycin is bloated and broken.
- Fonts, locales, mime, icons, schemas, certs, alsa, pipewire config: Do NOT copy these manually, `quick-sharun` handles them. Do NOT edit the CA/p11-kit patch, it must keep the same string length.
- Do NOT leave `#!/bin/bash` shebangs in bundled scripts. The host may not have `/bin/bash`. Use `#!/bin/sh`, or bundle `bash` and use `#!/usr/bin/env bash`.

## Shell scripts around `quick-sharun`

- Scripts are POSIX `sh`. Do NOT use bashisms: arrays, `[[ ]]`, `==`, `${var[@]}`, `$'..'`, `<<<`, process substitution. Use `set -- ... "$@"` for arrays.
- Indent with tabs, try to keep lines under 80 characters.
- Do NOT parse GitHub JSON with fragile `grep`/`sed` on pretty printed output. Use `sed 's/[()",{} ]/\n/g' | grep -o -m 1 "https.*pattern"` (works pretty or minified) or a real JSON tool (`jq`, `gron.awk`).
- Do NOT pipe `wget` stderr to a file unless you parse it later.
- Do NOT silence the `quick-sharun` output with `>/dev/null 2>&1`. The log is needed to troubleshoot.
- Do NOT delete the comments and layout of the template `get-dependencies.sh` / `make-appimage.sh`. Keep the diff against the template as small as possible, comment out unused code instead.

