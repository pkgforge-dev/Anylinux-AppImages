## **Anylinux AppImages**

![Downloads](https://img.shields.io/endpoint?url=https://cdn.jsdelivr.net/gh/pkgforge-dev/Anylinux-AppImages@main/.github/badge.json)

Designed to run seamlessly on any Linux distribution, including very very old distributions and musl-based ones. Our AppImages bundle all the needed dependencies and do not depend on host libraries to work, unlike most other AppImages, **all while being significantly smaller thanks to [DwarFS](https://github.com/mhx/dwarfs) and [optimized packages](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)**.

Most of the AppImages are made with [sharun](https://github.com/VHSgunzo/sharun). We also use an alternative better [runtime](https://github.com/VHSgunzo/uruntime).

The uruntime [automatically falls back to using namespaces](https://github.com/VHSgunzo/uruntime?tab=readme-ov-file#built-in-configuration) if FUSE is not available at all, and if namespaces are not possible it falls back to extract and run, so we **truly have 0 requirements:**

| Format                  | Requirements                                                                                                                                                                                                 |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Traditional AppImages (made by linuxdeploy or similar tools) | **Hard dependency on glibc** (rarely works on distros older than 4 years), also has a soft dependency on **FUSE** since the user has to manually extract when FUSE is unavailable, they also need an FHS compliant system to work. |
| Flatpak| **Hard dependency on bubblewrap and FUSE**. Must be supported by your distribution or be manually built and installed systemwide which requires elevated rights. |
| Snap | Similar requirements to flatpak minus bubblewrap, has a **hard dependency on systemd**. |
| **AnyLinux AppImages** (made with sharun) | Use **FUSE if available**, else **fallback to using namespaces** and if that is not possible then we automatically extract to `TMPDIR` and run with post cleanup, we **do not need an FHS filesystem** and **do not depend on the host libc**, so eh make sure you have `/bin/sh` and write access to `/tmp`??? (If you can boot to a graphical session you already met those requirements). **How is this possible?** See: [How to guide](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md) |
| **AnyLinux AppImages** (made with RunImage) | Similar to sharun AppImages but have a **Hard dependency on namespaces**, Lutris and virt-manager are the only ones that use this method, pending migration to sharun. |


---

| Applications                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------ |
[12to11](https://github.com/pkgforge-dev/12to11-AppImage)                                                                |
[alacritty](https://github.com/pkgforge-dev/alacritty-AppImage)                                                          |
[Android Tools](https://github.com/pkgforge-dev/android-tools-AppImage)                                                  |
[Android Translation Layer](https://github.com/pkgforge-dev/android_translation_layer-AppImage)                          |
[anki](https://github.com/pkgforge-dev/anki-AppImage)                                                                    |
[AppImageUpdate](https://github.com/pkgforge-dev/AppImageUpdate-Enhanced-Edition)                                        |
[ares-emu](https://github.com/pkgforge-dev/ares-emu-appimage)                                                            |
[Audio Sharing](https://github.com/pkgforge-dev/Audio-Sharing-AppImage)                                                  |
[Authenticator](https://github.com/pkgforge-dev/Authenticator-AppImage)                                                  |
[Azahar](https://github.com/pkgforge-dev/Azahar-AppImage-Enhanced)                                                       |
[Blender](https://github.com/pkgforge-dev/Blender-AppImage)                                                              |
[Cannonball](https://github.com/pkgforge-dev/Cannonball-AppImage)                                                        |
[Cartridges](https://github.com/pkgforge-dev/Cartridges-AppImage)                                                        |
[CDogs-SDL](https://github.com/pkgforge-dev/CDogs-SDL-AppImage)                                                          |
[Cemu](https://github.com/pkgforge-dev/Cemu-AppImage-Enhanced)                                                           |
[Citron](https://github.com/pkgforge-dev/Citron-AppImage)                                                                |
[Clapper](https://github.com/pkgforge-dev/Clapper-AppImage)                                                              |
[Clementine](https://github.com/pkgforge-dev/Clementine-AppImage)                                                        |
[Collision](https://github.com/pkgforge-dev/Collision-AppImage)                                                          |
[ClassiCube](https://github.com/pkgforge-dev/ClassiCube-AppImage)                                                        |
[ClownMDEmu](https://github.com/pkgforge-dev/ClownMDEmu-AppImage)                                                        |
[CorsixTH](https://github.com/pkgforge-dev/CorsixTH-AppImage)                                                            |
[CroMagRally](https://github.com/pkgforge-dev/CroMagRally-AppImage)                                                      |
[Cromite](https://github.com/pkgforge-dev/Cromite-AppImage)                                                              |
[Cursor](https://github.com/pkgforge-dev/Cursor-AppImage-enhanced)                                                       |
[cursor-cli](https://github.com/pkgforge-dev/cursor-cli-AppImage)                                                        |
[DarkPlaces](https://github.com/pkgforge-dev/DarkPlaces-AppImage)                                                        |
[Discord](https://github.com/pkgforge-dev/Discord-AppImage)                                                              |
[Dolphin-emu](https://github.com/pkgforge-dev/Dolphin-emu-AppImage)                                                      |
[DeaDBeeF](https://github.com/pkgforge-dev/DeaDBeeF-AppImage)                                                            |
[Defold](https://github.com/pkgforge-dev/Defold-AppImage)                                                                |
[DeSmuME](https://github.com/pkgforge-dev/DeSmuME-AppImage)                                                              |
[DevilutionX](https://github.com/pkgforge-dev/DevilutionX-AppImage)                                                      |
[dhewm3](https://github.com/pkgforge-dev/dhewm3-AppImage)                                                                |
[Drum Machine](https://github.com/pkgforge-dev/Drum-Machine-AppImage)                                                    |
[dunst](https://github.com/pkgforge-dev/dunst-AppImage)                                                                  |
[EasyTAG](https://github.com/pkgforge-dev/EasyTAG-AppImage)                                                              |
[ECWolf](https://github.com/pkgforge-dev/ECWolf-AppImage)                                                                |
[eduke32](https://github.com/pkgforge-dev/eduke32-AppImage)                                                              |
[Elastic](https://github.com/pkgforge-dev/Elastic-AppImage)                                                              |
[ePSXe](https://github.com/pkgforge-dev/ePSXe-AppImage)                                                                  |
[Extension Manager](https://github.com/pkgforge-dev/Extension-Manager-AppImage)                                          |
[ExtremeTuxRacer](https://github.com/pkgforge-dev/ExtremeTuxRacer-AppImage)                                              |
[Exult](https://github.com/pkgforge-dev/Exult-AppImage)                                                                  |
[Eyedropper](https://github.com/pkgforge-dev/Eyedropper-AppImage)                                                        |
[Fabother-World](https://github.com/pkgforge-dev/Fabother-World-AppImage)                                                |
[Filelight](https://github.com/pkgforge-dev/Filelight-AppImage)                                                          |
[foot](https://github.com/pkgforge-dev/foot-AppImage)                                                                    |
[Fretboard](https://github.com/pkgforge-dev/Fretboard-AppImage)                                                          |
[Gapless](https://github.com/pkgforge-dev/Gapless-AppImage)                                                              |
[Gear Lever](https://github.com/pkgforge-dev/Gear-Lever-AppImage)                                                        |
[Ghostship](https://github.com/pkgforge-dev/Ghostship-AppImage)                                                          |
[Ghostty](https://github.com/pkgforge-dev/ghostty-appimage)                                                              |
[GIMP-and-PhotoGIMP](https://github.com/pkgforge-dev/GIMP-and-PhotoGIMP-AppImage)                                        |
[Gnome Calculator](https://github.com/pkgforge-dev/Gnome-Calculator-AppImage)                                            |
[Gnome Pomodoro](https://github.com/pkgforge-dev/gnome-pomodoro-appimage)                                                |
[Gnome System Monitor](https://github.com/pkgforge-dev/Gnome-System-Monitor-AppImage)                                    |
[Gnome Text Editor](https://github.com/pkgforge-dev/Gnome-Text-Editor-AppImage)                                          |
[Godot](https://github.com/pkgforge-dev/Godot-AppImage)                                                                  |
[GoldenDict-ng](https://github.com/pkgforge-dev/GoldenDict-ng-AppImage)                                                  |
[gpu-screen-recorder](https://github.com/pkgforge-dev/gpu-screen-recorder-AppImage)                                      |
[Gradia](https://github.com/pkgforge-dev/Gradia-AppImage)                                                                |
[Graphs](https://github.com/pkgforge-dev/Graphs-AppImage)                                                                |
[htop](https://github.com/pkgforge-dev/htop-AppImage)                                                                    |
[Identity](https://github.com/pkgforge-dev/Identity-AppImage)                                                            |
[Impression](https://github.com/pkgforge-dev/Impression-AppImage)                                                        |
[isle-portable](https://github.com/pkgforge-dev/isle-portable-AppImage)                                                  |
[kaffeine](https://github.com/pkgforge-dev/kaffeine-AppImage)                                                            |
[kdeconnect](https://github.com/pkgforge-dev/kdeconnect-AppImage)                                                        |
[kdenlive](https://github.com/pkgforge-dev/kdenlive-AppImage-Enhanced)                                                   |
[Keypunch](https://github.com/pkgforge-dev/Keypunch-AppImage)                                                            |
[KiCad](https://github.com/pkgforge-dev/KiCad-AppImage)                                                                  |
[Kronos](https://github.com/pkgforge-dev/Kronos-AppImage)                                                                |
[Ladybird](https://github.com/pkgforge-dev/ladybird-appimage)                                                            |
[Libation](https://github.com/pkgforge-dev/Libation-AppImage)                                                            |
[LibreCAD](https://github.com/pkgforge-dev/LibreCAD-AppImage)                                                            |
[LocalSend](https://github.com/pkgforge-dev/localsend-AppImage)                                                          |
[Lutris](https://github.com/pkgforge-dev/Lutris-AppImage)                                                                |
[MAME](https://github.com/pkgforge-dev/MAME-AppImage)                                                                    |
[Mednafen](https://github.com/pkgforge-dev/mednafen-appimage)                                                            |
[MESA](https://github.com/pkgforge-dev/MESA-AppImage)                                                                    |
[Mini-vMac](https://github.com/pkgforge-dev/Mini-vMac-AppImage)                                                          |
[Mousai](https://github.com/pkgforge-dev/Mousai-AppImage)                                                                |
[mpv](https://github.com/pkgforge-dev/mpv-AppImage)                                                                      |
[NBlood](https://github.com/pkgforge-dev/NBlood-AppImage)                                                                |
[NewsFlash](https://github.com/pkgforge-dev/NewsFlash-AppImage)                                                          |
[Nomacs](https://github.com/pkgforge-dev/Nomacs-AppImage)                                                                |
[NSZ](https://github.com/pkgforge-dev/NSZ-AppImage)                                                                      |
[NXEngine-evo](https://github.com/pkgforge-dev/NXEngine-evo-AppImage)                                                    |
[OBS Studio](https://github.com/pkgforge-dev/OBS-Studio-AppImage)                                                        |
[okteta](https://github.com/pkgforge-dev/okteta-AppImage)                                                                |
[opencode](https://github.com/pkgforge-dev/opencode-AppImage-Enhanced)                                                   |
[OpenJazz](https://github.com/pkgforge-dev/OpenJazz-AppImage)                                                            |
[OpenLara](https://github.com/pkgforge-dev/OpenLara-AppImage)                                                            |
[OpenTyrian2000](https://github.com/pkgforge-dev/OpenTyrian2000-AppImage)                                                |
[Oversteer](https://github.com/pkgforge-dev/Oversteer-AppImage)                                                          |
[pavucontrol-qt](https://github.com/pkgforge-dev/pavucontrol-qt-AppImage)                                                |
[PCExhumed](https://github.com/pkgforge-dev/PCExhumed-AppImage)                                                          |
[phoenix-x-server](https://github.com/pkgforge-dev/phoenix-x-server-AppImage)                                            |
[Pinta](https://github.com/pkgforge-dev/Pinta-AppImage)                                                                  |
[Pixelpulse2](https://github.com/pkgforge-dev/Pixelpulse2-AppImage)                                                      |
[playerctl](https://github.com/pkgforge-dev/playerctl-AppImage)                                                          |
[polybar](https://github.com/pkgforge-dev/polybar-AppImage)                                                              |
~[PPSSPP](https://github.com/pkgforge-dev/PPSSPP-AppImage)~ - [Upstreamed](https://github.com/hrydgard/ppsspp/releases). |
[puddletag](https://github.com/pkgforge-dev/puddletag-AppImage)                                                          |
[Rednukem](https://github.com/pkgforge-dev/Rednukem-AppImage)                                                            |
[Pyglossary](https://github.com/pkgforge-dev/PyGlossary-AppImage)                                                        |
[Rewaita](https://github.com/pkgforge-dev/Rewaita-AppImage)                                                              |
[RigelEngine](https://github.com/pkgforge-dev/RigelEngine-AppImage)                                                      |
[qarma](https://github.com/pkgforge-dev/qarma-AppImage)                                                                  |
[QElectroTech](https://github.com/pkgforge-dev/QElectroTech-AppImage)                                                    |
[Qimgv](https://github.com/pkgforge-dev/Qimgv-AppImage)                                                                  |
[Reco](https://github.com/pkgforge-dev/Reco-AppImage)                                                                    |
[RMG](https://github.com/pkgforge-dev/RMG-AppImage-Enhanced)                                                             |
[Rnote](https://github.com/pkgforge-dev/Rnote-AppImage)                                                                  |
[rofi](https://github.com/pkgforge-dev/rofi-AppImage)                                                                    |
[ROLLER](https://github.com/pkgforge-dev/ROLLER-AppImage)                                                                |
[RSDKv3](https://github.com/pkgforge-dev/RSDKv3-AppImage)                                                                |
[RSDKv4](https://github.com/pkgforge-dev/RSDKv4-AppImage)                                                                |
[RustDesk](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced)                                                   |
[scrcpy](https://github.com/pkgforge-dev/scrcpy-AppImage)                                                                |
[SDLPoP](https://github.com/pkgforge-dev/SDLPoP-AppImage)                                                                |
[Secrets](https://github.com/pkgforge-dev/Secrets-AppImage)                                                              |
[servo](https://github.com/pkgforge-dev/servo-AppImage)                                                                  |
[Snes9x](https://github.com/pkgforge-dev/Snes9x-AppImage)                                                                |
[soh](https://github.com/pkgforge-dev/soh-AppImage)                                                                      |
[Sonic-Mania-Decompilation](https://github.com/pkgforge-dev/Sonic-Mania-Decompilation-AppImage)                          |
[sound-space-plus](https://github.com/pkgforge-dev/sound-space-plus-AppImage)                                            |
[spacecadetpinball](https://github.com/pkgforge-dev/spacecadetpinball-AppImage)                                          |
[SpaghettiKart](https://github.com/pkgforge-dev/SpaghettiKart-AppImage)                                                  |
[SpeedCrunch](https://github.com/pkgforge-dev/SpeedCrunch-AppImage)                                                      |
[st](https://github.com/pkgforge-dev/st-AppImage)                                                                        |
[Stella](https://github.com/pkgforge-dev/Stella-AppImage)                                                                |
[stirling-pdf](https://github.com/pkgforge-dev/Stirling-PDF-AppImage)                                                    |
[strawberry](https://github.com/pkgforge-dev/strawberry-AppImage)                                                        |
[Signal](https://github.com/pkgforge-dev/Signal-AppImage-Enhanced)                                                       |
[Sudachi](https://github.com/pkgforge-dev/Sudachi-AppImage)                                                              |
[SuperTux](https://github.com/pkgforge-dev/SuperTux-AppImage-Enhanced)                                                   |
[SuperTuxKart](https://github.com/pkgforge-dev/SuperTuxKart-AppImage-Enhanced)                                           |
[sView](https://github.com/pkgforge-dev/sView-AppImage)                                                                  |
[system-monitoring-center](https://github.com/pkgforge-dev/system-monitoring-center-AppImage)                            |
[Tagger](https://github.com/pkgforge-dev/Tagger-AppImage)                                                                |
[Taradino](https://github.com/pkgforge-dev/Taradino-AppImage)                                                            |
[Torzu](https://github.com/pkgforge-dev/Torzu-AppImage)                                                                  |
[TouchHLE](https://github.com/pkgforge-dev/TouchHLE-AppImage)                                                            |
[transmission-qt](https://github.com/pkgforge-dev/transmission-qt-AppImage)                                              |
[Tutanota Desktop](https://github.com/pkgforge-dev/Tutanota-Desktop-AppImage-Enhanced)                                   |
[Tux Football](https://github.com/pkgforge-dev/Tux-Football-AppImage)                                                    |
[Tuxpuck](https://github.com/pkgforge-dev/Tuxpuck-AppImage)                                                              |
[uad-ng](https://github.com/pkgforge-dev/uad-ng-AppImage)                                                                |
[UnleashedRecomp](https://github.com/pkgforge-dev/UnleashedRecomp-AppImage)                                              |
[Varia](https://github.com/pkgforge-dev/Varia-AppImage)                                                                  |
[vcmi](https://github.com/pkgforge-dev/vcmi-AppImage)                                                                    |
[VeraCrypt](https://github.com/pkgforge-dev/VeraCrypt-AppImage)                                                          |
[Viber](https://github.com/pkgforge-dev/Viber-AppImage-Enhanced)                                                         |
[Video Trimmer](https://github.com/pkgforge-dev/Video-Trimmer-AppImage)                                                  |
[virt-manager](https://github.com/pkgforge-dev/virt-manager-AppImage)                                                    |
[Warp](https://github.com/pkgforge-dev/Warp-AppImage)                                                                    |
[Webcamoid](https://github.com/pkgforge-dev/Webcamoid-AppImage)                                                          |
[wine](https://github.com/pkgforge-dev/wine-AppImage)                                                                    |
[xenia-canary](https://github.com/pkgforge-dev/xenia-canary-AppImage)                                                    |
[xoreos](https://github.com/pkgforge-dev/xoreos-AppImage)                                                                |
[Zenity](https://github.com/pkgforge-dev/Zenity-GTK3-AppImage)                                                           |

---

Also see [other projects](https://github.com/VHSgunzo/sharun?tab=readme-ov-file#projects-that-use-sharun) that use sharun for more. **Didn't find what you were looking for?** Open an issue here and we will see what we can do.
