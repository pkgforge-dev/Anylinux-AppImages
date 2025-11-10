## **Anylinux AppImages**

![Downloads](https://img.shields.io/endpoint?url=https://cdn.jsdelivr.net/gh/pkgforge-dev/Anylinux-AppImages@main/.github/badge.json)

Designed to run seamlessly on any Linux distribution, including very very old distributions and musl-based ones. Our AppImages bundle all the needed dependencies and do not depend on host libraries to work, unlike most other AppImages, **all while being signiticantly smaller thanks to [DwarFS](https://github.com/mhx/dwarfs) and [optimized packages](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)**.

Most of the AppImages are made with [sharun](https://github.com/VHSgunzo/sharun). We also use an alternative better [runtime](https://github.com/VHSgunzo/uruntime).

The uruntime [automatically falls back to using namespaces](https://github.com/VHSgunzo/uruntime?tab=readme-ov-file#built-in-configuration) if FUSE is not available at all, and if namespaces are not possible it falls back to extract and run, so we **truly have 0 requirements:**

| Format                  | Requirements                                                                                                                                                                                                 |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Traditional AppImages (made by linuxdeploy or similar tools) | **Hard dependency on glibc** (rarely works on distros older than 4 years), also has a soft dependency on **FUSE** since the user has to manually extract when FUSE is unavailable, they also need an FHS compliant system to work. |
| Flatpak| **Hard dependency on bubblewrap and FUSE**. Must be supported by your distribution or be manually built and installed systemwide which requires elevated rights. |
| Snap | Similar requirements to flatpak minus bubblewrap, has a **hard dependency on systemd**. |
| **AnyLinux AppImages** (made with sharun) | Use **FUSE if avaiable**, else **fallback to using namespaces** and if that is not possible then we automatically extract to `TMPDIR` and run with post cleanup, we **do not need an FHS filesystem** and **do not depend on the host libc**, so eh make sure you have `/bin/sh` and write access to `/tmp`??? (If you can boot to a graphical session you already met those requirements). **How is this possible?** See: [How to guide](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md) |
| **AnyLinux AppImages** (made with RunImage) | Similar to sharun AppImages but have a **Hard dependency on namespaces**, Lutris and virt-manager are the only ones that use this method, pending migration to sharun. |


---

| Applications                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------ |
[alacritty](https://github.com/pkgforge-dev/alacritty-AppImage)                                                          |
[Android Tools](https://github.com/pkgforge-dev/android-tools-AppImage)                                                  |
[Android Translation Layer](https://github.com/pkgforge-dev/android_translation_layer-AppImage)                          |
[AppImageUpdate](https://github.com/pkgforge-dev/AppImageUpdate-Enhanced-Edition)                                        |
[ares-emu](https://github.com/pkgforge-dev/ares-emu-appimage)                                                            |
[Azahar](https://github.com/pkgforge-dev/Azahar-AppImage-Enhanced)                                                       |
[Cemu](https://github.com/pkgforge-dev/Cemu-AppImage-Enhanced)                                                           |
[Citron](https://github.com/pkgforge-dev/Citron-AppImage)                                                                |
[Clapper](https://github.com/pkgforge-dev/Clapper-AppImage)                                                              |
[Clementine](https://github.com/pkgforge-dev/Clementine-AppImage)                                                        |
[Cromite](https://github.com/pkgforge-dev/Cromite-AppImage)                                                              |
[Cursor](https://github.com/pkgforge-dev/Cursor-AppImage-enhanced)                                                       |
[Dolphin-emu](https://github.com/pkgforge-dev/Dolphin-emu-AppImage)                                                      |
[DeaDBeeF](https://github.com/pkgforge-dev/DeaDBeeF-AppImage)                                                            |
[DeSmuME](https://github.com/pkgforge-dev/DeSmuME-AppImage)                                                              |
[dunst](https://github.com/pkgforge-dev/dunst-AppImage)                                                                  |
[EasyTAG](https://github.com/pkgforge-dev/EasyTAG-AppImage)                                                              |
[Fretboard](https://github.com/pkgforge-dev/Fretboard-AppImage)                                                          |
[Gapless](https://github.com/pkgforge-dev/Gapless-AppImage)                                                              |
[Ghostty](https://github.com/pkgforge-dev/ghostty-appimage)                                                              |
[GIMP-and-PhotoGIMP](https://github.com/pkgforge-dev/GIMP-and-PhotoGIMP-AppImage)                                        |
[Gnome Calculator](https://github.com/pkgforge-dev/Gnome-Calculator-AppImage)                                            |
[Gnome Pomodoro](https://github.com/pkgforge-dev/gnome-pomodoro-appimage)                                                |
[Gnome Text Editor](https://github.com/pkgforge-dev/Gnome-Text-Editor-AppImage)                                          |
[gpu-screen-recorder](https://github.com/pkgforge-dev/gpu-screen-recorder-AppImage)                                      |
[htop](https://github.com/pkgforge-dev/htop-AppImage)                                                                    |
[Impression](https://github.com/pkgforge-dev/Impression-AppImage)                                                        |
[kdeconnect](https://github.com/pkgforge-dev/kdeconnect-AppImage)                                                        |
[kdenlive](https://github.com/pkgforge-dev/kdenlive-AppImage-Enhanced)                                                   |
[Ladybird](https://github.com/pkgforge-dev/ladybird-appimage)                                                            |
[Lutris](https://github.com/pkgforge-dev/Lutris-AppImage)                                                                |
[MAME](https://github.com/pkgforge-dev/MAME-AppImage)                                                                    |
[Mednafen](https://github.com/pkgforge-dev/mednafen-appimage)                                                            |
[mpv](https://github.com/pkgforge-dev/mpv-AppImage)                                                                      |
[NewsFlash](https://github.com/pkgforge-dev/NewsFlash-AppImage)                                                          |
[NSZ](https://github.com/pkgforge-dev/NSZ-AppImage)                                                                      |
[OBS Studio](https://github.com/pkgforge-dev/OBS-Studio-AppImage)                                                        |
[pavucontrol-qt](https://github.com/pkgforge-dev/pavucontrol-qt-AppImage)                                                |
[Pinta](https://github.com/pkgforge-dev/Pinta-AppImage)                                                                  |
[Pixelpulse2](https://github.com/pkgforge-dev/Pixelpulse2-AppImage)                                                      |
[playerctl](https://github.com/pkgforge-dev/playerctl-AppImage)                                                          |
[polybar](https://github.com/pkgforge-dev/polybar-AppImage)                                                              |
~[PPSSPP](https://github.com/pkgforge-dev/PPSSPP-AppImage)~ - [Upstreamed](https://github.com/hrydgard/ppsspp/releases). |
[puddletag](https://github.com/pkgforge-dev/puddletag-AppImage)                                                          |
[Rnote](https://github.com/pkgforge-dev/Rnote-AppImage)                                                                  |
[rofi](https://github.com/pkgforge-dev/rofi-AppImage)                                                                    |
[scrcpy](https://github.com/pkgforge-dev/scrcpy-AppImage)                                                                |
[servo](https://github.com/pkgforge-dev/servo-AppImage)                                                                  |
[sound-space-plus](https://github.com/pkgforge-dev/sound-space-plus-AppImage)                                            |
[SpeedCrunch](https://github.com/pkgforge-dev/SpeedCrunch-AppImage)                                                      |
[st](https://github.com/pkgforge-dev/st-AppImage)                                                                        |
[strawberry](https://github.com/pkgforge-dev/strawberry-AppImage)                                                        |
[Sudachi](https://github.com/pkgforge-dev/Sudachi-AppImage)                                                              |
[Torzu](https://github.com/pkgforge-dev/Torzu-AppImage)                                                                  |
[TouchHLE](https://github.com/pkgforge-dev/TouchHLE-AppImage)                                                            |
[transmission-qt](https://github.com/pkgforge-dev/transmission-qt-AppImage)                                              |
[uad-ng](https://github.com/pkgforge-dev/uad-ng-AppImage)                                                                |
[UnleashedRecomp](https://github.com/pkgforge-dev/UnleashedRecomp-AppImage)                                              |
[virt-manager](https://github.com/pkgforge-dev/virt-manager-AppImage)                                                    |
[xenia-canary](https://github.com/pkgforge-dev/xenia-canary-AppImage)                                                    |
[Zenity](https://github.com/pkgforge-dev/Zenity-GTK3-AppImage)                                                           |

---

Also see [other projects](https://github.com/VHSgunzo/sharun?tab=readme-ov-file#projects-that-use-sharun) that use sharun for more. **Didn't find what you were looking for?** Open an issue here and we will see what we can do.
