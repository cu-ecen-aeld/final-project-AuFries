#!/usr/bin/env bash
set -euo pipefail

OUT="${OUT:-boot.scr}"
BBB_IP="${BBB_IP:-192.168.7.2}"
HOST_IP="${HOST_IP:-192.168.7.1}"
NETMASK="${NETMASK:-255.255.255.0}"
TFTP_KERNEL="${TFTP_KERNEL:-zImage}"
TFTP_DTB="${TFTP_DTB:-am335x-boneblack.dtb}"
NFS_ROOT="${NFS_ROOT:-/srv/nfs/bbb}"
LOADADDR="${LOADADDR:-0x82000000}"
FDTADDR="${FDTADDR:-0x88000000}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Missing required command: $1" >&2
    echo "Install with: sudo apt-get install -y u-boot-tools" >&2
    exit 1
  }
}

tmp_cmd=""
cleanup() {
  # Safe even with set -u
  if [[ -n "${tmp_cmd}" && -f "${tmp_cmd}" ]]; then
    rm -f "${tmp_cmd}"
  fi
}
trap cleanup EXIT

main() {
  require_cmd mkimage

  tmp_cmd="$(mktemp -t bootcmd.XXXXXX)"

  cat > "${tmp_cmd}" <<EOF
echo "=== RUNNING BBB NETBOOT boot.scr ==="

setenv ipaddr ${BBB_IP}
setenv serverip ${HOST_IP}
setenv netmask ${NETMASK}

setenv loadaddr ${LOADADDR}
setenv fdtaddr  ${FDTADDR}

setenv bootfile ${TFTP_KERNEL}
setenv fdtfile  ${TFTP_DTB}
setenv nfsroot  ${NFS_ROOT}

setenv bootargs "console=ttyS0,115200n8 root=/dev/nfs rw nfsroot=\${serverip}:\${nfsroot},vers=3,tcp ip=\${ipaddr}:\${serverip}::\${netmask}:bbb:eth0:off"

echo "TFTP kernel..."
tftpboot \${loadaddr} \${bootfile}
echo "TFTP dtb..."
tftpboot \${fdtaddr}  \${fdtfile}

echo "Booting kernel..."
bootz \${loadaddr} - \${fdtaddr}
EOF

  mkimage -A arm -T script -C none -n 'bbb netboot' -d "${tmp_cmd}" "${OUT}"
  echo "[OK] Wrote ${OUT}"
  file "${OUT}" || true

  echo
  echo "Copy it to the SD boot partition (one-time):"
  echo "  sudo mount /dev/sdX1 /mnt/bbb-boot"
  echo "  sudo cp ${OUT} /mnt/bbb-boot/boot.scr"
  echo "  sync && sudo umount /mnt/bbb-boot"
}

main "$@"