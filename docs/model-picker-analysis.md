# 快速模型选择器：当前官方包解包分析

- 仓库：`pygojrc/codex-desktop-linux`
- 分析包：Release `manjaro-kde-26.831.20005`
- 包文件：`codex-desktop-26.831.20005-1-x86_64.pkg.zst`
- 包 SHA-256：`c7fcd75cbe91fa402c3bf2f157eb75abb7ac70218f2d6a3c11fcbd6e815d8d0d`
- 目标平台：Manjaro KDE x86_64

## 结论

本次已实际解包并校验 `app.asar`。当前版本的快速模型选择器不在历史补丁所说的 `app-initial-*.js`，而在：

```
/usr/lib/chatgpt/resources/app.asar
└── webview/assets/app-primary-a0bff570446b.js
```

主 bundle 是压缩的一行 JavaScript，文件大小为 7,777,355 字节。模型选择器相关代码位于大约 6,495,000～7,073,000 字节偏移处。

## 一、解包结果

包内实际确认到：

| 文件 | 大小 | 作用 |
| --- | ---: | --- |
| `/usr/lib/chatgpt/resources/app.asar` | 292,412,845 字节 | Electron 主应用归档 |
| `/usr/lib/chatgpt/resources/busy-bar.asar` | 1,013,392 字节 | Busy Bar 独立归档，不是模型选择器 |
| `app.asar/webview/assets/app-primary-a0bff570446b.js` | 7,777,355 字节 | 当前模型选择器所在主 webview bundle |
| `app.asar/webview/assets/app-initial-cccb87527a41.js` | 9,994,496 字节 | 当前包存在，但没有找到 `composer-model-picker` 标记 |

本次操作只在临时分析目录中完成了解包，没有修改或覆盖系统安装文件，也没有修改 Release 包。

## 二、当前版本的快速滑动控件

### 1. 核心构造函数：`hur`

在 `app-primary-a0bff570446b.js` 中：

```js
function hur(e, {
  includeUltraInSlider,
  removeXHigh,
  sliderModelsConfig
} = {})
```

它返回快速 Power/Reasoning 滑动控件使用的 `powerSelections`。

处理顺序：

1. 如果存在 `sliderModelsConfig.presets`，先按远程/运行时 preset 生成候选；
2. 将 preset 中的 `model` 和 `reasoning_effort` 与当前模型列表匹配；
3. 如果匹配结果至少有 3 项，则使用该结果；
4. 否则使用 bundle 内置的静态 `wur`；
5. 如果仍不足 3 项，回退到静态 `Eur`；
6. `ultra` 和 `xhigh` 是否参与由 `includeUltraInSlider`、`removeXHigh` 控制。

因此，快速滑动列表不是单纯的 UI 标签数组，而是“preset + 当前可用模型 + supported reasoning effort”的交集。

### 2. 当前版本实际静态候选

当前 bundle 中可以直接读到：

```js
wur = [
  { id: "gpt-5.6-terra:low",  model: "gpt-5.6-terra", modelLabel: "5.6 Terra", reasoningEffort: "low" },
  { id: "gpt-5.6-sol:low",    model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   reasoningEffort: "low" },
  { id: "gpt-5.6-sol:medium", model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   reasoningEffort: "medium" },
  { id: "gpt-5.6-sol:high",   model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   reasoningEffort: "high" },
  { id: "gpt-5.6-sol:xhigh",  model: "gpt-5.6-sol",   modelLabel: "5.6 Sol",   reasoningEffort: "xhigh" }
]

Tur = {
  id: "gpt-5.6-sol:ultra",
  model: "gpt-5.6-sol",
  modelLabel: "5.6 Sol",
  reasoningEffort: "ultra"
}

Eur = [
  { id: "gpt-5.6-terra:low",    model: "gpt-5.6-terra", reasoningEffort: "low" },
  { id: "gpt-5.6-terra:medium", model: "gpt-5.6-terra", reasoningEffort: "medium" },
  { id: "gpt-5.6-terra:high",   model: "gpt-5.6-terra", reasoningEffort: "high" },
  { id: "gpt-5.6-terra:xhigh",  model: "gpt-5.6-terra", reasoningEffort: "xhigh" }
]
```

注意：这是当前版本真实存在的静态列表。它并不包含 `gpt-5.6-luna`。Luna 通过另一个条件分支动态加入。

### 3. 相关辅助函数

