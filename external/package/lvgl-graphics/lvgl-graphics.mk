################################################################################
# lvgl-graphics
################################################################################

LVGL_GRAPHICS_VERSION = 85aa60d18b3d5e5588d7b247abf90198f07c8a63
LVGL_GRAPHICS_SITE = https://github.com/lvgl/lvgl.git
LVGL_GRAPHICS_SITE_METHOD = git

LVGL_GRAPHICS_INSTALL_STAGING = YES
LVGL_GRAPHICS_DEPENDENCIES = libdrm

LVGL_GRAPHICS_CONF_OPTS = \
	-DBUILD_SHARED_LIBS=OFF \
	-DCONFIG_LV_BUILD_EXAMPLES=OFF \
	-DCONFIG_LV_BUILD_DEMOS=OFF \
	-DLV_BUILD_CONF_DIR=$(@D) \
	-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include/libdrm" \
	-DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -I$(STAGING_DIR)/usr/include/libdrm"

define LVGL_GRAPHICS_PRE_CONFIGURE_HOOK
	cp $(LVGL_GRAPHICS_PKGDIR)/lv_conf.h $(@D)/lv_conf.h
endef
LVGL_GRAPHICS_PRE_CONFIGURE_HOOKS += LVGL_GRAPHICS_PRE_CONFIGURE_HOOK

define LVGL_GRAPHICS_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(BR2_CMAKE) --install $(@D) --prefix $(STAGING_DIR)/usr
	$(INSTALL) -D -m 0644 $(LVGL_GRAPHICS_PKGDIR)/lv_conf.h \
		$(STAGING_DIR)/usr/include/lvgl/lv_conf.h
endef

define LVGL_GRAPHICS_INSTALL_TARGET_CMDS
	true
endef

$(eval $(cmake-package))