#!/usr/bin/env bash
set -Eeuo pipefail

# 此脚本只在一次性的 Arch Linux 容器中运行。
pacman -Syu --noconfirm --needed rust nodejs npm zstd sudo

group_name="builder"
if getent group "$RUNNER_GID" >/dev/null; then
    group_name="$(getent group "$RUNNER_GID" | cut -d: -f1)"
else
    groupadd --gid "$RUNNER_GID" "$group_name"
fi
useradd --create-home --uid "$RUNNER_UID" --gid "$group_name" builder

# makepkg 拒绝以 root 身份运行，因此使用与宿主 runner 相同 UID 的普通用户。
runuser -u builder -- env \
    HOME=/home/builder \
    PACKAGE_VERSION="$PACKAGE_VERSION" \
    bash -c 'cd /work && cargo build --release -p codex-update-manager && ./scripts/build-pacman.sh'

package_file="$(find dist -maxdepth 1 -type f -name 'codex-desktop-*.pkg.tar.zst' -print -quit)"
test -n "$package_file"
test -f "$package_file"

# 校验 pacman 元数据以及发布包必须包含的关键文件。
pacman -Qip "$package_file"
pacman -Qlp "$package_file" | tee /tmp/pacman-release-contents.txt >/dev/null
tar -xOf "$package_file" .PKGINFO | tee /tmp/pacman-release-pkginfo.txt >/dev/null
grep -q '^pkgname = codex-desktop$' /tmp/pacman-release-pkginfo.txt
grep -q '^arch = x86_64$' /tmp/pacman-release-pkginfo.txt
grep -q 'opt/codex-desktop/start.sh' /tmp/pacman-release-contents.txt
grep -q 'usr/bin/codex-update-manager' /tmp/pacman-release-contents.txt
grep -q 'usr/lib/systemd/user/codex-update-manager.service' /tmp/pacman-release-contents.txt

printf '%s\n' "$package_file" > /work/.pacman-release-package
