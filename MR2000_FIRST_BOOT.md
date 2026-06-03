# MR2000 First Boot: Initramfs Only

Build completed on 2026-05-01 with Docker Desktop. Rebuilt once after the first RAM boot to include the MR2000 ath11k board-data files in the initramfs image.

Use this file first:

```text
/Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb
```

Do not flash these yet:

```text
/Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-factory.bin
/Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-sysupgrade.bin
```

The factory and sysupgrade images exist, but this is a first-pass hardware port. Boot the initramfs image from RAM first so flash is untouched.

## Build Outputs

```text
6a2ca521118c102093a6a227050c2086bb94a267b4cfaafea239a1a0b88b6eac  openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb
86832a59eb1631f23cf2ab718a16192eb02f259450a929f78d702b5b5dde8908  openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-factory.bin
1abe96e8f236629bcac2c50bf74b5858d360632a5dfc285609ebb8b3d4661edd  openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-sysupgrade.bin
```

## U-Boot Facts From Serial

- U-Boot command prompt: `IPQ5018#`
- Router U-Boot IP: `192.168.1.1`
- TFTP server IP expected by U-Boot: `192.168.1.10`
- U-Boot load address: `0x44000000`
- U-Boot uses `tftpb` in its built-in flash helpers.

## First RAM Boot Commands

On the Mac, connect Ethernet to a LAN port and set the Mac Ethernet IP to `192.168.1.10/24`.

Prepare the built-in macOS TFTP server:

```sh
sudo mkdir -p /private/tftpboot
sudo cp /Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-initramfs-uImage.itb /private/tftpboot/mr2000-initramfs.itb
sudo chmod 644 /private/tftpboot/mr2000-initramfs.itb
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

In serial, interrupt U-Boot and run:

```text
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.10
setenv bootargs console=ttyMSM0,115200n8
tftpb $loadaddr mr2000-initramfs.itb
bootm $loadaddr
```

If `tftpb` is not accepted, use this instead:

```text
tftpboot $loadaddr mr2000-initramfs.itb
bootm $loadaddr
```

Do not run `saveenv` during the first test.

## What To Capture If It Boots

After OpenWrt reaches a shell, capture:

```sh
dmesg
cat /proc/mtd
ip link
wifi status
logread
```

## RAM Boot Result So Far

`mr2000-serial-idk-2-boot.log` is the best current boot log.

Good signs:

- TFTP loaded `mr2000-initramfs.itb` successfully: `12288700` bytes.
- OpenWrt booted to a root shell on the MR2000.
- The earlier ath11k board-data fetch failures are gone.
- Both Wi-Fi radios now probe and report firmware versions.
- `wifi status` shows `radio0` and `radio1` up, enabled, and not in retry-failed state.
- Enabling the default APs works in RAM: `MR2000-Test-2G` and `MR2000-Test-5G` appear, `iw dev` shows `phy0-ap0` and `phy1-ap0`, and hostapd reports `AP-ENABLED` for both.
- `lan4`, `eth0`, and `br-lan` are up; this matches a cable plugged into LAN4.
- Router-to-Mac LAN ping works from OpenWrt RAM boot to `192.168.1.10`: 3/3 replies, 0% packet loss.
- Moving the cable from LAN4 to LAN1 works: `lan4` goes down, `lan1` links at 1 Gbps full duplex, and `br-lan` forwards through port 1.
- Moving the cable from LAN1 to LAN2 works: `lan1` goes down, `lan2` links at 1 Gbps full duplex, and `br-lan` forwards through port 2.
- Moving the cable from LAN2 to LAN3 works: `lan2` goes down, `lan3` links at 1 Gbps full duplex, and `br-lan` forwards through port 3.
- Moving the cable from LAN3 to WAN works: `lan3` goes down, `wan` links and `ip link` shows `wan` as `UP,LOWER_UP`.
- USB host mode enumerates a connected high-speed device on `xhci-hcd`; `/sys/bus/usb/devices/1-1` reports `PNY USB 3.2.1 FD`.
- `block info` is not present in the initramfs image, so USB block-device mounting was not tested by this capture.
- WPS button did not produce an observed OpenWrt hotplug/log event during this test.
- Reset button triggered OpenWrt shutdown/reboot and returned the router to U-Boot/boot flow. Treat reset as a reboot/reset control, not as a safe diagnostic button, during initramfs testing.

Still expected or not yet meaningful during initramfs testing:

- `wan` shows `NO-CARRIER` if no cable is plugged into the WAN port.
- `/etc/fw_env.config` and NVMEM warnings are not fatal for the RAM boot.
- `mtdsplit: no squashfs found in "rootfs"` is expected while booting initramfs instead of a flashed squashfs image.
- SSDK `incorrect port 0` messages need watching, but LAN4 is still working.

Next small capture batch:

No more button tests are needed for the initial RAM bring-up.

Then test, in this order:

- WAN port link appears.
- LAN ports `lan1` through `lan4` appear.
- Both radios probe without firmware/caldata errors.
- Reset and WPS buttons generate events.
- USB and LEDs behave reasonably.

Flash testing can now be considered, but only by serial/U-Boot into the inactive primary slot first. Use:

```text
/Users/endless/Desktop/OpenWRT-For-My-MR2000/MR2000_FLASH_TEST.md
```
