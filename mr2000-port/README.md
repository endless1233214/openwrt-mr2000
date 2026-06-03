# Linksys MR2000 OpenWrt Porting Kit

Status: first-pass port files are drafted, serial/TFTP initramfs boot works, and
the router has been flashed successfully through the factory-slot U-Boot/TFTP
path. The build kit is now aimed at OpenWrt 25.12.4. This is still not ready for
blind web UI flashing or unattended sysupgrade.

## What Is In This Folder

- `../build-output/`
  - Local Docker build artifacts for the MR2000.
  - First file to test: `openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb`.
  - Do not flash `factory.bin` or `sysupgrade.bin` until initramfs boot succeeds.
- `../MR2000_FIRST_BOOT.md`
  - Exact first-boot checklist and TFTP/U-Boot commands.
- `../MR2000_FLASH_TEST.md`
  - Controlled first flash procedure. Uses serial/U-Boot, flashes the inactive primary slot only, and preserves the currently active stock slot.
- `patches/openwrt-v25.12.4-local/0001-local-qualcommax-ipq50xx-add-linksys-mr2000.patch`
  - Best patch for a local test build.
  - Includes the OpenWrt device support plus local `ipq-wifi/files/` board-data blobs.
- `patches/openwrt-v25.12.4-local/0002-local-ipq-wifi-copy-package-files.patch`
  - Lets the local board-data files be copied into the generated `ipq-wifi`
    package during the build.
- `patches/openwrt-v25.12.2/0001-qualcommax-ipq50xx-add-linksys-mr2000.patch`
  - Upstream-style OpenWrt patch.
  - Expects board data to exist in the `firmware/qca-wireless` source package.
- `patches/qca-wireless/0001-ath11k-add-linksys-mr2000-board-data.patch`
  - Upstream-style board-data patch for OpenWrt's `firmware/qca-wireless.git`.
- `board-data/`
  - Raw FCC board-data files extracted from the stock Linksys firmware.
  - Generated `board-linksys_mr2000.ipq5018` and `board-linksys_mr2000.qcn6122` files.

## Evidence Collected

- Linksys support page identifies the MR2000 / Hydra 6 as AX3000, IPQ5018-class hardware with 512 MB DDR3, four LAN ports, one WAN port, and USB 3.0:
  <https://support.linksys.com/kb/article/6251-en/>
- FCC internal photos show the MR2000 PCB silkscreen:
  `WRT0-366AX_V01 / ESX-X20-1601R`
  <https://fccid.io/2AYRA-08321/Internal-Photos/Internal-photos-5678480>
- OpenWrt 25.12.2 has nearby Linksys IPQ5018 targets, but not MR2000:
  <https://downloads.openwrt.org/releases/25.12.2/targets/qualcommax/ipq50xx/profiles.json>
- Stock firmware image:
  `FW_MR2000_1.1.5.210166_prod.img`
  SHA256: `5e9a3bc3182541fe9d39634d71d84f603c2b3519b9aad579d863f4cff71d0d70`
- Stock DTB model:
  `Qualcomm Technologies, Inc. IPQ5018/AP-MP03.5-C1`
- Stock DTB compatible:
  `qcom,ipq5018-mp03.5-c1`, `qcom,ipq5018`
- Stock memory:
  512 MB at `0x40000000`
- Stock NAND:
  QPIC NAND, 128 KiB block size, 2 KiB page size, ECC 4-bit / 512-byte step
- Stock image layout:
  FIT kernel at offset `0x0`, UBI rootfs starts at `0x800000`, Linksys trailer starts at `0x2880000`
- Stock wireless:
  IPQ5018 radio board id `0x23`, QCN6122 radio board id `0x60`
- Stock Ethernet:
  IPQ5018 GE PHY is the WAN path; QCA8337 on MDIO1 is the four-port LAN switch

## Serial Capture 2026-05-01

Captured in `mr2000-serial.log` with:

```sh
screen -L /dev/cu.wchusbserial10 115200
```

Useful confirmed facts:

