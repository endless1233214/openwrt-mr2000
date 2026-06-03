# MR2000 Router Baseline

This file records the router defaults that should survive future image rebuilds.

## Why This Exists

The first flashed MR2000 image booted and routed, but it did not include the SQM
kernel modules. Installing SQM later failed because OpenWrt kernel modules must
match the exact image build. For this router, performance and safety defaults
belong in the image.

## Baseline Packages

The build config should include:

```text
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_luci-app-adblock-fast=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_adblock-fast=y
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_kmod-ifb=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_tc-tiny=y
```

## Baseline Runtime Config

The image overlay at `files/etc/uci-defaults/99-mr2000-performance-baseline`
applies these defaults on first boot:

- SQM enabled on `wan` with CAKE and `piece_of_cake.qos`
- SQM rates initially set to the current stable live values: `35000` down and
  `7500` up
- WAN MTU set to `1430`
- packet steering enabled
- software/hardware flow offloading disabled so it does not bypass SQM
- Dropbear bound to the `lan` interface
- LuCI/uhttpd bound to `192.168.1.1:80` and `192.168.1.1:443`

## Live Verification

After booting a rebuilt image, verify with:

```sh
uci show sqm
tc -s qdisc show dev wan
tc -s qdisc show dev ifb4wan
uci show dropbear
uci show uhttpd
netstat -lntu
```

Treat `tc -s qdisc` as the source of truth for SQM. Service status alone can be
misleading.

## Flashing Caution

The MR2000 sysupgrade path previously produced a U-Boot-incompatible slot image.
Keep using the factory image through the known-good serial/U-Boot/TFTP path until
sysupgrade is retested and documented as safe.
