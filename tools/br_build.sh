#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

# Optional override: prod|debug|qemu|defconfig
IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "${1:-}")

O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"
DEFCONFIG_PATH="${ENVHUB_BR2_EXTERNAL}/configs/${defconfig}"

# Submodule upkeep (if buildroot is a submodule)
if [[ -d .git ]] && git submodule status buildroot >/dev/null 2>&1; then
  git submodule sync -- buildroot
  git submodule update --init --recursive -- buildroot
fi

if [[ ! -d "${ENVHUB_BUILDROOT_DIR}" ]]; then
  echo "ERROR: Buildroot directory not found: ${ENVHUB_BUILDROOT_DIR}" >&2
  exit 1
fi
if [[ ! -f "$DEFCONFIG_PATH" ]]; then
  echo "ERROR: defconfig not found: $DEFCONFIG_PATH" >&2
  exit 1
fi

# If no .config for this output dir, load it
if [[ ! -f "${O_DIR}/.config" ]]; then
  echo "[envhub] No .config in ${outdir}; loading ${defconfig}"
  make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" BR2_EXTERNAL="${ENVHUB_BR2_EXTERNAL}" "${defconfig}"
fi

# Record active
envhub_set_current_profile_and_defconfig "$profile" "$defconfig"

echo "[envhub] Building (profile=${profile}, O=${outdir})"
make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" BR2_EXTERNAL="${ENVHUB_BR2_EXTERNAL}"
echo "[envhub] Build complete"