- Serial settings are `115200 8N1`.
- U-Boot: `U-Boot 2016.01 (Jan 19 2022 - 14:15:30 +0800)`.
- Linksys/GMTK U-Boot: `1.0.01 ([IPQ5018].[SPF11.4].[CSU2])`.
- `machid=8040004`.
- NAND: GigaDevice `GD5F2GQ5REYIH`, 256 MiB, 2048-byte page, 128 KiB block, ECC 4-bit.
- Boot env currently has `boot_part=2`, `boot_part_ready=3`, `auto_recovery=yes`.
- Router U-Boot IP defaults: `ipaddr=192.168.1.1`, `serverip=192.168.1.10`.
- Active boot commands read an 8 MiB FIT kernel from `kernel` or `alt_kernel`, then mount UBI rootfs from the matching rootfs slot.
- `kernsize=800000`, `prikern=6c0000`, `altkern=58c0000`, `imgsize=5200000`.
- `qca_bootargs=console=ttyMSM0,115200n8 cnss2.bdf_pci1=0x60 cnss2.skip_radio_bmap=2 cnss2.bdf_integrated=0x23`.
- The combined Linksys image slot size is `0x5200000`, matching the drafted OpenWrt `IMAGE_SIZE := 83968k`.

Observed U-Boot flash helpers:

```sh
flashimg=tftpb $loadaddr $image && nand erase $prikern $imgsize && nand write $loadaddr $prikern $filesize
flashimg2=tftpb $loadaddr $image && nand erase $altkern $imgsize && nand write $loadaddr $altkern $filesize
```

Do not use those helpers until the OpenWrt initramfs image has booted cleanly.

## OpenWrt RAM Boot Captures 2026-05-01

`mr2000-serial-idk-boot.log` proved the MR2000 DTS can boot OpenWrt from RAM, but showed missing ath11k board-data files in the initramfs image.

`mr2000-serial-idk-2-boot.log` is the current best OpenWrt boot:

- TFTP succeeded with the rebuilt image: `12288700` bytes.
- OpenWrt booted to `root@OpenWrt`.
- The old ath11k board-data fetch failures are gone.
- `ath11k c000000.wifi` probes as IPQ5018 and reports firmware `WLAN.HK.2.7.0.1-01744-QCAHKSWPL_SILICONZ-1`.
- `ath11k b00a040.wifi` probes as QCN6122 and reports the same firmware family.
- `wifi status` reports both radios up and not retry-failed.
- Enabling the default APs works in RAM: `MR2000-Test-2G` and `MR2000-Test-5G` appear, `iw dev` shows `phy0-ap0` and `phy1-ap0`, and hostapd reports `AP-ENABLED` for both.
- `lan4`, `eth0`, and `br-lan` are up; `wan` is `NO-CARRIER` with no WAN cable attached.
- Router-to-Mac LAN ping works from OpenWrt RAM boot to `192.168.1.10`: 3/3 replies, 0% packet loss.
- Moving the cable from LAN4 to LAN1 works: `lan4` goes down, `lan1` links at 1 Gbps full duplex, and `br-lan` forwards through port 1.
- Moving the cable from LAN1 to LAN2 works: `lan1` goes down, `lan2` links at 1 Gbps full duplex, and `br-lan` forwards through port 2.
- Moving the cable from LAN2 to LAN3 works: `lan2` goes down, `lan3` links at 1 Gbps full duplex, and `br-lan` forwards through port 3.
- Moving the cable from LAN3 to WAN works: `lan3` goes down, `wan` links and `ip link` shows `wan` as `UP,LOWER_UP`.
- USB host mode enumerates a connected high-speed device on `xhci-hcd`; `/sys/bus/usb/devices/1-1` reports `PNY USB 3.2.1 FD`.
- `block info` is not present in the initramfs image, so USB block-device mounting was not tested by this capture.
- WPS button did not produce an observed OpenWrt hotplug/log event during this test.
- Reset button triggered OpenWrt shutdown/reboot and returned the router to U-Boot/boot flow. Treat reset as a reboot/reset control, not as a safe diagnostic button, during initramfs testing.

Next capture targets from the initramfs shell:

No more button tests are needed for the initial RAM bring-up.

## Full Stock Boot Capture 2026-05-01

Captured in `mr2000-serial-full-boot.log`.

Useful extra facts:

