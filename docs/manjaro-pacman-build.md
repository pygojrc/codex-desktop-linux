<2026-08-15> 分析 codex-desktop Manjaro（pacman）安装包构建及可选构建选项

# codex-desktop Manjaro 安装包构建分析

> 仓库：/data/projects/Local/codex-desktop-linux
> 目标：分析如何构建 Manjaro 安装包（pacman / PKGBUILD）及可选构建选项。

## 一、构建入口与总体流程

Manjaro 基于 Arch Linux，使用 `pacman` + `makepkg`。构建入口为 `make pacman`，核心脚本：

- `scripts/build-pacman.sh`：pacman 专属打包脚本
- `packaging/linux/PKGBUILD.template`：PKGBUILD 模板
- `scripts/lib/package-common.sh`：跨格式（deb/rpm/pacman）通用暂存逻辑
- `scripts/lib/linux-features.js`：特性（features）依赖/资源/钩子渲染

`make pacman` 流程（`scripts/build-pacman.sh`）：

1. 前置校验 `ensure_app_layout`：必须先在 `codex-app/` 生成官方上游应用（`make build-app` 或 `./install.sh`）；校验 `start.sh`、`ChatGPT`、`app.asar`、`codex` 存在。
2. 架构映射 `map_arch`：`x86_64`→上游 `amd64`，`aarch64`→`arm64`，其它报错。
3. 版本：`pkgver` 默认 `date -u +%Y.%m.%d.%H%M%S`，`pkgrel=1`。
4. 阶段化（staging）：复制 `codex-app/` 到 `opt/codex-desktop`，按是否启用 updater、启用的 Linux features 注入桌面项、图标、AppArmor、systemd 服务等。
5. 渲染 PKGBUILD：sed 替换 `__PACKAGE_NAME__` / `__PKGVER__` / `__ARCH__` / `__STAGING_DIR__` / `__LINUX_FEATURE_DEPENDENCIES__` 等占位符（`build-pacman.sh:150`）。
6. 调用 `makepkg -f --nodeps --skipinteg`，`PKGEXT=.pkg.tar.zst`，输出到 `dist/`，并建 `codex-desktop-latest.pkg.tar.zst` 软链（`build-pacman.sh:206`）。
7. 调用 makepkg 前会先 `maybe-build-updater` 编译 Rust updater（除非 `PACKAGE_WITH_UPDATER=0`）。

注意：makepkg **禁止以 root 运行**（`build-pacman.sh:103`）。

## 二、可选构建选项

### A. Makefile 变量（推荐方式）

| 变量 | 默认值 | 作用 |
|------|--------|------|
| `PACKAGE_WITH_UPDATER` | `1` | `0` 时去掉 `codex-update-manager`、polkit/curl/dpkg/gnupg/nodejs 等 updater 专用依赖与 update-builder 包，桌面项移除更新动作；并跳过 Rust updater 编译 |
| `MAX_BUILD_THREADS` | `0` | 非 0 时生成带 `-jN` 与 `zstd -T` 的 `makepkg.conf`，加速压缩（`build-pacman.sh:54`） |
| `PACKAGE_VERSION` | 时间戳 | 覆盖 `pkgver`（`Makefile:123`） |
| `UPSTREAM_DEB` | 空 | 传入本地官方 `.deb` 作为结构输入（非信任根） |
| `PACMAN_STAGE_ONLY` | `0`（关） | `1` 时仅生成 `dist/pacman-stage/` + 渲染好的 `PKGBUILD`，不调用 makepkg（`build-pacman.sh:190`） |

### B. 包名/图标/源覆盖

