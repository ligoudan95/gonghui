# AI 生图工作台

本地单页 Web 工具（浏览器直接打开即用，零依赖零构建、完全离线——唯一联网行为是调用你配置的生图 API 端点），服务《冒险者工会》116 件美术素材 + 9 张单位锚图的批量 AI 生图生产。支持 **Gemini** 与 **GPT（OpenAI 兼容）** 双通道自由切换。

数据源：`DEMO/art_spec/风格指导/AI生图提示词全集.md`（生产辅助交付版，116 件逐件完整提示词 + 04 组 9 张单位锚图提示词）。

## 文件清单

| 文件 | 说明 |
|---|---|
| `index.html` | 工作台主页面（内嵌全部 CSS/JS，无 CDN） |
| `assets_data.js` | 素材数据（由 extract_prompts.py 生成，勿手改） |
| `extract_prompts.py` | 解析脚本：全集 md → assets_data.js（Python3 标准库，幂等） |
| `assets_status.js` | 入库状态快照（由 gen_assets_status.py 生成，勿手改；独立于 assets_data.js 生成链，互不覆写） |
| `gen_assets_status.py` | 快照生成脚本：registry 键清单 + 来源留档表 AI 分区 + 特殊注记 → assets_status.js（Python3 标准库，自带 119 件口径对账） |
| `server.py` | 本地静态 + API 转发二合一服务器（Python3 标准库零依赖，解决站点 CORS 限制；含 `/proxy-get` 图片下载代理与 `/rt-store` 系列运行时存储端点——生成图+提示词的进程内存缓存，刷新页面自动恢复、关服即清、软上限 512MiB） |
| `启动工作台.cmd` | Windows 双击一键：启动 server.py 并打开工作台页面 |
| `README.md` | 本说明 |

## 打开方式

**推荐：双击 `启动工作台.cmd`（本地代理模式，解决站点 CORS 限制）**——自动启动 `server.py` 并打开 `http://127.0.0.1:8765/`。

也可手动等价操作：

```
cd DEMO/tools/ai_art_studio
python server.py          # 默认端口 8765，可 python server.py 8899 改端口
```

然后浏览器访问 `http://127.0.0.1:8765/`。

**为什么需要本地代理**：daseinai.xyz 等站点对浏览器 CORS 预检（OPTIONS + Origin）一律 403 且不返回跨域头，网页内直接 fetch 该站必报 `Failed to fetch`（curl 不受影响）。本地代理在本机 127.0.0.1 伺服页面并把 API 请求原样转发（等效 curl 链路），从根上绕开浏览器 CORS 限制。页面加载时自动探测代理（127.0.0.1:8765），每 30 秒重探、设置栏可手动「重探」。

其他打开方式：

- **直接双击 `index.html`**（file:// 模式）也可用：页面仍会自动探测本地代理，探测到就走代理转发；探测不到则直连（对无 CORS 限制的端点（如 Gemini 官方）直连可用；**daseinai.xyz 实测必须走本地代理**，直连必被浏览器拦截）。
- **`python -m http.server`**：仅伺服静态文件、**不解决 CORS**（localhost 伺服后跨域照旧被拦，daseinai 实测如此）；须跨站调用时不要用这个，走本地代理模式。

## 使用流程

