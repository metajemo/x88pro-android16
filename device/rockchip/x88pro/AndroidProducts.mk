# AndroidProducts.mk - X88 Pro Android TV Box
#
# Declares the X88 Pro as a buildable AOSP product.
# Referenced by the build system when running:
#   lunch aosp_x88pro-bp2a-eng
#
# Board: X88PRO-RK3566-4D32-V1.0
# SoC:   Rockchip RK3566

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/device.mk

COMMON_LUNCH_CHOICES := \
    aosp_x88pro-bp2a-eng \
    aosp_x88pro-bp2a-userdebug
