#!/usr/bin/env bash
set -euo pipefail

# Map friendly profile names to Buildroot defconfig targets in BR2_EXTERNAL/configs/
profile_to_defconfig() {
  case "${1:-}" in
    prod|production) echo "envhub_defconfig" ;;
    debug|dev)       echo "envhub_dev_defconfig" ;;
    qemu)            echo "envhub_qemu_defconfig" ;;
    *) return 1 ;;
  esac
}

# Map friendly profile names to Buildroot output directories (relative to buildroot/)
profile_to_outdir() {
  case "${1:-}" in
    prod|production) echo "output-prod" ;;
    debug|dev)       echo "output-debug" ;;
    qemu)            echo "output-qemu" ;;
    *) return 1 ;;
  esac
}

# Infer profile from defconfig name (used for "save back to active")
defconfig_to_profile() {
  case "${1:-}" in
    envhub_defconfig)       echo "prod" ;;
    envhub_dev_defconfig)   echo "debug" ;;
    envhub_qemu_defconfig)  echo "qemu" ;;
    *) return 1 ;;
  esac
}