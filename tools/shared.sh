#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root robustly from this file location
_SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVHUB_REPO_ROOT="${ENVHUB_REPO_ROOT:-$(cd "${_SHARED_DIR}/.." && pwd)}"

ENVHUB_BUILDROOT_DIR="${ENVHUB_BUILDROOT_DIR:-${ENVHUB_REPO_ROOT}/buildroot}"

# Your external tree root is external/ (contains external.desc)
ENVHUB_BR2_EXTERNAL="${ENVHUB_BR2_EXTERNAL:-${ENVHUB_REPO_ROOT}/external}"

# Default defconfig
ENVHUB_DEFCONFIG_NAME="${ENVHUB_DEFCONFIG_NAME:-envhub_defconfig}"

# State
ENVHUB_STATE_DIR="${ENVHUB_STATE_DIR:-${ENVHUB_REPO_ROOT}/.envhub}"
ENVHUB_CURRENT_PROFILE_FILE="${ENVHUB_CURRENT_PROFILE_FILE:-${ENVHUB_STATE_DIR}/current_profile}"
ENVHUB_CURRENT_DEFCONFIG_FILE="${ENVHUB_CURRENT_DEFCONFIG_FILE:-${ENVHUB_STATE_DIR}/current_defconfig}"

# Profiles helper (optional but expected in this scheme)
if [[ -f "${ENVHUB_REPO_ROOT}/tools/profiles.sh" ]]; then
  # shellcheck disable=SC1091
  source "${ENVHUB_REPO_ROOT}/tools/profiles.sh"
fi

envhub_get_current_profile() {
  if [[ -f "${ENVHUB_CURRENT_PROFILE_FILE}" ]]; then
    cat "${ENVHUB_CURRENT_PROFILE_FILE}"
  else
    echo "prod"
  fi
}

envhub_set_current_profile_and_defconfig() {
  local profile="$1"
  local defconfig="$2"
  mkdir -p "${ENVHUB_STATE_DIR}"
  echo "${profile}" > "${ENVHUB_CURRENT_PROFILE_FILE}"
  echo "${defconfig}" > "${ENVHUB_CURRENT_DEFCONFIG_FILE}"
}

envhub_resolve_profile_defconfig_outdir() {
  # Input can be: profile (prod/debug/qemu) OR a defconfig filename
  local arg="${1:-}"

  local profile=""
  local defconfig=""
  local outdir=""

  if [[ -n "$arg" ]]; then
    if profile_to_defconfig "$arg" >/dev/null 2>&1; then
      profile="$arg"
      defconfig="$(profile_to_defconfig "$profile")"
      outdir="$(profile_to_outdir "$profile")"
      echo "${profile}|${defconfig}|${outdir}"
      return 0
    else
      # treat as defconfig
      defconfig="$arg"
      if defconfig_to_profile "$defconfig" >/dev/null 2>&1; then
        profile="$(defconfig_to_profile "$defconfig")"
      else
        profile="$(envhub_get_current_profile)"
      fi
      outdir="$(profile_to_outdir "$profile")"
      echo "${profile}|${defconfig}|${outdir}"
      return 0
    fi
  fi

  # No arg: use state
  profile="$(envhub_get_current_profile)"
  defconfig="${ENVHUB_DEFCONFIG_NAME}"
  if [[ -f "${ENVHUB_CURRENT_DEFCONFIG_FILE}" ]]; then
    defconfig="$(cat "${ENVHUB_CURRENT_DEFCONFIG_FILE}")"
  else
    defconfig="$(profile_to_defconfig "$profile" 2>/dev/null || echo "${ENVHUB_DEFCONFIG_NAME}")"
  fi
  outdir="$(profile_to_outdir "$profile")"

  echo "${profile}|${defconfig}|${outdir}"
}