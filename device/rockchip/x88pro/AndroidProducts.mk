# AndroidProducts.mk - X88 Pro Android TV Box
#
# Board: X88PRO-RK3566-4D32-V1.0
# SoC:   Rockchip RK3566

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/aosp_x88pro.mk

COMMON_LUNCH_CHOICES := \
    aosp_x88pro-bp2a-eng \
    aosp_x88pro-bp2a-userdebug
