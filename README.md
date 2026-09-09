# Build Linux Kernel with Intel oneAPI `icx` (Guide + Automation)

This repository provides a **guide-first** workflow for building a modern x86-64 Linux kernel with Intel oneAPI LLVM-based tooling.

It includes:

- A practical Intel `icx` build guide
- Scripts to patch Kbuild for Intel compiler detection
- Scripts to automate configure/build/install commands
- One end-to-end script to run the full flow

> Kernel `.c` files must use **`icx`** (C compiler).  
> `icpx` is the C++ compiler and is only optional for host-side C++ tools.

---

## Included scripts

- `/home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/patch_kbuild_for_icx.py`  
  Patches kernel source tree files:
  - `scripts/as-version.sh` (treats `icx` as LLVM IAS)
  - top-level `Makefile` (selects `scripts/Makefile.clang` for Intel compiler text)

- `/home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/build_kernel_icx.sh`  
  Runs `make` with recommended Intel/LLVM toolchain variables and `KCFLAGS="-ffreestanding -fno-builtin"`.

- `/home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/full_kernel_icx_flow.sh`  
  One all-in-one script that checks tools, patches Kbuild, prepares config, builds, and optionally installs.

---

## Why these changes are needed

Intel `icx` is LLVM-based but its compiler identity is not always detected by kernel logic that expects typical Clang strings.

Two build-system touchpoints matter:

1. `scripts/as-version.sh` must classify `icx` as LLVM integrated assembler
2. top-level `Makefile` must choose `scripts/Makefile.clang` for Intel compiler version text

Also, to prevent unresolved Intel runtime symbols in kernel/module objects, use:

- `-ffreestanding`
- `-fno-builtin`

---

## Quick start

1. Prepare dependencies (kernel deps + LLVM tools + oneAPI with `icx`/`icpx`)
2. Run the all-in-one script:

```bash
/home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/full_kernel_icx_flow.sh \
  --kernel-src /path/to/linux \
  --jobs 10
```

3. Optional install step:

```bash
/home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/full_kernel_icx_flow.sh \
  --kernel-src /path/to/linux \
  --jobs 10 \
  --install
```

---

## Manual script usage

### 1) Patch kernel build files for Intel LLVM detection

```bash
python3 /home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/patch_kbuild_for_icx.py \
  --kernel-src /path/to/linux
```

### 2) Build with Intel/LLVM toolchain

```bash
/home/runner/work/Linux-kernel-intel-c/Linux-kernel-intel-c/scripts/build_kernel_icx.sh \
  --kernel-src /path/to/linux \
  --jobs 10
```

### 3) Full build command used by the script

```bash
make -j10 \
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
  bzImage modules
```

---

## Notes

- Use `CC=icx` for kernel C compilation.
- Keep host tools on GCC/binutils unless you explicitly want Intel/LLVM host tools.
- If ORC/objtool issues appear, fallback to frame-pointer unwinder can be used in config.
- Prefer `INSTALL_MOD_STRIP=1` during module install to avoid oversized `.ko` files.
