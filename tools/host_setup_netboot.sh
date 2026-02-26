#!/usr/bin/env bash
set -euo pipefail

# Host-side one-time setup for BBB netboot: static IP + TFTP + NFS export.
#
# Usage:
#   sudo ./tools/host_setup_netboot.sh
#
# Optional env overrides:
#   IFACE=enp3s0
#   HOST_IP=192.168.7.1
#   NET_CIDR=24
#   TFTP_DIR=/srv/tftp
#   NFS_DIR=/srv/nfs/bbb
#   NFS_NETWORK=192.168.7.0/24
#   APPLY_NETWORK_GUARD=1

IFACE="${IFACE:-}"
HOST_IP="${HOST_IP:-192.168.7.1}"
NET_CIDR="${NET_CIDR:-24}"
TFTP_DIR="${TFTP_DIR:-/srv/tftp}"
NFS_DIR="${NFS_DIR:-/srv/nfs/bbb}"
NFS_NETWORK="${NFS_NETWORK:-192.168.7.0/24}"
APPLY_NETWORK_GUARD="${APPLY_NETWORK_GUARD:-1}"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root (sudo)." >&2
    exit 1
  fi
}

pick_iface() {
  if [[ -n "${IFACE}" ]]; then
    echo "${IFACE}"
    return
  fi

  # Try to pick a likely wired interface (skip lo, docker, virbr, wlan).
  local cand
  cand="$(ip -o link show | awk -F': ' '{print $2}' \
    | grep -Ev '^(lo|docker|br-|virbr|veth|wl|wlan|tun|tap)' \
    | head -n 1 || true)"
  if [[ -z "${cand}" ]]; then
    echo "ERROR: Could not auto-detect Ethernet interface. Set IFACE=... and rerun." >&2
    exit 1
  fi
  echo "${cand}"
}

configure_host_ip() {
  local iface="$1"
  echo "[*] Configuring host interface ${iface} to ${HOST_IP}/${NET_CIDR}"
  ip addr flush dev "${iface}" || true
  ip addr add "${HOST_IP}/${NET_CIDR}" dev "${iface}"
  ip link set "${iface}" up
}

install_packages() {
  echo "[*] Installing packages: tftpd-hpa, nfs-kernel-server, u-boot-tools"
  apt-get update
  apt-get install -y tftpd-hpa nfs-kernel-server u-boot-tools
}

configure_tftp() {
  echo "[*] Configuring TFTP root at ${TFTP_DIR}"
  mkdir -p "${TFTP_DIR}"
  chown -R tftp:tftp "${TFTP_DIR}"

  # Configure tftpd-hpa
  cat >/etc/default/tftpd-hpa <<EOF
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${TFTP_DIR}"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --create"
EOF

  systemctl enable tftpd-hpa
  systemctl restart tftpd-hpa
}

configure_nfs() {
  echo "[*] Configuring NFS export at ${NFS_DIR} for ${NFS_NETWORK}"
  mkdir -p "${NFS_DIR}"

  local exports_line="${NFS_DIR} ${NFS_NETWORK}(rw,sync,no_root_squash,no_subtree_check)"
  if ! grep -qF "${exports_line}" /etc/exports 2>/dev/null; then
    echo "${exports_line}" >> /etc/exports
  fi

  exportfs -ra
  systemctl enable nfs-kernel-server
  systemctl restart nfs-kernel-server
}

apply_network_guard_patch() {
  [[ "${APPLY_NETWORK_GUARD}" == "1" ]] || return 0

  # This patch is applied to the NFS root later (after rootfs is deployed),
  # but we also support applying immediately if the file already exists.
  local script="${NFS_DIR}/etc/init.d/S40network"
  if [[ ! -f "${script}" ]]; then
    echo "[i] ${script} not present yet (rootfs not deployed). Network guard will be applied during deploy."
    return 0
  fi

  if grep -q "OK (already configured)" "${script}"; then
    echo "[i] Network guard already present in ${script}"
    return 0
  fi

  echo "[*] Applying network guard to ${script}"
  # Insert just after 'start)' line
  sed -i '/^\s*start)\s*$/a\
\t# If we netbooted with ip=... the kernel already configured eth0.\
\t# Avoid ifupdown fighting existing addresses/routes ("File exists").\
\tif ip -4 addr show dev eth0 2>/dev/null | grep -q "inet "; then\
\t\techo "Starting network: OK (already configured)"\
\t\texit 0\
\tfi\
' "${script}"
}

main() {
  need_root
  local iface
  iface="$(pick_iface)"

  configure_host_ip "${iface}"
  install_packages
  configure_tftp
  configure_nfs

  echo "[*] Verifying services..."
  systemctl --no-pager --full status tftpd-hpa || true
  systemctl --no-pager --full status nfs-kernel-server || true

  apply_network_guard_patch

  echo
  echo "[OK] Host netboot setup complete."
  echo "     Host IP: ${HOST_IP}/${NET_CIDR} on ${iface}"
  echo "     TFTP:    ${TFTP_DIR}"
  echo "     NFS:     ${NFS_DIR} exported to ${NFS_NETWORK}"
}

main "$@"