- `PACKAGE_NAME`：改包名（默认 `codex-desktop`），所有 `opt/codex-desktop`、`.desktop`、`.install`、二进制名统一替换 `PACKAGE_NAME_PLACEHOLDER`。
- `PACKAGE_ICON_SOURCE`：自定义图标（`scripts/lib/package-common.sh:367`）。
- `UPDATER_BINARY_SOURCE` / `UPDATER_SERVICE_SOURCE` / `PACKAGED_RUNTIME_SOURCE`：覆盖 updater 二进制、systemd 服务模板、运行时来源。
- `APP_DIR_OVERRIDE` / `DIST_DIR_OVERRIDE`：指向已有 `codex-app/` 与自定义 `dist/`。
- `MAKEPKG_CONF`：完全自定义 makepkg 配置。

### C. Linux 特性（features）

通过 `make setup-native`（`scripts/bootstrap-wizard.sh`）交互向导或 `CODEX_LINUX_FEATURES=a,b` 选择。**默认全部禁用**（提交态 `features.json` 为空）。由 `scripts/lib/linux-features.js` 处理（`SUPPORTED_PACKAGE_FORMATS` 含 `"pacman"`）：

1. 包依赖 `packageDependencies.{pacman:[...]}`：构建时
   `node scripts/lib/linux-features.js --package-dependencies pacman <app-dir>`
   并入 PKGBUILD `depends`（`build-pacman.sh:157`）。
   - 现状：当前仓库所有 `linux-features/*/feature.json` **均未声明 `packageDependencies`**（搜索 0 命中），机制已就位但未启用；特性主要靠 `resources`/`stage.sh` 注入。
   - 校验：依赖 token 必须匹配 `^[A-Za-z0-9][A-Za-z0-9+._:@()=<>~\/-]*$`（`PACKAGE_DEPENDENCY_PATTERN`，`linux-features.js:32`）；pacman 不支持 rpm 的 `%{codex_elf_suffix}` 后缀。
2. 包资源 `packageResources`：声明 `{ source, target, mode, formats }`。pacman 限制：
   - `target` 根路径禁止占用 `.BUILDINFO/.CHANGELOG/.INSTALL/.MTREE/.PKGINFO`（`PACMAN_RESERVED_PACKAGE_TARGETS`，`linux-features.js:35`）。
   - `formats` 可限定仅对该格式生效；多特性 `target` 不可重复/互相包含。
   - 资源须为普通文件，不能是符号链接祖先链。
3. 包安装钩子 `packageHooks`（`stage.sh`）：`--stage-package-resources` / `--package-hooks pacman`，用于生成 `.install` 片段、附加文件、改权限。

可用特性约 30 个（全部 `defaultEnabled:false`）：`computer-use-linux`、`global-dictation`、`omarchy-theme`、`read-aloud`、`record-and-replay`、`frameless-titlebar`、`ui-tweaks`、`appshots`、`mcp-helper-reaper`、`pet-overlay`、`authenticated-proxy`、`codex-micro` 等。

## 三、各选项对最终 PKGBUILD/包的影响对照

- `PACKAGE_WITH_UPDATER=1`（默认）：`depends` 追加 polkit/curl/dpkg/gnupg/nodejs 等 updater 专用依赖；包内含 `codex-update-manager`、update-builder、polkit 规则、D-Bus/systemd 用户服务、桌面项更新动作。
- `PACKAGE_WITH_UPDATER=0`：无 updater 相关依赖/文件/服务/动作，且跳过 Rust 编译，构建最快。
- `MAX_BUILD_THREADS=8`：对大包（上游 Electron 应用数百 MB）主要在 zstd 压缩阶段并行提速。
- `PACMAN_STAGE_ONLY=1`：保留 `dist/pacman-stage/PKGBUILD` + `opt/codex-desktop` 暂存树，便于审计或手动 `makepkg`。

## 四、推荐组合与最简命令

