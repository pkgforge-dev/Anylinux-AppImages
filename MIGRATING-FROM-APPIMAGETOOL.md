---
layout: default
title: Migrating from legacy appimagetool
---

# Migrating from legacy `appimagetool`

The legacy [AppImageKit](https://github.com/AppImage/AppImageKit) `appimagetool` is a
C/GLib program that shells out to `mksquashfs` and wraps the AppDir in a SquashFS
AppImage type-2 runtime. This project uses
[pkgforge-dev/appimagetool](https://github.com/pkgforge-dev/appimagetool) instead: a
Rust rewrite that builds a **DWARFS** image with the [uruntime](https://github.com/VHSgunzo/uruntime)
runtime, downloads its helpers on demand, and generates zsync data itself.

The command you already know (`appimagetool ./AppDir`) still works. What changed is
mostly the flags around it, plus a couple of AppDir rules that are now enforced.

If you are starting from scratch, you almost certainly want the [Quick Start
Guide](HOW-TO-MAKE-THESE.md#quick-start-guide) instead — `quick-sharun` calls this
`appimagetool` for you. This page is for existing hand-rolled AppDirs that only need
their packaging step updated.

-----------------------------------

### *Install the new tool*

Grab the plain release binary (MIT, downloads helpers at build time):

```sh
curl -fL -o appimagetool \
  https://github.com/pkgforge-dev/appimagetool/releases/latest/download/appimagetool-x86_64-linux
chmod +x appimagetool
```

Or build it with `cargo build --release`.

Two flavours are published: `appimagetool-<arch>` (no embedded helpers, MIT) and
`appimagetool-full-<arch>` (embeds `uruntime` + `mkdwarfs`, needs no network at build
time, but is GPL-3.0-or-later because it carries the DwarFS writer). `--license` prints
what a given build actually contains.

-----------------------------------

### *CLI cheat-sheet*

| Legacy (AppImageKit) | pkgforge-dev | Notes |
| --- | --- | --- |
| `appimagetool AppDir` | `appimagetool AppDir` | unchanged |
| `appimagetool AppDir out.AppImage` (2nd positional) | `appimagetool AppDir -o <dir> -n out.AppImage` | the output path is **no longer a positional**; only one positional arg is accepted |
| `ARCH=x86_64` | `APPIMAGE_ARCH=x86_64` for the runtime, `ARCH` for the filename | `ARCH` is now only a display alias (`amd64`, etc.) |
| `-n`, `--no-appstream` | *removed* | the new tool does not validate AppStream, so there is nothing to suppress |
| `-u`, `--updateinformation STRING` | `-u`, `--update-info STRING` (env `UPINFO`) | same zsync update string |
| `--runtime-file FILE` | `--runtime FILE` (env `RUNTIME`) | expects a uruntime binary, not the legacy runtime |
| `--comp XZ` | `--dwarfs-comp <opts>` | DWARFS options, not SquashFS compressors |
| `--mksquashfs-opt ...` | `--mkdwarfs PATH`, `--dwarfs-comp ...` | mksquashfs is no longer in the pipeline |
| `--exclude-file FILE` | *removed* | remove files from the AppDir before building |
| `-s`, `--sign [--sign-key ID]` | *removed* | no GPG signing step |
| `-g`, `--guess` | *removed* | in CI, `GITHUB_REPOSITORY` auto-derives the update info |
| `-l`, `--list` | *removed* | inspect with the AppImage runtime (`--appimage-extract`) instead |
| `-v`, `--verbose` | `-v`, repeatable | `-vv` for more |
| `VERSION` env | `VERSION` env, or `~/version` | unchanged |

> **Careful:** `-n` is the trap. In the legacy tool `-n` means `--no-appstream`; in the
> new tool it means `--name` and takes a value. A script written for the old tool will
> silently reinterpret its arguments.

-----------------------------------

### *AppDir requirements*

The new tool validates the AppDir up front. It requires:

1. an **executable `AppRun`** in the AppDir root,
2. a **`.DirIcon`** (PNG or SVG),
3. **exactly one** `.desktop` file in the AppDir root.

Items 1 and 3 held before too; `.DirIcon` is now mandatory rather than best-effort. The
tool then writes `X-AppImage-*` metadata into the desktop entry and produces
`<AppName>-<Version>-anylinux-<Arch>.AppImage` in `--output` (default `.`), unless you
pin the filename with `--name` / `OUTNAME`. `<Version>` comes from `VERSION` or a
`~/version` file.

-----------------------------------

### *Update information and zsync*

The legacy tool shelled out to `zsyncmake`. The new one generates the `.zsync` file
itself whenever update info is set:

```sh
appimagetool ./AppDir \
  --output ./dist \
  --update-info "gh-releases-zsync|org|repo|latest|*-x86_64.AppImage.zsync"
```

In GitHub Actions, if `GITHUB_REPOSITORY` is set you usually need nothing at all — the
tool derives `gh-releases-zsync|owner|repo|latest|*<arch>.AppImage.zsync`:

```sh
VERSION=1.2.3 appimagetool ./AppDir --output ./dist
```

It also writes an `appinfo` sidecar next to the AppImage.

-----------------------------------

### *Reproducibility*

`mkdwarfs` is invoked with `--no-create-timestamp`, so the image itself carries no
wall-clock timestamp. As of 0.5.2 the tool does **not** read `SOURCE_DATE_EPOCH` yet;
if you need byte-identical output today, pin `--name` and `VERSION` and reuse a cached
`--runtime` / `--mkdwarfs`.

-----------------------------------

### *Worked example: updating a hand-rolled build script*

A packaging step written for the legacy tool typically looks like this:

```sh
if [ -f "./appimagetool" ]; then
    chmod +x ./appimagetool
    ARCH=x86_64 ./appimagetool -n "$BUILD_DIR" MyApp-x86_64.AppImage
fi
```

Under the new tool this fails for three independent reasons:

- `-n "$BUILD_DIR"` now sets the **output name** to the value of `$BUILD_DIR`, instead
  of skipping the AppStream check.
- `MyApp-x86_64.AppImage` is then treated as the **AppDir**, not the output, and the
  build dies with a confusing "No AppRun found" message.
- `ARCH=x86_64` no longer picks the runtime; `APPIMAGE_ARCH` does.

**The migrated step:**

```sh
APPIMAGE_ARCH=x86_64 ./appimagetool "$BUILD_DIR" \
    --output . \
    --name MyApp-x86_64.AppImage
```

`--output .` is the default and can be dropped, and `-o`/`-n` are short for the same
thing. Or drive it entirely from the environment:

```sh
APPIMAGE_ARCH=x86_64 OUTNAME=MyApp-x86_64.AppImage ./appimagetool "$BUILD_DIR"
```

There is one more thing to check while you are there. Hand-rolled scripts often treat
`.DirIcon` as optional, or fall back to a `.bmp` or a symlink when the PNG is missing.
The new tool rejects a missing `.DirIcon`, so make the icon a hard requirement:

```sh
if [ ! -f "myapp.png" ]; then
    echo "myapp.png is required: it becomes the AppDir .DirIcon" >&2
    exit 1
fi
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps"
cp "myapp.png" "$BUILD_DIR/myapp.png"
cp "myapp.png" "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/myapp.png"
cp "myapp.png" "$BUILD_DIR/.DirIcon"
```

Everything else in the script stays as-is: the AppDir contents, the `AppRun`, the
desktop entry and the AppStream file. The new `appimagetool` only cares about the
AppDir layout, not about what `AppRun` launches.

If the AppDir is hand-rolled rather than produced by `quick-sharun`, that is fine —
migrating the `appimagetool` call alone is the correct minimal change. If it later
moves to `quick-sharun`, any custom `AppRun` logic has to move into a `.hook` file (see
[hook-system.md](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/hooks/hook-system.md)).

-----------------------------------

### *Verifying a build*

```sh
VERSION=1.0 APPIMAGE_ARCH=x86_64 ./appimagetool ./MyApp.AppDir -o ./dist
# -> ./dist/MyApp-1.0-anylinux-x86_64.AppImage

# Run it without FUSE (handy in containers and CI):
APPIMAGE_EXTRACT_AND_RUN=1 ./dist/MyApp-1.0-anylinux-x86_64.AppImage
```

uruntime still exports the conventional `$APPIMAGE`, `$APPDIR` and `$OWD` variables, so
an `AppRun` that relies on them keeps working.

-----------------------------------

### *See also*

- [HOW-TO-MAKE-THESE.md](HOW-TO-MAKE-THESE.md) — the `quick-sharun` workflow this
  project recommends for new AppImages
- [FAQ.md](FAQ.md)
- [pkgforge-dev/appimagetool](https://github.com/pkgforge-dev/appimagetool) — upstream
  README and full CLI reference
