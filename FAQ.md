---
layout: default
title: Frequently Asked Questions
---

# Why DwarFS instead of SquashFS?

DwarFS is a lot faster than SquashFS while being smaller at the same time.

<img width="631" height="257" alt="Screenshot_2026-04-27_02-09-36" src="https://github.com/user-attachments/assets/4b1096f8-95a2-443d-a9bd-5f0fa7dcffbe" />

---
DwarFS also offers PGO like optimizations, [which allows us to make small appimages that start instantly.](https://github.com/pkgforge-dev/CollaboraOffice-AppImage/pull/1) 

# Why bundle glibc instead of musl?

* Using musl would mean any hardware accelerated application will not work with the proprietary nvidia driver.
* musl runs into performance issues because the default allocator is not great, this even [affected the type2 AppImage runtime](https://github.com/AppImage/type2-runtime/issues/116).
* It does not really save space, the libc is a small fraction of the entire AppImage size, the reason likes distros like alpine linux are small is because they optimize most of their packages for size like [this example](https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/icu/data-filter-en.yml) that results in a `libicudata.so` that is **less than 1 MiB** in size while most other distros do not bother to do this optimization and ship a **30 MiB** `libicudata.so`. Many of these optimizations are already by the [debloated packages repo.](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)
* With glibc, we are able to dlopen optional libraries on the host **even when those link to musl**. If we used musl the opposite is usually not possible as musl lacks a lot of symbols that libraries expect from glibc. For example here is the Qt6-demo dlopening alpine's GTK3 to use the GTK3 platform theme and look native on the system:

<img width="623" height="547" alt="image" src="https://github.com/user-attachments/assets/2d28ff5f-a46b-4f96-97b4-7f3d457de1e3" />


---

We only use musl where it is very useful, that is when making static binaries.

