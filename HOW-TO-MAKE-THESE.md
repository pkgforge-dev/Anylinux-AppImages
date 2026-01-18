# How to make truly portable AppImages that work on any linux system.

-----------------------------------
### *Index*
-----------------------------------
- [Quick Start Guide](#quick-start-guide)
  - [Prerequisites](#prerequisites)
  - [Basic workflow](#basic-workflow)
  - [Step-by-step example](#step-by-step-example)
  - [Using hooks](#using-hooks)
  - [Available environment variables](#available-environment-variables)
- [Understanding the approach](#understanding-the-approach)
  - [The problem](#the-problem)
  - [The solution](#the-solution)
  - [How does it work?](#how-does-it-work)
  - [Sharun](#sharun)
- [Further considerations](#further-considerations)
  - [Isn't this very bloated?](#isnt-this-very-bloated)
  - [What about nvidia?](#what-about-nvidia)
- [Examples and templates](#examples-and-templates)


-----------------------------------

## *Quick Start Guide*

**TL;DR:** Use `quick-sharun.sh` to bundle your application with all its dependencies into a truly portable AppImage that works on any Linux system.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Prerequisites*

You'll need:
- A Linux system (preferably Arch Linux for building)
- Basic shell scripting knowledge
- The application you want to package (very preferably installed to /usr)

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Basic workflow*

Creating an AppImage with quick-sharun involves these steps:

1. **Install your application** and its dependencies on your build system
2. **Download quick-sharun.sh** from this repository
3. **Set environment variables** to configure `quick-sharun`
4. **Run quick-sharun** with your application's binary (and libraries) path to deploy.
5. **Generate the AppImage** with `--make-appimage` flag

That's it! The script will:
- Detect and bundle all required libraries (including those that are dlopened)
- Create a portable AppImage that works everywhere

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Step-by-step example*

Let's create an AppImage for a simple application. Here's a minimal example:

```bash
#!/bin/sh
set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"

# Configure the AppImage
export ICON=/usr/share/icons/hicolor/256x256/apps/myapp.png
export DESKTOP=/usr/share/applications/myapp.desktop
export OUTPATH=./dist
export OUTNAME=myapp-"$ARCH".AppImage

# Install your application (example using pacman)
pacman -Syu --noconfirm base-devel wget myapp

# Download and run quick-sharun
wget "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun

# Bundle the application
./quick-sharun /usr/bin/myapp

# Create the AppImage
./quick-sharun --make-appimage
```

**Using debloated packages** (smaller AppImages):

```bash
EXTRA_PACKAGES="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

wget "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh

# Installs a debloated MESA, vulkan, Qt, GTK, libicudata, and more
./get-debloated-pkgs.sh --add-mesa --prefer-nano

# Some appsm might requiere these as well
./get-debloated-pkgs.sh --add-common --prefer-nano ffmpeg-mini intel-media-driver-mini
```

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Using hooks*

Hooks are scripts that solve common problems automatically. Add them using the `ADD_HOOKS` variable:

```bash
export ADD_HOOKS="self-updater.bg.hook:fix-namespaces.hook"
./quick-sharun /usr/bin/myapp
```

**Available hooks:**

- **`self-updater.bg.hook`** - Makes the AppImage self-updatable using appimageupdatetool
- **`fix-namespaces.hook`** - Fixes namespace restrictions for apps that need them (web browsers and electron apps mostly)
- **`udev-installer.hook`** - Prompts to user to install bundled udev rules when needed
- **`vulkan-check.src.hook`** - Checks and fixes several commons issues that might affect vulkan and hardware acceleration in general
- **`x86-64-v3-check.hook`** - Checks for x86-64-v3 CPU support for applications that need it.
- **`host-libjack.src.hook`** - Uses host's JACK library when possible for performance gains, see the comments in the script for more details why this is needed.

See all hooks in [`useful-tools/hooks/`](https://github.com/pkgforge-dev/Anylinux-AppImages/tree/main/useful-tools/hooks)

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Available environment variables*

**Basic configuration:**
- `APPDIR` - Where to build the AppDir (default: `$PWD/AppDir`)
- `ICON` - Path to application icon
- `DESKTOP` - Path to .desktop file
- `OUTPATH` - Where to save the AppImage (default: `$PWD`)
- `OUTNAME` - Name of the output AppImage file, if not set the name in the .desktop file will be used

**Deployment options:**
- `DEPLOY_OPENGL=1` - Bundles OpenGL libraries (mesa) (should happen automatically)
- `DEPLOY_VULKAN=1` - Bundles Vulkan libraries (mesa) (should happen automatically)
- `DEPLOY_PYTHON=1` - Bundles Python using lib4bin uv python deployment (likely to be deprecated since DEPLOY_SYS_PYTHON is better)
- `DEPLOY_SYS_PYTHON=1` - Bundles system Python installation, often a lot smaller than using DEPLOY_PYTHON
- `DEPLOY_LOCALE=1` - Deploys locale files (default: enabled)

**Library handling:**
- `STRACE_MODE=1` - Uses strace to find dynamically loaded libraries (default: enabled)
- `STRIP=1` - Strips debug symbols to reduce size (default: enabled unless NO_STRIP is set)

**Hooks:**
- `ADD_HOOKS="hook1.hook:hook2.hook"` - Colon-separated list of hooks to add

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

## *Understanding the approach*

This section explains the technical details and philosophy behind these AppImages. If you just want to create AppImages, the [Quick Start Guide](#quick-start-guide) above is all you need.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *The problem*

For a long time the suggested practice to make AppImages has been to bundle most of the libraries an application needs but not all like libc, dynamic linker, and several more mentioned in the [exclude list](https://github.com/AppImageCommunity/pkg2appimage/blob/master/excludelist)

This approach has two big issues:

* It forces the developer to build on an old version of glibc to guarantee that the application works on most linux distros being used, because glibc sucks. This is specially problematic if your application needs something new like QT6 or GTK4 which is not available on such old distros.

* It also means the application cannot work on musl libc systems.

And the future stability isn't that great either, because glibc still sometimes breaks userspace with updates.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *The solution*

* ~~Lets use a container~~ ❌ nope that has a bunch of limitations and weird quirks, [very bloated](https://imgur.com/a/appimage-vs-flatpak-size-comparison-QH1dPyb) and depends on unprivileged user-namespaces [which you cannot even rely on...](https://github.com/linuxmint/mint22-beta/issues/82). It's worth adding that there are some cases where containers are really the only viable option, especially with applications that depend on both 32 and 64 bit libs, in which doing this without a container is going to be a lot of pain, but yeah, always leave this as a last resort method.

* Compile statically! Sure, that works, go and compile all of kdenlive statically and get back to me once you get it done.

* Bundle every library the application needs and don't rely on the host libc. ✅


This is the solution, truly portable application bundles that have everything they need.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *How does it work?*

**Note:** This section explains the technical implementation details. The `quick-sharun` script and `sharun` tool handle all of this automatically, so you don't need to do any of this manually. This is here for educational purposes.

1. First issue to overcome:

Since we are going to bundle our own libc, it means we cannot use the host dynamic linker even, which means we have to bundle our own `ld-linux/musl.so` and this has a problem, we cannot simply patch out binaries to use the bundled interpreter like `patchelf --set-interpreter '$ORIGIN/ld-linux.so'` because that `$ORIGIN` resolution is done by the interpreter itself.

**We can** have a relative interpreter like `./ld-linux.so`, the problem with this though is that we need to change the current working directory to that location for this to work. In other words, for AppImages, the current working directory will change to the random mountpoint of the AppImage and this is a problem if your application is a terminal emulator, that opens at the current working directory for example.

Instead we have to run the dynamic linker first, and then give it the binary we want to launch , which is possible, so our `AppRun` will look like this instead:


```
#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"

exec "$CURRENTDIR"/ld-linux-x86-64.so.2 "$CURRENTDIR"/bin/app "$@"
```

However this has a small issue that `/proc/self/exe` will be `ld-linux-x86-64.so.2` instead of the name of the binary we launched. For most applications, this isn't an issue, but when it is an issue, it is quite a big one. **Sharun fixes this problem** (see below), so we will continue with this approach to explain the rest.


2. Second issue to overcome:

Now that we have our own dynamic linker, how do we tell it that we can to use all the libraries we have in our own `lib` directory?

* `LD_LIBRARY_PATH` ❌ nope, terrible idea, **never use this variable**, it causes a lot of headaches because it is inherited by child processes, which means everything being launched by our application will try to use our libraries, and this causes insanely broken behaviours that are hard to catch, [for example](https://github.com/zen-browser/desktop/issues/2748) this issue lasted several months and no one had an idea what was going on until I [removed](https://github.com/zen-browser/desktop/pull/6156/files) the usage of `LD_LIBRARY_PATH`, which the application didn't even need to have it set in this case. Also see: [LD_LIBRARY_PATH – or: How to get yourself into trouble!](https://www.hpc.dtu.dk/?page_id=1180)

* Lets see our rpath to be `$ORIGIN/path/to/libs`, totally valid! ☑️ however a lot of times this is not done at compile time and instead it is done with `patchelf`, and while 99% of the time it is fine, that 1% when it breaks something it is also very hard to catch what went wrong.

* Tell the dynamic linker to use our bundled libraries directly ✅ This is not well known, but the dynamic linker supports the `--library-path` flag, which behaves very similar to `LD_LIBRARY_PATH` without being a variable that gets inherited by other processes, it is the perfect solution we just needed, so aur `AppRun` example will now look like this:

 ```
#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"

exec "$CURRENTDIR"/ld-linux-x86-64.so.2 \
	--library-path "$CURRENTDIR"/lib \
	"$CURRENTDIR"/bin/app "$@"
```

Now we are ready to start making our truly portable AppImage, now just need to bundle the libraries and dynamic linker and we are good to go! Kinda now we need to fix the following issue… **And also bundling all the libraries needed isn't as easy as just running `ldd` + `cp`** Sharun handles this automatically (see below).

3. Third issue to overcome:

Lets make our application relocatable. Thankfully this is already possible with almost all applications, I often see developers adding exceptions to their applications to make them portable, **but they are rarely needed at all**, because we already have the **XDG Base dir specification** that helps a ton here: https://specifications.freedesktop.org/basedir-spec/latest/

Instead of hardcoding your application to look for files in `/usr/share`, you need to check `XDG_DATA_DIRS`, which very likely your application already does since common libraries already follow the specification.

Then in our `AppRun` we include our `share` directory in `XDG_DATA_DIRS`, issue solved ✅

Same way, the dependencies we bundle will almost always have means to make relocatable any support plugin/support file they need, just to give a few examples:

* `PERLLIB` for perl

* `GCONV_PATH` for glibc

* Qt has `QT_PLUGIN_PATH`, but it also has a different method to be relocatable by making a `qt.conf` file next to our qt app binary. **This is much better because this variable has similar issues to** `LD_LIBRARY_PATH`

* `PIPEWIRE_MODULE_DIR` and `SPA_PLUGIN_DIR` for pipewire.

* `VK_DRIVER_FILES` and `__EGL_VENDOR_LIBRARY_DIRS` for mesa (vulkan and opengl) 💪

And many many more!

But isn't this a lot of work to find and set all the env variables that my application needs? **Yes it is**


4. Forth issue to overcome, I don't want to do any of this that's a lot of work.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Sharun*

There is a solution for this, made by @VHSGunzo called sharun:

https://github.com/VHSgunzo/sharun

* sharun is able to find all the libraries your application needs, **including those that are dlopened**, it turns out a lot of applications depend on dlopened libraries, those are libraries you cannot easily find with just `ldd`. Sharun uses a deployment script called `lib4bin` that has the strace mode, **that mode makes `lib4bin` open the application with strace to check all the dlopened libraries and then bundle them.**

* sharun also detects and sets a ton of [env variables](https://github.com/VHSgunzo/sharun?tab=readme-ov-file#environment-variables-that-are-set-if-sharun-finds-a-directory-or-file.) that the application needs to work.

* it also fixes the issue of  `/proc/self/exe` being `ld-linux-x86-64.so.2` 👀 For this issue, what it does is it places all the shared libraries and binaries in `shared/{lib,bin}` and then hardlinks itself to the `bin` directory of our `AppDir`; then when you call `bin/app`, it automatically calls the bundled dynamic linker and runs the binary with the name of the hardlink, while giving the path to our bundled libraries with `--library-path`

* sharun also doubles as the `AppRun` and additional env variables can be added by making a `.env` file next to it, **this means we no longer depend on the host shell to get our application to launch.**

* sharun is also just not for AppImages, you can use it anywhere you need to make any sort of application portable, you can even make pseudo static binaries from existing dynamic binaries which sharun does with the help of wrappe.

* sharun even has hooks to fix applications that aren't relocatable, like webkit2gtk which is hardcoded to look for some binaries in `/usr/lib`, it fixes this with patching all automatically for you.


Any application made with sharun ends up being able to work **on any linux distro**, be it ubuntu 14.04, musl distros and even directly in NixOS without any wrapper (non FHS environment).

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

## *Further considerations*

-----------------------------------

### *Isn't this very bloated?*

Not really, if your application isn't hardware accelerated, bundling all the libraries will usually only increase the size of the application by less than 10 MiB.

For applications that are hardware accelerated, there is the problem that mesa links to `libLLVM.so`, which is a huge +130 MiB library that's used for a lot of things. Distros by default build it with support for the following:

```
AArch64
AMDGPU
ARM
AVR
BPF
Hexagon
Lanai
LoongArch
Mips
MSP430
NVPTX
PowerPC
RISCV
Sparc
SystemZ
VE
WebAssembly
X86
XCore
```

When for most applications you only need llvm to support AMDGPU and X86/AArch64.

We already make such version of llvm here: https://github.com/pkgforge-dev/archlinux-pkgs-debloated which reduces the size of libLLVM.so down to 66 MiB.


Such package and other debloated packages we have are used by [Goverlay](https://github.com/benjamimgois/goverlay), which results a **60 MiB** AppImage that works on any linux system, which is surprisingly small considering this application bundles **Qt** and **mesa**  (vulkan) among other things.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *What about nvidia?*

Nvidia releases its proprietary driver as a binary blob that is already widely compatible on its own, it's only requirement is a new enough version of glibc, which the appimages made here will do as long as you build them on a glibc distro. Then you just need to add the nvidia icds to `VK_DRIVER_FILES` to be able to use it without problem.

If you don't have the proprietary nvidia driver, mesa already includes nouveau support for the few GPUs where this driver actually works (NVIDIA GTX 16 series or newer).

Goes without saying that sharun handles all of this already on its own.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

## *Examples and templates*

### Demo examples

See the ready-to-use demo scripts in [`useful-tools/demo/`](https://github.com/pkgforge-dev/Anylinux-AppImages/tree/main/useful-tools/demo):

* [vkcube + glxgears](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/demo/vkcube-glxgears-appimage.sh) - Bundles OpenGL and Vulkan test applications ([download demo](https://github.com/pkgforge-dev/Anylinux-AppImages/releases/tag/demo))
* [gtk3-demo](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/demo/gtk3-demo-appimage.sh) - Simple GTK3 application
* [gtk4-demo](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/demo/gtk4-demo-appimage.sh) - Simple GTK4 application
* [qt6-dbus-demo](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/demo/qt6-dbus-demo-appimage.sh) - Qt6 application with D-Bus

### Real-world examples

Browse through our production AppImage repositories for more complex examples:

* [Cromite](https://github.com/pkgforge-dev/Cromite-AppImage/blob/7e3171f1b2a6138cb27a7309c1e386435ea1fe12/cromite-appimage.sh#L38-L59) - Chromium-based browser
* [Azahar](https://github.com/pkgforge-dev/Azahar-AppImage-Enhanced/blob/d2e97d16ebce1f421187b9887767e6660ac57dcb/azahar-appimage.sh#L73-L97) - Nintendo 3DS emulator
* [scrcpy](https://github.com/pkgforge-dev/scrcpy-AppImage/blob/97fb70cc3b2885753116f43d3f64106cae2227d1/scrcpy-appimage.sh#L11-L43) - Android screen mirroring
* [See all AppImages](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/README.md#applications)

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------
