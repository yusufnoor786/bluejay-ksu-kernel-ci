#!/usr/bin/env bash
# Show why the KernelSU-Next patch did or did not happen. Run from the ROM source root (after lunch):
#   /path/to/doctor.sh          (or: ANDROID_BUILD_TOP=<rom root> doctor.sh)
#   /path/to/doctor.sh --fix    install the build_kernel hook and patch the already-built kernel now
TOP=${ANDROID_BUILD_TOP:-$PWD}
DEV=$TOP/device/google/bluejay
KD=$TOP/device/google/bluejay-kernels/6.1
KB=$TOP/out-kernel/google/gs-6.1
ok() { printf '  [ ok ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; FAILS=$((FAILS+1)); }
inf() { printf '  [info] %s\n' "$*"; }
FAILS=0

echo "ROM root: $TOP"
echo "1) device tree"
if [ -d "$DEV/.git" ]; then inf "branch $(git -C "$DEV" rev-parse --abbrev-ref HEAD), last commit: $(git -C "$DEV" log -1 --format='%h %s' | cut -c1-70)"; else bad "$DEV is not a git checkout"; fi
for f in ksu-kernel/patch-kernel.sh ksu-kernel/install-build-hook.sh; do
  if [ -x "$DEV/$f" ]; then ok "$f present + executable"; elif [ -e "$DEV/$f" ]; then bad "$f present but NOT executable (chmod +x)"; else bad "$f missing (git pull in $DEV)"; fi
done
[ -f "$DEV/vendorsetup.sh" ] && ok "vendorsetup.sh present" || inf "vendorsetup.sh missing (only needed for the lunch wrapper)"
grep -q "ksu_kernel_patch" "$DEV/device-bluejay.mk" 2>/dev/null && ok "device-bluejay.mk has the warn-only check" || bad "device-bluejay.mk has no KSU check (re-run setup-bluejay.sh)"
grep -q "TARGET_KERNEL_DEVICE := bluejay" "$DEV/device-bluejay.mk" 2>/dev/null && ok "TARGET_KERNEL_DEVICE is bluejay" || bad "TARGET_KERNEL_DEVICE is not 'bluejay' in device-bluejay.mk (the hook only runs for bluejay)"

echo "2) build_kernel hook in the ROM scripts"
mapfile -t FILES < <(find "$TOP/vendor" "$TOP/build" -maxdepth 4 -name envsetup.sh 2>/dev/null | xargs -r grep -l 'Kernel build output copied to' 2>/dev/null)
if [ ${#FILES[@]} -eq 0 ]; then bad "no envsetup.sh defining build_kernel found under vendor/ or build/"; fi
for f in "${FILES[@]}"; do
  if grep -qF "KSU-Next hook" "$f"; then ok "hook installed in ${f#$TOP/}"; else bad "hook NOT installed in ${f#$TOP/}  (run install-build-hook.sh)"; fi
done
inf "your current shell may still hold an OLD build_kernel; after installing, run: source build/envsetup.sh"
inf "check the loaded one with:  declare -f build_kernel | grep -c 'KSU-Next hook'   (must print 1 or more)"

echo "3) kernel workspace + tools"
[ -d "$KB/.repo" ] && ok "kernel workspace $KB exists" || bad "kernel workspace missing (lunch has not built the kernel yet)"
[ -f "$KB/out/bluejay/dist/boot.img" ] && ok "unpatched dist boot.img exists" || bad "no $KB/out/bluejay/dist/boot.img"
[ -x "$KB/tools/bazel" ] && ok "kernel workspace has tools/bazel" || bad "tools/bazel missing in the kernel workspace"
command -v git >/dev/null && ok "git found" || bad "git not found"
if command -v curl >/dev/null || command -v wget >/dev/null; then ok "curl/wget found"; elif command -v python3 >/dev/null; then inf "no curl/wget, python3 will be used"; else bad "no curl, wget or python3 (cannot download ksud)"; fi
[ -x "$TOP/out-kernel/.ksu/ksud" ] && ok "ksud cached" || inf "ksud not downloaded yet (patch-kernel.sh downloads it once)"
for m in kernelsu susfs; do [ -f "$KB/private/google-modules/$m/BUILD.bazel" ] && ok "$m module sources in the kernel workspace" || inf "$m module sources not cloned yet (patch-kernel.sh clones them)"; done

echo "4) result"
if [ -f "$KD/.ksu-kernel-release" ]; then
  ok "STAMP present: $(head -1 "$KD/.ksu-kernel-release")"
  if [ -f "$KD/boot.img" ] && [ "$(sed -n 2p "$KD/.ksu-kernel-release")" = "$(sha256sum "$KD/boot.img" | cut -d' ' -f1)" ]; then ok "boot.img matches the patched hash -> KernelSU-Next IS in the ROM's kernel"; else bad "stamp exists but boot.img does not match it (changed after patching)"; fi
else
  bad "NOT patched: no $KD/.ksu-kernel-release"
fi
[ -f "$KD/boot.img" ] && [ -f "$KB/out/bluejay/dist/boot.img" ] && { a=$(sha256sum "$KD/boot.img" | cut -c1-16); b=$(sha256sum "$KB/out/bluejay/dist/boot.img" | cut -c1-16); inf "ROM prebuilt boot.img $a   unpatched dist $b   ($( [ "$a" = "$b" ] && echo 'SAME = unpatched' || echo 'different = patched'))"; }

if [ "${1:-}" = "--fix" ]; then
  echo "5) --fix"
  [ -x "$DEV/ksu-kernel/install-build-hook.sh" ] && ( cd "$TOP" && ANDROID_BUILD_TOP="$TOP" "$DEV/ksu-kernel/install-build-hook.sh" )
  [ -x "$DEV/ksu-kernel/patch-kernel.sh" ] && ( cd "$TOP" && ANDROID_BUILD_TOP="$TOP" "$DEV/ksu-kernel/patch-kernel.sh" )
fi
echo; echo "$FAILS problem(s) found."
