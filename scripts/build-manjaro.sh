#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$REPO_DIR/dist}"
WORK_DIR="${WORK_DIR:-$DIST_DIR/work}"
UPSTREAM_URL="${CHATGPT_DEB_URL:-https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb}"
PACKAGE_NAME='codex-desktop'

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*" >&2; }

[[ "$(uname -m)" == x86_64 ]] || die 'this release is only for Manjaro KDE x86_64'
command -v curl >/dev/null || die 'curl is required'
command -v dpkg-deb >/dev/null || die 'dpkg-deb is required'
command -v makepkg >/dev/null || die 'makepkg is required'
command -v node >/dev/null || die 'node is required'
command -v npx >/dev/null || die 'npx is required'

mkdir -p "$DIST_DIR" "$WORK_DIR"
rm -rf "$WORK_DIR/stage" "$WORK_DIR/pkgbuild"
mkdir -p "$WORK_DIR/stage" "$WORK_DIR/pkgbuild"

deb_path="$WORK_DIR/chatgpt_amd64.deb"
info "Downloading official ChatGPT Linux package"
curl --fail --location --retry 3 --retry-all-errors --output "$deb_path" "$UPSTREAM_URL"

package_name="$(dpkg-deb -f "$deb_path" Package)"
upstream_version="$(dpkg-deb -f "$deb_path" Version)"
upstream_arch="$(dpkg-deb -f "$deb_path" Architecture)"
[[ "$package_name" == chatgpt ]] || die "unexpected upstream package: $package_name"
[[ "$upstream_arch" == amd64 ]] || die "unexpected upstream architecture: $upstream_arch"
[[ "$upstream_version" =~ ^[0-9][0-9A-Za-z.+:~-]*$ ]] || die "invalid upstream version: $upstream_version"

# Arch pkgver does not accept Debian's epoch separator or hyphen.
pkgver="${upstream_version//:/_}"
pkgver="${pkgver//-/_}"
[[ "$pkgver" =~ ^[0-9][0-9A-Za-z.+_]*$ ]] || die "version cannot be represented as an Arch pkgver: $upstream_version"

# dpkg-deb -x extracts only the data archive. Debian postinst/prerm scripts
# are intentionally excluded, so the package cannot install an APT source.
info "Extracting data archive with dpkg-deb"
dpkg-deb -x "$deb_path" "$WORK_DIR/stage"

# Patch the official webview bundle before repackaging.
asar_dir="$WORK_DIR/app-asar"
patched_asar="$WORK_DIR/app.asar.patched"
mkdir -p "$asar_dir"
info "Patching quick slider default: gpt-5.6-luna:medium first"
npx --yes @electron/asar@4.3.0 extract \
  "$WORK_DIR/stage/usr/lib/chatgpt/resources/app.asar" \
  "$asar_dir"
node "$REPO_DIR/scripts/patch-quick-model-picker.js" \
  "$asar_dir/webview/assets"
npx --yes @electron/asar@4.3.0 pack "$asar_dir" "$patched_asar"
mv -- "$patched_asar" "$WORK_DIR/stage/usr/lib/chatgpt/resources/app.asar"

# Keep /usr/bin/chatgpt as a real wrapper rather than the upstream symlink.
# This makes both KDE launches and direct command-line launches use Fcitx5.
chatgpt_wrapper="$WORK_DIR/stage/usr/bin/chatgpt"
[[ -e "$chatgpt_wrapper" || -L "$chatgpt_wrapper" ]] || die "upstream chatgpt launcher is missing"
rm -f "$chatgpt_wrapper"
cat > "$chatgpt_wrapper" <<'EOF'
#!/bin/sh
set -eu
export GTK_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
exec /usr/lib/chatgpt/codex-launcher "$@"
EOF
chmod 0755 "$chatgpt_wrapper"

desktop_file="$WORK_DIR/stage/usr/share/applications/chatgpt.desktop"
[[ -f "$desktop_file" ]] || die "upstream desktop entry is missing"
sed -i \
  's|^Exec=env GTK_IM_MODULE=fcitx XMODIFIERS=@im=fcitx chatgpt %U$|Exec=chatgpt %U|' \
  "$desktop_file"
grep -Fqx 'Exec=chatgpt %U' "$desktop_file" \
  || die 'unexpected ChatGPT desktop entry'

cat > "$WORK_DIR/pkgbuild/PKGBUILD" <<EOF
$(sed "s/^pkgver=.*/pkgver=$pkgver/" "$REPO_DIR/PKGBUILD")
EOF

info "Building ${PACKAGE_NAME}-${pkgver}-1-x86_64.pkg.zst"
(
  cd "$WORK_DIR/pkgbuild"
  CODEX_STAGE_DIR="$WORK_DIR/stage" \
    PKGDEST="$DIST_DIR" \
    PKGEXT='.pkg.tar.zst' \
    makepkg --nodeps --skipinteg --force
)

package_path="$DIST_DIR/${PACKAGE_NAME}-${pkgver}-1-x86_64.pkg.zst"
makepkg_path="$DIST_DIR/${PACKAGE_NAME}-${pkgver}-1-x86_64.pkg.tar.zst"
[[ -f "$makepkg_path" ]] || die "makepkg did not create the standard package: $makepkg_path"
mv -- "$makepkg_path" "$package_path"
[[ -f "$package_path" ]] || die "package was not created: $package_path"
(
  cd "$DIST_DIR"
  sha256sum "$(basename "$package_path")" > "$(basename "$package_path").sha256"
)
cat > "$DIST_DIR/release-metadata.json" <<EOF
{
  "package": "$(basename "$package_path")",
  "sha256": "$(cut -d' ' -f1 "$package_path.sha256")",
  "upstreamPackage": "chatgpt",
  "upstreamVersion": "$upstream_version",
  "upstreamUrl": "$UPSTREAM_URL",
  "architecture": "x86_64",
  "inputMethod": "GTK_IM_MODULE=fcitx XMODIFIERS=@im=fcitx",
  "quickSliderPatch": "gpt-5.6-luna:medium-first"
}
EOF
info "Built: $package_path"
printf '%s\n' "$package_path"