```bash
# 安装构建依赖（Arch/Manjaro 分支含 base-devel/rustup/nodejs 等）
bash scripts/install-deps.sh

# 生成官方上游应用（需网络校验签名仓库）
CODEX_LINUX_FEATURES= ./install.sh            # 无特性

# 最小包：无 updater、无特性
PACKAGE_WITH_UPDATER=0 CODEX_LINUX_FEATURES= make pacman

# 带并行压缩 + 启用特性
MAX_BUILD_THREADS=8 CODEX_LINUX_FEATURES=omarchy-theme,frameless-titlebar make pacman

# 仅生成 PKGBUILD 做审计/二次打包
PACKAGE_WITH_UPDATER=0 PACMAN_STAGE_ONLY=1 make pacman
# 手动：
cd dist/pacman-stage && makepkg -f --nodeps --skipinteg

# 固定版本号（可复现构建）
PACKAGE_VERSION=1.2.3 make pacman

# 安装（普通用户构建，root 安装）
sudo pacman -U --noconfirm dist/codex-desktop-latest.pkg.tar.zst
```

## 五、产物与安装位置

- `dist/codex-desktop-<ver>-1-<arch>.pkg.tar.zst`（arch: `x86_64`/`aarch64`）
- `dist/codex-desktop-latest.pkg.tar.zst`（软链）
- `dist/pacman-stage/`（仅 `PACMAN_STAGE_ONLY` 时保留）
- 安装后文件位于 `/opt/codex-desktop/`（符合 AGENTS.md 输出身份约束）；桌面名 **ChatGPT Community**，图标为社区专属图标。

## 六、约束提醒（来自仓库 AGENTS.md）

- 仅支持最新签名官方 stable 包（amd64/arm64）；不安装上游 APT 源/密钥/包身份/维护脚本。
- 信任 `InRelease`（经固定密钥）→ 校验 `Packages` 与包 SHA-256；`latest` URL 非信任根。
- 无启用 ASAR 特性时，须保持 `resources/app.asar` 字节级一致。
- 自定义包与官方包可共存，但都使用上游 `Codex` 用户配置，**不可并发运行**。
- 不编辑生成产物（`codex-app/`、`dist/`、`target/` 等）。

## 七、本次结论：关闭 updater

本次 Manjaro 构建决定使用不包含 updater 的 pacman 包。该选择只作用于本次
构建命令，不修改仓库默认值；仓库默认仍为 `PACKAGE_WITH_UPDATER=1`。

推荐命令：

```bash
PACKAGE_WITH_UPDATER=0 make pacman
```

关闭后，构建器会跳过 `codex-update-manager` 的 Rust 编译，并在生成的
`PKGBUILD` 中移除 updater 专用依赖 `polkit`、`curl`、`dpkg`、`gnupg`、
`nodejs`；最终包也不包含 update-builder、systemd user service、polkit
policy 和 updater 安装钩子。应用本体、`codex-desktop` 命令、桌面入口、
AppArmor 配置以及已启用 Linux features 仍然保留。

关闭 updater 后，软件包不再提供事务式自动更新；后续更新需要重新获取并
验证官方 payload、重新构建 pacman 包，再手动安装，例如：

```bash
PACKAGE_WITH_UPDATER=0 make build-app
PACKAGE_WITH_UPDATER=0 make pacman
sudo pacman -U --noconfirm dist/codex-desktop-latest.pkg.tar.zst
```

如果使用本地可信官方 `.deb`，应显式传入 `UPSTREAM_DEB`；该输入仍会执行
包结构和 SHA-256 检查，但来源真实性由调用者负责：

```bash
UPSTREAM_DEB=/absolute/path/chatgpt_<version>_<arch>.deb \
PACKAGE_WITH_UPDATER=0 make build-app
PACKAGE_WITH_UPDATER=0 make pacman
```

关闭 updater 不等于关闭 Linux features。若需要同时构建无 updater、无可选
feature 的最小包，应先使用空的 `features.json`，然后执行：

```bash
PACKAGE_WITH_UPDATER=0 make pacman
```

验收重点是确认包内不存在 updater 相关文件和依赖，同时确认 `/opt/codex-desktop`
下的官方运行时、桌面入口和 `resources/app.asar`（无 ASAR feature 时）仍符合
原有构建约束。