1. **选提供商**：设置栏第一项「提供商」——Gemini（官方 REST）或 GPT·OpenAI 兼容。**两家的 API Key、Base URL、模型各自分存**（localStorage 分槽），切换回来配置不丢。
2. **填 Key**：粘贴当前提供商的 API Key（密码框，可点「显」查看）。Key 只存本机浏览器 localStorage，不写 cookie、不上传任何第三方。Key 申请指引见下文「API Key 申请」。
3. **配置端点**：Base URL 默认——Gemini=`https://generativelanguage.googleapis.com`、OpenAI=`https://api.openai.com`；用中转站就改成中转地址（结尾不带 `/`，脚本自动拼路径）。**结尾多填了 `/v1` 或 `/` 也没关系**：工具拼接时自动剥除（输入框下方会提示「已自动去除尾部 /v1」，存储值保持你填的原样）。中转配置示例（2026-10-02 实测）：grsai → 提供商选 GPT·OpenAI 兼容、Base URL 填 `https://grsai.dakka.com.cn`（OpenAI images 兼容端点）；grsai 也可走 **Gemini 原生端点**——提供商选 Gemini、Base URL 填 `https://grsai.dakka.com.cn`、设置栏「鉴权方式」切 **Bearer 头**、模型 `nano-banana-2`（该站 Gemini 端点只认 `Authorization: Bearer` 头，默认的 Google 原生 `?key=` 参数会报 `apikey is empty`）。
4. **选模型**：下拉预设 + 输入框可直接敲自定义型号：
   - Gemini 组：`gemini-2.5-flash-image` / `gemini-3.1-pro-image` / `gemini-2.0-flash-exp-image` / `nano-banana-2` / `nano-banana-2-4k-cl`（后两项为 grsai **Gemini 原生端点**型号，须配合「鉴权方式 = Bearer 头」；2026-10-02 实测：`nano-banana-2` Bearer 鉴权全通——十档比例 aspectRatio 生效、inlineData b64 返回；`nano-banana-2-4k-cl` 余额不足未验）
   - OpenAI 组：`gpt-image-2.5` / `nano-banana-2` / `nano-banana-2-4k-cl` / `gpt-image-1` / `gpt-image-1.5` / `gpt-image-2.5-flare` / `gpt-image-2.5-sunburst` / `dall-e-3`（2026-10-02 daseinai 实测：2.5 可用、1 与 1.5 上游渠道异常，站内无 dall-e-3；2026-10-02 grsai **OpenAI 兼容端点**实测：`nano-banana-2` 可用但响应为 url 形态（工作台已支持，见下），`nano-banana-2-4k-cl` 余额不足未验——同名型号在 Gemini 组走原生端点+Bearer，见上；预设仅为建议，可自由输入自定义型号）
5. **选比例与分辨率**：长宽比例（10 档枚举）两家共用；**点击素材时按其目标规格自动推荐最接近的比例**（背景→16:9、tile→1:1、单位竖条→2:3），可随时手改。
   - Gemini：比例直接生效；分辨率 1K/2K/4K 可选（「默认」= 不传该字段）。
   - OpenAI：**比例自动映射为 size 并在界面明示**（如「当前比例 16:9 将映射为 size = 1536x1024」）；分辨率下拉在 OpenAI 模式下禁用（不适用）。
6. **选素材**：左栏单击行 → 中栏自动载入该件**中文版正向提示词**（可自由编辑；「切换英文」中英互切，已编辑时弹确认防丢，「还原」恢复原文）。
7. **（可选）挂参考图**：中栏提示词区下方「参考图」条——点「+ 添加图片」选文件，或**直接把图片文件拖进该条**。上限 3 张（超出忽略并提示）；长边超 1500px 自动等比压缩到 1500（悬浮小卡可见「原始 → 发送」的尺寸与体积变化；gif 压缩后会转为 png，属正常）。**仅 Gemini 通道支持**——当前提供商为 GPT·OpenAI 兼容时点「生 成」会被直接阻止并提示（零请求发出），切回 Gemini 或清空参考图即可。参考图**随任务快照冻结**：任务发起后清空/替换参考图不影响已入队任务（失败重试也按原快照重发）；切换素材参考图保留不清空。锚图用法：先把锚图下载落盘，再从文件导入为参考图。
8. **生成**：点「生 成」（或 Ctrl+Enter）——**多并发 + 排队模型**，不必等一张显示完才能点下一张：发起后右栏顶部立即出现任务占位卡（转圈），可切别的素材继续发起，详见下文「多并发生成」。成功 → 占位卡**原位**变成缩略图 + 该素材自动标红「已生成」；缩略图/大图均标注出图通道（Gemini/GPT）与实际比例/size（url 形态响应的图额外标注「URL 源」），挂了参考图的任务另标注「参考图×N」。
9. **收图**：**右键缩略图 → 「下载 PNG」**，文件名 = 资源英文名 id（如 `spr_cls_mage_cast_ranged.png`、`bg_battle_mine.png`、锚图 `anchor_spr_cls_warrior.png`），与全集命名规则一一对应；jpeg/webp 出图会自动经 canvas 转为 png。**URL 源图**（端点只返回 url、如 grsai `nano-banana-2`）下载自动三级降级：①直连 fetch ②本地代理 `/proxy-get` ③两级都失败时错误框提示手动另存（url 自动复制到剪贴板/错误区可选中）——也可随时右键缩略图 → 「在新标签页打开图片」手动另存。
10. **标记与管理**：缩略图右上角按钮循环标记（无 → ★星 → 红 → 蓝 → 绿，状态存 localStorage）；「只看已标记」筛选；双击缩略图开大图（滚轮缩放/拖拽平移/Esc 关闭，底部有下载按钮）。**大图内 ← / → 方向键或两侧箭头钮可在当前浏览集合内循环切换**（末张→首张；Home/End 跳首末张；底部显示「第 x / N 张」）——集合在打开大图瞬间按当前筛选口径定格（打开后再改筛选/新图完成不影响本次序列，关闭重开重新定格）。信息条「**提示词**」钮展开只读提示词面板（可一键复制，切换图自动联动）；「**删除**」钮删除当前图并自动跳到相邻图。右键缩略图还有「**复制提示词**」。单击参考图小卡可放大预览（信息条为该图「原始 → 发送」参数，下载即压缩后字节）。
11. **进度**：左栏双击行手动切换「已生成」红标（再双击恢复）；顶栏显示总进度 x/125。
12. **入库状态（只读）**：左栏每行右侧的彩色小徽章 = 该件在**游戏工程**的入库实况快照（读 `assets_status.js`，不随生图/双击变化）——`入库`（绿·已正式入库）/ `待替换`（橙·已正式但待重生成替换）/ `错件`（红·占位被错件拦截待重导出）/ `占位`（灰·占位待生成）/ `—`（锚图等不入状态口径）。悬浮徽章可见状态全称；左栏搜索框下方小字显示快照生成时间。**与「已生成」红标是两套口径**：已生成 = 你的本地生图进度标记（手动双击，存 localStorage）；入库状态 = 游戏工程 registry + 来源留档实况（典型场景：协会背景错件回滚占位后，工作台仍显「已生成」，看徽章即知游戏侧实为「错件」占位）。刷新快照见下文「重新生成数据」。

