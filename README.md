## **Anylinux AppImages**

![Downloads](https://img.shields.io/endpoint?url=https://cdn.jsdelivr.net/gh/pkgforge-dev/Anylinux-AppImages@main/.github/badge.json)

Designed to run seamlessly on any Linux distribution, including older distributions and musl-based ones. Our AppImages bundle all the needed dependencies and do not depend on host libraries to work, unlike most other AppImages.

Most of the AppImages are made with [sharun](https://github.com/VHSgunzo/sharun). We also use an alternative, better [runtime](https://github.com/VHSgunzo/uruntime).

The uruntime [automatically falls back to using extract and run](https://github.com/VHSgunzo/uruntime?tab=readme-ov-file#built-in-configuration) if FUSE is not available at all, so we **truly have 0 requirements.**

We also try to avoid the usage of containers/namespaces and similar methods, so far the AppImages that depend on them are Lutris and virt-manager.

**How is this possible?** See: [How to guide](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md)

---

| Applications                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------ |
[alacritty](https://github.com/pkgforge-dev/alacritty-AppImage)                                                          |
[Android Tools](https://github.com/pkgforge-dev/android-tools-AppImage)                                                  |
[AppImageUpdate](https://github.com/pkgforge-dev/AppImageUpdate-Enhanced-Edition)                                        |
[ares-emu](https://github.com/pkgforge-dev/ares-emu-appimage)                                                            |
[Azahar](https://github.com/pkgforge-dev/Azahar-AppImage-Enhanced)                                                       |
[Cemu](https://github.com/pkgforge-dev/Cemu-AppImage-Enhanced)                                                           |
[Citron](https://github.com/pkgforge-dev/Citron-AppImage)                                                                |
[Clementine](https://github.com/pkgforge-dev/Clementine-AppImage)                                                        |
[Cromite](https://github.com/pkgforge-dev/Cromite-AppImage)                                                              |
[Dolphin-emu](https://github.com/pkgforge-dev/Dolphin-emu-AppImage)                                                      |
[DeaDBeeF](https://github.com/pkgforge-dev/DeaDBeeF-AppImage)                                                            |
[DeSmuME](https://github.com/pkgforge-dev/DeSmuME-AppImage)                                                              |
[dunst](https://github.com/pkgforge-dev/dunst-AppImage)                                                                  |
[EasyTAG](https://github.com/pkgforge-dev/EasyTAG-AppImage)                                                              |
[Ghostty](https://github.com/pkgforge-dev/ghostty-appimage)                                                              |
[GIMP-and-PhotoGIMP](https://github.com/pkgforge-dev/GIMP-and-PhotoGIMP-AppImage)                                        |
[Gnome Calculator](https://github.com/pkgforge-dev/Gnome-Calculator-AppImage)                                            |
[Gnome Pomodoro](https://github.com/pkgforge-dev/gnome-pomodoro-appimage)                                                |
[Gnome Text Editor](https://github.com/pkgforge-dev/Gnome-Text-Editor-AppImage)                                          |
[gpu-screen-recorder](https://github.com/pkgforge-dev/gpu-screen-recorder-AppImage)                                      |
[htop](https://github.com/pkgforge-dev/htop-AppImage)                                                                    |
[kdeconnect](https://github.com/pkgforge-dev/kdeconnect-AppImage)                                                        |
[kdenlive](https://github.com/pkgforge-dev/kdenlive-AppImage-Enhanced)                                                   |
[Ladybird](https://github.com/pkgforge-dev/ladybird-appimage)                                                            |
[Lutris](https://github.com/pkgforge-dev/Lutris-AppImage)                                                                |
[MAME](https://github.com/pkgforge-dev/MAME-AppImage)                                                                    |
[Mednafen](https://github.com/pkgforge-dev/mednafen-appimage)                                                            |
[mpv](https://github.com/pkgforge-dev/mpv-AppImage)                                                                      |
[NSZ](https://github.com/pkgforge-dev/NSZ-AppImage)                                                                      |
[OBS Studio](https://github.com/pkgforge-dev/OBS-Studio-AppImage)                                                        |
[pavucontrol-qt](https://github.com/pkgforge-dev/pavucontrol-qt-AppImage)                                                |
[Pixelpulse2](https://github.com/pkgforge-dev/Pixelpulse2-AppImage)                                                      |
[playerctl](https://github.com/pkgforge-dev/playerctl-AppImage)                                                          |
[polybar](https://github.com/pkgforge-dev/polybar-AppImage)                                                              |
~[PPSSPP](https://github.com/pkgforge-dev/PPSSPP-AppImage)~ - [Upstreamed](https://github.com/hrydgard/ppsspp/releases). |
[puddletag](https://github.com/pkgforge-dev/puddletag-AppImage)                                                          |
[Rnote](https://github.com/pkgforge-dev/Rnote-AppImage)                                                                  |
[rofi](https://github.com/pkgforge-dev/rofi-AppImage)                                                                    |
[scrcpy](https://github.com/pkgforge-dev/scrcpy-AppImage)                                                                |
[SpeedCrunch](https://github.com/pkgforge-dev/SpeedCrunch-AppImage)                                                      |
[st](https://github.com/pkgforge-dev/st-AppImage)                                                                        |
[strawberry](https://github.com/pkgforge-dev/strawberry-AppImage)                                                        |
[Sudachi](https://github.com/pkgforge-dev/Sudachi-AppImage)                                                              |
[Torzu](https://github.com/pkgforge-dev/Torzu-AppImage)                                                                  |
[transmission-qt](https://github.com/pkgforge-dev/transmission-qt-AppImage)                                              |
[UnleashedRecomp](https://github.com/pkgforge-dev/UnleashedRecomp-AppImage)                                              |
[virt-manager](https://github.com/pkgforge-dev/virt-manager-AppImage)                                                    |
[xenia-canary](https://github.com/pkgforge-dev/xenia-canary-AppImage)                                                    |
[Zenity](https://github.com/pkgforge-dev/Zenity-GTK3-AppImage)                                                           |

---

Also see [other projects](https://github.com/VHSgunzo/sharun?tab=readme-ov-file#projects-that-use-sharun) that use sharun for more. **Didn't find what you were looking for?** Open an issue here and we will see what we can do.
