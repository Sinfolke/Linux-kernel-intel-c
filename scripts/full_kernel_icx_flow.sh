#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC=""
JOBS="$(nproc)"
INSTALL=0
USE_BOOT_CONFIG=1
USE_LOCALMODCONFIG=0

usage() {
  cat <<'EOF'
Usage:
  full_kernel_icx_flow.sh --kernel-src /path/to/linux [options]

Options:
  --jobs N                 Build parallelism (default: nproc)
  --install                Run modules_install/install/initramfs/grub update
  --no-boot-config         Skip copying /boot/config-$(uname -r) to .config
  --localmodconfig         Run make localmodconfig after olddefconfig
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kernel-src) KERNEL_SRC="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --install) INSTALL=1; shift ;;
    --no-boot-config) USE_BOOT_CONFIG=0; shift ;;
    --localmodconfig) USE_LOCALMODCONFIG=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${KERNEL_SRC}" || ! -f "${KERNEL_SRC}/Makefile" ]]; then
  echo "Please provide a valid kernel source with --kernel-src." >&2
  usage
  exit 1
fi

for tool in icx ld.lld llvm-ar llvm-nm llvm-strip llvm-objcopy llvm-objdump llvm-readelf python3 make; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "Missing required tool: ${tool}" >&2
    exit 1
  }
done

python3 "${SCRIPT_DIR}/patch_kbuild_for_icx.py" --kernel-src "${KERNEL_SRC}"

if [[ ${USE_BOOT_CONFIG} -eq 1 && -f "/boot/config-$(uname -r)" ]]; then
  cp "/boot/config-$(uname -r)" "${KERNEL_SRC}/.config"
fi

make -C "${KERNEL_SRC}" olddefconfig

if [[ ${USE_LOCALMODCONFIG} -eq 1 ]]; then
  make -C "${KERNEL_SRC}" localmodconfig
fi

"${SCRIPT_DIR}/build_kernel_icx.sh" --kernel-src "${KERNEL_SRC}" --jobs "${JOBS}"

if [[ ${INSTALL} -eq 1 ]]; then
  sudo make -C "${KERNEL_SRC}" modules_install INSTALL_MOD_STRIP=1
  sudo depmod -a
  sudo make -C "${KERNEL_SRC}" install
  sudo update-initramfs -u -k "$(make -s -C "${KERNEL_SRC}" kernelrelease)"
  sudo update-grub
fi
