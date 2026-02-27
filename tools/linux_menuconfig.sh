#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

# Optional arg: prod|debug|qemu|defconfig (defaults to active profile)
IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "${1:-}")

O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"

if [[ ! -d "${ENVHUB_BUILDROOT_DIR}" ]]; then
  echo "ERROR: Buildroot directory not found: ${ENVHUB_BUILDROOT_DIR}" >&2
  exit 1
fi

# Make sure this profile has a buildroot .config in its output dir
if [[ ! -f "${O_DIR}/.config" ]]; then
  echo "[envhub] No Buildroot .config in ${outdir}; run one of:"
  echo "  make use DEV_MODE=${profile} && make menuconfig"
  echo "  make build (will autoload the defconfig)"
  exit 1
fi

echo "[envhub] linux-menuconfig (profile=${profile}, O=${outdir})"
make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" linux-menuconfig