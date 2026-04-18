---
layout: default
title: Home
permalink: /
---

## **Anylinux AppImages**

![Downloads](https://img.shields.io/endpoint?url=https://cdn.jsdelivr.net/gh/pkgforge-dev/Anylinux-AppImages@main/.github/badge.json)

Designed to run seamlessly on any Linux distribution, including very very old distributions and musl-based ones. Our AppImages bundle all the needed dependencies and do not depend on host libraries to work, unlike most other AppImages, **all while being significantly smaller thanks to [DwarFS](https://github.com/mhx/dwarfs) and [optimized packages](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)**.

Most of the AppImages are made with [sharun](https://github.com/VHSgunzo/sharun). We also use an alternative better [runtime](https://github.com/VHSgunzo/uruntime).

The uruntime [automatically falls back to using namespaces](https://github.com/VHSgunzo/uruntime?tab=readme-ov-file#built-in-configuration) if FUSE is not available at all, and if namespaces are not possible it falls back to extract and run, so we **truly have 0 requirements:**

| Format | Requirements |
| --- | --- |
| Traditional AppImages (made by linuxdeploy or similar tools) | **Hard dependency on glibc** (rarely works on distros older than 4 years), also has a soft dependency on **FUSE** since the user has to manually extract when FUSE is unavailable, they also need an FHS compliant system to work. |
| Flatpak | **Hard dependency on bubblewrap and FUSE**. Must be supported by your distribution or be manually built and installed systemwide which requires elevated rights. |
| Snap | Similar requirements to flatpak minus bubblewrap, has a **hard dependency on systemd**. |
| **AnyLinux AppImages** (made with sharun) | Use **FUSE if available**, else **fallback to using namespaces** and if that is not possible then we automatically extract to `TMPDIR` and run with post cleanup, we **do not need an FHS filesystem** and **do not depend on the host libc**, so eh make sure you have `/bin/sh` and write access to `/tmp`??? (If you can boot to a graphical session you already met those requirements). **How is this possible?** See: [How to guide](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md) |
| **AnyLinux AppImages** (made with RunImage) | Similar to sharun AppImages but have a **Hard dependency on namespaces**, Lutris and virt-manager are the only ones that use this method, pending migration to sharun. |

For more useful documentation about Anylinux-AppImages, see the pages below:

- [How to make these](HOW-TO-MAKE-THESE.md)
- [Hall of fame/shame](HALL-OF-FAME.md)
- [Size comparison](disk-usage-vs-flatpak.md)
- [Build tools and scripts](useful-tools/)

<!-- APPS_LIST_START -->

---

| Applications | Description |
| --- | --- |
| [12to11](https://github.com/pkgforge-dev/12to11-AppImage) | This is a tool for running Wayland applications on an X server, preferably with a compositing manager running |
| [86Box](https://github.com/pkgforge-dev/86box-AppImage-Enhanced) | 86Box is a low level x86 emulator that runs older operating systems and software designed for IBM PC systems and compatibles from 1981 through fairly recent system designs based on the PCI bus |
| [AAAAXY](https://github.com/pkgforge-dev/AAAAXY-AppImage-Enhanced) | A nonlinear 2D puzzle platformer taking place in impossible spaces |
| [Abaddon](https://github.com/pkgforge-dev/Abaddon-AppImage) | An alternative Discord client with voice support made with C++ and GTK 3 |
| [Aerofoil](https://github.com/pkgforge-dev/Aerofoil-AppImage) | Multiplatform desktop/mobile/browser port of Glider PRO, the classic Macintosh paper airplane game |
| [Akhenaten](https://github.com/pkgforge-dev/Akhenaten-AppImage) | Akhenaten aims to make the original game Pharaoh compatible with modern systems with redesigned original engine |
| [alacritty](https://github.com/pkgforge-dev/alacritty-AppImage) | A cross-platform, OpenGL terminal emulator |
| [Amarok](https://github.com/pkgforge-dev/Amarok-AppImage) | Powerful music player that lets you rediscover your music |
| [Amiberry](https://github.com/pkgforge-dev/Amiberry-AppImage) | Optimized Amiga emulator |
| [Android Tools](https://github.com/pkgforge-dev/android-tools-AppImage) | Unofficial AppImage of Android Platform Tools (adb, fastboot, etc). Can also install udev rules. |
| [Android Translation Layer](https://github.com/pkgforge-dev/android_translation_layer-AppImage) | A translation layer that allows running Android apps on a Linux system |
| [anki](https://github.com/pkgforge-dev/anki-AppImage) | Anki is a smart spaced repetition flashcard program |
| [AppImageUpdate](https://github.com/pkgforge-dev/AppImageUpdate) | Fast, bandwidth-efficient AppImage updater using zsync |
| [ares-emu](https://github.com/pkgforge-dev/ares-emu-appimage) | ares is a cross-platform, open source, multi-system emulator, focusing on accuracy and preservation |
| [Audacious](https://github.com/pkgforge-dev/Audacious-AppImage) | A lightweight and versatile audio player |
| [Audacity](https://github.com/pkgforge-dev/Audacity-AppImage-Enhanced) | Audacity is an easy-to-use, multi-track audio editor and recorder |
| [Audio Sharing](https://github.com/pkgforge-dev/Audio-Sharing-AppImage) | With Audio Sharing you can share your current computer audio playback in the form of an RTSP stream |
| [Augustus](https://github.com/pkgforge-dev/Augustus-AppImage-Enhanced) | An open source re-implementation of Caesar III |
| [Authenticator](https://github.com/pkgforge-dev/Authenticator-AppImage) | Simple application for generating Two-Factor Authentication Codes |
| [Awakened POE Trade](https://github.com/pkgforge-dev/Awakened-POE-Trade-AppImage-Enhanced) | Path of Exile app for price checking |
| [Azahar](https://github.com/pkgforge-dev/Azahar-AppImage-Enhanced) | An open-source 3DS emulator project based on Citra. |
| [BanjoRecomp](https://github.com/pkgforge-dev/BanjoRecomp-AppImage) | PC Port of Banjo-Kazooie |
| [BasiliskII](https://github.com/pkgforge-dev/BasiliskII-AppImage-Enhanced) | Basilisk II and SheepShaver Macintosh emulators |
| [BibleTime](https://github.com/pkgforge-dev/BibleTime-AppImage) | BibleTime is a powerful cross platform Bible study tool. |
| [Blender](https://github.com/pkgforge-dev/Blender-AppImage) | Blender is the free and open source 3D creation suite |
| [Bulky](https://github.com/pkgforge-dev/Bulky-AppImage) | Bulky - Rename multiple files at once |
| [Cannonball](https://github.com/pkgforge-dev/Cannonball-AppImage) | CannonBall is an souped up game engine for the OutRun arcade game |
| [Cartridges](https://github.com/pkgforge-dev/Cartridges-AppImage) | Cartridges is a simple game launcher for all of your games |
| [CatacombGL](https://github.com/pkgforge-dev/CatacombGL-AppImage) | CatacombGL is a source port of Catacomb 3D and the Catacomb Adventure series |
| [C-Dogs_SDL](https://github.com/pkgforge-dev/CDogs-SDL-AppImage) | C-Dogs SDL is a classic overhead run-and-gun game, supporting up to 4 players in co-op and deathmatch modes |
| [Cemu](https://github.com/pkgforge-dev/Cemu-AppImage-Enhanced) | Cemu, a Wii U emulator that is able to run most Wii U games |
| [Clapper](https://github.com/pkgforge-dev/Clapper-AppImage) | Clapper is a modern media player designed for simplicity and ease of use |
| [ClassiCube](https://github.com/pkgforge-dev/ClassiCube-AppImage) | ClassiCube is a custom Minecraft Classic compatible client |
| [Clementine](https://github.com/pkgforge-dev/Clementine-AppImage) | Clementine is a modern music player and library organizer |
| [Clock Signal](https://github.com/pkgforge-dev/CLK-AppImage) | Emulator of 8- and 16-bit platforms |
| [ClownMDEmu](https://github.com/pkgforge-dev/ClownMDEmu-AppImage) | Reference standalone frontend for ClownMDEmu, a Sega Mega Drive/Sega Genesis emulator |
| [CollaboraOffice](https://github.com/pkgforge-dev/CollaboraOffice-AppImage) | Collabora Office is a collaborative online office suite |
| [Collision](https://github.com/pkgforge-dev/Collision-AppImage) | File hash comparator application |
| [Commander-Genius](https://github.com/pkgforge-dev/Commander-Genius-AppImage) | Commander Genius is an open-source interpreter for the Commander Keen |
| [CopyQ](https://github.com/pkgforge-dev/CopyQ-AppImage) | CopyQ is an advanced clipboard manager |
| [CorsixTH](https://github.com/pkgforge-dev/CorsixTH-AppImage) | Open source clone of Theme Hospital |
| [Crispy Doom](https://github.com/pkgforge-dev/Crispy-Doom-AppImage) | Crispy Doom is a limit-removing enhanced-resolution Doom source port based on Chocolate Doom |
| [CroMagRally](https://github.com/pkgforge-dev/CroMagRally-AppImage) | This is a port of Pangea Software’s racing game Cro-Mag Rally to modern operating systems |
| [Cromite](https://github.com/pkgforge-dev/Cromite-AppImage) | Cromite is a Chromium fork based on Bromite with built-in support for ad blocking and an eye for privacy |
| [Cuberite](https://github.com/pkgforge-dev/Cuberite-AppImage) | A lightweight, fast and extensible game server for Minecraft |
| [Cursor](https://github.com/pkgforge-dev/Cursor-AppImage-enhanced) | Cursor is an AI editor and coding agent |
| [cursor-cli](https://github.com/pkgforge-dev/cursor-cli-AppImage) | Cursor is an AI editor and coding agent |
| [D1X-Rebirth](https://github.com/pkgforge-dev/D1X-Rebirth-AppImage) | DXX-Rebirth is a source port of Descent based on D1X |
| [D2X-Rebirth](https://github.com/pkgforge-dev/D2X-Rebirth-AppImage) | DXX-Rebirth is a source port of Descent 2, based on D2X |
| [Daggerfall-Unity](https://github.com/pkgforge-dev/Daggerfall-Unity-AppImage) | Open source recreation of Daggerfall in the Unity engine |
| [DarkPlaces](https://github.com/pkgforge-dev/DarkPlaces-AppImage) | DarkPlaces is a game engine based on the Quake 1 engine by id Software |
| [DeaDBeeF](https://github.com/pkgforge-dev/DeaDBeeF-AppImage) | DeaDBeeF (as in 0xDEADBEEF) is a modular cross-platform audio player |
| [Defold](https://github.com/pkgforge-dev/Defold-AppImage) | Defold is a completely free to use game engine for development of desktop, mobile and web games. |
| [DeSmuME](https://github.com/pkgforge-dev/DeSmuME-AppImage) | DeSmuME is a Nintendo DS emulator |
| [dethrace](https://github.com/pkgforge-dev/dethrace-AppImage) | Reverse engineering the 1997 game "Carmageddon" |
| [DevilutionX](https://github.com/pkgforge-dev/DevilutionX-AppImage-Enhanced) | Diablo build for modern operating systems |
| [dhewm3](https://github.com/pkgforge-dev/dhewm3-AppImage) | dhewm 3 (Doom3 sourceport) main repository |
| [Discord](https://github.com/pkgforge-dev/Discord-AppImage) | Discord is a instant messaging and VoIP social platform that allows communication through voice calls, video calls, text messaging, and media |
| [DNZHRecomp](https://github.com/pkgforge-dev/DNZHRecomp-AppImage) | Recompilation of Duke Nukem Zero Hour |
| [Dolphin-emu](https://github.com/pkgforge-dev/Dolphin-emu-AppImage) | Dolphin is a GameCube / Wii emulator, allowing you to play games for these two platforms on PC with improvements |
| [DOOM64EXUltra](https://github.com/pkgforge-dev/DOOM64EXUltra-AppImage) | A recreation of a Nintendo 64 Doom port |
| [DOSBox-X](https://github.com/pkgforge-dev/DOSBox-X-AppImage) | DOSBox-X is a cross-platform DOS emulator based on the DOSBox project |
| [Dr. Robotnik's Ring Racers](https://github.com/pkgforge-dev/Dr-Robotniks-Ring-Racers-AppImage) | Dr. Robotnik's Ring Racers is a kart racing video game originally based on the 3D Sonic the Hedgehog fangame Sonic Robo Blast 2, itself based on a modified version of Doom Legacy |
| [dRally](https://github.com/pkgforge-dev/dRally-AppImage) | Port of Death Rally (1996) running natively on Linux |
| [Drum Machine](https://github.com/pkgforge-dev/Drum-Machine-AppImage) | Drum Machine is a modern and intuitive application for creating, playing, and managing drum patterns |
| [DuckStation-GPL](https://github.com/pkgforge-dev/DuckStation-GPL-AppImage-Enhanced) | Fast PlayStation 1 emulator for x86-64/AArch32/AArch64/RV64 |
| [dunst](https://github.com/pkgforge-dev/dunst-AppImage) | Lightweight and customizable notification daemon |
| [EasyTAG](https://github.com/pkgforge-dev/EasyTAG-AppImage) | Easy Tag is app for edit audio file metadata |
| [ECWolf](https://github.com/pkgforge-dev/ECWolf-AppImage) | Advanced port of Wolfenstein 3D based off of Wolf4SDL |
| [EDuke32](https://github.com/pkgforge-dev/EDuke32-AppImage) | EDuke32 is an awesome, free homebrew game engine and source port of the classic PC first person shooter |
| [Elastic](https://github.com/pkgforge-dev/Elastic-AppImage) | Elastic allows to design and export spring physics-based animations to use with libadwaita |
| [Element Desktop](https://github.com/pkgforge-dev/Element-Desktop-AppImage) | Element Desktop is a Matrix client for desktop platforms with Element Web at its core. |
| [ePSXe](https://github.com/pkgforge-dev/ePSXe-AppImage) | PlayStation 1 Emulator |
| [ET Legacy](https://github.com/pkgforge-dev/ETLegacy-AppImage) | ET: Legacy is an open source project based on the code of Wolfenstein: Enemy Territory |
| [Extension Manager](https://github.com/pkgforge-dev/Extension-Manager-AppImage) | A native tool for browsing, installing, and managing GNOME Shell Extensions |
| [ExtremeTuxRacer](https://github.com/pkgforge-dev/ExtremeTuxRacer-AppImage) | High speed arctic racing game based on Tux Racer |
| [Exult](https://github.com/pkgforge-dev/Exult-AppImage) | Exult is a project to recreate Ultima 7 for modern operating systems |
| [Eyedropper](https://github.com/pkgforge-dev/Eyedropper-AppImage) | Color picker and color converter |
| [Fabother-World](https://github.com/pkgforge-dev/Fabother-World-AppImage) | This is an Another World VM implementation |
| [FeatherPad](https://github.com/pkgforge-dev/FeatherPad-AppImage) | Lightweight Qt plain-text editor for Linux |
| [FFmpeg](https://github.com/pkgforge-dev/FFmpeg-AppImage) | FFmpeg is the leading multimedia framework, able to decode, encode, transcode, mux, demux, stream, filter and play pretty much anything that humans and machines have created |
| [Filelight](https://github.com/pkgforge-dev/Filelight-AppImage) | Apps can help show disk usage and delete unused files |
| [Flycast](https://github.com/pkgforge-dev/Flycast-AppImage-Enhanced) | Flycast is a multiplatform Sega Dreamcast, Naomi, Naomi 2 and Atomiswave emulator |
| [Foobillard++](https://github.com/pkgforge-dev/Foobillardpp-AppImage) | OpenGL Billard Game based on foobillard 3.0a |
| [foot](https://github.com/pkgforge-dev/foot-AppImage) | The fast, lightweight and minimalistic Wayland terminal emulator |
| [fooyin](https://github.com/pkgforge-dev/fooyin-AppImage) | fooyin is a customisable desktop music player |
| [FreeTube](https://github.com/pkgforge-dev/FreeTube-Appimage) | An Open Source YouTube app for privacy |
| [Fretboard](https://github.com/pkgforge-dev/Fretboard-AppImage) | Fretboard lets you find guitar chords by typing their names or plotting them on an interactive guitar neck |
| [Galculator](https://github.com/pkgforge-dev/Galculator-AppImage) | GTK 2 / GTK 3 based scientific calculator |
| [Gapless](https://github.com/pkgforge-dev/Gapless-AppImage) | A light weight music player written in GTK4, with a fluent adaptive user interface |
| [GCAP2025](https://github.com/pkgforge-dev/GCAP2025-AppImage) | Brazilian goverment software for calculating taxes and declaration generator |
| [GCAP2026](https://github.com/pkgforge-dev/GCAP2026-AppImage) | Brazilian goverment software for calculating taxes and declaration generator |
| [GCstar](https://github.com/pkgforge-dev/GCstar-AppImage) | Desktop application to manage of various types of collections (books, comics, films, TV shows, music, games, wines, stamp, coins, etc |
| [Gear Lever](https://github.com/pkgforge-dev/Gear-Lever-AppImage) | An utility to manage AppImages with ease |
| [Gearboy](https://github.com/pkgforge-dev/Gearboy-AppImage) | Game Boy / Game Boy Color / Super Game Boy emulator, debugger and embedded MCP server |
| [Gearcoleco](https://github.com/pkgforge-dev/Gearcoleco-AppImage) | Gearcoleco is a very accurate cross-platform ColecoVision |
| [Geargrafx](https://github.com/pkgforge-dev/Geargrafx-AppImage) | PC Engine / TurboGrafx-16 / SuperGrafx / PCE CD-ROM² emulator, debugger, and embedded MCP server |
| [Gearlynx](https://github.com/pkgforge-dev/Gearlynx-AppImage) | Atari Lynx emulator, debugger, and embedded MCP server for macOS, Windows, Linux, BSD and RetroArch. |
| [Gearsystem](https://github.com/pkgforge-dev/Gearsystem-AppImage) | Gearsystem is a very accurate, cross-platform Sega Master System / Game Gear / SG-1000 emulator |
| [Ghostship](https://github.com/pkgforge-dev/Ghostship-AppImage-Enhanced) | A Super Mario 64 PC Port |
| [Ghostty](https://github.com/pkgforge-dev/ghostty-appimage) | Ghostty is a fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration |
| [GIMP-and-PhotoGIMP](https://github.com/pkgforge-dev/GIMP-and-PhotoGIMP-AppImage) | GIMP is a free and open-source image editor. PhotoGIMP is a free, community-driven patch that transforms GIMP (GNU Image Manipulation Program) into a layout that feels familiar to Adobe Photoshop users |
| [Gnome Calculator](https://github.com/pkgforge-dev/Gnome-Calculator-AppImage) | Calculator is an application that solves mathematical equations |
| [Gnome Pomodoro](https://github.com/pkgforge-dev/gnome-pomodoro-appimage) | Gnome Pomodoro is a productivity tool designed to help you manage your time effectively using the Pomodoro Technique |
| [Gnome System Monitor](https://github.com/pkgforge-dev/Gnome-System-Monitor-AppImage) | System Monitor is a process viewer and system monitor with an attractive, easy-to-use interface |
| [Gnome Text Editor](https://github.com/pkgforge-dev/Gnome-Text-Editor-AppImage) | A simple text editor |
| [GNU FreeDink](https://github.com/pkgforge-dev/GNU-FreeDink-AppImage) | Humorous top-down adventure and role-playing game |
| [Godot](https://github.com/pkgforge-dev/Godot-AppImage) | Godot Engine – Multi-platform 2D and 3D game engine |
| [GoldenDict-ng](https://github.com/pkgforge-dev/GoldenDict-ng-AppImage) | GoldenDict-ng is an advanced dictionary lookup program, supporting many formats |
| [Gopher64](https://github.com/pkgforge-dev/Gopher64-AppImage) | Gopher64 is a cross-platform N64 emulator |
| [gpu-screen-recorder](https://github.com/pkgforge-dev/gpu-screen-recorder-AppImage) | This is a screen recorder that has minimal impact on system performance by recording your monitor using the GPU only, similar to shadowplay on windows |
| [Gradia](https://github.com/pkgforge-dev/Gradia-AppImage) | Gradia helps you get your screenshots ready for sharing, whether quickly with friends or colleagues, or professionally with the entire world |
| [Gram](https://github.com/pkgforge-dev/Gram-AppImage-Enhanced) | The Gram Code Editor |
| [Graphs](https://github.com/pkgforge-dev/Graphs-AppImage) | Graphs is a simple, yet powerful tool that allows you to plot and manipulate your data with ease |
| [gThumb](https://github.com/pkgforge-dev/gThumb-AppImage) | Image viewer, editor, browser and organizer |
| [Gwenview](https://github.com/pkgforge-dev/Gwenview-AppImage) | Gwenview is a fast and easy to use image viewer by KDE, ideal for browsing and displaying a collection of images |
| [Haruna](https://github.com/pkgforge-dev/Haruna-AppImage) | Open source video player built with Qt/QML and libmpv |
| [Hatari](https://github.com/pkgforge-dev/Hatari-AppImage) | The Atari ST, STE, TT and Falcon emulator |
| [Helium Browser](https://github.com/pkgforge-dev/Helium-Browser-AppImage-Enhanced) | Private, fast, and honest web browser based on ungoogled-Chromium |
| [HP-15C](https://github.com/pkgforge-dev/HP-15C-Simulator-AppImage) | The latest HP-15C Simulator |
| [htop](https://github.com/pkgforge-dev/htop-AppImage) | htop is a cross-platform interactive process viewer |
| [Identity](https://github.com/pkgforge-dev/Identity-AppImage) | Compare images and videos |
| [ImageMagick](https://github.com/pkgforge-dev/ImageMagick-AppImage) | ImageMagick is a free, open-source software suite for creating, editing, converting, and displaying images |
| [Impression](https://github.com/pkgforge-dev/Impression-AppImage) | Software for creating bootable drives |
| [innoextract](https://github.com/pkgforge-dev/innoextract-AppImage) | A tool to unpack installers created by Inno Setup |
| [ioquake3](https://github.com/pkgforge-dev/ioquake3-AppImage) | The ioquake3 community effort to continue supporting/developing id's Quake III Arena |
| [Iris](https://github.com/pkgforge-dev/Iris-AppImage-Enhanced) | Sony PlayStation 2 emulator |
| [IRPF2025](https://github.com/pkgforge-dev/IRPF2025-AppImage) | Use this program to file your income tax return |
| [IRPF2026](https://github.com/pkgforge-dev/IRPF2026-AppImage) | Use this program to file your income tax return |
| [isle-portable](https://github.com/pkgforge-dev/isle-portable-AppImage-Enhanced) | A portable version of LEGO Island (1997) |
| [ITGmania](https://github.com/pkgforge-dev/ITGmania-AppImage) | ITGmania is a fork of StepMania 5.1, an advanced cross-platform rhythm game for home and arcade use |
| [ITR2025](https://github.com/pkgforge-dev/ITR2025-AppImage) | Use this program to complete the original or amended Rural Property Tax Return (DITR) for each of your rural properties |
| [kaffeine](https://github.com/pkgforge-dev/kaffeine-AppImage) | Kaffeine is a media player. What makes it different from the others is its excellent support of digital TV (DVB). Kaffeine has user-friendly interface, so that even first time users can start immediately playing their movies: from DVD (including DVD menus, titles, chapters, etc.), VCD, or a file |
| [kdeconnect](https://github.com/pkgforge-dev/kdeconnect-AppImage) | KDE Connect is a multi-platform app that allows your devices to communicate |
| [kdenlive](https://github.com/pkgforge-dev/kdenlive-AppImage-Enhanced) | Kdenlive is a powerful, free and open-source video editor |
| [KeePassXC](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced) | KeePassXC is a cross-platform community-driven port of the Windows application “KeePass Password Safe |
| [Kega Fusion](https://github.com/pkgforge-dev/Kega-Fusion-AppImage) | Fusion is a Sega SG1000, SC3000, SF7000, Master System, Game Gear, Genesis/Megadrive, SVP, Pico, SegaCD/MegaCD and 32X emulator |
| [Keypunch](https://github.com/pkgforge-dev/Keypunch-AppImage) | Practice your typing skills |
| [KiCad](https://github.com/pkgforge-dev/KiCad-AppImage) | A Cross Platform and Open Source PCB Design Suite |
| [Kid3](https://github.com/pkgforge-dev/Kid3-AppImage) | Efficient audio tagger that supports a large variety of file formats |
| [Knights](https://github.com/pkgforge-dev/Knights-AppImage) | Knights is KDE's chess frontend. It supports playing local games against human players or against chess engines |
| [Kronos](https://github.com/pkgforge-dev/Kronos-AppImage) | Kronos is a Sega Saturn emulator. |
| [Ladybird](https://github.com/pkgforge-dev/ladybird-appimage) | Ladybird is a new browser engine built from scratch |
| [lba2-classic-community](https://github.com/pkgforge-dev/lba2-classic-community-AppImage) | Community-maintained source port of the original Little Big Adventure 2 (Twinsen’s Odyssey) engine |
| [Libation](https://github.com/pkgforge-dev/Libation-AppImage) | Libation is a free, open-source application for downloading and managing your Audible audiobooks |
| [LibreCAD](https://github.com/pkgforge-dev/LibreCAD-AppImage) | LibreCAD is a free Open Source CAD application |
| [LightZone](https://github.com/pkgforge-dev/LightZone-AppImage) | LightZone is a professional-level digital darkroom and photo editor |
| [LinuxToys](https://github.com/pkgforge-dev/LinuxToys-AppImage) | LinuxToys is a collection of user-friendly tools designed for Linux systems. It aims to make powerful Linux functionality accessible to all users through an intuitive interface |
| [LocalSend](https://github.com/pkgforge-dev/localsend-AppImage) | An open-source cross-platform alternative to AirDrop |
| [Luanti](https://github.com/pkgforge-dev/Luanti-AppImage) | Luanti (formerly Minetest) is an open source voxel game-creation platform with easy modding and game creation |
| [Lutris](https://github.com/pkgforge-dev/Lutris-AppImage) | Lutris is a video game preservation platform aiming to keep your video game collection up and running for the years to come |
| [MAME](https://github.com/pkgforge-dev/MAME-AppImage) | MAME is a multi-purpose emulation framework |
| [ManiaDrive](https://github.com/pkgforge-dev/ManiaDrive-AppImage) | ManiaDrive is a free clone of Trackmania, the great game from Nadéo studio |
| [MarioKart64Recomp](https://github.com/pkgforge-dev/MarioKart64Recomp-AppImage) | Recompilation of Mario Kart 64 |
| [Media Downloader](https://github.com/pkgforge-dev/Media-Downloader-AppImage) | Media Downloader is a Qt/C++ front end to yt-dlp, youtube-dl, gallery-dl, lux, you-get, svtplay-dl, aria2c, wget and safari books |
| [Mednafen](https://github.com/pkgforge-dev/mednafen-appimage) | Mednafen is a portable, utilizing OpenGL and SDL, argument(command-line)-driven multi-system emulator |
| [melonDS](https://github.com/pkgforge-dev/melonDS-AppImage-Enhanced) | melonDS aims at providing fast and accurate Nintendo DS emulation |
| [MESA](https://github.com/pkgforge-dev/MESA-AppImage) | Experimental AppImage that lets you use the latest Mesa graphic stack with any binary on your system |
| [mGBA](https://github.com/pkgforge-dev/mGBA-AppImage-Enhanced) | Game Boy Advance Emulator |
| [Mini-vMac](https://github.com/pkgforge-dev/Mini-vMac-AppImage) | Mini vMac is a miniature Macintosh 68K emulator |
| [Mixxx](https://github.com/pkgforge-dev/Mixxx-AppImage) | Mixxx is Free DJ software |
| [Mousai](https://github.com/pkgforge-dev/Mousai-AppImage) | Mousai is a simple application that can recognize songs similar to Shazam, but uses Audd.io API |
| [mpv](https://github.com/pkgforge-dev/mpv-AppImage) | Commandline media player |
| [NBlood](https://github.com/pkgforge-dev/NBlood-AppImage) | Blood port based on EDuke32 |
| [Nestopia](https://github.com/pkgforge-dev/Nestopia-AppImage) | Cross-platform Nestopia emulator core with a GUI |
| [Neverball](https://github.com/pkgforge-dev/Neverball-AppImage) | Neverball is part puzzle game, part action game, and entirely a test of skill |
| [NewsFlash](https://github.com/pkgforge-dev/NewsFlash-AppImage) | Newsflash is a program designed to complement an already existing web-based RSS reader account |
| [NFSIISE](https://github.com/pkgforge-dev/NFSIISE-AppImage) | Need For Speed™ II SE - Cross-platform wrapper with 3D acceleration and TCP protocol |
| [Nomacs](https://github.com/pkgforge-dev/Nomacs-AppImage) | nomacs is a free image viewer for windows, linux, and mac systems |
| [NP2kai](https://github.com/pkgforge-dev/Neko-Project-II-Kai-AppImage) | NP2kai is a PC-9801 series emulator |
| [NSZ](https://github.com/pkgforge-dev/NSZ-AppImage) | A compression/decompresson script (with optional GUI) that allows user to compress/decompress Nintendo Switch dumps loselessly |
| [Nugget-Doom](https://github.com/pkgforge-dev/Nugget-Doom-AppImage-Enhanced) | Nugget Doom is a Doom source port forked from Woof! with additional features. |
| [NXEngine-evo](https://github.com/pkgforge-dev/NXEngine-evo-AppImage-Enhanced) | SDL2 port NXEngine platformer (clone of Cave Story) |
| [OBS Studio](https://github.com/pkgforge-dev/OBS-Studio-AppImage) | OBS Studio - Free and open source software for live streaming and screen recording |
| [Odamex](https://github.com/pkgforge-dev/Odamex-AppImage) | Online Multiplayer Doom port |
| [Obsidian](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced) | Personal Knowledge Base. Alternative for Notion |
| [okteta](https://github.com/pkgforge-dev/okteta-AppImage) | Okteta is a simple editor for the raw data of files. |
| [OpenClaw](https://github.com/pkgforge-dev/OpenClaw-AppImage) | Reimplementation of Captain Claw (1997) platformer |
| [opencode](https://github.com/pkgforge-dev/opencode-AppImage-Enhanced) | The open source coding agent |
| [OpenJazz](https://github.com/pkgforge-dev/OpenJazz-AppImage) | OpenJazz is a free, open-source version of the classic Jazz Jackrabbit™ games |
| [OpenLara](https://github.com/pkgforge-dev/OpenLara-AppImage) | Classic Tomb Raider open-source engine |
| [OpenLoco](https://github.com/pkgforge-dev/OpenLoco-AppImage) | An open source re-implementation of Chris Sawyer's Locomotion |
| [openMSX](https://github.com/pkgforge-dev/openMSX-AppImage) | openMSX - the MSX emulator that aims for perfection |
| [OpenRCT2](https://github.com/pkgforge-dev/OpenRCT2-AppImage-Enhanced) | An open source re-implementation of RollerCoaster Tycoon 2 |
| [OpenSWE1R](https://github.com/pkgforge-dev/OpenSWE1R-AppImage) | An Open-Source port of the 1999 Game "Star Wars Episode 1: Racer" |
| [OpenTTD](https://github.com/pkgforge-dev/OpenTTD-AppImage) | OpenTTD is an open source simulation game based upon Transport Tycoon Deluxe |
| [OpenTyrian2000](https://github.com/pkgforge-dev/OpenTyrian2000-AppImage) | An open-source port of the DOS shoot-em-up Tyrian. |
| [OptiImage](https://github.com/pkgforge-dev/OptiImage-AppImage) | Optimize your images with OptiImage, a useful image compressor that supports PNG, JPEG, WebP and SVG file types |
| [OrcaSlicer](https://github.com/pkgforge-dev/OrcaSlicer-AppImage-Enhanced) | G-code generator for 3D printers (Bambu, Prusa, Voron, VzBot, RatRig, Creality, etc.) |
| [Oversteer](https://github.com/pkgforge-dev/Oversteer-AppImage) | Steering Wheel Manager for GNU/Linux |
| [pavucontrol-qt](https://github.com/pkgforge-dev/pavucontrol-qt-AppImage) | pavucontrol-qt is the Qt port of the volume control pavucontrol for the sound server PulseAudio |
| [PCExhumed](https://github.com/pkgforge-dev/PCExhumed-AppImage) | Reverse-engineered ports of Build games using EDuke32 engine technology and development principles (NBlood/Rednukem/PCExhumed) |
| [PCSX-Redux](https://github.com/pkgforge-dev/PCSX-Redux-AppImage-Enhanced) | The PCSX-Redux project is a collection of tools, research, hardware design, and libraries aiming at development and reverse engineering on the PlayStation 1 |
| [PCSX2](https://github.com/pkgforge-dev/PCSX2-AppImage-Enhanced) | PCSX2 is a free and open-source PlayStation 2 (PS2) emulator |
| [PDF Arranger](https://github.com/pkgforge-dev/PDF-Arranger-AppImage) | PDF Arranger is a small python-gtk application |
| [PDF Tricks](https://github.com/pkgforge-dev/PDF-Tricks-AppImage) | A simple, efficient application for small manipulations in PDF files |
| [Perfect Dark](https://github.com/pkgforge-dev/Perfect-Dark-AppImage) | work in progress port of n64decomp/perfect_dark to modern platforms |
| [Phantom-Satellite](https://github.com/pkgforge-dev/Phantom-Satellite-AppImage) | Phantom Satellite web browser, a fork of Pale Moon that aims to support older/niche platforms, without sacrificing support for more common/modern platforms |
| [phoenix-x-server](https://github.com/pkgforge-dev/phoenix-x-server-AppImage) | Phoenix is a new X server, written from scratch in Zig (not a fork of Xorg server). This X server is designed to be a modern alternative to the Xorg server |
| [Piglit](https://github.com/pkgforge-dev/Piglit-AppImage) | OpenGL test suite, and test-suite runner |
| [Pinta](https://github.com/pkgforge-dev/Pinta-AppImage) | Simple GTK Paint Program |
| [Pixelpulse2](https://github.com/pkgforge-dev/Pixelpulse2-AppImage) | Pixelpulse is a powerful user interface for visualizing and manipulating signals while exploring systems attached to affordable analog interface devices, such as Analog Devices' ADALM1000. |
| [Play!](https://github.com/pkgforge-dev/Play-AppImage-Enhanced) | PlayStation2 Emulator |
| [playerctl](https://github.com/pkgforge-dev/playerctl-AppImage) | mpris media player command-line controller |
| [Plus42](https://github.com/pkgforge-dev/Plus42-AppImage) | Free42, in turn, is a complete re-implementation of the HP-42S scientific programmable RPN calculator, which was made from 1988 until 1995 by Hewlett-Packard |
| [PokeMMO](https://github.com/pkgforge-dev/PokeMMO-AppImage) | Multiplayer Nintendo DS and GBA game emulator |
| [polybar](https://github.com/pkgforge-dev/polybar-AppImage) | A fast and easy-to-use status bar |
| [POSTAL](https://github.com/pkgforge-dev/POSTAL-AppImage) | Postal is a 1997 shoot 'em up video game developed by Running with Scissors and published by Ripcord Games. Now source is available under |
| [Prey2006](https://github.com/pkgforge-dev/Prey2006-AppImage) | Prey 2006 SDK integrated with Doom 3 GPL release |
| [PrismLauncher](https://github.com/pkgforge-dev/PrismLauncher-AppImage-Enhanced) | A custom launcher for Minecraft that allows you to easily manage multiple installations of Minecraft at once |
| [Ptyxis](https://github.com/pkgforge-dev/Ptyxis-AppImage) | A terminal for a container-oriented desktop |
| [puddletag](https://github.com/pkgforge-dev/puddletag-AppImage) | Powerful, simple, audio tag editor for GNU/Linux |
| [Pyglossary](https://github.com/pkgforge-dev/PyGlossary-AppImage) | A tool for converting dictionary files aka glossaries |
| [qarma](https://github.com/pkgforge-dev/qarma-AppImage) | Qarma is a tool to create dialog boxes, based on Qt |
| [QElectroTech](https://github.com/pkgforge-dev/QElectroTech-AppImage) | QElectroTech is a libre and open source desktop application to create diagrams and schematics |
| [QEMU](https://github.com/pkgforge-dev/QEMU-AppImage) | QEMU is a generic and open source machine & userspace emulator and virtualizer |
| [Qimgv](https://github.com/pkgforge-dev/Qimgv-AppImage) | Fast, easy to use image viewer |
| [Qmmp](https://github.com/pkgforge-dev/Qmmp-AppImage) | Qt-based multimedia player |
| [QMPlay2](https://github.com/pkgforge-dev/QMPlay2-AppImage-Enhanced) | QMPlay2 is a video and audio player which can play most formats and codecs |
| [QtCreator](https://github.com/pkgforge-dev/QtCreator-AppImage) | Qt Creator is a cross-platform, integrated development environment (IDE) for application developers to create applications for multiple desktop, embedded, and mobile device platforms |
| [QTerminal](https://github.com/pkgforge-dev/QTerminal-AppImage) | A lightweight Qt-based terminal emulator |
| [QuantumLauncher](https://github.com/pkgforge-dev/QuantumLauncher-AppImage-Enhanced) | A simple, powerful Minecraft launcher |
| [Quickshell](https://github.com/pkgforge-dev/Quickshell-AppImage) | Flexible toolkit for making desktop shells with QtQuick, for Wayland and X11 |
| [Raptor](https://github.com/pkgforge-dev/Raptor-AppImage) | Reversed-engineered source port from Raptor Call Of The Shadows |
| [Readest](https://github.com/pkgforge-dev/Readest-AppImage-Enhanced) | Readest is a modern, feature-rich ebook reader designed for avid readers |
| [Reco](https://github.com/pkgforge-dev/Reco-AppImage) | Reco is an audio recorder focused on being concise and simple to use |
| [Rednukem](https://github.com/pkgforge-dev/Rednukem-AppImage) | Reverse-engineered port of Build games using EDuke32 engine technology and development principles |
| [REDRIVER2](https://github.com/pkgforge-dev/REDRIVER2-AppImage) | Driver 2 Playstation game reverse engineering effort |
| [Rewaita](https://github.com/pkgforge-dev/Rewaita-AppImage) | Rewaita brings a fresh look to Adwaita apps using popular color schemes |
| [RigelEngine](https://github.com/pkgforge-dev/RigelEngine-AppImage) | A modern re-implementation of the classic DOS game Duke Nukem II |
| [Rigs-of-Rods](https://github.com/pkgforge-dev/Rigs-of-Rods-AppImage) | Rigs of Rods - open-source, soft-body physics sandbox |
| [Riseup-VPN](https://github.com/pkgforge-dev/Riseup-VPN-AppImage) | Bitmask is an open source application to provide easy and secure encrypted communication with a VPN |
| [Ristretto](https://github.com/pkgforge-dev/Ristretto-AppImage) | Ristretto is an image viewer for the Xfce desktop environment |
| [RMG](https://github.com/pkgforge-dev/RMG-AppImage-Enhanced) | Rosalie's Mupen GUI is a free and open-source mupen64plus (Cross-platform plugin-based N64 emulator) front-end |
| [Rnote](https://github.com/pkgforge-dev/Rnote-AppImage) | Rnote is an open-source vector-based drawing app for sketching, handwritten notes and to annotate documents and pictures |
| [RocksnDiamonds](https://github.com/pkgforge-dev/RocksnDiamonds-AppImage) | Rocks'n'Diamonds is an open source C arcade style game based off Boulder Dash (Commodore 64), Emerald Mine Supaplex and Sokoban |
| [rofi](https://github.com/pkgforge-dev/rofi-AppImage) | Window switcher, application launcher and dmenu replacement |
| [ROLLER](https://github.com/pkgforge-dev/ROLLER-AppImage) | Reverse engineering the 1995 game Whiplash/Fatal Racing |
| [rquickshare](https://github.com/pkgforge-dev/rquickshare-AppImage-Enhanced) | Rust implementation of NearbyShare/QuickShare from Android for Linux and macOS. |
| [RSDKv3](https://github.com/pkgforge-dev/RSDKv3-AppImage) | A Full Decompilation of Sonic CD (2011) & Retro Engine (v3) |
| [RSDKv4](https://github.com/pkgforge-dev/RSDKv4-AppImage) | A complete decompilation of Sonic 1 & Sonic 2 (2013) & Retro Engine (v4) |
| [Ruffle](https://github.com/pkgforge-dev/Ruffle-AppImage) | A Flash Player emulator written in Rust |
| [RustDesk](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced) | An open-source remote desktop application designed for self-hosting, as an alternative to TeamViewer |
| [RVGL](https://github.com/pkgforge-dev/RVGL-AppImage) | RVGL is a cross-platform rewrite / port of Re-Volt that runs natively on a wide variety of platforms |
| [Sanicball](https://github.com/pkgforge-dev/Sanicball-AppImage) | Extraordinarily fast racing game |
| [Satty](https://github.com/pkgforge-dev/Satty-AppImage) | Modern Screenshot Annotation |
| [Sayonara-Player](https://github.com/pkgforge-dev/Sayonara-Player-AppImage-Enhanced) | Sayonara is a small, clear and fast audio player for Linux written in C++, supported by the Qt framework |
| [scrcpy](https://github.com/pkgforge-dev/scrcpy-AppImage) | Display and control your Android device |
| [ScummVM](https://github.com/pkgforge-dev/ScummVM-AppImage) | ScummVM allows you to play classic graphic point-and-click adventure games, text adventure games, and RPGs |
| [SDLPoP](https://github.com/pkgforge-dev/SDLPoP-AppImage) | An open-source port of Prince of Persia, based on the disassembly of the DOS version. |
| [Secrets](https://github.com/pkgforge-dev/Secrets-AppImage) | Secrets is a password manager which makes use of the KeePass v.4 format |
| [servo](https://github.com/pkgforge-dev/servo-AppImage) | Servo Parallel Browser Engine Project |
| [Shotwell](https://github.com/pkgforge-dev/Shotwell-AppImage) | Shotwell is a photo manager with simple image enhancement features |
| [Signal](https://github.com/pkgforge-dev/Signal-AppImage-Enhanced) | Simple, powerful, and secure messenger |
| [Simitone](https://github.com/pkgforge-dev/Simitone-AppImage) | Community fork of Simitone, a re-implementation of The Sims 1, based off of FreeSO. |
| [Simutrans](https://github.com/pkgforge-dev/Simutrans-AppImage) | Simutrans is a freeware and open-source transportation simulator |
| [Slack](https://github.com/pkgforge-dev/Slack-AppImage) | Team communication b2b platform |
| [Snes9x](https://github.com/pkgforge-dev/Snes9x-AppImage-Enhanced) | Snes9x - Portable Super Nintendo Entertainment System (TM) emulator |
| [SongRec](https://github.com/pkgforge-dev/SongRec-AppImage) | An open-source Shazam client for Linux, written in Rust. |
| [soh](https://github.com/pkgforge-dev/soh-AppImage-Enhanced) | Ship of Harkinian (SOH) is built atop a custom library dubbed libultraship (LUS) |
| [Sonic 3 A.I.R.](https://github.com/pkgforge-dev/Sonic-3-AIR-AppImage) | Source and data to build Sonic 3 A.I.R. (Angel Island Revisited) and the Oxygen Engine |
| [Sonic-Mania-Decompilation](https://github.com/pkgforge-dev/Sonic-Mania-Decompilation-AppImage) | A complete decompilation of Sonic Mania (2017) |
| [Sonic Robo Blast 2](https://github.com/pkgforge-dev/SRB2-AppImage) | Sonic Robo Blast 2 is a 3D Sonic the Hedgehog fangame based on a modified version of Doom Legacy. |
| [sound-space-plus](https://github.com/pkgforge-dev/sound-space-plus-AppImage) | Rhythm-based aim game |
| [spacecadetpinball](https://github.com/pkgforge-dev/spacecadetpinball-AppImage) | Decompilation of 3D Pinball for Windows – Space Cadet |
| [SpaghettiKart](https://github.com/pkgforge-dev/SpaghettiKart-AppImage-Enhanced) | Native port of Mario Kart64 |
| [SpeedCrunch](https://github.com/pkgforge-dev/SpeedCrunch-AppImage) | SpeedCrunch is a high-precision scientific calculator |
| [SRB2Kart](https://github.com/pkgforge-dev/SRB2Kart-AppImage) | SRB2Kart is a kart racing mod based on the 3D Sonic the Hedgehog fangame Sonic Robo Blast 2, based on a modified version of Doom Legacy |
| [st](https://github.com/pkgforge-dev/st-AppImage) | st is a simple terminal implementation for X |
| [Starfox64Recomp](https://github.com/pkgforge-dev/Starfox64Recomp-AppImage) | Starfox 64: Recompiled is a project that uses N64: Recompiled to statically recompile Starfox 64 into a native port with many new features, enhancements, and extensive mod support |
| [Stella](https://github.com/pkgforge-dev/Stella-AppImage) | A multi-platform Atari 2600 Emulator |
| [stirling-pdf](https://github.com/pkgforge-dev/Stirling-PDF-AppImage) | Stirling PDF is a powerful, open-source PDF editing platform |
| [strawberry](https://github.com/pkgforge-dev/strawberry-AppImage) | Strawberry is a music player and music collection organizer, originally forked from Clementine in 2018 |
| [Super Mario War](https://github.com/pkgforge-dev/Supermariowar-AppImage) | A fan-made multiplayer Super Mario Bros. style deathmatch game |
| [Supermodel](https://github.com/pkgforge-dev/Supermodel-AppImage) | Supermodel: A Sega Model 3 Arcade Emulator |
| [SuperTux](https://github.com/pkgforge-dev/SuperTux-AppImage-Enhanced) | SuperTux is a jump'n'run game with strong inspiration from the Super Mario Bros. games for the various Nintendo platforms |
| [SuperTuxKart](https://github.com/pkgforge-dev/SuperTuxKart-AppImage-Enhanced) | SuperTuxKart is a free kart racing game |
| [sView](https://github.com/pkgforge-dev/sView-AppImage) | Multi-featured system monitor |
| [system-monitoring-center](https://github.com/pkgforge-dev/system-monitoring-center-AppImage) | Multi-featured system monitor |
| [tachoparser](https://github.com/pkgforge-dev/tachoparser-AppImage) | Decode and verify tachograph data (VU data and driver card data) |
| [Tagger](https://github.com/pkgforge-dev/Tagger-AppImage) | Tagger audio application |
| [Taisei Project](https://github.com/pkgforge-dev/Taisei-Project-AppImage) | Taisei Project is an open source fan-game set in the world of Tōhō Project |
| [Tokodon](https://github.com/pkgforge-dev/Tokodon-AppImage) | Tokodon is a Mastodon client for Plasma and Plasma Mobile |
| [Taradino](https://github.com/pkgforge-dev/Taradino-AppImage) | SDL2 port of Rise of the Triad |
| [Tauon](https://github.com/pkgforge-dev/Tauon-AppImage) | A music player for the desktop. Designed to be powerful and streamlined, putting the user in control of their music collection |
| [Telegram](https://github.com/pkgforge-dev/Telegram-AppImage) | Cross-platform messanger based on MTProto |
| [Torzu](https://github.com/pkgforge-dev/Torzu-AppImage) | Torzu is an advanced Nintendo Switch emulator |
| [TouchHLE](https://github.com/pkgforge-dev/TouchHLE-AppImage) | High-level emulator for iPhone OS apps |
| [transmission-qt](https://github.com/pkgforge-dev/transmission-qt-AppImage) | Transmission is a fast, easy, and free BitTorrent client. It comes in several flavors |
| [Trelby](https://github.com/pkgforge-dev/Trelby-AppImage) | Screenplay writing software |
| [Tutanota Desktop](https://github.com/pkgforge-dev/Tutanota-Desktop-AppImage-Enhanced) | Tuta is an email service with a strong focus on security and privacy that lets you encrypt emails, contacts and calendar entries on all your devices. |
| [Tux Football](https://github.com/pkgforge-dev/Tux-Football-AppImage) | Tux Football is a great 2D soccer (sometimes called football) game for Windows and Linux |
| [Tuxpuck](https://github.com/pkgforge-dev/Tuxpuck-AppImage) | TuxPuck is an air hockey game and clone of the Amiga/Atari ST game Shufflepuck Café |
| [uad-ng](https://github.com/pkgforge-dev/uad-ng-AppImage) | Cross-platform GUI written in Rust using ADB to debloat non-rooted Android devices |
| [UEFITool](https://github.com/pkgforge-dev/UEFITool-AppImage) | UEFI firmware image viewer and editor |
| [UnleashedRecomp](https://github.com/pkgforge-dev/UnleashedRecomp-AppImage) | An unofficial PC port of the Xbox 360 version of Sonic Unleashed |
| [Varia](https://github.com/pkgforge-dev/Varia-AppImage) | Quick and efficient download manager |
| [vcmi](https://github.com/pkgforge-dev/vcmi-AppImage) | Open-source engine for Heroes of Might and Magic III |
| [VeraCrypt](https://github.com/pkgforge-dev/VeraCrypt-AppImage) | Disk encryption with strong security based on TrueCrypt |
| [Viber](https://github.com/pkgforge-dev/Viber-AppImage-Enhanced) | Cross-platform instant messaging voice-over-Internet Protocol application |
| [Video Trimmer](https://github.com/pkgforge-dev/Video-Trimmer-AppImage) | Video Trimmer cuts out a fragment of a video given the start and end timestamps |
| [virt-manager](https://github.com/pkgforge-dev/virt-manager-AppImage) | Desktop tool for managing virtual machines via libvirt |
| [vokoscreenNG](https://github.com/pkgforge-dev/vokoscreenNG-AppImage) | vokoscreenNG for Windows and Linux is a powerful screencast creator |
| [Warp](https://github.com/pkgforge-dev/Warp-AppImage) | Warp allows you to securely send files to each other via the internet or local network by exchanging a word-based code |
| [Webamp-Desktop](https://github.com/pkgforge-dev/Webamp-Desktop-AppImage-Enhanced) | Experimental cross-platform  desktop version of Winamp 2.9 reimplementation |
| [Webcamoid](https://github.com/pkgforge-dev/Webcamoid-AppImage) | Webcamoid is a full featured and multiplatform camera suite. |
| [WebCord](https://github.com/pkgforge-dev/WebCord-AppImage-Enhanced) | A Discord and SpaceBar :electron:-based client implemented without Discord API. |
| [WhatsDesk](https://github.com/pkgforge-dev/WhatsDesk-AppImage) | WhatsDesk is a unofficial client of whatsapp |
| [WhatSie](https://github.com/pkgforge-dev/WhatSie-AppImage) | Feature rich WhatsApp web client based on Qt WebEngine for Linux Desktop |
| [wine](https://github.com/pkgforge-dev/wine-AppImage) | Wine (originally an acronym for "Wine Is Not an Emulator") is a compatibility layer capable of running Windows applications on several POSIX-compliant operating systems, such as Linux, macOS, & BSD |
| [wipEout-Rewrite](https://github.com/pkgforge-dev/wipEout-Rewrite-AppImage) | This is a re-implementation of the 1995 PSX game wipEout |
| [Xash3D-FWGS](https://github.com/pkgforge-dev/Xash3D-FWGS-AppImage-Enhanced) | Xash3D FWGS is a game engine, aimed to provide compatibility with Half-Life Engine |
| [xemu](https://github.com/pkgforge-dev/xemu-AppImage-Enhanced) | A free and open-source application that emulates the original Microsoft Xbox game console |
| [xenia-canary](https://github.com/pkgforge-dev/xenia-canary-AppImage) | Xbox 360 Emulator |
| [xeyes](https://github.com/pkgforge-dev/xeyes-AppImage) | A "follow the mouse" X demo, using the X SHAPE extension |
| [Xiphos](https://github.com/pkgforge-dev/Xiphos-AppImage) | Xiphos is a Bible study tool |
| [xoreos](https://github.com/pkgforge-dev/xoreos-AppImage) | A reimplementation of BioWare's Aurora engine (and derivatives) |
| [xournalpp](https://github.com/pkgforge-dev/xournalpp-AppImage-Enhanced) | Handwritten note-taking software |
| [Xsnow](https://github.com/pkgforge-dev/Xsnow-AppImage) | Xsnow is an application that animates snowfall, Santa and some scenery on your desktop |
| [Yamagi Quake II](https://github.com/pkgforge-dev/Yamagi-Quake-II-AppImage) | The Yamagi Quake II client |
| [Ymir](https://github.com/pkgforge-dev/Ymir-AppImage) | Sega Saturn emulator |
| [yt-dlp](https://github.com/pkgforge-dev/yt-dlp-AppImage) | A feature-rich command-line audio/video downloader |
| [ZapZap](https://github.com/pkgforge-dev/ZapZap-AppImage-Enhanced) | WhatsApp desktop application written in PyQt6 + PyQt6-WebEngine. |
| [Zelda64Recomp](https://github.com/pkgforge-dev/Zelda64Recomp-AppImage) | Zelda 64: Recompiled is a project that uses N64: Recompiled to statically recompile Majora's Mask |
| [Zen Browser](https://github.com/pkgforge-dev/Zen-Browser-AppImage-Enhanced) | Zen is a firefox-based browser with the aim of pushing your productivity to a new level! |
| [Zenity](https://github.com/pkgforge-dev/Zenity-GTK3-AppImage) | Zenity - a rewrite of gdialog, the GNOME port of dialog which allows you to display dialog boxes from the commandline and shell scripts |
| [Zod-Engine](https://github.com/pkgforge-dev/Zod-Engine-AppImage) | Zod Engine is a remake of the 1996 classic game by Bitmap Brothers called Z. Z is a capture the flag style RTS |
| [ZSNES](https://github.com/pkgforge-dev/ZSNES-AppImage) | A maintained fork of ZSNES, a Super Nintendo emulator |

---

<!-- APPS_LIST_END -->

Also see [other projects](https://github.com/VHSgunzo/sharun?tab=readme-ov-file#projects-that-use-sharun) that use sharun for more. **Didn't find what you were looking for?** Open an issue here and we will see what we can do.
