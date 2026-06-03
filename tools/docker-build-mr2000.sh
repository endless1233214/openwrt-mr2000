#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/openwrt-build}"
OUT_DIR="${OUT_DIR:-$ROOT/build-output}"
OPENWRT_BRANCH="${OPENWRT_BRANCH:-v25.12.4}"
PATCH="$ROOT/mr2000-port/patches/openwrt-v25.12.4-local/0001-local-qualcommax-ipq50xx-add-linksys-mr2000.patch"
PATCH_COPY_FILES="$ROOT/mr2000-port/patches/openwrt-v25.12.4-local/0002-local-ipq-wifi-copy-package-files.patch"
FILES_DIR="$ROOT/files"

mkdir -p "$OUT_DIR"

if [ ! -d "$BUILD_DIR/.git" ]; then
  git clone --depth 1 --branch "$OPENWRT_BRANCH" https://github.com/openwrt/openwrt.git "$BUILD_DIR"
fi

cd "$BUILD_DIR"

if git apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  echo "MR2000 patch already present in $BUILD_DIR"
else
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "openwrt-build has local changes but the MR2000 patch is not fully present; refusing to continue." >&2
    exit 1
  fi
  git apply "$PATCH"
fi

if ! grep -Fq '$(CP) ./files/* $(PKG_BUILD_DIR)/' package/firmware/ipq-wifi/Makefile; then
  git apply "$PATCH_COPY_FILES"
fi

./scripts/feeds update -a
./scripts/feeds install -a

if [ -d "$FILES_DIR" ]; then
  rsync -a "$FILES_DIR"/ "$BUILD_DIR/files"/
fi

cat > .config <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_linksys_mr2000=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-adblock-fast=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_adblock-fast=y
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_kmod-ifb=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_tc-tiny=y
EOF

make defconfig
make download -j"$(nproc)"
make -j"$(nproc)" V=s

mkdir -p "$OUT_DIR"
find "$BUILD_DIR/bin/targets/qualcommax/ipq50xx" -maxdepth 1 -type f \
  \( -name '*linksys_mr2000*' -o -name 'profiles.json' -o -name 'sha256sums' \) \
  -exec cp -v {} "$OUT_DIR"/ \;

(
  cd "$OUT_DIR"
  find . -maxdepth 1 -type f ! -name SHA256SUMS.txt -print0 | \
    xargs -0 shasum -a 256 > SHA256SUMS.txt
)

echo
echo "Artifacts copied to: $OUT_DIR"
