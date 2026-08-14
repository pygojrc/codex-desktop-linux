<2026-08-15> Arch pacman Release workflow

- 目标：仅发布可由 Manjaro/Arch pacman 安装的 `codex-desktop` 包。
- 决定：新增独立 `release-pacman.yml`，固定 `PACKAGE_WITH_UPDATER=0`，不发布 deb、RPM 或 AppImage。
- 构建边界：两个 GitHub runner 分别运行 x86_64 与 aarch64 Arch 容器；容器中先验证当前签名官方 Linux `.deb`，再以普通用户真实执行 `makepkg`。
- 发布边界：仅在 `pygojrc/codex-desktop-linux` 的 main push 或手动触发时发布；Release 同时附带两个 `.pkg.tar.zst` 和 `SHA256SUMS`。
