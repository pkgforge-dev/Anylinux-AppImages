---
layout: default
title: Frequently Asked Questions
---

# Is it really any linux?

<details>
  <summary>Here is <a href="https://github.com/pkgforge-dev/GIMP-and-PhotoGIMP-AppImage">GIMP</a> running in Ubuntu <b>10.04</b></summary>
  <img width="1414" height="861" alt="image" src="https://github.com/user-attachments/assets/876de873-38f0-46c6-a721-d830b1af18aa" />
</details>

<details>
  <summary>Here is <a href="https://github.com/pkgforge-dev/Cromite-AppImage">Cromite</a> running in NixOS <b>without any FHS-wrapper</b></summary>
  <img width="1096" height="671" alt="image" src="https://github.com/user-attachments/assets/a7eac601-3a00-428a-9777-c7b4cdb8a2ba" />
</details>

<details>
  <summary>Here is <a href="https://github.com/pkgforge-dev/Cromite-AppImage">Cromite</a> running in Ubuntu 14.04</summary>
  <img width="1426" height="873" alt="image" src="https://github.com/user-attachments/assets/d60d31cc-9efa-4d06-9e75-bccff066f2b7" />
</details>

<details>
  <summary>Here is <a href="https://github.com/pkgforge-dev/wine-AppImage">WINE</a> running foobar2000 in Ubuntu 14.04</summary>
  <img width="1426" height="873" alt="image" src="https://github.com/user-attachments/assets/8382a2e4-61fb-45c6-bea7-83d7551ee64c" />
</details>

<details>
  <summary>Here is <a href="https://github.com/pkgforge-dev/QEMU-AppImage">QEMU</a> running in Ubuntu 12.04</summary>
  <img width="1025" height="822" alt="image" src="https://github.com/user-attachments/assets/3734afe3-05e3-4d53-9c4a-94b701abc46b" />
</details>

<details>
  <summary>Here is <a href="https://github.com/pkgforge-dev/FeatherPad-AppImage">FeatherPad</a> running in <b>Ubuntu 6.10</b> 👀</summary>
  <img width="1414" height="861" alt="image" src="https://github.com/user-attachments/assets/dd93cdde-f706-4143-b6db-c5c46f755c36" />
</details>

<details>
  <summary>Here is <code>aarch64</code> <a href="https://github.com/pkgforge-dev/Trelby-AppImage">Trelby</a> running on <b>32-bit</b> ARM debian 👀</summary>
  This is possible because this system had a 64bit kernel and CPU. <b>We barely depend on the host userland</b> besides some POSIX utils like <code>sh</code>.
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/a76e02d2-8b8b-411c-92e0-07aa9c6c75aa" />
</details>

<details>
  <summary>Here is <code>ppc64</code> <b>BE</b> <a href="https://github.com/pkgforge-dev/Galculator-AppImage">Galculator</a> running on a <b>32-bit</b> PowerPC system 👀</summary>
  Once again because we do not depend on the host userland, <b>as long as the kernel and CPU can execute the payload, it will work!</b>.

  <b>This also means our ppc64 BE ELFv2 AppImages work on ELFv1 systems!</b>
  <img width="1440" height="900" alt="image" src="https://github.com/user-attachments/assets/772c8b90-2aeb-4b11-bf7c-e9a547c8c755" />
</details>

<details>
  <summary>Here is <a href="https://git.eden-emu.dev/eden-emu/eden">Eden</a> running in <b>FreeBSD</b> using Vulkan with NVIDIA via Linuxulator 👀</summary>
  <img width="1193" height="671" alt="image" src="https://github.com/user-attachments/assets/473de2ba-f950-4e3a-9327-d741c70eda6e" />
</details>

# What's the minimum supported kernel version?

* Short answer: **2.6.17** (Ubuntu 6.10 era).

* Anything older than 2.6.17 is not possible due to no `openat` (needed by `dwarfs`), which means we are unable to execute `sharun`.

glibc on archlinux is compiled with `--enable-kernel=4.4`, that does not mean it is unable to run on kernels older than that, it will work as long as it doesn't attempt to use a syscall not present in such kernels. For example GIMP3 runs perfectly in Ubuntu 10.04 (kernel **2.6.32**) as shown above.

However one problematic syscall is `statx`, which is kernel **4.11** which Qt depends on and apps will crash when missing.

