#!/bin/sh
set -eu

REPOSITORY='pygojrc/codex-desktop-linux'
API_URL="https://api.github.com/repos/$REPOSITORY/releases/latest"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*" >&2; }

[ "$(uname -m)" = x86_64 ] || die 'this package is only for Manjaro KDE x86_64'
command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v sha256sum >/dev/null 2>&1 || die 'sha256sum is required'
command -v pacman >/dev/null 2>&1 || die 'pacman is required; this installer is for Manjaro/Arch'

release_json="$(curl --fail --location --retry 3 --retry-all-errors \
  --header 'Accept: application/vnd.github+json' "$API_URL")"
package_url="$(printf '%s\n' "$release_json" \
  | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\(https:[^"]*codex-desktop-[^"]*-x86_64\.pkg\.zst\)".*/\1/p' \
  | head -n 1)"
[ -n "$package_url" ] || die 'latest Release has no x86_64 .pkg.zst asset'

checksum_url="${package_url}.sha256"
temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-desktop-install.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT HUP INT TERM
package_path="$temporary_dir/$(basename "$package_url")"
checksum_path="$package_path.sha256"

info "Downloading $(basename "$package_url")"
curl --fail --location --retry 3 --retry-all-errors -o "$package_path" "$package_url"
curl --fail --location --retry 3 --retry-all-errors -o "$checksum_path" "$checksum_url"

expected="$(sed -n 's/^\([0-9a-fA-F]\{64\}\)[[:space:]].*/\1/p' "$checksum_path" | head -n 1)"
actual="$(sha256sum "$package_path" | awk '{print $1}')"
[ -n "$expected" ] || die 'invalid Release checksum file'
[ "$actual" = "$expected" ] || die 'SHA-256 verification failed'

info 'Installing package with pacman'
if [ "$(id -u)" -eq 0 ]; then
  pacman -U --noconfirm "$package_path"
elif command -v sudo >/dev/null 2>&1; then
  sudo pacman -U --noconfirm "$package_path"
else
  die 'sudo is required when this installer is not run as root'
fi

info 'Installation complete'
