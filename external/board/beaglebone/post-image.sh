#!/bin/sh
set -eu

: "${BINARIES_DIR:?Missing BINARIES_DIR}"
: "${HOST_DIR:?Missing HOST_DIR}"

EXTERNAL_PATH="${BR2_EXTERNAL_ENVHUB_PATH:-${BR2_EXTERNAL_PATH:-}}"
if [ -z "${EXTERNAL_PATH}" ]; then
  echo "ERROR: BR2_EXTERNAL_ENVHUB_PATH/BR2_EXTERNAL_PATH not set."
  exit 1
fi

DTC="${HOST_DIR}/bin/dtc"
FDTOVERLAY="${HOST_DIR}/bin/fdtoverlay"

BASE_DTB="${BINARIES_DIR}/am335x-boneblack.dtb"
OVERLAY_SRC="${EXTERNAL_PATH}/board/beaglebone/overlays/spi0-spidev.dtso"

OVERLAY_DTBO="${BINARIES_DIR}/spi0-spidev.dtbo"
MERGED_DTB="${BINARIES_DIR}/am335x-boneblack-envhub.dtb"

echo "post-image: merge SPI0 spidev overlay into new dtb"
echo "  BASE_DTB     = ${BASE_DTB}"
echo "  OVERLAY_SRC  = ${OVERLAY_SRC}"
echo "  MERGED_DTB   = ${MERGED_DTB}"

[ -x "${DTC}" ] || { echo "ERROR: dtc not found at ${DTC}"; exit 1; }
[ -x "${FDTOVERLAY}" ] || { echo "ERROR: fdtoverlay not found at ${FDTOVERLAY}"; exit 1; }
[ -f "${BASE_DTB}" ] || { echo "ERROR: base dtb not found: ${BASE_DTB}"; exit 1; }
[ -f "${OVERLAY_SRC}" ] || { echo "ERROR: overlay source not found: ${OVERLAY_SRC}"; exit 1; }

# Compile overlay
"${DTC}" -@ -I dts -O dtb -o "${OVERLAY_DTBO}" "${OVERLAY_SRC}"

# Apply overlay -> merged dtb
"${FDTOVERLAY}" -i "${BASE_DTB}" -o "${MERGED_DTB}" "${OVERLAY_DTBO}"

echo "post-image: done"