<2026-08-15> Arch pacman Release workflow

- 目标：仅发布可由 Manjaro/Arch pacman 安装的 `codex-desktop` 包。
- 决定：新增独立 `release-pacman.yml`，固定 `PACKAGE_WITH_UPDATER=0`，不发布 deb、RPM 或 AppImage。
- 构建边界：两个 GitHub runner 分别运行 x86_64 与 aarch64 Arch 容器；容器中先验证当前签名官方 Linux `.deb`，再以普通用户真实执行 `makepkg`。
- 发布边界：仅在 `pygojrc/codex-desktop-linux` 的 main push 或手动触发时发布；Release 同时附带两个 `.pkg.tar.zst` 和 `SHA256SUMS`。
- 修订：首轮 aarch64 runner 无法拉取固定 amd64 Arch 镜像；按用户要求收紧为仅发布 x86_64 包，并移除 aarch64 构建与发布路径。
- 结果：提交 `7492fc5` 触发的 GitHub Actions run `31822457745` 已通过；Arch 容器中的真实 `makepkg`、产物 SHA-256 二次校验与 GitHub Release 上传均完成。Release tag 为 `arch-26.810.41047-7492fc5fd18a`，发布 x86_64 pacman 包及 `SHA256SUMS`。
- 修复：发布 workflow 不再上传 `dist/` 下的 `latest` 软链接，只复制并上传明确版本包到 `dist/release/`，避免同一包以两个文件名重复进入 Release。
- 2026-08-15 输入法分析：用户反馈 Manjaro KDE Wayland + Fcitx5 Rime 五笔快速输入存在延迟或丢字，官方 `.deb` 与本项目 Arch 包均复现。只读检查确认包内官方 `ChatGPT` runtime 和 `resources/app.asar` 未修改，launcher 未默认加入 Wayland/X11/IME 参数；公开资料将问题优先指向 Electron/Chromium 原生 Wayland、KWin text-input 协议和 Fcitx5 frontend 的交互。已新增 `running_docs/stable/manjaro-wayland-fcitx5-ime.md`，等待用户通过 XWayland、Wayland text-input-v1 和环境变量隔离 A/B 测试人工确认，当前不标记为已修复。
- 2026-08-15 首轮人工测试：方案 2（取消 GTK/Qt/SDL IM 环境的 XWayland 启动）未修复；方案 3（原生 Wayland + text-input-v1）无法调用五笔。方案 2 结果不具备最终判定力，因为 XWayland Electron 按 Fcitx 官方建议应单独设置 `GTK_IM_MODULE=fcitx`；方案 3 表明当前显式 Wayland IME 参数未建立可用输入上下文。下一步补测校正后的 XWayland 组合，并测试不显式指定 text-input 版本的原生 Wayland组合。
- 2026-08-15 第二轮人工测试：原生 Wayland 使用 `--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime` 且不指定 `--wayland-text-input-version` 时正常；XWayland 使用 `GTK_IM_MODULE=fcitx XMODIFIERS=@im=fcitx --ozone-platform=x11` 时也正常。原因进一步收敛为 Electron 启动参数/输入法环境组合问题，显式 text-input-v1 参数不适合当前环境。当前只完成命令行人工验证，尚未修改默认 launcher 或验证桌面菜单启动。
- 2026-08-15 最终人工验证：用户确认只在 pacman 桌面入口 `.desktop` 的 `Exec=env` 中加入 `GTK_IM_MODULE=fcitx` 和 `XMODIFIERS=@im=fcitx`，通过 KDE 应用菜单启动后五笔输入即恢复正常。最小修复范围进一步收敛为 `packaging/linux/codex-desktop.desktop` 的普通启动和 `new-window` 两个 `Exec` 行；不修改 launcher、Electron Wayland 参数、系统级环境变量或官方 ASAR。当前仅记录验证结论，尚未实施源码修复、构建或发布。
