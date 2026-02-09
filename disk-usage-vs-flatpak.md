<div align="center" markdown="1">

# Flatpak vs Anylinux-AppImages 
# Disk usage comparison with 20 apps

</div>

* All the appimages used here use sharun with the exception of Lutris that uses RunImage.
* Cromite was used for AppImage, however since there is no flatpak of cromite (due to a security issue with flatpak) ungoogled chromium was the closest thing picked for the flatpak equivalent.
* sas was included in the list of AppImages, since it is what provides AppImage sandboxing for AM. (hence 21 apps there). 
* The test was done on Artix linux on a Btrfs filesystem with zstd compression.

Steps:

* AppImages were installed with [appman](https://github.com/ivan-hc/AM) with this command.

```shell
appman -i \
	ares \
	azahar-enhanced \
	cemu-enhanced \
	cromite \
	discord \
	dolphin-emu \
	freetube-enhanced \
	goverlay \
	gpu-screen-recorder \
	kdenlive-enhanced \
	librecad \
	lutris \
	mame \
	mpv \
	obs-studio \
	oversteer \
	pinta \
	ppsspp \
	puddletag \
	rnote \
  sas

appman -f
```

* With `flatpak` the following command was used: 

```shell
flatpak install \
	com.dec05eba.gpu_screen_recorder \
	com.discordapp.Discord \
	com.github.flxzt.rnote \
	com.github.PintaProject.Pinta \
	com.obsproject.Studio \
	dev.ares.ares \
	info.cemu.Cemu \
	io.freetubeapp.FreeTube \
	io.github.benjamimgois.goverlay \
	io.github.berarma.Oversteer \
	io.github.ungoogled_software.ungoogled_chromium \
	io.mpv.Mpv \
	net.lutris.Lutris \
	net.puddletag.puddletag \
	org.azahar_emu.Azahar \
	org.DolphinEmu.dolphin-emu \
	org.kde.kdenlive \
	org.librecad.librecad \
	org.mamedev.MAME \
	org.ppsspp.PPSSPP

flatpak uninstall --unused
flatpak-dedup-checker
```
---

<div align="center" markdown="1">

# Result 

ApppImage: 2.0 GiB.

flatpak: 6.27 GiB.

AnyLinux-AppImages use **3.1 times** less storage than flatpak. 

</div>

<img width="1439" height="408" alt="results" src="https://github.com/user-attachments/assets/6bad6b23-beb1-45b0-9e08-07042341ff73" />

---

Worthy note: 

* Not all filesystems support transparent compression, if this test had been done on ext4 filesystem then flatpak would have taken **14.86 GiB** of disk, **more than 7x more than AppImage.**

In the end a lot of the bloat is flatpak comes from the fact that flatpak suffers what I call flatpak-hell, flatpak-hell is when one application depends on runtime version 2.2.0 but application B depends on a runtime version 2.2.1 so that means that both runtimes need to be downloaded and installed.

Lets assume flatpak manages to fix this issue (will never happen), how will that look? Well we can simulate that using alpine linux:

<div align="center" markdown="1">

---

# Bonus comparison: Anylinux-AppImages vs Alpine linux

</div>


Alpine linux is a very minimal distro whose developers actually put effort to reduce the size of the packages, [example](https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/icu/data-filter-en.yml).

We have to upgrade to the edge repo since stable is too old and lacks a lot of apps:

```shell
distrobox create -i alpine
distrobox enter alpine
printf "%s\n" \
	"https://dl-cdn.alpinelinux.org/alpine/edge/main" \
	"https://dl-cdn.alpinelinux.org/alpine/edge/community" \
	"https://dl-cdn.alpinelinux.org/alpine/edge/testing" \
	| sudo tee -a /etc/apk/repositories
sudo sed -i -e '/v3.21/d' /etc/apk/repositories
sudo apk upgrade
```

After doing this `podman ps -a --size --filter "name=alpine"` reports a container size of `535MB (virtual 560MB)`. 

Now lets add the applications, even after upgrading to the edge repo a lot of applications are not available, I was only able to install the following 12 applications:

- Note: These 12 applications as AppImage use **1.5 GiB**.

```shell
sudo apk add \
	cemu \
	chromium \
	freetube \
	kdenlive \
	lutris \
	wine \
	mame \
	mpv \
	obs-studio \
	pinta \
	ppsspp \
	rnote
```

* No idea how alpine does not list wine as a dependency of lutris, in the appimage this is included.

* chromium is the closest thing we have here to cromite.

After adding those 12 applications the container size increase **`3.27GB (virtual 3.29GB)`.** So yeah we also use less storage than Alpine, note however I think this size does not take Btrfs compression into account, I tried to get the value but couldn't (running `btrfs filesystem du -s` on the alpine container reported 7 MIb which is just impossible lol). 