| 函数/变量 | 当前作用 |
| --- | --- |
| `vur(e)` | 将模型对象的 `supportedReasoningEfforts` 展开为 `model:reasoningEffort` 候选 |
| `xur(e, t)` | 只保留存在于当前模型列表、且 reasoning effort 仍受支持的候选，并设置 `powerSettingIndex` |
| `q4(e, t)` | 获取选中模型的 `supportedReasoningEfforts` |
| `S9n(e, t)` | 校正当前 reasoning effort，使其落在可用档位中 |
| `C9n(e, t, n)` / `w9n(e, t)` | 在相邻 reasoning effort 档位之间切换 |
| `hur(e, ...)` | 组合 preset、静态列表和当前模型列表，生成快速滑动选择项 |
| `idr(e)` | 渲染 `powerSelections` 对应的滑动控件 |
| `kur()` | 延迟加载 `./impl-acbd30e29fda.js` 中的 `ModelPickerPowerSliderImpl` |

## 三、详细模型列表的位置

模型选择器控制器是压缩后的函数 `$Or(e)`，大约位于 bundle 偏移 7,054,732 附近。

它的主要流程是：

```
UT({ additionalAvailableModels, hostId })
  -> 得到模型列表
  -> modelsForPicker(...)
  -> 过滤可用模型
  -> vur(...)
  -> hur(...)
  -> 传给模型选择器菜单
```

在 `$Or` 中可以看到：

- `te`：经过 `modelsForPicker` 处理后的模型列表；
- `ue`：经过可用性处理后的模型选项；
- `je=ue?.filter(skr).map(okr)`：取出未禁用模型；
- `Me=vur(je)`：把模型展开成 model/reasoning 候选；
- `Le=hur(je,...)`：构造快速滑动列表；
- `v?.map(...)`：渲染详细模型菜单中的每一项；
- 选中时调用 `le(model, reasoningEffort)`。

菜单渲染函数 `fOr(e)` 大约位于偏移 7,022,xxx，负责把 `modelOptions` 渲染成菜单项。快速滑动控件则通过 `Dfr`、`idr` 和延迟加载的 `ModelPickerPowerSliderImpl` 渲染。

## 四、当前版本的 Luna 分支

当前 bundle 中确实存在 `gpt-5.6-luna`，关键代码位于 `$Or`：

```js
let x = vc(ur, b.hostId)

let W = x ? ["gpt-5.6-luna"] : []

let G = new Set([...additionalAvailableModels, ...W, selectedModel])

let { data: J } = UT({
  additionalAvailableModels: G,
  hostId: K
})
```

随后：

```let ne = te?.find(ckr)
let re = te

if (x) {
  re = ne == null ? [] : [{ ...ne, model: fIe }]
}
```

过滤函数为：

```function ckr(e) {
  let { model: t } = e
  return t === "gpt-reserve" || t === "gpt-5.6-luna"
}
```

这说明：

