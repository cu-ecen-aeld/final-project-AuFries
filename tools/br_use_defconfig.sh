#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

arg="${1:-}"

usage() {
  cat <<EOF
Usage:
  ./envhub br:use <prod|debug|qemu|defconfig_name>
  ./envhub br:use --list

Effects:
  - Sets active profile/defconfig in .envhub/
  - Uses separate output dirs per profile (buildroot/output-*)

EOF
}

if [[ -z "$arg" || "$arg" == "-h" || "$arg" == "--help" ]]; then
  usage; exit 0
fi

if [[ "$arg" == "--list" ]]; then
  echo "Profiles:"
  echo "  prod  -> envhub_defconfig      (O=output-prod)"
  echo "  debug -> envhub_dev_defconfig  (O=output-debug)"
  echo "  qemu  -> envhub_qemu_defconfig (O=output-qemu)"
  echo
  echo "Defconfigs in ${ENVHUB_BR2_EXTERNAL}/configs:"
  ls -1 "${ENVHUB_BR2_EXTERNAL}/configs" 2>/dev/null || true
  exit 0
fi

IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "$arg")

# Validate filename
if [[ "$defconfig" == /* || "$defconfig" == *"/"* || "$defconfig" == "." || "$defconfig" == ".." ]]; then
  echo "ERROR: defconfig must be a simple filename, not '$defconfig'" >&2
  exit 2
fi

DEFCONFIG_PATH="${ENVHUB_BR2_EXTERNAL}/configs/${defconfig}"
if [[ ! -f "$DEFCONFIG_PATH" ]]; then
  echo "ERROR: defconfig not found: $DEFCONFIG_PATH" >&2
  exit 1
fi

envhub_set_current_profile_and_defconfig "$profile" "$defconfig"

echo "[envhub] Active profile:  ${profile}"
echo "[envhub] Active defconfig: ${defconfig}"
echo "[envhub] Output dir:      ${ENVHUB_BUILDROOT_DIR}/${outdir}"