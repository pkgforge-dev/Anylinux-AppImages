# How to make truly portable AppImages that work on any linux system.

-----------------------------------
### *Index*
-----------------------------------
- [The problem](#the-problem)
- [The solution](#the-solution)
- [How do I do it?](#how-do-i-do-it)
  - [Sharun](#sharun)
- [Further considerations](#further-considerations)
  - [Isn’t this very bloated?](#isnt-this-very-bloated)
  - [What about nvidia?](#what-about-nvidia)

-----------------------------------

## *The problem*

For a long time the suggested practice to make AppImages has been to bundle most of the libraries an application needs but not all like libc, dynamic linker, and several more mentioned in the [exclude list](https://github.com/AppImageCommunity/pkg2appimage/blob/master/excludelist)

This approach has two big issues:

* It forces the developer to build on an old version of glibc to guarantee that the application works on most linux distros being used, because glibc sucks. This is specially problematic if your application needs something new like QT6 or GTK4 which is not available on such old distros. 

* It also means the application cannot work on musl libc systems.

And the future stability isn’t that great either, because glibc still sometimes breaks userspace with updates.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

## *The solution*

* ~~Lets use a container~~ ❌ nope that has a bunch of limitations and weird quirks, [very bloated](https://i.imgur.com/25AOq00.png) and depends on namespaces [which you cannot even rely on...](https://github.com/linuxmint/mint22-beta/issues/82) Worth adding there are some cases where containers are really the only viable option, specially with applications that depend on both 32 and 64 bit libs in which doing this without a container is going to be a lot of pain, but yeah, always leave this as a last resort method. 

* Compile statically! Sure, that works, go and compile all of kdenlive statically and get back to me once you get it done. 

* Bundle every library the application needs and don’t rely on the host libc. ✅


This is the solution, truly portable application bundles that have everything they need. 

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

## *How do I do it?*

1. First issue to overcome: 

Since we are going to bundle our own libc, it means we cannot use the host dynamic linker even, which means we have to bundle our own `ld-linux/musl.so` and this has a problem, we cannot simply patch out binaries to use the bundled interpreter like `patchelf –set-interpreter ‘$ORIGIN/ld-linux.so` because that `$ORIGIN` resolution is done by the interpreter itself. 

**We can** have a relative interpreter like `./ld-linux.so`, the problem with this though is that we need to change the current working directory to that location for this to work, in other words for appimages the current working dir will change to the random mountpoint of the appimage, this is a problem if your application is a terminal emulator that opens at the current working directory for example. 

Instead we have to run the dynamic linker first, and then give it the binary we want to launch , which is possible, so our `AppRun` will look like this instead: 


```
#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"

exec "$CURRENTDIR"/ld-linux-x86-64.so.2 "$CURRENTDIR"/bin/app "$@"
```

However this has a small issue that `/proc/self/exe` will be `ld-linux-x86-64.so.2` instead of the name of the binary we launched, for most applications this isn’t an issue, but when it is an issue it is quite a big issue. **Later on I will show what can fix this problem** (issue 4), we will continue with this approach to explain the rest.


2. Second issue to overcome:

Now that we have our own dynamic linker, how do we tell it that we can to use all the libraries we have in our own `lib` directory? 

* `LD_LIBRARY_PATH` ❌ nope, terrible idea, **never use this variable**, it causes a lot of headaches because it is inherited by child processes, which means everything being launched by our application will try to use our libraries, and this causes insanely broken behaviours that are hard to catch, [for example](https://github.com/zen-browser/desktop/issues/2748) this issue lasted several months and no one had an idea what was going on until I [removed](https://github.com/zen-browser/desktop/pull/6156/files) the usage of `LD_LIBRARY_PATH`, which the application didn’t even need to have it set in this case. Also see: [LD_LIBRARY_PATH – or: How to get yourself into trouble!](https://www.hpc.dtu.dk/?page_id=1180)

* Lets see our rpath to be `$ORIGIN/path/to/libs`, totally valid! ☑️ however a lot of times this is not done at compile time and instead it is done with `patchelf`, and while 99% of the time it is fine, that 1% when it breaks something it is also very hard to catch what went wrong.

* Tell the dynamic linker to use our bundled libraries directly ✅ This is not well known, but the dynamic linker supports the `--library-path` flag, which behaves very similar to `LD_LIBRARY_PATH` without being a variable that gets inherited by other processes, it is the perfect solution we just needed, so aur `AppRun` example will now look like this: 

 ```
#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"

exec "$CURRENTDIR"/ld-linux-x86-64.so.2 \
	--library-path "$CURRENTDIR"/lib \
	"$CURRENTDIR"/bin/app "$@"
```

Now we are ready to start making our truly portable AppImage, now just need to bundle the libraries and dynamic linker and we are good to go! Kinda now we need to fix the following issue… **And also bundling all the libraries needed isn’t as easy as just running `ldd` + `cp`** I will show how to do this quickly further down here (issue 4). 

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

But isn’t this a lot of work to find and set all the env variables that my application needs? **Yes it is**


4. Forth issue to overcome, I don’t want to do any of this that’s a lot of work.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *Sharun*

There is a solution for this, made by @VHSGunzo called sharun: 

https://github.com/VHSgunzo/sharun

* sharun is able to find all the libraries your application needs, **including those that are dlopened**, it turns out a lot of applications depend on dlopened libraries, those are libraries you cannot easily find with just `ldd`. Sharun uses a deployment script called `lib4bin` that has the strace mode, **that mode makes `lib4bin` open the application with strace to check all the dlopened libraries and then bundle them.**  

* sharun also detects and sets a ton of [env variables](https://github.com/VHSgunzo/sharun?tab=readme-ov-file#environment-variables-that-are-set-if-sharun-finds-a-directory-or-file.) that the application needs to work.

* it also fixes the issue of  `/proc/self/exe` being `ld-linux-x86-64.so.2` 👀 For this what it does is placed all the shared libraries and binaries in `shared/{lib,bin}` and then hardlinks itself to the `bin` directory of our `AppDir`, then when you `bin/app` it automatically calls the bundled dynamic linker and runs the binary with the name of the hardlink while giving the path to our bundled libraries with `--library-path`

* sharun also doubles as the `AppRun` and additional env variables can be added by making a `.env` file next to it, **this means we no longer depend on the host shell to get our application to launch.**

* sharun is also just not for AppImages, you can use it anywhere you need to make any sort of application portable, you can even make pseudo static binaries from existing dynamic binaries which sharun does with the help of wrappe.

* sharun even has hooks to fix applications that aren’t relocatable, like webkit2gtk which is hardcoded to for some binaries in `/urs/lib`, it fixes this with patching all automatically for you.


Any application made with sharun ends up being able to work **on any linux distro**, be it ubuntu 14.04, musl distros and even directly in NixOS without any wrapper (non FHS environment). 

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

## *Further considerations*

-----------------------------------

### *Isn’t this very bloated?*

Not really, if your application isn’t hardware accelerated, bundling all the libraries will usually only increase the size of the application by less than 10 MiB.

For applications that are hardware accelerated, there is the problem that mesa links to `libLLVM.so`, which is a huge +130 MiB library that’s used for a lot of things. Distros by default build it with support for the following: 

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

We already make such version of llvm here: https://github.com/pkgforge-dev/llvm-libs-debloated which reduces the size of libLLVM.so down to 66 MiB.


Such package and other debloated packages we have are used by [Goverlay](https://github.com/benjamimgois/goverlay), which results a **60 MiB** AppImage that works on any linux system, which is surprisingly small considering this application bundles **Qt** and **mesa**  (vulkan) among other things. 

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------

### *What about nvidia?*

Nvidia releases its proprietary driver as a binary blob that is already widely compatible on its own, it’s only requirement is a new enough version of glibc, which the appimages made here will do as long as you build them on a glibc distro. Then you just need to add the nvidia icds to `VK_DRIVER_FILES` to be able to use it without problem. 

If you don’t have the proprietary nvidia driver, mesa already includes nouveau support for the few GPUs where this driver actually works (anything 16 series or newer). 

Goes without saying that sharun handles all of this already on its own.

-----------------------------------

| [Back to Index](#index) |
| - |

-----------------------------------
