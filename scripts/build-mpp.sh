#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_package="${MPP_SOURCE_PACKAGE:?Set MPP_SOURCE_PACKAGE to the pinned 26.928.40906 Release asset}"
asar_bin="${MPP_ASAR_BIN:?Set MPP_ASAR_BIN to the pinned @electron/asar CLI}"
config="${MPP_FEATURES_CONFIG:-$repo_dir/configs/mpp/features.json}"
dist="${DIST_DIR:-$repo_dir/dist}"
work="$dist/work-mpp"
source_sha='18cf3d38cc6c50ba41425890404888089019e3fecf43e06c0fedabe63165b7a7'
version='26.928.40906'
pkgrel=2

die() { echo "error: $*" >&2; exit 1; }
[[ "$(uname -m)" == x86_64 ]] || die 'x86_64 host required'
[[ -f "$source_package" ]] || die "missing source package: $source_package"
[[ -x "$asar_bin" ]] || die "missing asar CLI: $asar_bin"
[[ "$(git -C "$repo_dir/upstream/ilysenko" rev-parse HEAD)" == a0b23fed42be7f03d5a23f017efb111b1346a559 ]] || die 'submodule commit mismatch'
echo "$source_sha  $source_package" | sha256sum -c -

mkdir -p "$dist"
rm -rf -- "$work"
mkdir -p "$work/stage" "$work/pkgbuild" "$work/extracted"
tar -xf "$source_package" -C "$work/stage"
grep -Fqx 'pkgname = codex-desktop' "$work/stage/.PKGINFO" || die 'source package name mismatch'
grep -Fqx "pkgver = $version-1" "$work/stage/.PKGINFO" || die 'source package version mismatch'
grep -Fqx 'arch = x86_64' "$work/stage/.PKGINFO" || die 'source package architecture mismatch'
for file in .PKGINFO .BUILDINFO .MTREE .INSTALL; do rm -f -- "$work/stage/$file"; done

resources="$work/stage/usr/lib/chatgpt/resources"
[[ -f "$resources/app.asar" && -x "$work/stage/usr/lib/chatgpt/resources/codex" &&
   -x "$work/stage/usr/lib/chatgpt/resources/codex-code-mode-host" ]] || die 'application payload is incomplete'
grep -Fqx 'export GTK_IM_MODULE=fcitx' "$work/stage/usr/bin/chatgpt" || die 'Fcitx5 wrapper is missing'
original_asar_sha="$(sha256sum "$resources/app.asar" | cut -d' ' -f1)"

"$asar_bin" list --is-pack "$resources/app.asar" > "$work/original.layout"
"$asar_bin" extract "$resources/app.asar" "$work/extracted"
if [[ -d "$resources/app.asar.unpacked" ]]; then
  cp -a "$resources/app.asar.unpacked/." "$work/extracted/"
fi
hash_extracted() {
  (cd "$work/extracted" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$1"
}
hash_extracted "$work/before.sha256"
node "$repo_dir/scripts/patch-mpp.js" "$work/extracted" "$config" "$dist/mpp-patch-report.json"
hash_extracted "$work/after.sha256"
node "$repo_dir/scripts/verify-mpp.js" "$work/before.sha256" "$work/after.sha256" "$dist/mpp-patch-report.json"

node "$repo_dir/upstream/ilysenko/scripts/patches/lib/asar-layout.js" \
  "$work/original.layout" "$work/extracted" "$work/ordering" "$work/unpack-dir-pattern"
unpack_dir_pattern="$(cat "$work/unpack-dir-pattern")"
pack_args=(pack "$work/extracted" "$work/new.asar" --ordering "$work/ordering" --unpack '{*.node,*.so,*.dylib}')
if [[ -n "$unpack_dir_pattern" ]]; then pack_args+=(--unpack-dir "$unpack_dir_pattern"); fi
"$asar_bin" "${pack_args[@]}"
"$asar_bin" list --is-pack "$work/new.asar" > "$work/new.layout"
node "$repo_dir/upstream/ilysenko/scripts/patches/lib/asar-layout.js" verify "$work/original.layout" "$work/new.layout"
"$asar_bin" extract "$work/new.asar" "$work/reextracted"
test -f "$work/reextracted/.vite/build/$(node -p "require('$dist/mpp-patch-report.json').mainBundle")" || die 'repacked ASAR cannot be extracted'
mv -- "$work/new.asar" "$resources/app.asar"
if [[ -d "$work/new.asar.unpacked" ]]; then
  rm -rf -- "$resources/app.asar.unpacked"
  mv -- "$work/new.asar.unpacked" "$resources/app.asar.unpacked"
fi
patched_asar_sha="$(sha256sum "$resources/app.asar" | cut -d' ' -f1)"
[[ "$patched_asar_sha" != "$original_asar_sha" ]] || die 'ASAR was not modified'

sed -e "s/^pkgver=.*/pkgver=$version/" -e "s/^pkgrel=.*/pkgrel=$pkgrel/" \
  "$repo_dir/PKGBUILD" > "$work/pkgbuild/PKGBUILD"
(
  cd "$work/pkgbuild"
  CODEX_STAGE_DIR="$work/stage" PKGDEST="$dist" PKGEXT='.pkg.tar.zst' makepkg --nodeps --skipinteg --force
)
package="codex-desktop-$version-$pkgrel-x86_64.pkg.tar.zst"
[[ -f "$dist/$package" ]] || die 'makepkg did not produce the expected package'
tar -xOf "$dist/$package" usr/bin/chatgpt | cmp - "$work/stage/usr/bin/chatgpt"
tar -tf "$dist/$package" > "$work/package-files.txt"
grep -Fqx 'usr/lib/chatgpt/resources/codex-code-mode-host' "$work/package-files.txt"
grep -Fqx 'usr/lib/chatgpt/resources/codex' "$work/package-files.txt"
(cd "$dist" && sha256sum "$package" > "$package.sha256")

SOURCE_SHA="$source_sha" ORIGINAL_ASAR_SHA="$original_asar_sha" PATCHED_ASAR_SHA="$patched_asar_sha" \
PACKAGE="$package" DIST="$dist" CONFIG="$config" FEATURE_COMMIT=a0b23fed42be7f03d5a23f017efb111b1346a559 \
REPOSITORY_COMMIT="$(git -C "$repo_dir" rev-parse HEAD)" node <<'JS'
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');
const e = process.env;
const sha = (buffer) => crypto.createHash('sha256').update(buffer).digest('hex');
const config = fs.readFileSync(e.CONFIG);
const pkg = fs.readFileSync(path.join(e.DIST, e.PACKAGE));
const report = JSON.parse(fs.readFileSync(path.join(e.DIST, 'mpp-patch-report.json')));
const metadata = {
  package: e.PACKAGE,
  sha256: sha(pkg),
  upstreamVersion: '26.928.40906',
  sourceRelease: 'manjaro-kde-26.928.40906',
  sourcePackageSha256: e.SOURCE_SHA,
  feature: 'model-picker-default-presets',
  featureSourceCommit: e.FEATURE_COMMIT,
  repositoryCommit: e.REPOSITORY_COMMIT,
  featuresConfigSha256: sha(config),
  originalAsarSha256: e.ORIGINAL_ASAR_SHA,
  patchedAsarSha256: e.PATCHED_ASAR_SHA,
  patchStatuses: report.patches.map(({ name, status }) => ({ name, status })),
};
fs.writeFileSync(path.join(e.DIST, 'mpp-release-metadata.json'), `${JSON.stringify(metadata, null, 2)}\n`);
JS
echo "Built and verified: $dist/$package"
