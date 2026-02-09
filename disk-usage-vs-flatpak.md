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

```
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

```
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

