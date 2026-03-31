# Partition Layout — X88 Pro RK3566

Comparison of the stock Android 11 partition layout versus the Android 16 build.

---

## Physical Partition Table (eMMC — unchanged across both OSes)

The physical partition table on `mmcblk2` is identical between Android 11 and Android 16.
We keep the stock layout — only the content of partitions changes, not their positions or sizes.

| # | Partition | Size | Notes |
|---|---|---|---|
| p1 | `uboot` | 4 MB | Rockchip U-Boot bootloader — **NOT flashed** (kept stock) |
| p2 | `trust` | 4 MB | ARM TrustZone / OP-TEE firmware — **NOT flashed** (kept stock) |
| p3 | `misc` | 4 MB | BCB (Boot Control Block), used by recovery |
| p4 | `dtbo` | 4 MB | Device tree blob overlays |
| p5 | `vbmeta` | 1 MB | Android Verified Boot (AVB) metadata |
| p6 | `boot` | 64 MB | Kernel + ramdisk (generic_ramdisk) |
| p7 | `recovery` | 96 MB | Recovery OS |
| p8 | `baseparameter` | 1 MB | Rockchip display calibration parameters |
| p9 | `super` | 3.1 GB | Dynamic partition container (see below) |
| p10 | `userdata` | ~111 GB | User data (formatted on first boot) |

> Source: Phase 1 `gdisk` extraction from stock device.
> Physical partition table is on the eMMC at `/dev/mmcblk2`.

---

## Super Partition Layout

The `super` partition is a dynamic partition container managed by `lpmake` / Android's
logical partition system. Its internal layout differs significantly between Android 11 and 16.

### Android 11 (Stock — RK3566 BSP)

Android 11 on Rockchip BSP uses dynamic partitions but with a different internal structure.
The stock super.img (3.1 GB raw dump from Phase 1) contains:

| Logical Partition | Approx. Size | Notes |
|---|---|---|
| `system` | ~1.8 GB | Full system (A11 framework + preinstalled apps) |
| `vendor` | ~500 MB | Rockchip vendor blobs |
| `product` | ~400 MB | Product-specific apps |

> Note: Exact Android 11 logical partition sizes can be inspected with:
> ```bash
> simg2img backup/super.img /tmp/super_raw.img
> lpunpack /tmp/super_raw.img /tmp/super_extracted/
> ```

### Android 16 (Our Build)

Android 16 uses a 5-partition dynamic layout. Sizes are from the actual built images.

| Logical Partition | Partition Size (BoardConfig) | Actual Built Size | Filesystem | Notes |
|---|---|---|---|---|
| `system` | 1232 MB (limit) | 1.2 GB | ext4 | AOSP framework + core apps |
| `vendor` | 493 MB (limit) | 94 MB | ext4 | Rockchip HAL blobs |
| `product` | 750 MB (limit) | 284 MB | ext4 | Product-specific apps |
| `system_ext` | 50 MB (limit) | ~1 MB | ext4 | System extensions |
| `odm` | 4 MB (limit) | 889 KB | ext4 | ODM layer (SELinux policy) |
| **super total** | **3.1 GB** | **~1.5 GB used** | — | Container: `rockchip_dynamic_partitions` group |

**Key differences from Android 11:**
- `system` is significantly smaller (1.2 GB vs 1.8 GB) — AOSP base without bloat
- `vendor` is dramatically smaller (94 MB vs 500 MB) — only required blobs
- `odm` is a new separate partition (Android 11 BSP merged ODM into vendor)
- `system_ext` is a new partition (Android 12+ split from system)
- Overall super utilization: ~1.5 GB of 3.1 GB (vs ~2.7 GB in stock Android 11)

---

## Partition Size Configuration (Android 16)

Set in `device/rockchip/x88pro/BoardConfig.mk`:

```makefile
# Physical super partition (matches hardware)
BOARD_SUPER_PARTITION_SIZE             := 3263168512  # 3.1 GB

# Dynamic partition group containing all logical partitions
BOARD_SUPER_PARTITION_GROUPS           := rockchip_dynamic_partitions
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_SIZE := 3258974208  # max group size (~3.1 GB)
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext vendor product odm

# Per-partition limits (upper bounds, actual images are smaller)
BOARD_SYSTEMIMAGE_PARTITION_SIZE       := 1291911168  # 1232 MB
BOARD_VENDORIMAGE_PARTITION_SIZE       := 515899392   # 493 MB
BOARD_PRODUCTIMAGE_PARTITION_SIZE      := 795017216   # 750 MB
BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE   := 52592640    # 50 MB
BOARD_ODMIMAGE_PARTITION_SIZE          := 4194304     # 4 MB

# Fixed-size physical partitions
BOARD_BOOTIMAGE_PARTITION_SIZE         := 67108864    # 64 MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE     := 100663296   # 96 MB
```

> The system partition size was increased from 1104 MB to 1232 MB during Phase 4
> bring-up (Issue 16 in BUILD_TROUBLESHOOTING.md) — A16 AOSP content is ~1128 MB.

---

## What We Flash vs What We Keep

| Partition | Action | Reason |
|---|---|---|
| `uboot` | **Keep stock** | Avoid brick risk; Rockchip loader works fine |
| `trust` | **Keep stock** | TrustZone firmware; no A16 replacement |
| `misc` | **Keep stock** | Not needed to change |
| `dtbo` | **Flash new** | Built from BSP kernel `rk3566-box-demo-v10.dtb` |
| `vbmeta` | **Flash new** | Must match boot/dtbo/super content |
| `boot` | **Flash new** | BSP kernel 5.10 + A16 ramdisk |
| `recovery` | **Flash new** | A16 recovery |
| `baseparameter` | **Keep stock** | Rockchip display calibration |
| `super` | **Flash new** | A16 system/vendor/product/odm |
| `userdata` | **Wiped on first boot** | A16 formats on first launch |
