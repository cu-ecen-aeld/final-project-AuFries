#!/usr/bin/env bash
set -euo pipefail

# Deploy kernel+DTB to TFTP dir and rootfs to NFS dir (no SD touching).
#
# Usage:
#   sudo ./tools/deploy_netboot.sh
#
# Behavior:
#   - If OUTDIR is not set, auto-select based on .envhub/current_profile (default: prod)
#     prod  -> buildroot/output-prod
#     debug -> buildroot/output-debug
#     qemu  -> buildroot/output-qemu
#
# Optional env overrides:
#   OUTDIR=buildroot/output-debug
#   TFTP_DIR=/srv/tftp
#   NFS_DIR=/srv/nfs/bbb
#   TFTP_KERNEL_NAME=zImage            # destination name in TFTP
#   TFTP_DTB_NAME=am335x-boneblack.dtb # destination name in TFTP
#   KERNEL_SRC=auto|zImage|Image       # which kernel file to deploy (auto detects)
#   DTB_SRC=auto|am335x-boneblack.dtb  # which dtb to deploy (auto detects)
#   ROOTFS_MODE=rsync|tar              # rsync uses OUTDIR/target, tar uses OUTDIR/images/rootfs.tar
#   APPLY_NETWORK_GUARD=1|0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TFTP_DIR="${TFTP_DIR:-/srv/tftp}"
NFS_DIR="${NFS_DIR:-/srv/nfs/bbb}"

TFTP_KERNEL_NAME="${TFTP_KERNEL_NAME:-zImage}"
TFTP_DTB_NAME="${TFTP_DTB_NAME:-am335x-boneblack.dtb}"

KERNEL_SRC="${KERNEL_SRC:-auto}"  # auto | zImage | Image
DTB_SRC="${DTB_SRC:-auto}"        # auto | <dtb filename>

ROOTFS_MODE="${ROOTFS_MODE:-rsync}"  # rsync | tar
APPLY_NETWORK_GUARD="${APPLY_NETWORK_GUARD:-1}"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root (sudo)." >&2
    exit 1
  fi
}

read_current_profile() {
  local pfile="${REPO_ROOT}/.envhub/current_profile"
  if [[ -f "${pfile}" ]]; then
    cat "${pfile}"
  else
    echo "prod"
  fi
}

default_outdir_from_profile() {
  local profile="$1"
  case "${profile}" in
    prod|production) echo "${REPO_ROOT}/buildroot/output-prod" ;;
    debug|dev)       echo "${REPO_ROOT}/buildroot/output-debug" ;;
    qemu)            echo "${REPO_ROOT}/buildroot/output-qemu" ;;
    *)               echo "${REPO_ROOT}/buildroot/output-prod" ;;
  esac
}

