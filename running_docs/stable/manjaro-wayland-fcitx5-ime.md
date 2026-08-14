<2026-08-15> Manjaro KDE Wayland + Fcitx5 Rime 五笔输入延迟分析与测试建议

# Manjaro KDE Wayland + Fcitx5 Rime 五笔输入问题

## 现象

用户在 Manjaro Linux、KDE、Wayland、Fcitx5、Rime 五笔环境中使用官方
Linux `.deb` 和本项目发布的 Arch 包时，快速敲击五笔编码会出现输入延迟或
丢失，导致输入框收到的内容与预期不符。用户反馈，早期基于 `.dmg` 修改的
Linux 版本未观察到同样问题。

当前分析未在用户真实桌面窗口中自动复现，也未将问题标记为已修复。后续需要
由用户在真实 KDE Wayland 会话中人工执行 A/B 测试并确认。

## 已确认的本地证据

- 当前可见系统为 Manjaro Linux、x86_64、KDE、Wayland。
- 当前可见 Fcitx5 版本为 `5.1.21`，已安装 Wayland input method frontend，
  默认输入法为 Rime。
- 用户下载的包为
  `codex-desktop-26.810.41047+7492fc5fd18a-1-x86_64.pkg.tar.zst`。
- 包内 `build-info.json` 显示上游来源为官方 Linux `chatgpt_26.810.41047_amd64.deb`。
- 包内 `patch-report.json` 显示没有启用 ASAR patch，且
  `resources/app.asar` 的 `preservedByteForByte` 为 `true`。
- 包内 launcher 默认只增加 `--class=codex-desktop`、桌面身份和项目 hook，
  没有默认加入 Wayland、X11 或输入法参数。
- launcher 允许通过
  `${XDG_CONFIG_HOME:-$HOME/.config}/codex-desktop/electron-flags.conf`
  或命令行传入 Electron 参数。

因此，官方 `.deb` 与本项目 Arch 包都复现问题时，问题更可能位于官方
Electron/Chromium runtime、Wayland、KWin 和 Fcitx5 之间，而不是 pacman
打包或本项目的 ASAR 修改。

## 公开资料结论

Fcitx 官方 Wayland 文档指出，Wayland 输入法依赖 compositor 与应用之间的
text-input 协议；Electron/Chromium 原生 Wayland 需要额外的 Ozone/IME 参数。
对于 KDE KWin，文档提示 text-input-v1 与 text-input-v3 存在兼容差异，并建议
优先测试 text-input-v1。KDE Wayland 下还建议不要全局设置
`GTK_IM_MODULE`、`QT_IM_MODULE`、`SDL_IM_MODULE`，保留
`XMODIFIERS=@im=fcitx` 用于 XWayland 应用。

参考：[Fcitx 官方 Wayland 使用说明](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en)。

