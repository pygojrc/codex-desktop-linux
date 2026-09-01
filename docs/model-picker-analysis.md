# 快速模型选择器代码分析

- 分析仓库：`pygojrc/codex-desktop-linux`
- 分析基线：`8fd522346cac878db34cf5d242a71cdccc4f92aa`
- 目标平台：Manjaro KDE x86_64
- 结论：当前仓库没有快速模型选择器的业务代码；选择器属于官方 ChatGPT Linux 应用的打包运行时。

## 一、当前仓库实际包含什么

当前构建链是：

```
官方 chatgpt_amd64.deb
    -> dpkg-deb -x
    -> 替换 /usr/bin/chatgpt 为 Fcitx 包装脚本
    -> makepkg
    -> codex-desktop-*.pkg.zst
```

关键位置：

| 位置 | 作用 | 是否包含模型选择器实现 |
| --- | --- | --- |
| `PKGBUILD` | 声明 Manjaro/Arch 包元数据和依赖 | 否 |
| `scripts/build-manjaro.sh` | 下载官方 `.deb`、解包、写入包装脚本、重打包 | 否 |
| `/usr/bin/chatgpt` | 启动包装脚本，设置 Fcitx 环境后执行官方运行时 | 否 |
| `/usr/lib/chatgpt/codex-launcher` | 官方应用启动入口 | 不是选择器源码 |
| 官方运行时的 `resources/app.asar` 及其中的 webview bundle | Electron 应用和 ChatGPT Web UI | 是，快速模型选择器在这里 |

当前项目的构建脚本只调用 `dpkg-deb -x` 提取 data archive，不执行 Debian maintainer scripts，也没有修改 `app.asar`。因此，在当前已发布的包中，模型选择器仍然是官方应用原样提供的。

## 二、快速滑动选择器的代码位置

这里需要区分两个 UI：

1. 紧凑的 Power/快速滑动控件：滑动的是 reasoning effort（例如 low、medium、high 等），实际可用档位来自模型对象的 `supportedReasoningEfforts`。
2. 详细模型列表：显示具体模型选项，运行时结构中表现为 `config.model.options`。

历史仓库中保留过一份针对官方 bundle 的定位补丁。它不是当前项目的依赖，但可以作为代码定位依据：