- Stock U-Boot boots from `boot_part=2`, reading `alt_kernel` at `0x58c0000`.
- Stock kernel is `Linux 4.4.60`, built Fri Apr 8 2022.
- Stock kernel command line uses `ubi.mtd=alt_rootfs`.
- Stock Linux creates the expected 18 MTD partitions from the command line.
- `alt_rootfs` attaches as `ubi0` on `mtd15`; `syscfg` mounts separately as another UBI device.
- Stock init sets MAC addresses from base `80:69:1A:0B:5F:03`.
- Stock init identifies the model as `MR2000`.
- Stock init sets up Wi-Fi firmware and board data for region `US`.
- Stock init loads Wi-Fi caldata from `mtd7`, which is `0:ART`.
- Stock Wi-Fi reaches AP-enabled state on `ath0` at 2.4 GHz and `ath1` at 5 GHz.
- The serial login prompt appears, but `root` and `admin` logins were rejected. Stock shell access is not required for the OpenWrt bring-up path.

Useful implication for the OpenWrt DTS:

- The current two-radio OpenWrt plan is right: IPQ5018 plus one QCN6122 radio.
- The caldata source should remain `0:ART`.
- The active stock boot slot is the alternate slot, so first flash tests must preserve the ability to return to the other slot.

## Why Serial First

The stock image format strongly suggests an OpenWrt `factory.bin` can eventually be made for the stock Linksys firmware updater. That is not the first thing to flash.

For first bring-up, use a 3.3 V USB-TTL serial adapter:

- Connect GND, TX, and RX only.
- Do not connect VCC.
- Use `115200 8N1`.
- Capture U-Boot output and stock boot output before trying OpenWrt.

Serial gives us U-Boot access, TFTP/initramfs boot testing, boot logs, and a recovery path if the first DTS is wrong.

## Local Source Build

Use Linux for the first build. The full OpenWrt source build is the right tool here because this target is not supported by the official ImageBuilder yet.

```sh
git clone https://github.com/openwrt/openwrt.git
cd openwrt
git checkout v25.12.4
git apply /Users/endless/Desktop/Projects/OpenWRT-For-My-MR2000/mr2000-port/patches/openwrt-v25.12.4-local/0001-local-qualcommax-ipq50xx-add-linksys-mr2000.patch
git apply /Users/endless/Desktop/Projects/OpenWRT-For-My-MR2000/mr2000-port/patches/openwrt-v25.12.4-local/0002-local-ipq-wifi-copy-package-files.patch
./scripts/feeds update -a
./scripts/feeds install -a
```

Minimal first-test config:

```sh
cat > .config <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_linksys_mr2000=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_PACKAGE_luci=y
EOF
make defconfig
make -j"$(nproc)" V=s
```

Expected first output to test over serial/TFTP:

- `bin/targets/qualcommax/ipq50xx/openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb`

Local Docker build output from 2026-05-01:

```text
/Users/endless/Desktop/Projects/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb
SHA256: 6a2ca521118c102093a6a227050c2086bb94a267b4cfaafea239a1a0b88b6eac
```

The factory image is useful later, after initramfs boot succeeds:

- `bin/targets/qualcommax/ipq50xx/openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-factory.bin`

## First Boot Test Checklist

From stock firmware or U-Boot, capture:

```sh
printenv
mtdparts
smeminfo
bdinfo
```

If stock Linux shell access is available, capture:

```sh
cat /proc/mtd
cat /sys/firmware/devicetree/base/model
cat /sys/firmware/devicetree/base/compatible
fw_printenv
dmesg
ip link
```

For the first OpenWrt test, boot initramfs only. Do not write flash yet.

Things to verify in OpenWrt initramfs:

- `/proc/mtd` partition names match the Linksys dual-firmware assumptions.
- `wan`, `lan1`, `lan2`, `lan3`, and `lan4` appear.
- WAN link works on the single Internet port.
- LAN link works on each of the four LAN ports.
- Both Wi-Fi radios probe without firmware/caldata errors.
- Reset and WPS buttons generate input events.
- USB power and USB activity LED behavior are sane.

Only after that should the `factory.bin` or `sysupgrade.bin` path be tested.

## Known Risk Areas

- The DTS uses stock DTB evidence for the QCN6122 radio as `q6_wcss_pd3`, with stock BDF and M3 dump addresses. This is exactly the sort of thing serial boot logs will confirm or correct.
- QCN6122 caldata is currently mapped like nearby Linksys/IPQ5018 devices at ART offset `0x26800`. If Wi-Fi probes but calibration fails, the alternate likely offset is `0x4c000`.
- USB VBUS appears to be always powered or handled outside the GPIO used by the stock DTB. GPIO17 is treated as the USB LED, not as a regulator.
- The WAN/LAN split is inferred from the stock ESS/QCA8337 bitmap: internal GE PHY for WAN, QCA8337 ports 1-4 for LAN.