## 四套口径说明（119 / 118 / 116 / 125）

不同场景下「素材总数」有四套口径，工作台与工程侧各取所需：

| 口径 | 数值 | 含义 |
|---|---|---|
| 规格书总量 | 119 | 规格书 00-10 组全量 = 116 生图件 + `bg_guild_hall`（批 3 试运行首件，参考图转正、不在全集）+ 字体 2 件（`font_cn_body`/`font_cn_title`，不走 AI 生图、维持未入册） |
| registry 键 | 118 | 游戏工程 `data/assets/registry.tres` 登记键数 = 119 − 字体 2 件 + `ui_main_theme`（UI 主题资源，非生图件） |
| 全集生图件 | 116 | 《AI生图提示词全集》逐件出提示词的量 = 119 − bg_guild_hall − 字体 2 件。注：批 3 后半后**实际待产 111**（5 件背景已正式入库） |
| 工作台条目 | 125 | 本工具左栏行数 = 116 生图件 + 9 张单位锚图（锚图为生产辅助件，不入库、状态列显示「—」） |

- **已生成 vs 入库状态**：已生成 = 工作台本地标记（你手动双击切换，存 localStorage，只代表你的生图进度，与游戏工程无关联）；入库状态 = 游戏工程实况快照（registry 在册键 + `art_source_log.md` AI 分区已登记行 + 特殊注记三路合成）。
- **快照刷新时机**：每次素材入库批完成后重跑一次 `python gen_assets_status.py`（详见下文「重新生成数据」），然后刷新工作台页面即见新状态。

## 多并发生成（并发 + 排队）

工作台支持同时发起多个生成请求、超出并发数的自动排队，批量出图不必逐张等待。

