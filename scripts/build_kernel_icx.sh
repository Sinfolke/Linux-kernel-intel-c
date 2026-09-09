#!/usr/bin/env bash
set -euo pipefail

KERNEL_SRC=""
JOBS="$(nproc)"
TARGETS="bzImage modules"
EXTRA_MAKE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kernel-src)
      KERNEL_SRC="$2"
      shift 2
      ;;
    --jobs)
      JOBS="$2"
      shift 2
      ;;
    --targets)
      TARGETS="$2"
      shift 2
      ;;
    --)
      shift
      EXTRA_MAKE_ARGS+=("$@")
      break
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${KERNEL_SRC}" ]]; then
  echo "Usage: $0 --kernel-src /path/to/linux [--jobs N] [--targets \"bzImage modules\"] [-- extra make args]" >&2
  exit 1
fi

if [[ ! -f "${KERNEL_SRC}/Makefile" ]]; then
  echo "Invalid kernel source directory: ${KERNEL_SRC}" >&2
  exit 1
fi

make -C "${KERNEL_SRC}" -j"${JOBS}" \
  CC=icx \
  LD=ld.lld \
  AR=llvm-ar \
  NM=llvm-nm \
  STRIP=llvm-strip \
  OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump \
  READELF=llvm-readelf \
  LLVM_IAS=1 \
  KCFLAGS="-ffreestanding -fno-builtin" \
  ${TARGETS} \
  "${EXTRA_MAKE_ARGS[@]}"