Fcitx5 issue #1077 报告了 Arch + Wayland 环境中输入法冻结、候选框异常和
输入暂时无法继续的同类现象：[Fcitx5 lagging](https://github.com/fcitx/fcitx5/issues/1077)。
Fcitx5 issue #1602 则报告了 Electron 应用与 Fcitx5 的兼容问题，说明该组合
仍有公开活动问题，但该 issue 主要是 X11 环境，不能直接等同于当前 Wayland
问题：[Does not work with Electron-based programs](https://github.com/fcitx/fcitx5/issues/1602)。
Electron 上游也曾长期跟踪原生 Wayland IME 支持问题：[Electron #33662](https://github.com/electron/electron/issues/33662)。

## 当前原因排序

1. Electron/Chromium 原生 Wayland IME 与 KWin/Fcitx5 Wayland frontend 的
   输入上下文或事件时序问题。
2. KWin 与 Electron/Chromium 实际使用的 text-input 协议版本不匹配，尤其是
   text-input-v1/v3 的选择。
3. 官方 Linux runtime 所带 Electron/Chromium 版本存在输入法回归，或与旧的
   `.dmg` 版本使用了不同的 Electron/Ozone 后端。
4. 实际桌面进程继承了与 KDE Wayland 不匹配的 GTK/Qt/SDL 输入法环境变量。
5. Rime 五笔预编辑、候选词提交与 Electron renderer 的 commit 时序问题。

本项目 pacman 打包本身的可能性较低：官方 `.deb` 也有相同现象，且本项目
没有修改官方 `app.asar`。

## 建议的人工 A/B 测试

测试前需要从托盘和窗口中完全退出官方 `.deb` 版本及
`codex-desktop`，避免已有 Electron 单实例接管后续启动参数。不要同时运行
两个版本。

每次测试都使用同一个 Codex 输入框、同一个 Rime 五笔方案和同一组固定测试
文本。建议先慢速确认，再快速连续输入 20 次；记录最终提交文字、是否丢字、
是否出现候选框卡住，以及重新聚焦输入框后是否恢复。

### A：强制 XWayland

```bash
env -u GTK_IM_MODULE \
    -u QT_IM_MODULE \
    -u SDL_IM_MODULE \
    XMODIFIERS=@im=fcitx \
    /usr/bin/codex-desktop --ozone-platform=x11
```

如果 A 测试明显恢复，说明问题集中在原生 Wayland IME 路径，而不是 Rime
词库或 Codex 网页输入框本身。

### B：强制原生 Wayland + Fcitx IME + KWin 推荐的 v1

```bash
env -u GTK_IM_MODULE \
    -u QT_IM_MODULE \
    -u SDL_IM_MODULE \
    XMODIFIERS=@im=fcitx \
    /usr/bin/codex-desktop \
    --enable-features=UseOzonePlatform \
    --ozone-platform=wayland \
    --enable-wayland-ime \
    --wayland-text-input-version=1
```

如果 B 比默认启动明显改善，说明默认 Electron/Chromium 的 Wayland IME 参数
或协议版本选择可能是问题点。

### C：验证是否为环境变量污染

A、B 都显式取消了 `GTK_IM_MODULE`、`QT_IM_MODULE` 和 `SDL_IM_MODULE`。
如果取消后恢复，而不取消时异常，则需要检查 KDE 会话、`im-config`、shell
profile 和桌面启动器中是否全局写入了这些变量。KDE Wayland 不应仅根据
`fcitx5-diagnose` 的通用警告就把这三个变量全局设为 `fcitx`。

### D：持久化参数测试（可选）

如果命令行 A 或 B 已经证明某一套参数有效，可临时写入项目专用配置，避免
影响其它应用：

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/codex-desktop"
printf '%s\n' '--ozone-platform=x11' > \
  "${XDG_CONFIG_HOME:-$HOME/.config}/codex-desktop/electron-flags.conf"
```

上面的例子只持久化 A 的 XWayland 参数。若验证 B 有效，应按 B 的参数每行
写入一个完整参数。测试完成后删除该项目专用文件即可恢复默认行为：

```bash
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/codex-desktop/electron-flags.conf"
```

该删除只针对项目专用配置文件，不涉及系统输入法配置。

## 人工判定标准

- **确认修复**：同一固定五笔测试，在快速输入 20 次中不再丢字，最终提交
  内容与慢速输入一致，候选框和输入焦点均正常。
- **部分改善**：丢字次数明显降低，但仍有可复现错误；记录使用的参数和
  复现频率，不能标记为完全修复。
- **未修复**：A、B、默认启动均有相同错误；下一步应收集运行中的 Electron
  后端、Fcitx 输入上下文和 Wayland debug 日志，而不是继续修改 pacman
  workflow。

## 当前状态

当前仅完成静态分析和公开资料核对，没有修改运行时、没有修改系统输入法配置，
也没有声称问题已经修复。

## 首轮人工测试结果

- 方案 2（强制 XWayland，但使用了取消 `GTK_IM_MODULE`、`QT_IM_MODULE`、
  `SDL_IM_MODULE` 的命令）未修复输入延迟。该结果暂时不能证明 XWayland
  路径无效，因为 Fcitx 官方对 XWayland Electron 建议按 X11 路径设置
  `GTK_IM_MODULE=fcitx`，需要补做校正后的测试。
- 方案 3（原生 Wayland + `--enable-wayland-ime` + text-input-v1）无法调用
  五笔输入法，说明这套参数下 Electron 没有建立可用的 Fcitx Wayland 输入
  上下文，暂不建议持久化该参数。
- 当前下一步优先测试“XWayland + 每应用 Fcitx GTK/XIM 环境”，并单独测试
  不显式指定 text-input 版本的原生 Wayland 参数。

## 第二轮人工测试结果

用户确认以下两种命令行启动方式均可正常调用 Fcitx5 Rime 五笔，快速输入也
未观察到此前的异常：

### 原生 Wayland

```bash
env -u GTK_IM_MODULE \
    -u QT_IM_MODULE \
    -u SDL_IM_MODULE \
    XMODIFIERS=@im=fcitx \
    /usr/bin/codex-desktop \
    --enable-features=UseOzonePlatform \
    --ozone-platform=wayland \
    --enable-wayland-ime
```

### XWayland

```bash
env GTK_IM_MODULE=fcitx \
    XMODIFIERS=@im=fcitx \
    /usr/bin/codex-desktop \
    --ozone-platform=x11
```

该结果将原因进一步收敛为启动参数/环境组合问题：

1. 原生 Wayland 需要显式启用 `UseOzonePlatform`、`ozone-platform=wayland`
   和 `enable-wayland-ime`；不应继续显式固定 `text-input-v1`，因为本机该
   参数组合无法调用五笔。
2. XWayland Electron 需要为应用进程设置 `GTK_IM_MODULE=fcitx` 和
   `XMODIFIERS=@im=fcitx`；之前取消 `GTK_IM_MODULE` 的测试不能代表完整的
   XWayland + Fcitx 配置。
3. 两种命令行方案均正常只证明启动参数级人工验证通过；尚未修改项目默认
   launcher，也未验证桌面菜单直接启动是否自动带上这些参数。

在最终 `.desktop` 验证前，原生 Wayland 方案曾作为默认候选，XWayland 方案
作为兼容性回退路径。最终人工验证表明，当前项目无需改变 Ozone 后端，只需
在桌面入口设置 Fcitx 环境变量即可解决问题。

## 最终人工验证结果

用户进一步确认：不需要给 Codex 增加 Wayland Ozone 参数，只需要在 pacman
桌面入口的 `Exec=env` 中加入以下两个环境变量，五笔输入即可正常工作：

```text
GTK_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
```

验证结论：

- 从 KDE 应用菜单通过 `.desktop` 启动时，加入这两个变量后五笔输入正常；
- 快速输入不再出现此前的输入延迟或丢字现象；
- 不需要设置 `--wayland-text-input-version=1`；
- 不需要修改系统级环境变量；
- 不需要修改 `resources/app.asar` 或 Electron runtime。

因此，针对当前 Manjaro pacman 发布目标，最小修复位置应是
`packaging/linux/codex-desktop.desktop` 的两个 `Exec=env` 行，包括普通启动
和 `new-window` 启动入口。计划加入变量但尚未实施：

```ini
Exec=env GTK_IM_MODULE=fcitx XMODIFIERS=@im=fcitx ... /usr/bin/codex-desktop %u
```

该结论只覆盖 KDE 应用菜单通过 pacman 桌面入口启动的路径；直接运行
`/usr/bin/codex-desktop` 时仍不会自动获得这两个变量，除非由调用环境提供。
