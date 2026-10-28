#!/usr/bin/env bash
# Patch the dist boot.img with KernelSU-Next and package everything the Lineage
# device tree needs (device/google/bluejay-kernels/6.1) into one tarball.
# usage: package.sh <dist_dir> <kernelsu.ko> <ksud> <out_dir>
set -euo pipefail
DIST=$1; KO=$2; KSUD=$3; OUT=$4
mkdir -p "$OUT/stage"
STAGE=$OUT/stage

"$KSUD" boot-patch-v2 --boot "$DIST/boot.img" --module "$KO" --output "$STAGE/boot.img" --force

for f in dtb.img dtbo.img vendor_dlkm.img; do cp "$DIST/$f" "$STAGE/"; done
cp "$DIST"/*.dtb "$DIST"/*.dtbo "$STAGE/" 2>/dev/null || true
# stock kernel modules only; kernelsu.ko / susfs must NOT be here (ROM puts every *.ko in vendor_dlkm)
cp "$DIST"/*.ko "$STAGE/"
rm -f "$STAGE"/kernelsu.ko "$STAGE"/susfs_guard_lkm.ko
cp "$DIST/boot.img" "$OUT/boot-stock.img"

( cd "$STAGE" && tar -czf "$OUT/bluejay-kernel-ksu.tar.gz" . )
( cd "$OUT" && sha256sum bluejay-kernel-ksu.tar.gz > bluejay-kernel-ksu.tar.gz.sha256 )
ls -la "$OUT"
