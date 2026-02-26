#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source tools/shared.sh

# Always run from the qemu profile output by default
IFS="|" read -r profile defconfig outdir < <(envhub_resolve_profile_defconfig_outdir "${1:-qemu}")
O_DIR="${ENVHUB_BUILDROOT_DIR}/${outdir}"
IMAGES_DIR="${O_DIR}/images"

KERNEL_IMG="${IMAGES_DIR}/Image"
ROOTFS_IMG="${IMAGES_DIR}/rootfs.ext4"

HOST_SSH_PORT="${HOST_SSH_PORT:-10022}"
MEM="${QEMU_MEM:-512M}"
SMP="${QEMU_SMP:-1}"
CPU="${QEMU_CPU:-cortex-a53}"

if [[ ! -f "$KERNEL_IMG" || ! -f "$ROOTFS_IMG" ]]; then
  echo "ERROR: Missing QEMU artifacts in ${IMAGES_DIR}" >&2
  echo "Fix:" >&2
  echo "  make use DEV_MODE=qemu && make build" >&2
  exit 1
fi

echo "[envhub] QEMU using O=${outdir}"
echo "[envhub] SSH: ssh -p ${HOST_SSH_PORT} root@localhost"

exec qemu-system-aarch64 \
  -M virt \
  -cpu "${CPU}" \
  -m "${MEM}" \
  -nographic \
  -smp "${SMP}" \
  -kernel "${KERNEL_IMG}" \
  -append "rootwait root=/dev/vda console=ttyAMA0" \
  -netdev user,id=eth0,hostfwd=tcp::${HOST_SSH_PORT}-:22 \
  -device virtio-net-device,netdev=eth0 \
  -drive file="${ROOTFS_IMG}",if=none,format=raw,id=hd0 \
  -device virtio-blk-device,drive=hd0 \
  -device virtio-rng-pci