- [历史 model-picker-model-list.js](https://github.com/ilysenko/codex-desktop-linux/blob/705620c37f7d2e2b0e1ca286ff1d723dd5db127b/linux-features/ui-tweaks/patches/model-picker-model-list.js)
- [历史 ui-tweaks/patch.js](https://github.com/ilysenko/codex-desktop-linux/blob/705620c37f7d2e2b0e1ca286ff1d723dd5db127b/linux-features/ui-tweaks/patch.js)

该补丁通过以下特征定位官方压缩 bundle：

- 文件名匹配：`app-initial-*.js`
- 菜单视图标记：`composer-model-picker-menu-view-v1`、`composer-model-picker-menu-view-v2`
- 组件标记：`chatgpt-model-picker`
- 模型选项渲染：`.options.map(...)`
- 推理档位计算：`supportedReasoningEfforts`

对应函数如下：

| 函数 | 作用 |
| --- | --- |
| `applyDefaultAdvancedViewPatch` | 将模型选择器默认视图从 simple 切换到 advanced |
| `applyInlineModelListPatch` | 把 `config.model.options` 直接渲染到列表中 |
| `findDynamicPowerSelectionsFunction` | 定位快速 Power 选择器的档位计算函数 |
| `applyDynamicSupportedReasoningEffortsPatch` | 根据模型支持的 reasoning effort 动态构造快速滑动档位 |
| `applyModelPickerModelListPatch` | 组合上述模型选择器补丁 |

因此，“快速滑动选择模型”的核心不是一个可以在当前仓库直接编辑的固定数组，而是官方 webview bundle 中的模型过滤和 reasoning-effort 映射逻辑。

## 三、是否可以增加或修改快速模型列表

可以，但有前提，且需要修改构建阶段的官方 `app.asar`；仅修改 `PKGBUILD`、`/usr/bin/chatgpt` 或 KDE desktop entry 不能改变模型列表。

### 1. Luna 已经由上游返回时

如果上游的模型接口已经返回 Luna，例如：

```json
{
  "model": "gpt-5.6-luna",
  "hidden": false,
  "supportedReasoningEfforts": ["low", "medium", "high"]
}
```

并且当前账号、灰度开关和服务端权限允许，那么详细模型列表通常可以自动显示它。历史补丁的测试数据也曾使用 `gpt-5.6-luna` 和 `gpt-5.6-terra` 作为可见模型示例。

这种情况下，优先检查：

- `model/list` 返回值中是否有 Luna；
- `hidden` 是否为 false；
- ChatGPT web UI 的 rollout/allowlist 是否过滤了它；
- 当前账号是否有该模型权限。

如果 Luna 被服务端返回但只被本地的 `available_models` allowlist 隐藏，修改过滤条件可能有用；如果服务端没有返回，单纯在 UI 中增加一项并不能保证请求成功。

### 2. 让 Luna 出现在紧凑 Power/快速滑动控件中

这和“详细模型列表出现 Luna”不是同一件事。快速滑动控件通常根据 `supportedReasoningEfforts` 生成档位，并且需要满足当前 bundle 的最少档位数量和筛选规则。

因此 Luna 要进入快速控件，至少要满足：

- Luna 是当前会话实际选中的模型；
- Luna 有足够的 `supportedReasoningEfforts`；
- 该模型没有被 `hidden`、服务端 allowlist 或客户端 host/auth 规则过滤；
- 快速控件的 resolver 接受该模型，而不是只处理某个硬编码模型 ID。

如果目标只是“在快速入口能选 Luna 模型”，更可能需要修改模型候选项映射，而不是只改滑块的标签。模型 ID 必须使用上游真实接受的 ID，不能只显示一个自定义名称。

### 3. 上游没有返回 Luna 时

也可以做实验性 UI 注入，但风险较高：

- UI 可以显示选项，但后端可能拒绝该模型 ID；
- 可能被登录方式、订阅等级、区域或 rollout 再次过滤；
- 新版 ChatGPT 更新后，压缩变量名、bundle 文件名和函数结构可能变化；
- 错误 patch 可能导致 webview 白屏或模型选择器无法打开。

所以不建议把一个未经服务端确认的 Luna ID 写死为默认发布功能。

## 四、建议的实现方式

若要实际加入 Luna，建议把修改放在 `scripts/build-manjaro.sh` 的 `dpkg-deb -x` 之后、`makepkg` 之前：

```
解包官方 .deb
  -> 识别 resources/app.asar
  -> 解包 app.asar
  -> 按 app-initial-*.js 和稳定字符串定位模型选择器
  -> 修改候选模型/allowlist 或显示逻辑
  -> 重新打包 app.asar
  -> 运行针对当前上游版本的 bundle fixture 测试
  -> makepkg
```

应遵守以下边界：

- 不恢复或引入 `ilysenko/codex-desktop-linux` 的完整功能树；
- 只保留一个小型、版本感知的构建补丁；
- patch 找不到稳定 marker 时应跳过或失败，不要对所有 JS 做无条件替换；
- 每个上游版本构建后检查模型选择器是否仍能打开；
- 至少验证详细列表、Power 滑块、发送请求和 Fcitx/Wubi 输入；
- 在 release metadata 中记录上游版本和 patch 是否命中。

## 五、如何在已安装版本中确认实际文件

在 Manjaro 上可以先确认官方 bundle 的位置：

```bash
find /usr/lib/chatgpt -type f \\
  \\( -name '*.asar' -o -name 'app-initial-*.js' \\) -print
```

如果系统安装了 `asar` 工具，再检查 archive 内的目标文件：

```bash
asar list /usr/lib/chatgpt/resources/app.asar \\
  | rg 'app-initial|webview|preload'
```

直接搜索定位字符串：

```bash
strings /usr/lib/chatgpt/resources/app.asar \\
  | rg 'composer-model-picker|chatgpt-model-picker|supportedReasoningEfforts|gpt-5.6-luna'
```

上游版本变化时，`app-initial-<hash>.js` 中的 hash 会变化；因此不能把某一个 hash 当成永久路径，应该用文件名模式和稳定 marker 定位。

## 六、最终判断

- 当前仓库没有可直接修改的“快速模型列表”源码，相关代码在官方 ChatGPT Linux `app.asar` 的压缩 webview bundle 中。
- 历史补丁已明确给出可定位的 bundle 模式、菜单 marker、模型选项渲染点和 Power slider resolver。
- 可以增加/修改 Luna，但应该在构建时 patch 官方 `app.asar`，并同时验证服务端模型 ID、权限和 `supportedReasoningEfforts`。
- 如果 Luna 已由 `model/list` 返回，优先修正客户端过滤/allowlist；如果没有返回，不建议仅靠 UI 硬编码后直接发布。
