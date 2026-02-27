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
OVERLAYS_DIR="${EXTERNAL_PATH}/board/beaglebone/dts-overlays"

MERGED_DTB="${BINARIES_DIR}/am335x-boneblack-envhub.dtb"
TMP_DTB="${BINARIES_DIR}/.am335x-boneblack-envhub.tmp.dtb"

echo "post-image: merge overlays from ${OVERLAYS_DIR}"
echo "  BASE_DTB    = ${BASE_DTB}"
echo "  MERGED_DTB  = ${MERGED_DTB}"

[ -x "${DTC}" ] || { echo "ERROR: dtc not found at ${DTC}"; exit 1; }
[ -x "${FDTOVERLAY}" ] || { echo "ERROR: fdtoverlay not found at ${FDTOVERLAY}"; exit 1; }
[ -f "${BASE_DTB}" ] || { echo "ERROR: base dtb not found: ${BASE_DTB}"; exit 1; }
[ -d "${OVERLAYS_DIR}" ] || { echo "ERROR: overlays dir not found: ${OVERLAYS_DIR}"; exit 1; }

# Gather overlays (deterministic order)
OVERLAY_SRCS="$(find "${OVERLAYS_DIR}" -maxdepth 1 -type f -name '*.dtso' | sort || true)"

if [ -z "${OVERLAY_SRCS}" ]; then
  echo "post-image: no overlays found (*.dtso) in ${OVERLAYS_DIR}; copying base dtb -> merged dtb"
  cp -f "${BASE_DTB}" "${MERGED_DTB}"
  exit 0
fi

# Start from base dtb
cp -f "${BASE_DTB}" "${TMP_DTB}"

for SRC in ${OVERLAY_SRCS}; do
  NAME="$(basename "${SRC}" .dtso)"
  DTBO="${BINARIES_DIR}/${NAME}.dtbo"

  echo "post-image: compiling overlay: ${SRC} -> ${DTBO}"
  "${DTC}" -@ -I dts -O dtb -o "${DTBO}" "${SRC}"

  echo "post-image: applying overlay: ${DTBO}"
  "${FDTOVERLAY}" -i "${TMP_DTB}" -o "${TMP_DTB}.next" "${DTBO}"
  mv -f "${TMP_DTB}.next" "${TMP_DTB}"
done

mv -f "${TMP_DTB}" "${MERGED_DTB}"
echo "post-image: done"