1. Luna 不是简单地写进静态 Power slider 数组；
2. 当 `x` 为真时，代码把 `gpt-5.6-luna` 加入模型查询的 `additionalAvailableModels`；
3. 然后从返回模型中选择 Luna/Reserve 候选，并把模型选项重写为内部的 Luna 选择；
4. `x` 来自压缩后的运行时 selector `vc(ur, b.hostId))，其具体符号名没有通过源码映射恢复；
5. `allowAeonDraftModelSelection`、`isAeonDraft`、`modelHostId` 等字段与这条特殊模型路径同时出现，表明 Luna 分支属于受权限/功能开关控制的特殊流程。

另外，bundle 中还有：

```gpt-5.6-luna-wm
```

它出现在 work-mode 相关逻辑中，不应与 composer 快速模型选择器的 `gpt-5.6-luna` 分支混为一谈。

## 五、能否把 Luna 加入快速滑动列表

可以，但要先区分目标。

### 目标 A：详细模型菜单显示 Luna

当前版本已经具备 Luna 的动态接入代码。更合理的做法是确认 `x` 对应的运行时条件是否满足，而不是直接伪造 UI 文本。

如果 `x` 为真，模型查询会收到 `gpt-5.6-luna` 作为额外模型候选。仍需满足：

- 账号/订阅拥有 Luna 权限；
- 服务端返回该模型；
- 模型没有被禁用；
- 当前请求链路接受真实模型 ID。

### 目标 B：Luna 出现在 Power 快速滑动控件

需要同时修改或满足：

- Luna 被加入当前 `je` 模型集合；
- Luna 的模型对象有有效的 `supportedReasoningEfforts`；
- `vur(je)` 能生成 Luna 的 `model:reasoningEffort` 条目；
- `hur(je,...)` 的 preset 或 fallback 能产生至少 3 个有效条目；
- `xur` 的交集检查通过；
- 选择回调 `le(model, reasoningEffort)` 将真实 Luna ID 发送到后端。

只增加：

```js
{ model: "gpt-5.6-luna", modelLabel: "5.6 Luna", reasoningEffort: "medium" }
```

通常是不够的，因为快速滑动控件有“至少 3 个有效档位”的门槛，而且后端模型列表、权限和 reasoning effort 仍然会参与过滤。

## 六、建议的 patch 点

如果后续决定在本项目构建时加入实验性 Luna 支持，推荐按以下优先级：

### 优先方案：启用现有 Luna 分支

在解包后的 `app-primary-*.js` 中，围绕 `$Or` 的以下逻辑做版本感知 patch：

```js
let x = vc(ur, b.hostId)
let W = x ? ["gpt-5.6-luna"] : []
...
if (x) {
  re = ne == null ? [] : [{ ...ne, model: fIe }]
}
```

但不能只把 `x` 的一个表达式替换为常量，必须验证：

- `UT` 是否返回 Luna；
- `ne=te.find(ckr)` 是否找到 Luna；
- `fIe` 是否为后端真正接受的模型 ID；
- composer、work mode 和已有模型选择是否没有被破坏。

### 备选方案：修改 `hur` 的 preset/fallback

如果目标只是让 Luna 在滑动条中有 3 个 reasoning 档位，可以在 `hur` 的 preset/fallback 逻辑中加入 Luna 候选。但这只适合 Luna 已经存在于当前模型集合的情况；否则 `xur` 会把它全部过滤掉。

### 不建议方案：只改静态 `wur`

直接把 Luna 写入 `wur` 最容易实现，但当前代码随后仍会经过 `xur` 与 `supportedReasoningEfforts` 的交集验证。它还绕过了当前版本已经存在的特殊 Luna 流程，升级后也最容易失效。

## 七、后续构建实现位置

本项目当前构建脚本在：

```
scripts/build-manjaro.sh
```

应在：

```
dpkg-deb -x
    -> 定位 resources/app.asar
    -> 解包 app.asar
    -> 定位 webview/assets/app-primary-*.js
    -> 按稳定 marker/函数结构 patch
    -> 重新打包 app.asar
    -> makepkg
```

建议 patch 使用：

- bundle 文件模式：`webview/assets/app-primary-*.js`
- 稳定 marker：`chatgpt-model-picker`、`supportedReasoningEfforts`、`sliderModelsConfig`、`gpt-5.6-luna`
- 结构 marker：`function hur`、`function vur`、`function xur`、`function ckr`
- 版本校验：文件 hash/上游版本/marker 数量
- 失败策略：marker 不匹配时停止构建，不做无条件全文替换

不能把 `app-primary-a0bff570446b.js` 的 hash 当成永久路径；下一次官方包更新后 hash 很可能变化。

## 八、复现分析命令

在已安装版本中：

```bash
find /usr/lib/chatgpt -type f \
  \( -name '*.asar' -o -name 'app-primary-*.js' \) -print
```

解包：

```bash
npx --yes @electron/asar extract \
  /usr/lib/chatgpt/resources/app.asar \
  ./app-asar
```

定位当前 bundle：

```bash\nfind ./app-asar -type f -name 'app-primary-*.js' -print\n```

搜索关键逻辑：

```bash
rg -o -F 'function hur' ./app-asar/webview/assets
rg -o -F 'function vur' ./app-asar/webview/assets
rg -o -F 'function xur' ./app-asar/webview/assets
rg -o -F 'gpt-5.6-luna' ./app-asar/webview/assets
rg -o -F 'supportedReasoningEfforts' ./app-asar/webview/assets
```

## 最终判断

当前版本比历史补丁更明确：

- 快速滑动核心是 `hur`；
- 当前静态快速候选是 Sol/Terra，不含 Luna；
- Luna 已经存在专门的条件分支；
- Luna 是否进入模型查询和模型选择器由 `x=vc(ur,b.hostId)` 控制；
- 要把 Luna 稳定加入快速滑动列表，最佳路径是复用/验证现有 Luna 分支，再处理 `supportedReasoningEfforts` 和 `hur` 的至少 3 档校验；
- 当前项目只负责打包，实际修改必须在构建阶段 patch 官方 `app.asar`，不能恢复旧第三方仓库代码。