- **并发数设置**：设置栏「并发生成数」下拉 1/2/3/4/5（**默认 2 · 保守**，localStorage 持久化）。选 1 = 串行，行为等同旧版（一张显示完才启动下一张，但也可以先把后续的排进队）。修改立即生效：上调并发会立刻把排队中的任务补位启动。
- **任务卡**：每发起一个任务，右栏缩略图网格**顶部**插入一张占位卡（转圈动画 + 素材中文名/id + 「排队中 / 生成中…」状态 + 右上角 × 取消钮）。完成后占位卡**原位**变成正常缩略图（不跳到顶部——保持发起批次的位置，直观对应）；失败则变成红色边错误卡（错误摘要前 120 字 + 点击卡展开完整错误到错误区 + 「重试」按钮 + × 删除卡）。
- **取消**：占位卡 × ——排队中的任务直接出队；生成中的任务 abort 该请求后移除卡。右栏标题行「全部取消」按钮（confirm 确认）一次性中止全部生成中请求并清空排队。
- **状态计数**：右栏标题行实时显示「进行中 N · 排队 M」，中栏生成按钮旁同步显示；有任务时才出现「全部取消」钮。
- **队列上限**：等待中的任务最多 20 个，超出提示「排队已满，稍后再点」（生成中的不计入上限）。
- **同素材多抽**：允许对同一素材连续点多次（每张独立任务卡，多抽挑最好）；该素材已有进行中的任务时再点，中栏会出现非阻塞提示「该素材已有 N 张生成中，已再排队 1 张」。
- **每任务参数快照**：任务发起瞬间快照提示词与全部端点配置（提供商/Base URL/模型/比例/分辨率/鉴权/Key）——排队期间切换素材、提供商或任何设置都不影响已入队任务；失败卡的「重试」也按原快照重发。**参考图随快照冻结**：发起瞬间挂着的参考图（含压缩后字节）一并定格，之后清空/替换参考图不影响该任务，重试亦按原参考图重发。
- **并发与限流**：并发对中转站/官方端点是瞬时压力放大，默认 2 保守。**并发过高可能触发站点限流（HTTP 429）或服务不可用（503）、排队反而变慢——遇此情况请到设置栏降并发**。本地代理模式（`server.py`）为多线程 `ThreadingHTTPServer`，并发转发天然支持，无需额外配置。
- **不跨刷新持久**：排队与生成中的任务仅存在于页面会话内，**刷新/关闭页面即自然丢弃**（不持久化、不自动续发）；已完成的图按「已知限制」1 的口径保存（本地服务在线 = 运行时缓存刷新自动恢复；离线 = 仅会话内存），请及时下载。

## 两家 API 对照

| | Gemini | GPT（OpenAI 兼容） |
|---|---|---|
| 端点 | `POST {base}/v1beta/models/{model}:generateContent` | `POST {base}/v1/images/generations` |
| 鉴权 | 设置栏「鉴权方式」二选一：**Google 原生**（默认）= url 参数 `?key={API_KEY}`；**Bearer 头** = 请求头 `Authorization: Bearer {API_KEY}`，Key 不进 URL（grsai 等中转站） | 请求头 `Authorization: Bearer {API_KEY}`（固定，无需设置） |
| 请求体 | `contents:[{parts:[{text}]}], generationConfig:{responseModalities:["IMAGE"], imageConfig:{aspectRatio, imageSize}}`；**挂参考图时 parts 前置 inlineData 段**：`{inlineData:{mimeType:"image/png", data:"<base64>"}}`（最多 3 段，text 提示词永远最后一段） | `{model, prompt, n:1, size}`；dall-e-3 系另加 `response_format:"b64_json"`；**不支持参考图**——工作台挂了参考图时点「生 成」会被直接阻止并提示（零请求发出） |
| 比例 | aspectRatio 枚举直接生效（1:1～21:9 十档） | **就近映射**：方形→1024x1024；横版类（3:2/4:3/5:4/16:9/21:9）→1536x1024；竖版类（2:3/3:4/4:5/9:16）→1024x1536；**dall-e-3 横竖用 1792x1024 / 1024x1792** |
| 分辨率 | imageSize 1K/2K/4K（部分模型不支持选「默认」） | 不适用（size 已含分辨率；下拉禁用） |
| 响应取图 | `candidates[0].content.parts[*].inlineData`（mimeType+base64） | `data[0]`：优先 `b64_json`（base64 png）；仅返回 `url` 时入列为「URL 源」（缩略图/大图直接显示远程直链，下载走三级降级） |
| Key 存储 | localStorage `gas_apikey_gemini`（鉴权方式随设置存 gemini 槽） | localStorage `gas_apikey_openai` |

**Gemini 请求样例**：

