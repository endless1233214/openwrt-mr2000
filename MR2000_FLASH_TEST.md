# MR2000 Controlled First Flash Test

Status: ready for a controlled serial/U-Boot flash test to the inactive primary slot.

Do not use the web UI for this first flash. Do not use `sysupgrade.bin` from U-Boot.

## First Flash Attempt Result

The first controlled flash to slot 1 partially succeeded:

- TFTP transferred the expected factory image size: `17434624 (10a0800 hex)`.
- `nand erase $prikern $imgsize` completed successfully.
- `nand write $loadaddr $prikern $filesize` wrote `17434624 bytes` successfully.
- `run bootpart1` loaded the OpenWrt FIT kernel from NAND and passed hash verification.
- Linux booted and identified `Machine model: Linksys MR2000`.
- UBI attached `mtd13` / `rootfs` cleanly with `bad PEBs: 0`.

The flashed boot did not reach userspace:

```text
Waiting for root device /dev/ubiblock0_0...
```

This means the first flash image/rootfs boot path needs fixing before OpenWrt can be considered installable.

After power cycling, U-Boot still reported the saved stock slot:

```text
enabled:yes, boot_part:2, boot_part_ready:3
```

But `bootpart2` did not boot stock:

```text
NAND read: device 0 offset 0x58c0000, size 0x800000
8388608 bytes read: OK
Wrong Image Format for bootm command
ERROR: can't get kernel image!
```

The `altkern` header was inspected:

```text
nand read $loadaddr $altkern 100
md.b $loadaddr 40
44000000: 55 42 49 23 ...
```

`55 42 49 23` is `UBI#`, not the FIT image magic `d0 0d fe ed`. This explains why U-Boot cannot boot `bootpart2`.

Do not erase or write anything else until the router is RAM-booted again and the flash layout/image recipe is fixed or a stock slot restore is prepared.

The router was successfully RAM-booted again after this using `mr2000-initramfs.itb`, and OpenWrt reached the console. Recovery access is still available through serial/TFTP/initramfs.

## Why This Is The Safer First Flash

- Stock is currently configured to boot slot 2: `boot_part=2`.
- Slot 2 starts at `altkern=0x58c0000` and is the known-good stock slot.
- The first flash test writes slot 1 only, starting at `prikern=0x6c0000`.
- Do not run `saveenv`; if the test boot fails, power cycle and the saved stock environment should return to slot 2.

## Image To Flash

Use:

```text
/Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-factory.bin
```

Expected SHA256:

```text
86832a59eb1631f23cf2ab718a16192eb02f259450a929f78d702b5b5dde8908
```

Expected TFTP size:

```text
17434624 bytes / 0x10a0800
```

This fits inside the slot size:

```text
0x5200000
```

## Mac TFTP Prep

Run on the Mac:

```sh
sudo cp /Users/endless/Desktop/OpenWRT-For-My-MR2000/build-output/openwrt-qualcommax-ipq50xx-linksys_mr2000-squashfs-factory.bin /private/tftpboot/mr2000-factory.bin
sudo chmod 644 /private/tftpboot/mr2000-factory.bin
shasum -a 256 /private/tftpboot/mr2000-factory.bin
```

## U-Boot Commands

At `IPQ5018#`, run:

```text
printenv boot_part boot_part_ready prikern altkern imgsize kernsize
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.10
tftpb $loadaddr mr2000-factory.bin
```

Stop and do not erase anything unless TFTP reports:

```text
Bytes transferred = 17434624 (10a0800 hex)
```

If the size matches exactly, continue:

```text
nand erase $prikern $imgsize
nand write $loadaddr $prikern $filesize
setenv boot_part 1
run bootpart1
```

Do not run:

```text
saveenv
flashimg2
nand erase $altkern $imgsize
nand write $loadaddr $altkern $filesize
```

## If It Fails

Power cycle the router and let it boot without interrupting U-Boot. Because `saveenv` was not used, the saved stock environment should still prefer `boot_part=2`.

## If It Boots

Capture:

```sh
cat /proc/mtd
ubus call system board
mount
df -h
ip link
wifi status
logread | grep -iE 'ubi|mtd|rootfs|overlay|ath11k|error|failed'
```
