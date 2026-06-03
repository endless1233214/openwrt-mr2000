# MR2000 Live Checkpoint

Last updated: 2026-05-02

## Current Goal

Bring up the rebuilt OpenWrt image for the Linksys MR2000 after fixing the flashed-rootfs partition-map bug.

## Important Network Rule

Use the Mac's Wi-Fi for normal internet/build traffic.

Use the Mac's USB Ethernet adapter only for the direct cable to the MR2000 for TFTP/router traffic.

Do not rely on the Ethernet adapter for internet. Do not let it become the Mac default route.

Recommended direct-router private subnet:

- Mac Ethernet/TFTP server: `192.168.2.10/24`
- MR2000 U-Boot: `192.168.2.1`
- U-Boot `serverip`: `192.168.2.10`
- U-Boot `ipaddr`: `192.168.2.1`

This avoids conflict with the Mac Wi-Fi LAN, which is also on `192.168.1.0/24`.

Current observed Mac Wi-Fi:

- Wi-Fi device: `en0`
- Wi-Fi IP: `192.168.1.152`
- Default route: `en0` via `192.168.1.1`

Current observed Ethernet candidates:

- `en3`, inactive
- `en4`, inactive
- `en7`, USB 10/100/1000 LAN, inactive during last check

## Current State

OpenWrt is flashed and booting from flash.

Final working flash path was U-Boot factory-slot flashing, not OpenWrt `sysupgrade.bin`.

Live flashed boot checks:

```text
/proc/cmdline includes:
rootfstype=squashfs ubi.mtd=alt_rootfs root=mtd:squashfs

df -h:
/dev/root                 8.5M      8.5M         0 100% /rom
/dev/ubi0_1              51.6M     60.0K     48.9M   0% /overlay
overlayfs:/overlay       51.6M     60.0K     48.9M   0% /
```

Verified partition map from the live flashed boot:

```text
root@OpenWrt:~# awk "NR==1 || /kernel|rootfs|alt_|sysdiag|syscfg/" /proc/mtd
dev:    size   erasesize  name
mtd12: 05200000 00020000 "kernel"
mtd13: 04a00000 00020000 "rootfs"
mtd14: 05200000 00020000 "alt_kernel"
mtd15: 04a00000 00020000 "alt_rootfs"
mtd16: 00200000 00020000 "sysdiag"
mtd17: 04400000 00020000 "syscfg"
```

Wi-Fi status after flashed boot reported `radio0` and `radio1` up, not pending, and not retry-failed.

LAN was configured for direct Mac Ethernet access without colliding with the Mac Wi-Fi LAN:

```text
network.lan.ipaddr='192.168.2.1'
network.lan.netmask='255.255.255.0'
```

Important caveat:

OpenWrt `sysupgrade -T /tmp/mr2000-sysupgrade.bin` passed, but actually running `sysupgrade -n -v` wrote a U-Boot-incompatible image to slot 2. U-Boot then failed with:

```text
Wrong Image Format for bootm command
ERROR: can't get kernel image!
```

Recovery was immediate from serial/U-Boot by TFTP flashing the fixed factory image to slot 2:

```text
setenv ipaddr 192.168.2.1
setenv serverip 192.168.2.10
setenv image mr2000-factory-fixed.bin
run flashimg2

Bytes transferred = 17827840 (1100800 hex)
NAND erase: device 0 offset 0x58c0000, size 0x5200000 ... OK
NAND write: device 0 offset 0x58c0000, size 0x1100800 ... OK
```

## Fresh Build Artifacts

Fresh images were built successfully and copied to:

`/Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/`

Fresh SHA256 values:

```text
25898309a7063d2754a7db6a90b2cd513e1612d18b9d64c6cc720abb9128d0ab  openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb
794264e53e8b0e6dea97e9e97c7c6fc2447269f048263a548f1ab16b6c109b7f  openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-factory.bin
0ef105cdb0866e243cbeb6671bc9776f4cc005274eeb7d046e737c99d3c036ca  openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-sysupgrade.bin
```

The first rebuild tried `mtdparts=` in DTS bootargs, but the qcomsmem parser still won and exposed only 16 partitions. That image must not be flashed.

The current rebuild fixes this with DTS `fixed-partitions`.

Relevant DTS markers:

```text
bootargs-append = " root=/dev/ubiblock0_0 rootwait coherent_pool=2M";
compatible = "fixed-partitions";
partition@ec0000 {
```

The factory image starts with FIT magic `d00dfeed` and still has the Linksys trailer `.LINKSYS.01000409MR2000...`.

The manifest includes LuCI, `uhttpd`, `dropbear`, and `ipq-wifi-linksys_mr2000`.

## Why This Rebuild Exists

The previous flashed factory image wrote correctly, but OpenWrt's kernel only exposed 16 qcomsmem partitions:

- `kernel` at `0x6c0000-0x58c0000`
- `rootfs` at `0x58c0000-0xaac0000`

That made OpenWrt attach the wrong UBI partition and stall at:

```text
Waiting for root device /dev/ubiblock0_0...
```

Read-only check from RAM OpenWrt proved the primary slot rootfs was actually present at `kernel + 8MiB`:

```text
dd if=/dev/mtd12 bs=131072 skip=64 count=1 2>/dev/null | hexdump -C -n 64
00000000  55 42 49 23 ...
```

So the fix was adding the stock-style 18-partition fixed partition map to the MR2000 DTS.

## Next Safe Step

Set a root password and do normal first-boot OpenWrt setup. LuCI is reachable from the Mac Ethernet side at `http://192.168.2.1/` when the Mac USB Ethernet adapter is `192.168.2.10/24` with no gateway.

Mac-side verification:

```text
ping 192.168.2.1: 2/2 replies
curl -I http://192.168.2.1/: HTTP/1.1 200 OK
```

Do not use the current `sysupgrade.bin` path for future upgrades until the MR2000 sysupgrade format is fixed or retested. Use the factory slot image from U-Boot/TFTP for now.

## Safety

Do not run `saveenv`, `flashimg`, `flashimg2`, `nand erase`, or `nand write` unless explicitly planned.

Router recovery is still available through serial/U-Boot/TFTP/initramfs.
