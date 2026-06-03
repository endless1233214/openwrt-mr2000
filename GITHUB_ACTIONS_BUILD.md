# Cloud Build for MR2000

This is the low-bandwidth way to build the first OpenWrt MR2000 images.

The Mac does not currently have Docker/Colima/Lima/Podman/OrbStack, and local disk is tight for a full OpenWrt source build. GitHub Actions can do the heavy downloading and compiling in the cloud, then you only download the final image artifact.

## What It Builds

Workflow:

```text
.github/workflows/build-mr2000.yml
```

The workflow now also applies the baseline in:

```text
MR2000_BASELINE.md
files/etc/uci-defaults/99-mr2000-performance-baseline
```

That baseline bakes in SQM/CAKE, adblock-fast, and first-boot router defaults
so a future reflash does not lose the performance and admin-hardening changes.

Primary first-test image:

```text
openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb
```

This is the one to boot from U-Boot over TFTP/RAM first. Do not flash it.

The workflow may also produce factory/sysupgrade images, but those should wait until initramfs boot is verified over serial.

## How To Use

1. Create or reuse an empty GitHub repository.
2. From this folder, initialize and push only the build kit:

```sh
cd /Users/endless/Desktop/Projects/OpenWRT-For-My-MR2000
git init
git add .
git commit -m "Add MR2000 OpenWrt build kit"
git branch -M main
git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git
git push -u origin main
```

3. Open the repository on GitHub.
4. Go to `Actions`.
5. Select `Build MR2000 OpenWrt Images`.
6. Click `Run workflow`.
7. Download the `mr2000-openwrt-images` artifact when it finishes.

## After Download

Keep the files together with the serial logs.

First test step is not web flashing. First test step is U-Boot booting the initramfs image over TFTP/RAM.