resolve_outdir() {
  if [[ -n "${OUTDIR:-}" ]]; then
    # Allow relative OUTDIR (relative to repo root)
    if [[ "${OUTDIR}" = /* ]]; then
      echo "${OUTDIR}"
    else
      echo "${REPO_ROOT}/${OUTDIR}"
    fi
    return
  fi
  local profile
  profile="$(read_current_profile)"
  default_outdir_from_profile "${profile}"
}

pick_kernel_file() {
  local outdir="$1"

  case "${KERNEL_SRC}" in
    zImage|Image)
      echo "${outdir}/images/${KERNEL_SRC}"
      return
      ;;
    auto)
      if [[ -f "${outdir}/images/zImage" ]]; then
        echo "${outdir}/images/zImage"
      elif [[ -f "${outdir}/images/Image" ]]; then
        echo "${outdir}/images/Image"
      else
        echo ""
      fi
      return
      ;;
    *)
      echo "ERROR: KERNEL_SRC must be auto|zImage|Image (got ${KERNEL_SRC})" >&2
      exit 1
      ;;
  esac
}

pick_dtb_file() {
  local outdir="$1"

  if [[ "${DTB_SRC}" != "auto" ]]; then
    echo "${outdir}/images/${DTB_SRC}"
    return
  fi

  # Prefer the canonical BBB dtb
  if [[ -f "${outdir}/images/am335x-boneblack.dtb" ]]; then
    echo "${outdir}/images/am335x-boneblack.dtb"
    return
  fi

  # Fall back to "any am335x-*.dtb" if present
  local any
  any="$(ls "${outdir}/images"/am335x-*.dtb 2>/dev/null | head -n 1 || true)"
  echo "${any}"
}

ensure_paths() {
  [[ -d "${OUTDIR_RESOLVED}" ]] || { echo "ERROR: OUTDIR not found: ${OUTDIR_RESOLVED}" >&2; exit 1; }
  [[ -d "${TFTP_DIR}" ]]        || { echo "ERROR: TFTP_DIR not found: ${TFTP_DIR}" >&2; exit 1; }
  [[ -d "${NFS_DIR}" ]]         || { echo "ERROR: NFS_DIR not found: ${NFS_DIR}" >&2; exit 1; }
}

deploy_tftp() {
  local kernel_path="$1"
  local dtb_path="$2"

  [[ -f "${kernel_path}" ]] || { echo "ERROR: Kernel image not found: ${kernel_path}" >&2; exit 1; }
  [[ -f "${dtb_path}" ]]    || { echo "ERROR: DTB not found: ${dtb_path}" >&2; exit 1; }

  echo "[*] Deploying kernel -> ${TFTP_DIR}/${TFTP_KERNEL_NAME}"
  cp -f "${kernel_path}" "${TFTP_DIR}/${TFTP_KERNEL_NAME}"

  echo "[*] Deploying dtb    -> ${TFTP_DIR}/${TFTP_DTB_NAME}"
  cp -f "${dtb_path}" "${TFTP_DIR}/${TFTP_DTB_NAME}"

  sync
}

deploy_nfs_rootfs() {
  echo "[*] Deploying rootfs to NFS (${NFS_DIR}) using mode: ${ROOTFS_MODE}"
  case "${ROOTFS_MODE}" in
    rsync)
      [[ -d "${OUTDIR_RESOLVED}/target" ]] || { echo "ERROR: Missing target dir: ${OUTDIR_RESOLVED}/target" >&2; exit 1; }
      rsync -aHAX --delete "${OUTDIR_RESOLVED}/target/" "${NFS_DIR}/"
      ;;
    tar)
      [[ -f "${OUTDIR_RESOLVED}/images/rootfs.tar" ]] || { echo "ERROR: Missing rootfs.tar: ${OUTDIR_RESOLVED}/images/rootfs.tar" >&2; exit 1; }
      rm -rf "${NFS_DIR:?}/"*
      tar -xpf "${OUTDIR_RESOLVED}/images/rootfs.tar" -C "${NFS_DIR}"
      ;;
    *)
      echo "ERROR: Unknown ROOTFS_MODE=${ROOTFS_MODE} (use rsync or tar)" >&2
      exit 1
      ;;
  esac
  sync
}

apply_network_guard_patch() {
  [[ "${APPLY_NETWORK_GUARD}" == "1" ]] || return 0

  local script="${NFS_DIR}/etc/init.d/S40network"
  if [[ ! -f "${script}" ]]; then
    echo "[i] No ${script} found; skipping network guard."
    return 0
  fi
  if grep -q "OK (already configured)" "${script}"; then
    echo "[i] Network guard already present in ${script}"
    return 0
  fi

  echo "[*] Applying network guard to ${script}"
  sed -i '/^\s*start)\s*$/a\
\t# If we netbooted with ip=... the kernel already configured eth0.\
\t# Avoid ifupdown fighting existing addresses/routes ("File exists").\
\tif ip -4 addr show dev eth0 2>/dev/null | grep -q "inet "; then\
\t\techo "Starting network: OK (already configured)"\
\t\texit 0\
\tfi\
' "${script}"
  sync
}

main() {
  need_root

  OUTDIR_RESOLVED="$(resolve_outdir)"
  ensure_paths

  local kernel_path dtb_path
  kernel_path="$(pick_kernel_file "${OUTDIR_RESOLVED}")"
  dtb_path="$(pick_dtb_file "${OUTDIR_RESOLVED}")"

  if [[ -z "${kernel_path}" ]]; then
    echo "ERROR: Could not find kernel image in ${OUTDIR_RESOLVED}/images (expected zImage or Image)." >&2
    exit 1
  fi
  if [[ -z "${dtb_path}" ]]; then
    echo "ERROR: Could not find an am335x DTB in ${OUTDIR_RESOLVED}/images." >&2
    echo "       Set DTB_SRC=<file.dtb> to select explicitly." >&2
    exit 1
  fi

  echo "[*] Using OUTDIR: ${OUTDIR_RESOLVED}"
  echo "[*] Kernel src:   ${kernel_path}"
  echo "[*] DTB src:      ${dtb_path}"

  deploy_tftp "${kernel_path}" "${dtb_path}"
  deploy_nfs_rootfs
  apply_network_guard_patch

  echo
  echo "[OK] Netboot deploy complete."
  echo "     TFTP: ${TFTP_DIR}/${TFTP_KERNEL_NAME} and ${TFTP_DIR}/${TFTP_DTB_NAME}"
  echo "     NFS:  ${NFS_DIR} updated via ${ROOTFS_MODE}"
  echo "Reboot the BBB to pick up changes."
}

main "$@"