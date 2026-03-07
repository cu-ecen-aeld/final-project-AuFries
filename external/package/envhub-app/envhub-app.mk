################################################################################
# envhub-app
################################################################################

ENVHUB_APP_VERSION = c44924a4999b67ef19fd796f7929a29535ee9fd1
ENVHUB_APP_SITE = https://github.com/AuFries/envhub-app.git
ENVHUB_APP_SITE_METHOD = git

ENVHUB_APP_DEPENDENCIES = lvgl-graphics libdrm

$(eval $(cmake-package))