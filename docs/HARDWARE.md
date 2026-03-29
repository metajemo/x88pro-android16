# X88 Pro Hardware Documentation

Detailed hardware information extracted from the device in Phase 1.

## Board

| Property | Value |
|---|---|
| Board name | X88PRO-RK3566-4D32-V1.0 |
| Board date | 2021-03-26 |
| Manufacturer | Unknown (generic Chinese TV box manufacturer) |

## SoC — Rockchip RK3566

| Property | Value |
|---|---|
| CPU | 4x ARM Cortex-A55 @ up to 1.8GHz |
| CPU Architecture | ARMv8-A (64-bit) |
| CPU part | 0xd05 (Cortex-A55) |
| CPU implementer | 0x41 (ARM) |
| GPU | ARM Mali-G52 2EE |
| NPU | 0.8 TOPS Neural Processing Unit |
| VPU | Rockchip RK VPU (hardware video decode/encode) |
| Process node | 22nm |

## Memory & Storage

| Component | Details |
|---|---|
| RAM | 8GB LPDDR4 (reported as ~7.5GB usable) |
| Storage | 128GB eMMC (mmcblk2) |
| eMMC bus | /dev/block/mmcblk2 |

## Connectivity

| Component | Chip | Notes |
|---|---|---|
| Ethernet | RTL8211 (M3295NL PHY) | Gigabit |
| WiFi/BT | AMPAK AP6398S (Broadcom BCM43598) | WiFi 5 + BT 5.0, driver: bcmdhd |
| USB | 3x USB-A + 1x USB-C OTG | Multiple USB controllers |

## Video Output

| Property | Value |
|---|---|
| HDMI | HDMI 2.0 @ fe0a0000 |
| Display subsystem | Rockchip VOP2 |

## Partition Layout

Extracted from `/dev/block/by-name/` and `df` output.

| Partition | Block device | Size | Mount point | Purpose |
|---|---|---|---|---|
| uboot | mmcblk2p1 | 4MB | - | U-Boot bootloader |
| trust | mmcblk2p2 | 4MB | - | ARM TrustZone firmware |
| misc | mmcblk2p3 | - | - | Bootloader flags |
| dtbo | mmcblk2p4 | 4MB | - | Device tree overlays |
| vbmeta | mmcblk2p5 | 1MB | - | Verified boot metadata |
| boot | mmcblk2p6 | 64MB | - | Kernel + ramdisk |
| security | mmcblk2p7 | - | - | Security keys |
| recovery | mmcblk2p8 | 96MB | - | Recovery OS |
| backup | mmcblk2p9 | - | - | Factory backup |
| cache | mmcblk2p10 | 356MB | /cache | System cache |
| metadata | mmcblk2p11 | 11MB | /metadata | Dynamic partition metadata |
| baseparameter | mmcblk2p12 | 1MB | - | Rockchip display params |
| logo | mmcblk2p13 | - | - | Boot logo image |
| super | mmcblk2p14 | ~3.1GB | - | Dynamic partitions |
| userdata | mmcblk2p15 | ~111GB | /data | User data |

### Dynamic Partitions (inside super)

| Logical partition | Block device | Size | Mount point |
|---|---|---|---|
| system | dm-0 | 1.0GB | / |
| system_ext | dm-1 | 50MB | /system_ext |
| vendor | dm-2 | 492MB | /vendor |
| product | dm-3 | 758MB | /product |
| odm | dm-4 | 588KB | /odm |

## Stock Firmware

| Property | Value |
|---|---|
| Android version | 11 |
| SDK level | 30 |
| Kernel | 4.19.172 |
| Kernel build | #160 SMP PREEMPT Wed Jul 13 15:40:46 CST 2022 |
| Build fingerprint | rockchip/rk356x_box/rk356x_box:11/RQ2A.210505.003/...:userdebug/release-keys |
| Build type | userdebug (allows `adb root`) |

## Device Tree Highlights

Key hardware nodes from `/proc/device-tree/` (3977 files total):

| Node | Address | Hardware |
|---|---|---|
| ethernet | fe010000 | Gigabit Ethernet |
| hdmi | fe0a0000 | HDMI 2.0 output |
| gpu | fde60000 | Mali-G52 GPU |
| npu | fde40000 | Neural Processing Unit |
| rkvdec | fdf80200 | Video decoder (H.264/H.265/VP9) |
| rkvenc | fdf40000 | Video encoder |
| rkcif | fdfe0000 | Camera interface |
| usb | fd800000 | USB 3.0 OTG |
| usbhost | fd840000+ | USB host controllers |
| dwmmc | fe000000 | eMMC controller |
| i2c | fe5a0000+ | I2C buses |
| spi | fe610000+ | SPI buses |
| serial | fe650000+ | UART serial ports |
| saradc | fe720000 | ADC (buttons) |
| wireless-wlan | - | WiFi |
| wireless-bluetooth | - | Bluetooth |
