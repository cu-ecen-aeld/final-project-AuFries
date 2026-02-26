#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

# Determine target: arg > current_defconfig > default
target="${1:-}"
if [[ -z "$target" && -f "${ENVHUB_CURRENT_DEFCONFIG_FILE}" ]]; then
  target="$(cat "${ENVHUB_CURRENT_DEFCONFIG_FILE}")"
fi
target="${target:-${ENVHUB_DEFCONFIG_NAME}}"

IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "$target")

O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"
mkdir -p "${ENVHUB_BR2_EXTERNAL}/configs"

OUT_DEFCONFIG="${ENVHUB_BR2_EXTERNAL}/configs/${defconfig}"

if [[ ! -f "${O_DIR}/.config" ]]; then
  echo "ERROR: No .config found in ${O_DIR}." >&2
  echo "Fix: load/build that profile first:" >&2
  echo "  make use DEV_MODE=${profile} && make menuconfig" >&2
  exit 1
fi

echo "[envhub] Saving defconfig -> ${OUT_DEFCONFIG} (from O=${outdir})"
make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" savedefconfig BR2_DEFCONFIG="${OUT_DEFCONFIG}"

# Record as active
envhub_set_current_profile_and_defconfig "$profile" "$defconfig"

# Optional: Linux kernel defconfig update (only if configured)
if grep -q "^BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE=" "${O_DIR}/.config" 2>/dev/null; then
  echo "[envhub] Saving Linux kernel defconfig (linux-update-defconfig)"
  make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" linux-update-defconfig
fi