```json
POST {BaseURL}/v1beta/models/gemini-2.5-flash-image:generateContent?key={API_KEY}
Content-Type: application/json

{
  "contents": [{ "parts": [
    { "inlineData": { "mimeType": "image/png", "data": "<参考图 base64，仅挂参考图时，最多 3 段>" } },
    { "text": "<提示词全文（永远最后一段）>" }
  ] }],
  "generationConfig": {
    "responseModalities": ["IMAGE"],
    "imageConfig": { "aspectRatio": "16:9", "imageSize": "2K" }
  }
}
```

（鉴权方式 = Bearer 头时：URL 不带 `?key=`，Key 改放请求头 `Authorization: Bearer {API_KEY}`，其余请求体完全一致——grsai 的 Gemini 原生端点即此形态，2026-10-02 实测。挂参考图 = 图生图（如以锚图为参考约束单位形象）；参考图在中栏「参考图」条导入，长边超 1500px 自动压缩，随任务快照冻结，仅此通道可用。）

**OpenAI 兼容请求样例**：

```json
POST {BaseURL}/v1/images/generations
Authorization: Bearer {API_KEY}
Content-Type: application/json

{ "model": "gpt-image-1", "prompt": "<提示词全文>", "n": 1, "size": "1536x1024" }
```

（dall-e-3 时 body 另含 `"response_format": "b64_json"`——dall-e 系默认返回 url，须显式改 base64；gpt-image-1 系默认即 b64_json，无须该参数。）

**API 版本口径**：Gemini 为 2025 下半年图像生成 REST 规范；OpenAI 侧按 Images API 公开形态（gpt-image-1 系 / dall-e-3）。中转站若改写过路径/鉴权/响应，页面会把 HTTP 状态码与响应体**完整原文**展示在错误区，按报文调整即可；无法在线验证 API 行为属正常，实测为准。

## API Key 申请（简述）

- **Gemini**：Google AI Studio（aistudio.google.com）登录 Google 账号 → 「Get API key」创建，免费档有额度；或走你自备的中转站拿 key+地址。
- **OpenAI**：platform.openai.com 登录 → API Keys 创建 `sk-…` key（需绑卡/充值，gpt-image-1 按张计费）；OpenAI 兼容中转站同理填中转地址+中转 key。
- 两家 key 在本工具里分槽保存，互不覆盖。

## 「附加负面规避说明」

两家 API 均无独立负面提示词字段。勾选后，生成时会把该件负面词转成自然语言规避句附在提示词尾：

- 中文提示词：追加 `请严格避免画面中出现以下元素：<负面中文>。`
- 英文提示词：追加 `Strictly avoid the following elements in the image: <负面英文>.`

## 常见错误排查

| 现象（错误区会显示完整信息） | 原因与处理 |
|---|---|
| `TypeError: Failed to fetch` / 网络请求失败 | 站点不支持浏览器直连（CORS，daseinai.xyz 实测如此）或 file:// 直开被拦——**双击 `启动工作台.cmd` 启动本地代理**，页面刷新/重探后自动走代理；也可能是 Base URL 不可达（中转站失效/断网）或 Key 无效 |
| `HTTP 401` / `API key not valid`（Gemini）或 `invalid_api_key`（OpenAI） | 当前提供商的 Key 填错，或中转站 key 与端点不配套 |
| `apikey is empty`（Gemini 中转站，如 grsai） | 该站 Gemini 端点只认 Bearer 头鉴权、不读 url `?key=` 参数——设置栏「鉴权方式」切 **Bearer 头** 再试（Key 改经 Authorization 头携带，不进 URL） |
| `HTTP 404` + `model not found` | 型号名不对，或该端点未部署此模型 |
| `HTTP 429` / `HTTP 503`（多并发下集中出现） | 站点限流 / 上游过载——到设置栏**降低并发生成数**再继续（默认 2 保守，见「多并发生成」） |
| `HTTP 400` 提及 `imageConfig`/`imageSize` | Gemini 侧该模型不支持这些字段——分辨率选「默认」再试 |
| `HTTP 400` 提及 `size`（OpenAI 侧） | 自定义模型不支持该 size 档位，换模型或改比例 |
| `finishReason = IMAGE_SAFETY`（Gemini）/ content policy（OpenAI） | 提示词触发安全策略，微调措辞 |
| `参考图仅 Gemini 通道支持…`（点生成被阻止） | 挂了参考图但当前提供商是 GPT·OpenAI 兼容——到设置栏切回 Gemini，或清空参考图（此为主动阻止，零请求发出，不计失败） |
| `运行时缓存已满…仅未纳入运行时保存` | server 运行时配对缓存达到 512MiB 软上限——先下载需要的图落盘，再点「清空」（会同步清 server 缓存）后继续；本张已生成成功，下载不受影响 |
| 响应为 `data[0].url` 形态（无 b64_json） | 正常支持（grsai `nano-banana-2` 实测即此形态）：入列显示并标注「URL 源」，缩略图/大图直显远程直链 |
| URL 源下载失败（提示「该图源跨域受限」） | 该图文件域的跨域 fetch 被拦——自动降级顺序：①直连 fetch ②本地代理 `/proxy-get`（启动 `server.py` 即有）；两级都失败时按错误框提示「右键缩略图 → 在新标签页打开图片 → 浏览器另存」，url 已复制到剪贴板（错误区也可选中），文件名手动改为资源 id.png |
| 生成成功但没有图 | 页面会展示完整响应 JSON，检查 `candidates` / `data` 结构 |

