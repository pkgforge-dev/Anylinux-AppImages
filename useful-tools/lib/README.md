# Helper libraries

The preload helper libraries used by [quick-sharun](../quick-sharun.sh) are no
longer kept in this repository, their sources now live in
[Anylinux-sharun](https://github.com/pkgforge-dev/Anylinux-sharun):

<https://github.com/pkgforge-dev/Anylinux-sharun/tree/main/lib>

- `anylinux.so`
- `gtk-fix-nonsense.so`
- `glycin-fix.so`
- `path-mapping.so`

They are prebuilt and shipped inside the `sharun+helper-libs-$ARCH.tar` release
artifact that quick-sharun downloads, so no C compiler is needed at deploy time
anymore.
