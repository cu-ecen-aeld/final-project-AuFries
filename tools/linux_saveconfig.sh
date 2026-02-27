#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "${1:-}")
O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"

if [[ ! -f "${O_DIR}/.config" ]]; then
  echo "ERROR: No Buildroot .config in ${O_DIR}. Build/load profile first." >&2
  exit 1
fi

if ! grep -q "^BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE=" "${O_DIR}/.config"; then
  echo "ERROR: This profile is not using BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE." >&2
  echo "Set it in Buildroot menuconfig first, then try again." >&2
  exit 1
fi

echo "[envhub] linux-update-defconfig (profile=${profile}, O=${outdir})"
make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" linux-update-defconfig