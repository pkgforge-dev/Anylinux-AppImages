# Available hooks

| Hook | Description |
|------|-------------|
| `self-updater.hook` | Makes the AppImage self-updatable using appimageupdatetool |
| `fix-namespaces.hook` | Fixes unprivileged user namespace restrictions (Ubuntu 24.04+) |
| `fix-gnome-csd.hook` | Uses host libdecor plugins for window decorations on GNOME Wayland |
| `udev-installer.hook` | Prompts the user to install bundled udev rules when needed |
| `vulkan-check.hook` | Checks and fixes common Vulkan and hardware acceleration issues |
| `x86-64-v3-check.hook` | Warns the user if their CPU does not support x86-64-v3 |
| `x86-64-v4-check.hook` | Warns the user if their CPU does not support x86-64-v4 |
| `host-libjack.hook` | Uses the host JACK library instead of the bundled one |
| `wayland-is-broken.hook` | Forces X11 fallback for applications with known Wayland issues |
| `sdl-soundfonts.hook` | Downloads and installs a SoundFont (FluidR3) when the application needs one |
| `get-yt-dlp.hook` | Downloads `yt-dlp` when the application requires it to play online videos |
| `qt-theme.hook` | Applies a custom Qt stylesheet via `APPIMAGE_QT_THEME` or a `.stylesheet` sidecar file |

Hooks are sourced by the generated `AppRun`. Older `.bg.hook` and `.src.hook` suffixes are only normalized for compatibility, so new examples should use plain `.hook` names.

Additional hooks can be placed in `$APPDIR/bin` and will be used automatically.

---

# The following functions and env variables are always available for hooks to use:

# Functions

- `notify`  - Show messages and notifications with various tools like kdialog, yad, zenity, notify-send and more.
    If no tool is available it will finally attempt to use the host terminal emulator to display the message
```
    FLAGS:
    -di, --display-info MESSAGE      Display simple message
    -de, --display-error MESSAGE     Display error message
    -dw, --display-warning MESSAGE   Display warning message
    -dq, --display-question MESSAGE  Display yes/no question
    -ni, --notify-info MESSAGE       Send simple notification
    -ne, --notify-error MESSAGE      Send error notification
    -nw, --notify-warning MESSAGE    Send warning notification

    NOTE: If no flag is provided --notify-info behaviour is used instead.
```

- `download` - USAGE: `download </path/to/dst-file> <url>`
   This tool will attempt to use `wget` or `curl` to download, if neither command is available it will return 1 with an error message to stderr.
- `is_cmd` - Checks if the given arguments are a valid command in `PATH`, this function does not print anything to stdout or stderr.
    This function accepts multiple arguments to check. Example: `is_cmd cat grep mkdir`
    If argument is a valid command it returns 0, else returns 1.
    If multiple arguments are given and one is missing, it still returns 1.
    You can pass the `--any` flag as first argument if you want to know if one of many arguments is available.
    Example: `is_cmd --any wget curl` will only return 1 if both `wget` and `curl` are not available.
- `run_gui_sudo` - This function performs the given argument as root using an available tool to ask to elevate rights.
   If the user is already root, it then directly performs the operation without any of the tools it checks for.
   It checks and uses the following commands:
```
   pkexec
   lxqt-sudo
   run0
```
   If none of these tools are available, it returns 1 with an error message to stderr.
   You can use `run_gui_sudo --check` to know beforehand if it is possible to run this function, it will return 1 if none of the tools are available and the user is not root.
- `err_msg` - Prints what is given to stderr in red color. Example: `err_msg "Failed to get current time!"`

# Variables

* `APPIMAGE_ARCH` - Architecture of the running AppImage, equivalent to the output of `uname -m`, example: `x86_64`.
* `HOSTPATH`      - The original value of `PATH` before `$APPDIR/bin` is added to `PATH`.
* `APPDIR`        - The directory where the `AppRun` is located. **We guarantee this variable to be set even when the AppImage is extracted.**

* `BINDIR`    - Value of `XDG_BIN_HOME` or if not set; `~/.local/bin`.
* `DATADIR`   - Value of `XDG_DATA_HOME` or if not set; `~/.local/share`.
* `CONFIGDIR` - Value of `XDG_CONFIG_HOME` or if not set; `~/.config`.
* `CACHEDIR`  - Value of `XDG_CACHE_HOME` or if not set; `~/.cache`.
* `STATEDIR`  - Value of `XDG_STATE_HOME` or if not set; `~/.local/state`.

* `HOST_HOME`            - Original value of `HOME` ignoring AppImage portable home mode.
* `HOST_XDG_CONFIG_HOME` - Original value of `XDG_CONFIG_HOME` ignoring AppImage portable config.
* `HOST_XDG_DATA_HOME`   - Original value of `XDG_DATA_HOME` ignoring AppImage portable data.
* `HOST_XDG_CACHE_HOME`  - Original value of `XDG_CACHE_HOME` ignoring AppImage portable cache.
* `HOST_XDG_STATE_HOME`  - (Do not rely on this variable since the uruntime does provide AppImage portable state).
