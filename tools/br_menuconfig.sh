#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "${1:-}")

O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"
DEFCONFIG_PATH="${ENVHUB_BR2_EXTERNAL}/configs/${defconfig}"

if [[ ! -d "${ENVHUB_BUILDROOT_DIR}" ]]; then
  echo "ERROR: Buildroot directory not found: ${ENVHUB_BUILDROOT_DIR}" >&2
  exit 1
fi
if [[ ! -f "$DEFCONFIG_PATH" ]]; then
  echo "ERROR: defconfig not found: $DEFCONFIG_PATH" >&2
  exit 1
fi

# If this output dir has no .config yet, load the defconfig for it
if [[ ! -f "${O_DIR}/.config" ]]; then
  echo "[envhub] No .config in ${outdir}; loading ${defconfig}"
  make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" BR2_EXTERNAL="${ENVHUB_BR2_EXTERNAL}" "${defconfig}"
fi

echo "[envhub] menuconfig (profile=${profile}, O=${outdir})"
make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" BR2_EXTERNAL="${ENVHUB_BR2_EXTERNAL}" menuconfig