To fix this and a several other potential issues, our fork of sharun now has a compatiblity layer for older kernels, for more details see the [Anylinux-sharun README](https://github.com/pkgforge-dev/Anylinux-sharun/blob/main/README.md#what-this-fork-adds).

<img width="880" height="696" alt="image" src="https://github.com/user-attachments/assets/78e6c7c0-40ec-4b93-b55b-360853b03181" />

Supporting old kernels has run into some interesting issues, for example: 

* A missing syscall should return `ENOSYS` so the caller knows and can fall back if possible. Some 2.6-x kernels instead **return the syscall number itself:** `getrandom` returns `318`, `clone3` returns `435`. **This causes glibc to think the syscall works**, **while Rust's std panics with** `range start index 318 out of range for slice of length 16`. The fix is just to notice `rax == nr` and treat it as `ENOSYS`.

* On 3.8.0-19 `prctl(PR_SET_NO_NEW_PRIVS)` followed by `execve` fails with `EPERM`. Yes `prctl` returns 0 and the very next `execve("/bin/sh", ...)` comes back `EPERM` lol? The fix is just probe if `execve` works, else don't use `prctl`.

# How come this only became possible in 2024?

* For an application to be truly portable we need to ship our own dynamic linker (ld-linux.so).
* It turns out it is not possible to have a relative dynamic linker with executables.
* polyfill glibc attempted to [fix this issue](https://github.com/corsix/polyfill-glibc/blob/main/docs/Command_line_options.md#elf-interpreter---print-interpreter---set-interpreter) with an experimental tool that replaces `PT_INTERP` with `PT_LOAD` and has the payload look for the relative dynamic linker but this never got finished.
* **We can execute the dynamic linker** first and then pass the binary to launch to bypass this limitation, **go-appimage had been doing this since ~2019.**
* [But that runs into issues with `/proc/self/exe`](https://github.com/probonopd/go-appimage/issues/49).
* [sharun](https://github.com/VHSgunzo/sharun) had to be made to fix the `/proc/self/exe` issues. And as far as I know, [brioche had been using the same approach before sharun as well](https://brioche.dev/blog/portable-dynamically-linked-packages-on-linux/).
* Once all the pieces were ready, the next step was changing the way we deploy AppImages and sorting all the bugs that came with that, AppImage was originally made with the idea of relying on the host glibc and a set of libraries that always had to come from the host.

**I didn't understand any of this**

* You know when you have a shell script that it has shebang right? `#!/bin/sh` for example. And lets see our script is in `/usr/bin/myscript`. Well when you execute that file, you **actually just tell the kernel to execute** `/bin/sh /usr/bin/myscript`.
* **So if we wanted to have a truly portable shell script**, we just would need to bundle our own `sh` and always execute `sh /path/to/script`. And this is true for shell scripts (with a few minor exceptions not worth mentioning here).
* In shell scripting there is this special parameter called `$0`, it tells you the path of the script that is being executed, remember this since it is very important.

**So what's the problem with dynamic binaries?**

* The equivalent of `$0` in binaries is reading `/proc/self/exe`, this is a magic symlink set by the kernel **that points to the current running process.**
* `/proc/self/exe` is **set by the kernel** when you execute a binary, **this is not something we can ask the kernel to change.**
* So when a binary that was executed with the dynamic linker (`ld-linux.so /path/to/binary`) if that binary checks `/proc/self/exe` **it will get the path to `ld-linux.so` instead of `/path/to/binary`** and many apps **break horribly as result**, some will even report `ld-linux.so` as the window class lol.
* **This stupid problem is what has prevented true 100% binary compatiblity in linux for decades** 😹

**This problem is what sharun fixes**, by using `userland-execve` and bypassing the kernel `execve`, since it is the kernel what sets `/proc/self/exe`, if we use `userland-execve` we can control where `/proc/self/exe` actually points to instead and fix this.

# Why Arch Linux?

Because our AppImages are built there. That is not about where they run, they run on Ubuntu **6.10** as shown at the top, but the build host decides what ends up inside them, and we recommend Arch Linux for that ([there are Arch containers for every architecture we support](https://github.com/pkgforge-dev/docker-archlinux)).

This is not distro tribalism either, Ubuntu has given us an absurd amount of trouble, and some of these hit users, not just us:

* **Ubuntu replaces working userspace tools with unfinished rewrites.** Since [Ubuntu 25.10](https://ubuntu.com/server/docs/reference/other-tools/sudo-rs/) `coreutils` is [uutils](https://github.com/uutils/coreutils) and `sudo` is `sudo-rs`. uutils' `ln -f` does not unlink the destination first, so it fails with `ln: 'file' and 'dir/file' are the same file` where GNU `ln` succeeds ([uutils#8830](https://github.com/uutils/coreutils/issues/8830)). Our hooks create hardlinks, so [every AppImage that uses one broke on Ubuntu 25.10+](https://github.com/pkgforge-dev/xenia-canary-AppImage/issues/14) and we had to `rm -f` before `ln -f` to work around it.

* **Ubuntu 20.04's `file` calls executables "shared objects".** Ubuntu builds PIE binaries, so `readelf` reports `Type: DYN` for a regular executable. `file` 5.38, the one Ubuntu 20.04 ships, reports those as `ELF 64-bit LSB shared object` instead of `pie executable` ([it was restored in 5.39](https://bkhome.org/news/202010/file-utility-confuses-executable-and-shared-library.html)). The original `lib4bin`/`sharun` decided what to deploy by grepping `file`'s output for the word "executable" ([code](https://github.com/VHSgunzo/sharun/blob/404f04bf3c197aa780011de19605ad8ace9829cf/lib4bin#L121)), so **sharun treated the application's own binary as just another shared object**, never deployed it to `bin/`, and the AppImage had nothing to launch.

* **Ubuntu restricts unprivileged user namespaces** since 24.04, which breaks the sandbox of every Chromium/Electron app and the namespace fallback we use when FUSE is not available ([issue](https://github.com/pkgforge-dev/Anylinux-AppImages/issues/795), [Claude Desktop](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/issues/8)). The restriction is also trivial to bypass, double clicking an AppImage works because Nautilus is allowed to do it lol. We ship [`fix-namespaces.hook`](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/hooks/fix-namespaces.md) so users can turn it off, but we should not need to.

* **Ubuntu's Mesa is ancient.** 24.04 shipped Mesa 24.0.5 in 2024 and its updates are still on the 25.2 series, while [upstream is at 26.2](https://docs.mesa3d.org/relnotes/26.2.4.html), and the only way to get a newer one on Ubuntu is an unofficial PPA. Mesa is the difference between a game working and a game crashing, in [Citron#14](https://codeberg.org/pkgforge-dev/Citron-AppImage/issues/14) the host driver was loaded instead of the bundled one and the user got a bug that had already been fixed. This is why we bundle Mesa, and why letting the host's drivers override the bundled ones ended up being a bad idea.

* **There are no debloated packages for Ubuntu.** Our [debloated packages](https://github.com/pkgforge-dev/archlinux-pkgs-debloated) (`mesa-mini`, `mesa-nano`, `icu-mini`, `llvm-libs-mini` and friends) are Arch packages, they are how we keep AppImages small and fast to start. Nothing comparable exists for Ubuntu, and it would be built against a Mesa that is a year behind anyway.

* **Building on Ubuntu produces broken AppImages even today.** [This aarch64 AppImage](https://github.com/pkgforge-dev/Anylinux-AppImages/issues/1001) built on Jammy crashes at startup with `GLib-ERROR: getauxval () failed`, while the same source built on any other distro the reporter tried works. Good luck debugging a glibc we do not control.

* **Ubuntu's packaging keeps changing under the CI.** The `ubuntu-latest` runner image moved to 26.04, where `qemu-user-static` became a virtual package, apt refuses to pick between `qemu-user-binfmt` and `qemu-user-binfmt-hwe`, and every emulated build dies in its first step. We now pin the runners to `ubuntu-24.04`, which says everything you need to know about `ubuntu-latest`.

**So deploy on Arch Linux**, and install the application to `/usr` before running `quick-sharun`, see [prerequisites](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md#prerequisites). If you use another distro you are on your own, and either way test the result on Alpine and NixOS before shipping it.

# Why bundle glibc instead of musl?

* Using musl would mean any hardware accelerated application will not work with the proprietary nvidia driver.
* musl runs into performance issues because the default allocator is not great, this even [affected the type2 AppImage runtime](https://github.com/AppImage/type2-runtime/issues/116).
* It does not really save space, the libc is a small fraction of the entire AppImage size, the reason distros like alpine linux are small is because they optimize most of their packages for size like [this example](https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/icu/data-filter-en.yml) that results in a `libicudata.so` that is **less than 1 MiB** in size while most other distros do not bother to do this optimization and ship a **30 MiB** `libicudata.so`. Many of these optimizations are already used in the [debloated packages repo.](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)
* With glibc, we are able to dlopen optional libraries on the host **even when those link to musl**. If we used musl the opposite is usually not possible as musl lacks a lot of symbols that libraries expect from glibc. For example here is the Qt6-demo dlopening alpine's GTK3 to use the GTK3 platform theme and look native on the system:

<img width="623" height="547" alt="image" src="https://github.com/user-attachments/assets/2d28ff5f-a46b-4f96-97b4-7f3d457de1e3" />

---

We only use musl where it is very useful, that is when making static binaries.

# Why not statically link everything?

* That is super hard, some libraries are not meant to be statically linked as well and that means a ton of patches are needed.
* Statically linking everything means **we are not able to dlopen any library from the host**, even optional ones like the example I just gave about dlopening the host GTK from Qt apps to follow the system theme.
* **It means goodbye to the proprietary nvidia driver.**
* **It means you are no longer able to use vulkan layers like mangohud or lsfg-vk.**
* **It means you are forever stuck with the version of MESA that was statically linked.** Remember, you can use the host Mesa if needed by setting `SHARUN_ALLOW_SYS_VKICD=1` and that is something you will want to do if you plan on using the same AppImage for several years in the future.
* Static linking some dependencies is still desired however, as that reduces the final size of the AppImage, **but a fully static binary is a very bad idea.**

# Why not use [solo](https://github.com/pg83/solo) or [detour](https://github.com/graphitemaster/detour)?

These solutions allow statically linked programs to dlopen host libraries, amazing no? Well that runs into several problems:

* What happens if my application needs OpenGL 4.6 but the host Mesa only supports OpenGL 4.5? [Sadness.](https://github.com/PixelGuys/Cubyz/issues/2975#issuecomment-4315191567)
* What happens if I end up statically linking LLVM and the host's Mesa links to a different version of LLVM? [More problems.](https://www.gfxstrand.net/faith/blog/2022/01/in-defense-of-nir/)
* Also it seems none of the solutions implement `dlmopen`, so you are likely to run into a lot of symbol collisions with host libraries depending on what you end up building.

Using the host Mesa you are also going to run into bugs that had already been fixed in Mesa, we used to allow our AppImage to use the host vulkan drivers along with the bundled drivers, [that ended up being a bad idea.](https://codeberg.org/pkgforge-dev/Citron-AppImage/issues/14)

Also you are not forced to use our bundled drivers always, you can always set `USE_HOST_MESA_DRIVERS=1`, this will help if you plan to use the same AppImage several years into the future, but it is not guaranteed to work forever due to glibc symbol nonsense.

We don't run into these problems with Nvidia, because Nvidia releases its proprietary driver linking to super old versions of glibc so you can be certain it will always work.

---

**UPDATE: We now have a similar feature via [cross-libc-dlopen](https://github.com/pkgforge-dev/cross-libc-dlopen)**, enabled via `USE_HOST_DRIVERS_EXPERIMENTAL=1` in `quick-sharun`.

This feature is only going to be used if the applications meets the following conditions:

* The application doesn't depend on a recent version of OpenGL. (A good test is checking if the application works with the `softpipe` driver since that only supports OpenGL 3.3)
* The application does not have a hard dependency on vulkan. (Most vulkan apps require relative new versions of vulkan (1.2 or newer) which only began to show up in Mesa 20.0 ~Ubuntu 20.04).
* The application has a fallback software renderer. Who knows what can happen in future, it is likely for example that OpenGL might not be installed by default anymore in the next decade and now we have applications that no longer work.

---

# Why DwarFS instead of SquashFS?

DwarFS is a lot faster than SquashFS while being smaller at the same time.

<img width="631" height="257" alt="Screenshot_2026-04-27_02-09-36" src="https://github.com/user-attachments/assets/4b1096f8-95a2-443d-a9bd-5f0fa7dcffbe" />

---
DwarFS also offers PGO like optimizations, [which allows us to make small appimages that start instantly.](https://github.com/pkgforge-dev/CollaboraOffice-AppImage/pull/1)

# AppImage has no thumbnail?

Because we use DwarFS instead of SquashFS, you need an AppImage thumbnailer that supports DwarFS:

* [appimage-thumbnailer](https://github.com/kem-a/appimage-thumbnailer)
* [simple-appimage-thumbnailer](https://github.com/Samueru-sama/simple-appimage-thumbnailer)

# I get `ERROR: Can't find a valid SQUASHFS superblock` in NixOS

Once again this is because we use DwarFS instead of SquashFS, NixOS has something called `appimage-run` which lets you run old type appimages that need an FHS env and some host libraries, `appimage-run` manually mounts the appimage instead of letting it execute itself which results in that error since it expects it to be SquashFS.

**None of this is needed for our appimages, they run directly in NixOS, so all you have to do is disable `appimage-run`.**

# Why is there no `usr` directory in the AppImages?

Because it causes more issues than it solves.

* `/usr` is the typical installation prefix for an application.

* `$APPDIR/usr` makes no sense, it just causes projects to code exceptions for appimage that do something along these lines: `getenv(APPDIR)` + `usr` + `xyz`. Instead we make `APPDIR` the installation prefix directly. **This means we can take any application and patch away the `/usr` prefix for `$APPDIR` and make them portable without the need for projects to support AppImage.** Here are some examples where projects checking for `$APPDIR` just made things worse: [1](https://github.com/kem-a/AppManager/issues/41#issuecomment-3905238762) [2](https://github.com/pkgforge-dev/Anylinux-AppImages/issues/330#issuecomment-3939566890)

* **NOTE:** `$APPDIR/shared` is an internal directory that sharun uses for itself, **you should never copy anything manually there.**
