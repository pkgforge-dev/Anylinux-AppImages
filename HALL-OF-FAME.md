<div align="center">

# Deploying libraries - Hall of Fame/Shame
We have been deploying applications for over 1 year already, so I thought I would rank how difficult it has been to deal with several common toolkits and libraries.

Inspired by [Dolphin Emulator and OpenGL drivers - Hall of Fame/Shame](https://dolphin-emu.org/blog/2013/09/26/dolphin-emulator-and-opengl-drivers-hall-fameshame/)

</div>

# Excellent - SDL

very easy to deploy, SDL does not have excessive dependencies and it is very configurable thru env variables.
There was only one [problem](https://github.com/libsdl-org/SDL/issues/14887) which which SDL fixed quickly once I let them know: 

# Excellent - iced and glfw

We haven't had do anything to deploying these without issue, they are just copy and paste pretty much, just bundle OpenGL and vulkan since it can use both. Also since iced is used by rust apps and those compile mostly static it makes them super easy to deploy in general. These two are mentioned together since we haven't deployed that many applications that use these libraries.

# Excellent - Chromium/electron

These are already very portable on their own and very very easy to deploy as result. The only issue we have encountered is that sometimes these load some binaries as libraries and we have to careful in those cases.

# Excellent - flutter

These are relocatable always, in fact distros often need to put the application in dedicated directory in `/usr/share` or `/usr/lib` since they need a relative `lib` directory next to the binary to work.

# Excellent - pipewire

Needs `PIPEWIRE_MODULE_DIR` and `SPA_PLUGIN_DIR` to be made relocatable. Otherwise perfect for deployment, it does have some performance issues but with pipewire-jack though.

# Good - Qt

Qt is very easy to make relocable, it supports a `qt.conf` file that accepts relative paths which prevents using the env variable `QT_PLUGIN_PATH` which is very problematic for child processes, Qt also looks into `XDG_DATA_DIRS` and several other locations to find its translation files, QtWebEgnine is super easy to dewploy as well.

The only reason it is not excellent is becuase deploying QML is a bit complicated since the .qml files have to deployed along with the libraries and determining which ones to add is a mess. Right now we just add all of qml when deployign qml as result of this. 

Qt also often links to libicudata (30 MiB lib) even though the vast majority of applications do not need this, thankfully it can be disabled at compile time, but ideally this should be dlopened instead when needed.

# Good - MESA

Very easy to deploy, plenty of env variables to configure it, lots of build options, more recently MESA now allows to build the radeon drivers without linking to LLVM which has resulted in a massive decrease of our AppImages as result. Vulkan/OpenGL ICD discovery is also handled automatically and it looks into `XDG_DATA_DIRS` among a ton of other locations to find those files. **And the icd files support relative library locations to the icd file itself** 👀 

My only complain is that we need to set `GBM_BACKENDS_PATH` and `LIBVA_DRIVERS_PATH`, these should be loaded relative to the location of libgallium. Hopefully mesa can do this like they did with [LIBGL_DRIVERS_PATH](https://www.phoronix.com/news/Mesa-24.2-Modern-Interfaces)

# Good - libdecor

This would have been horrible a few years ago, but libdecor has really done a lot of improve its situation and they want to [improve it more](https://gitlab.freedesktop.org/libdecor/libdecor/-/issues/44), so I will give them credit for that. I still think this library is totally useless, this wouldn't be needed at all if GNOME was so retarded to not provide server side decorations...

# Good ffmpeg

We do not have to do anything to make this relocatable, it just works™, However ffmpeg directly links to a ton of libraries, which means a lot of bloat often gets added, thankfully this can be mitigated by buidling ffmpeg with those options disabled, but ideally ffmpeg should dlopen the libraries when needed, there is no need to link and load libx265 because your music players uses ffmpeg, just no...

# Bad - alsa

alsa doesn't check `XDG_DATA_DIRS` to find its data directory, we have to set `ALSA_CONFIG_PATH` to the configuration file in that directory, which is hardcoded to look into `/usr/share/alsa` anyway lol and fixing that issue is a total mess since the file does not accept relative paths to its location, so you have to get the value of some env variable using what syntax this is, [like this](https://github.com/alsa-project/alsa-lib/blob/5f7fe33002d2d98d84f72e381ec2cccc0d5d3d40/src/conf/alsa.conf#L17-L26)

# Bad - GLIBC

glibc supports the `LOCPATH` env varaible but this doesn't work with locale archives, This problem affects NixOS and they have to [patch](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/libraries/glibc/nix-locale-archive.patch) it so that locale-archives can be made relocatable. We also have to set `GCONV_PATH` and good luck figuring out which gconv plugin your app exactly needs, and when the plugin is missing there is no error about it, [it is just totally random what happens](https://github.com/pkgforge-dev/Dolphin-emu-AppImage/issues/20)

# Bad Gstreamer

It is insane how you can screw up a system that is modular? First it is very difficult to determine what Gstreamer plugin an application needs unless you already know it before hand since you built it, Gstreamer uses something called `gst-plugin-scanner` which opens every single gstreamer plugin on the system, so we cannot easily determine using `strace` what plugin an application needs. It needs 4 env variables to be made relocatable `GST_PLUGIN_PATH`, `GST_PLUGIN_SYSTEM_PATH`, `GST_PLUGIN_SYSTEM_PATH_1_0` (lol?), and `GST_PLUGIN_SCANNER`.

Also sometimes the bloody [thing needs ffmpeg to work](https://github.com/pkgforge-dev/strawberry-AppImage/issues/21#issuecomment-3625129688), it is useless. Just use ffmpeg directly and do not bother with Gstreamer.

# Horrible - WebKit

WebKit is hardcoded to load some binaries in `/usr/lib` which makes no sense and there is no way to override this location other than recompiling with a [debug flag](https://github.com/WebKit/WebKit/blob/378d33fcfd7109660e72d4215bce53b9e64c5082/Source/WebKit/Shared/glib/ProcessExecutablePathGLib.cpp#L478) to expose a variable wtf. Sometimes it just dies depending on the OpenGL version you have, and with Nvidia you often have to set `WEBKIT_DISABLE_DMABUF_RENDERER=1` and `WEBKIT_DISABLE_COMPOSITING_MODE=1`. Hopefully tauri will be able to replace it with servo in the future, because this is just bad...

# Horrible - jack2

**The library needs matching versions between server and client to work** [1](https://gitlab.com/freedesktop-sdk/freedesktop-sdk/-/issues/1001#note_323464727)

`pipewire-jack` is often suggested as an alternative, but that has performance issues, so yeah you are very screwed up here. We do have a hook that lets use use the host jack2 when needed, but I cannot guarantee if this will keep working in the future.

# Garbage - GTK

Where do I even start?

* Every single GTK app has the path to its locales hardcoded at the prefix (`/usr/share/locale`) and there no env variable to change this.

* it depends on stuff like Gio, gdk-pixbuf, glycin, which bloats the final application. And those projects have their own set of issues when made relocable. And in the case of glycin it is a [total disaster.](https://github.com/VHSgunzo/sharun/issues/68).

* The vulkan backend was [totally broken wayland with intel gpus](https://www.phoronix.com/news/Mesa-25.3.3-Released), before that we had to fix it by building GTK4 without the vulkan backend, as sometimes `GSK_RENDERER=gl` just did not work as it ignores the variable, and in fact it looks like we will keep building GTK4 without vulkan as long as possible, because we also had an incident with one user on a super old intel laptop that does not support vulkan where gnome apps did not just work even with `GSK_RENDERER=gl` while the apppimages we make did.

* All GTK apps also have a useless dependency to a 30 MiB libicudata library, which is needed by libxml which is needed by libappstream which why would you even need to link to libappstream at all?? This is used to make AppStream metadata used in software stores, dafuck? 

* It also depends on Gstreamer 😹

At least more recently they are looking into adding [svg support into GTK4](https://www.phoronix.com/news/GTK-4.22-Native-SVG), which hopefully means they will get rid of the gdk-pixbuf and glycin dependency.
