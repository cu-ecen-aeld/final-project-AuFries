.PHONY: menuconfig saveconfig use build clean qemu qemu-build deploy

DEV_MODE ?= prod
CLEAN_MODE ?= clean

menuconfig:
	./envhub br:menuconfig

saveconfig:
	./envhub br:save-defconfig

use:
	./envhub br:use $(DEV_MODE)

build:
	./envhub br:build

clean:
	./envhub br:clean $(CLEAN_MODE)

qemu:
	./envhub qemu

qemu-build:
	./envhub br:use qemu
	./envhub br:build qemu

deploy:
	sudo ./tools/deploy_netboot.sh

.PHONY: current

current:
	@echo "Repo: $$(pwd)"
	@echo -n "Active profile: "
	@if [ -f .envhub/current_profile ]; then cat .envhub/current_profile; else echo "(none -> prod)"; fi
	@echo -n "Active defconfig: "
	@if [ -f .envhub/current_defconfig ]; then cat .envhub/current_defconfig; else echo "(none -> envhub_defconfig)"; fi

	@profile="$$( [ -f .envhub/current_profile ] && cat .envhub/current_profile || echo prod )"; \
	case "$$profile" in \
	  prod|production) outdir="output-prod"; defcfg="envhub_defconfig" ;; \
	  debug|dev)       outdir="output-debug"; defcfg="envhub_dev_defconfig" ;; \
	  qemu)            outdir="output-qemu"; defcfg="envhub_qemu_defconfig" ;; \
	  *)               outdir="output-prod"; defcfg="envhub_defconfig" ;; \
	esac; \
	if [ -f .envhub/current_defconfig ]; then defcfg="$$(cat .envhub/current_defconfig)"; fi; \
	echo "Output dir: buildroot/$$outdir"; \
	echo -n "Config present: "; \
	if [ -f "buildroot/$$outdir/.config" ]; then echo "yes"; else echo "no"; fi; \
	echo -n "External defconfig file: "; \
	if [ -f "external/configs/$$defcfg" ]; then echo "external/configs/$$defcfg (exists)"; else echo "external/configs/$$defcfg (MISSING)"; fi; \
	echo -n "Images present: "; \
	if [ -d "buildroot/$$outdir/images" ] && ls "buildroot/$$outdir/images" >/dev/null 2>&1; then echo "yes"; else echo "no"; fi; \
	if [ -f "buildroot/$$outdir/images/Image" ]; then echo "  kernel: buildroot/$$outdir/images/Image"; fi; \
	if [ -f "buildroot/$$outdir/images/rootfs.ext4" ]; then echo "  rootfs: buildroot/$$outdir/images/rootfs.ext4"; fi