---
layout: default
title: Frequently Asked Questions
---

# Is it really any linux?

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
  <summary>Here is <code>aarch64</code> <a href="https://github.com/pkgforge-dev/QEMU-AppImage">Trelby</a> running on <b>32-bit</b> ARM debian 👀</summary>
  This is possible because this system had a 64bit kernel and CPU, <b>We do not depend on the host userland besides a shell in <code>/bin/sh</code></b>
  <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/a76e02d2-8b8b-411c-92e0-07aa9c6c75aa" />
</details>

# How come this only became possible in 2024?

* For application to be truly portable we need to ship our own dynamic linker (ld-linux.so).
* It turns out it is not possible to have a relative dynamic linker with executables. 
* polyfill glibc attempted to [fix this issue](https://github.com/corsix/polyfill-glibc/blob/main/docs/Command_line_options.md#elf-interpreter---print-interpreter---set-interpreter) with a experimental tool that replaces `PT_INTERP` with `PT_LOAD` and have the payload look for the relative dynamic linker but this never got finished.
* **We can execute the dynamic linker** first and then pass the binary to launch to bypass this limitation, **go-appimage had been doing this since ~2019.**
* [But that runs into isues with `/proc/self/exe`](https://github.com/probonopd/go-appimage/issues/49).
* [sharun](https://github.com/VHSgunzo/sharun) had to be made to fix the `/proc/self/exe` issues. And as far as I know, [brioche had been using the same approach before sharun as well](https://brioche.dev/blog/portable-dynamically-linked-packages-on-linux/).
* Once all the pieces were ready, the next step was changing the way we deploy AppImages and sorting all the bugs that came with that, AppImage was originally made with the idea of relying on the host glibc and a set of libraries that always had to come from the host. 

# Why DwarFS instead of SquashFS?

DwarFS is a lot faster than SquashFS while being smaller at the same time.

<img width="631" height="257" alt="Screenshot_2026-04-27_02-09-36" src="https://github.com/user-attachments/assets/4b1096f8-95a2-443d-a9bd-5f0fa7dcffbe" />

---
DwarFS also offers PGO like optimizations, [which allows us to make small appimages that start instantly.](https://github.com/pkgforge-dev/CollaboraOffice-AppImage/pull/1) 

# Why bundle glibc instead of musl?

* Using musl would mean any hardware accelerated application will not work with the proprietary nvidia driver.
* musl runs into performance issues because the default allocator is not great, this even [affected the type2 AppImage runtime](https://github.com/AppImage/type2-runtime/issues/116).
* It does not really save space, the libc is a small fraction of the entire AppImage size, the reason distros like alpine linux are small is because they optimize most of their packages for size like [this example](https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/icu/data-filter-en.yml) that results in a `libicudata.so` that is **less than 1 MiB** in size while most other distros do not bother to do this optimization and ship a **30 MiB** `libicudata.so`. Many of these optimizations are already by the [debloated packages repo.](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)
* With glibc, we are able to dlopen optional libraries on the host **even when those link to musl**. If we used musl the opposite is usually not possible as musl lacks a lot of symbols that libraries expect from glibc. For example here is the Qt6-demo dlopening alpine's GTK3 to use the GTK3 platform theme and look native on the system:

<img width="623" height="547" alt="image" src="https://github.com/user-attachments/assets/2d28ff5f-a46b-4f96-97b4-7f3d457de1e3" />


---

We only use musl where it is very useful, that is when making static binaries.

# What is there no `usr` directory in the AppImages?

Because it causes more issues than it solves.

* `/usr` is the typical installation prefix for an application. 

* `$APPDIR/usr` makes no sense, it just casues projects to code exceptions for appimage that do something alone these lines: `getenv(APPDIR)` + `usr` + `xyz`. Instead we make `APPDIR` the installation prefix directly. **This means we can take any application and patch away the `/usr` prefix for `$APPDIR` and make them portable without the need for projects to support AppImage.** Here are some examples where projects checking for `$APPDIR` just made things worse: [1](https://github.com/kem-a/AppManager/issues/41#issuecomment-3905238762) [2](https://github.com/pkgforge-dev/Anylinux-AppImages/issues/330#issuecomment-3939566890)

* **NOTE:** `$APPDIR/shared` is the a internal directory that sharun uses for itself, **you should never copy anything manually there.**
