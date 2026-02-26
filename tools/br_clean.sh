#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

MODE="${1:-clean}"
PROFILE_OR_DEFCONFIG="${2:-}"

# If first arg is actually a profile and not a mode, treat it as profile
case "$MODE" in
  clean|dirclean|distclean) ;;
  *)
    PROFILE_OR_DEFCONFIG="$MODE"
    MODE="clean"
    ;;
esac

IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "${PROFILE_OR_DEFCONFIG}")

O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"

echo "[envhub] Clean mode=${MODE} (profile=${profile}, O=${outdir})"
make -C "${ENVHUB_BUILDROOT_DIR}" O="${O_DIR}" "${MODE}"