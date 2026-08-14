<2026-08-15> Arch pacman Release workflow

- 目标：仅发布可由 Manjaro/Arch pacman 安装的 `codex-desktop` 包。
- 决定：新增独立 `release-pacman.yml`，固定 `PACKAGE_WITH_UPDATER=0`，不发布 deb、RPM 或 AppImage。
- 构建边界：两个 GitHub runner 分别运行 x86_64 与 aarch64 Arch 容器；容器中先验证当前签名官方 Linux `.deb`，再以普通用户真实执行 `makepkg`。
- 发布边界：仅在 `pygojrc/codex-desktop-linux` 的 main push 或手动触发时发布；Release 同时附带两个 `.pkg.tar.zst` 和 `SHA256SUMS`。
- 修订：首轮 aarch64 runner 无法拉取固定 amd64 Arch 镜像；按用户要求收紧为仅发布 x86_64 包，并移除 aarch64 构建与发布路径。
- 结果：提交 `7492fc5` 触发的 GitHub Actions run `31822457745` 已通过；Arch 容器中的真实 `makepkg`、产物 SHA-256 二次校验与 GitHub Release 上传均完成。Release tag 为 `arch-26.810.41047-7492fc5fd18a`，发布 x86_64 pacman 包及 `SHA256SUMS`。
