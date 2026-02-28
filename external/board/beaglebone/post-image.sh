#!/bin/sh
set -eu

log() { echo "post-image: $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

: "${BINARIES_DIR:?Missing BINARIES_DIR}"
: "${HOST_DIR:?Missing HOST_DIR}"

EXTERNAL_PATH="${BR2_EXTERNAL_ENVHUB_PATH:-${BR2_EXTERNAL_PATH:-}}"
[ -n "${EXTERNAL_PATH}" ] || die "BR2_EXTERNAL_ENVHUB_PATH/BR2_EXTERNAL_PATH not set"

DTC="${HOST_DIR}/bin/dtc"
FDTOVERLAY="${HOST_DIR}/bin/fdtoverlay"
[ -x "${DTC}" ] || die "dtc not found at ${DTC}"
[ -x "${FDTOVERLAY}" ] || die "fdtoverlay not found at ${FDTOVERLAY}"

# Use host gcc preprocessor (reliable on dev machines)
CPP="gcc -E"

BASE_DTB="${BINARIES_DIR}/am335x-boneblack.dtb"
OVERLAYS_DIR="${EXTERNAL_PATH}/board/beaglebone/dts-overlays"
MERGED_DTB="${BINARIES_DIR}/am335x-boneblack-envhub.dtb"
TMP_DTB="${BINARIES_DIR}/.am335x-boneblack-envhub.tmp.dtb"

[ -f "${BASE_DTB}" ] || die "base dtb not found: ${BASE_DTB}"
[ -d "${OVERLAYS_DIR}" ] || die "overlays dir not found: ${OVERLAYS_DIR}"

# Kernel tree for dt-bindings includes (Buildroot puts kernel in output/build/linux-*)
LINUX_DIR="$(cd "${BINARIES_DIR}/../build" 2>/dev/null && ls -d linux-* 2>/dev/null | head -n 1 || true)"
[ -n "${LINUX_DIR}" ] || die "can't find kernel dir under $(cd "${BINARIES_DIR}/../build" && pwd)/linux-*"
LINUX_DIR="${BINARIES_DIR}/../build/${LINUX_DIR}"

INCLUDE_FLAGS="-I${LINUX_DIR}/include -I${LINUX_DIR}/arch/arm/boot/dts"

log "merge overlays from ${OVERLAYS_DIR}"
log "  BASE_DTB   = ${BASE_DTB}"
log "  MERGED_DTB = ${MERGED_DTB}"
log "  LINUX_DIR  = ${LINUX_DIR}"

# Deterministic overlay order
OVERLAY_SRCS="$(find "${OVERLAYS_DIR}" -maxdepth 1 -type f -name '*.dtso' | sort || true)"
if [ -z "${OVERLAY_SRCS}" ]; then
  log "no overlays (*.dtso); copying base dtb -> merged dtb"
  cp -f "${BASE_DTB}" "${MERGED_DTB}"
  exit 0
fi

cp -f "${BASE_DTB}" "${TMP_DTB}"

for SRC in ${OVERLAY_SRCS}; do
  NAME="$(basename "${SRC}" .dtso)"
  PP_DTS="${BINARIES_DIR}/${NAME}.pp.dts"
  DTBO="${BINARIES_DIR}/${NAME}.dtbo"

  log "compile: ${SRC} -> ${DTBO}"

  # Preprocess so #include <dt-bindings/...> works
  ${CPP} -nostdinc -undef -x assembler-with-cpp ${INCLUDE_FLAGS} "${SRC}" > "${PP_DTS}"

  # Compile overlay DTBO
  "${DTC}" -@ -I dts -O dtb -o "${DTBO}" "${PP_DTS}"

  log "apply: ${DTBO}"
  "${FDTOVERLAY}" -i "${TMP_DTB}" -o "${TMP_DTB}.next" "${DTBO}"
  mv -f "${TMP_DTB}.next" "${TMP_DTB}"
done

mv -f "${TMP_DTB}" "${MERGED_DTB}"
log "done"