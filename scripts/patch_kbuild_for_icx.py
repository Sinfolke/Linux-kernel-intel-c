#!/usr/bin/env python3
import argparse
import pathlib
import re
import sys

IAS_BLOCK = """# Intel oneAPI icx uses LLVM integrated assembler.
case "$(basename -- "$CC")" in
icx|icx.exe)
\techo "LLVM 0"
\texit 0
\t;;
esac
"""


def patch_as_version(path: pathlib.Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if 'icx|icx.exe' in text:
        return False

    lines = text.splitlines(keepends=True)
    insert_idx = None
    for i, line in enumerate(lines):
        if '-Wa,--version' in line or 'if [ -n "${LLVM}" ]' in line:
            insert_idx = i
            break

    if insert_idx is None:
        for i, line in enumerate(lines):
            if line.startswith("set -") or line.startswith("orig_args="):
                insert_idx = i + 1
                break

    if insert_idx is None:
        insert_idx = 1 if lines and lines[0].startswith("#!") else 0

    block = IAS_BLOCK
    if insert_idx > 0 and not lines[insert_idx - 1].endswith("\n\n"):
        block = "\n" + block
    lines.insert(insert_idx, block)
    path.write_text("".join(lines), encoding="utf-8")
    return True


def patch_makefile(path: pathlib.Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "findstring Intel,$(CC_VERSION_TEXT)" in text:
        return False

    pattern = (
        r'ifneq \(\$\(findstring clang,\$\(CC_VERSION_TEXT\)\),\)\n'
        r'include \$\(srctree\)/scripts/Makefile\.clang\n'
        r'endif'
    )
    replacement = (
        "ifneq ($(findstring clang,$(CC_VERSION_TEXT)),)\n"
        "include $(srctree)/scripts/Makefile.clang\n"
        "else ifneq ($(findstring Intel,$(CC_VERSION_TEXT)),)\n"
        "include $(srctree)/scripts/Makefile.clang\n"
        "endif"
    )

    new_text, n = re.subn(pattern, replacement, text, count=1)
    if n == 0:
        raise RuntimeError(
            "Could not find expected clang Makefile include block in top-level Makefile."
        )
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Patch Linux kernel build scripts for Intel oneAPI icx."
    )
    parser.add_argument(
        "--kernel-src",
        required=True,
        help="Path to Linux kernel source tree",
    )
    args = parser.parse_args()

    kernel_src = pathlib.Path(args.kernel_src).resolve()
    as_version = kernel_src / "scripts" / "as-version.sh"
    makefile = kernel_src / "Makefile"

    if not as_version.exists() or not makefile.exists():
        print("Kernel source tree missing expected files.", file=sys.stderr)
        return 1

    changed = []
    if patch_as_version(as_version):
        changed.append(str(as_version))
    if patch_makefile(makefile):
        changed.append(str(makefile))

    if changed:
        print("Patched:")
        for c in changed:
            print(f"  - {c}")
    else:
        print("No changes needed (already patched).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