## 已知限制

1. **生成图的保存口径（server 运行期 · 刷新自动恢复）**：本地服务（server.py）在线时，每张生成成功的图与提示词自动存入 server **进程内存**（运行时配对缓存）——刷新本页自动恢复（标注「恢复」），删除/清空操作也会同步远端缓存；**关闭 server.py（或点「清空」）即全清且不可再恢复**，恢复排列按完成顺序近似。缓存总量软上限 512MiB，满后新图不再纳入（会明确提示，但**不影响生成与下载**，请先下载落盘或清空）。本地服务未连接（离线直连模式）时退回纯会话内存口径：刷新/关闭页面即消失（红标与标记状态留存 localStorage）。无论哪种口径，**最终入库以工程 `assets/` 与 `art_source_log.md` 留档为准**，请及时下载；单会话内存随生成图片累积（高分辨率大批量尤其明显），建议分批下载并适时清空。
2. **同一素材多张图下载文件名相同**（均为 `id.png`），浏览器保存时自动加 ` (1)` 后缀区分。
3. **file:// 打开时 localStorage 按来源（origin）共享**：file:// 协议在浏览器内是同一个来源，**换目录、移动文件后打开仍在同一份存档**（红标/标记仍在），只有清除浏览器站点数据（或换浏览器/换设备）才会丢。注意 `http://localhost` 与 `file://` 是两个不同来源，两边数据互不相通。
4. **中转站兼容性**：工具按官方 API 形状发请求；Gemini 通道已内置「鉴权方式」切换（Google 原生 `?key=` 参数 / Bearer 头，grsai 的 Gemini 原生端点实测需后者，见上文配置示例）。其余改写过路径/鉴权形态的中转站，仍需在错误区看清 404/401 报文后自行适配端点。
5. **OpenAI 比例映射为就近档**：21:9 等超宽比例实际出图 1536x1024（约 3:2），出图后按各件「出图后处理」裁切即可（全集本就要求按目标比例裁切/缩放）。
6. **排队与生成中的任务不跨刷新**：多并发的队列/进行中任务仅会话内存，刷新即丢弃（设计如此，不自动续发）；失败任务的完整错误也随页面关闭消失，需要留档请及时从错误卡展开复制。

## 重新生成数据

**提示词数据**（全集 md 更新后，在本目录执行）：

```
python extract_prompts.py
```

脚本幂等（同输入同输出），自带对账：116 件 + 9 锚图逐项校验（缺字段/名字不一致/总表不匹配都会明确报错列出，非零退出）。

**入库状态快照**（每次素材入库批后重跑一次；与上互不影响——两者生成链独立，互不覆写）：

```
python gen_assets_status.py
```

脚本自带 119 件口径对账：registry 键数 118 / AI 分区登记件全部在册 / 特殊注记与登记·占位事实相符 / 字体 2 件确未入册 / 工作台 116 生图件全覆盖；任一失败非零退出且**不写出文件**（宁报勿漏）。当前落值基准：已正式入库 5 + 已正式（待重生成替换）1（bg_dormitory）+ 占位（错件拦截）1（bg_association_hall）+ 占位（待生成）110 + 未入册 2（字体）= 119。
