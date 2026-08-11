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
    PACKAGE_WITH_UPDATER="${PACKAGE_WITH_UPDATER:-0}" \
    bash -c 'cd /work && ./scripts/build-pacman.sh'

package_file="$(find dist -maxdepth 1 -type f -name 'codex-desktop-*.pkg.tar.zst' -print -quit)"
test -n "$package_file"
test -f "$package_file"

# 校验 pacman 元数据、启动器和发布包不含本地更新器。
pacman -Qip "$package_file"
pacman -Qlp "$package_file" | tee /tmp/pacman-release-contents.txt >/dev/null
tar -xOf "$package_file" .PKGINFO | tee /tmp/pacman-release-pkginfo.txt >/dev/null
grep -q '^pkgname = codex-desktop$' /tmp/pacman-release-pkginfo.txt
grep -q '^arch = x86_64$' /tmp/pacman-release-pkginfo.txt
grep -q 'opt/codex-desktop/start.sh' /tmp/pacman-release-contents.txt
if grep -qE '(^|/)codex-update-manager(\.service)?$' /tmp/pacman-release-contents.txt; then
    echo "发布包不得包含 codex-update-manager 或其 systemd 服务" >&2
    exit 1
fi

printf '%s\n' "$package_file" > /work/.pacman-release-package
