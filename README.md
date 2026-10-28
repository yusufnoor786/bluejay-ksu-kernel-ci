# bluejay-ksu-kernel-ci

GitHub Actions build of the Pixel 6a (bluejay) Lineage `gs-6.1` kernel with KernelSU-Next v3.4.2.
Each run syncs `yusufnoor786/android_kernel_google_gs-6.1_manifest` (`lineage-24.0`), builds the kernel
and `kernelsu.ko`, patches `boot.img` with `ksud boot-patch-v2`, and publishes
`bluejay-kernel-ksu.tar.gz` (+ `.sha256`) as a GitHub Release.

The ROM's device tree (`android_device_google_bluejay` fork) downloads the latest release into
`device/google/bluejay-kernels/6.1` when `lunch` runs. Run manually: Actions -> build-kernel -> Run workflow.
