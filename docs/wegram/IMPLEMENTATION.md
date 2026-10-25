# WeGram 设计摘要

本文件随仓库提交，只写设计、约束与做法。**不要写入**真实账号的聊天、联系人、群名与消息内容，Apple / App Store Connect 账号信息，本机绝对路径、日志路径、模拟器 UDID，以及私人截图的位置。逐日工作记录放在 git 忽略的 `build-input/` 里。

## 1. 目标与范围

- WeGram 基于官方 Telegram-iOS（TelegramMessenger/Telegram-iOS），把主界面重做成微信（iOS，以 WeChat 8 为参照）的视觉结构和交互习惯，仍是完整的 Telegram 客户端。
- **主界面只呈现微信结构**：微信 / 通讯录 / 发现 / 我四个 tab，以及聊天页、资料页、设置页。Telegram 独有的能力全部保留，收进隐藏入口（第 3 节）。
- **隐藏原则**：
  - 高频入口最多「一次唤出 + 一次选择」。
  - 菜单保留未读徽标、当前状态，以及回到「全部」的路径。
  - 手势捷径必须同时有可发现的普通入口（点击或 VoiceOver 自定义动作）。
  - 隐藏不等于删除：不绕过 Premium，不破坏通话、下载、代理、同步。
- **不在范围内（硬约束）**：
  - 不改 MTProto、认证、加密、请求重试与节流、同步、消息语义、已读回执、在线/输入状态、私密聊天/TTL、服务端权限判断。
  - 设备信息保持真实，不冒充官方客户端。
  - `TelegramCore` / `TelegramApi` / `MtProtoKit` 不做 WeGram 改动。
- **品牌**：应用显示名为 `WeGram`。主页面不显示 WeGram 标题；「关于」页显示 WeGram、真实版本号和上游致谢。内部 target、模块、bundle 结构、URL scheme（`tg://`、`telegram`）和协议字段保留，源码符号不做全局重命名。
- **主题**：不允许用户自选主题，只渲染 WeGram 日/夜两套。字号和「浅色/深色/跟随系统」保留。

## 2. 架构与关键文件

### 2.1 总体做法

- **以 opt-in 标志为主**：共享组件新增的外观参数默认 `false`，只有 WeChat 表层的调用方传 `true`，其它调用方保持上游外观。少数代码直接在 WeGram 资格条件下分支。
- **新视图尽量写成独立的 `Wegram*` 文件**，上游文件里只做最小接线。
- **资格在初始化时用 `let` 固定**（如 `ChatController.usesWegramNavigation`），避免预览/提升生命周期中途切换。

### 2.2 门禁标志与关键 helper

| 名称 | 位置 | 作用 |
|---|---|---|
| `usesWegramShape` / `usesWegramNeutralFill` | `TelegramPresentationData/Sources/PresentationData.swift`（bubble corners） | 气泡 `.wegram` 形状；状态节点据此隐藏气泡内时间和频道浏览数 |
| `wegramMessageLayoutIsSupported(...)` | `TelegramUI/Components/Chat/ChatMessageItem/Sources/ChatMessageItem.swift` | 判断消息是否走双侧头像布局。覆盖私聊、群、频道帖子、收藏；Replies、验证码会话、action 消息除外 |
| `wegramLockedThemeSettings` / `wegramAllowsChatWallpaper` | `PresentationData.swift` | 锁定主题；聊天背景只允许照片 |
| `wegramUnreadCountString` | `TelegramPresentationData/Sources/NumericFormat.swift` | 未读数 ≤99 显示原值，≥100 显示「99+」 |
| `wegramNavigationTitleFont` | TelegramPresentationData | WeGram 导航标题统一用系统字体 Medium 17pt |
| `NavigationBarTheme.contentTopInset` | Display | WeGram 导航内容下移 7/3pt；`MediaPickerScreen` 传 0 |
| `replacementRespectsTopInset` | `NavigationBarContentNode` | 替换内容（如聊天内搜索栏）遵守状态栏安全区 |
| `usesWegramLayout` / `isWegramSearchResult` / `hidesWegramListAccessories` | `ChatListUI/Sources/Node/ChatListItem.swift` | 主列表紧凑单行布局；搜索结果行复用该布局 |
| `usesWegramAppearance` | 多处 | 通用外观开关，例如 `ChannelAdminsController`、`QrCodeScanScreen`、`ChatSearchNavigationContentNode`、输入附件面板 |
| `usesWegramNavigation` | `ChatController.swift`、`LocationViewControllerNode.swift` | 聊天页是否用 WeGram 导航和菜单 |
| `usesWegramMessageLayout`、`usesWegramSelectionAppearance`、`usesWegramProfileLayout`、`usesWegramSearchFooterLayout`、`usesWegramReply`、`wegramStyle`、`hidesThumbnails`、`preserveNavigationStack`、`usesWegramContactStoriesFallback` | 各自组件 | 局部 opt-in |
| `flatStyle` | `ItemListRevealOptionsNode` | 侧滑按钮改为平面色块 |
| `plainCards` | `HeaderPanelContainerComponent` | 置顶消息卡片模式 |
| `wegramSubpage` | `ChatListNavigationBar` | 二级列表页（如折叠的聊天）导航栏 |
| `canUseWegramGroupDetails` | `PeerInfoScreen.swift` | 群/已加入频道使用「聊天信息」页 |
| `wegramHiddenPinnedMessage` | `ChatPresentationInterfaceState` | 私聊/收藏/频道隐藏置顶栏，改由菜单进入 |

### 2.3 共享视觉基础

- **`WegramIcon`**（`TelegramPresentationData/Sources/WegramIcon.swift`）：代码绘制的线性图标，28pt 画布，微信 24pt 网格按 28/24 缩放。
- **`WegramNavigationColors`**（`ComponentsThemes.swift`）是导航配色。Display 里还有：
  - 返回箭头 `wegramNavigationBackArrowImage`；
  - 列表箭头 `wegramDisclosureArrowImage` / `wegramDisclosureArrowFrame`；
  - 经典 51×31 开关 `WegramAppearanceSwitch`。
- **`WegramGroupedListColors` + `WegramSettingsCell`**（PeerInfoScreen）：分组列表的颜色和分隔线（组首/组尾整宽线，组内 56/16pt 缩进线）。
- **确认与弹层**：`PresentationDataUtils` 中的 `wegramConfirmationController`、`wegramAuthorizationConfirmationController`、`wegramTextConfirmationController`、`wegramMessageDeletionConfirmationController`，以及 `ActionSheetControllerTheme` 的 WeGram 主题（`wegramTheme`）。

### 2.4 各页面关键文件

下文 `PI/` = `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/`。

- **微信（主列表）**，位于 `submodules/ChatListUI/Sources/`：
  - `ChatListController.swift`、`ChatListControllerNode.swift`、`Node/ChatListItem.swift`；
  - `WegramShortcutMenuController.swift`（星标快捷菜单）；
  - `WegramStartChatController.swift`、`WegramAddFriendsController.swift`；
  - `WegramChatListTime.swift`、`WegramChatListPreview.swift`、`WegramChatListLoadingShapes.swift`、`WegramChatListEmptyView.swift`；
  - `WegramMutedIcon.swift`（`wegramMutedIcon(dark:)`）、`WegramFoldedChatsIcon.swift`。
  - 空查询的搜索分类网格是 `ChatListSearchContainerNode.swift` 内的私有 `WegramSearchCategoryView`。
- **通讯录**：`submodules/ContactListUI/Sources/ContactsController.swift`、`WegramContactCollation.swift`（A–Z/# 分组与索引条）。
- **发现**：`submodules/TelegramUI/Sources/WegramDiscoverController.swift`；朋友圈为 `WegramMomentsHeaderView`、`WegramMomentCell`。
- **我 / 设置**：
  - `PI/WegramMeView.swift` 放业务导航，`PI/WegramMeContentView.swift` 放视图；
  - `PI/WegramSettingsController.swift` + `WegramSettingsPage.swift`；
  - 子页面：`WegramNotificationsController`、`WegramPrivacyController`、`WegramStorageController`、`WegramDarkModeController`、`WegramAboutController`、`WegramDevicesController`、`WegramBioController` 等。
- **语言**：语言选择视图在独立叶子模块 `submodules/WegramLanguageUI`。
- **资料**：
  - 联系人：`PI/WegramContactContentView`、`WegramContactSettingsController`、`WegramRemarkEditorController`（编辑备注）。
  - 群/频道：`PI/WegramGroupContentView`（`WegramGroupContent.isChannel` 区分频道）、`WegramGroupManagementController`。
  - 管理员网格：`submodules/PeerInfoUI/Sources/WegramAdminGridView.swift`。
- **聊天页**：
  - 时间分组：`ChatHistoryEntry/Sources/WegramMessageTime.swift`；
  - 头像/作者/引用卡片几何：`ChatMessageItemCommon/Sources/WegramMessageLayout.swift`；
  - 时间与通知胶囊、照片壁纸材质：`ChatMessageItemCommon/Sources/WegramMessageDateNode.swift`（含 `WegramCapsuleBackgroundNode`）；
  - 气泡几何：`TelegramPresentationData/Sources/WegramBubbleGeometry.swift`；
  - 输入栏：`ChatTextInputPanelNode/Sources/WegramComposerLayout.swift`（`canUseWegramControls`、`wegramComposerShortcuts`）；
  - 附件面板：`TelegramUI/Sources/WegramAttachmentLayout.swift`、`WegramAttachmentInputNode.swift`；
  - 消息详情：`TelegramUI/Sources/WegramMessageDetails.swift`；
  - 长按网格菜单：`ContextUI/Sources/WegramMessageMenu.swift`、`WegramMessageMenuContent.swift`；
  - 置顶卡片与展开列表：`TelegramUI/Sources/ChatPinnedMessageTitlePanelNode.swift`（含 `PinnedCardMetrics`、`PinnedListOverlayView`）。
- **通话**：`CallScreen/Sources/Components/WegramVoiceCallView.swift`、`TelegramCallsUI/Sources/WegramCallFloatingWindow.swift`（72pt 浮窗卡片，拖到边缘收成 16×72pt 把手）。
- **登录**：`AuthorizationUI/Sources/WegramWelcomeView.swift`（欢迎页，经 `AuthorizationSequenceSplashController` 启用）、`WegramAuthorizationLanguageController`、`WegramPhoneEntryLayout`。
- **应用图标**：`Telegram/Telegram-iOS/WeGramAppIcon.xcassets`（标准 `.appiconset`，由 `Telegram/BUILD` 的 `app_icons` 引用）。图案是绿色气泡围一条珊瑚色针织围巾，侧边打结、两条方头带流苏的尾巴；围巾全程等宽、横向罗纹，不收尖也不变成别的东西（旧版末端折成纸飞机，看着像豆荚）。各尺寸由 1024 母版缩放，RGB 无透明。

## 3. Telegram 功能 → 隐藏入口

状态：「模拟器已验」表示在登录态模拟器上实际走过入口路径；「已接入」表示已编译接线，尚未实际走完路径。

| 能力 | 入口 | 路径 | 状态 |
|---|---|---|---|
| 聊天分组（Folders） | 「微信」tab 已选中时再点一次 | 原分组菜单（勾选当前项、未读数、底部管理）；选中后标题显示「微信·<分组名>」 | 模拟器已验 |
| 收藏、下载、通话等常用入口 | 主列表左上星标 | `WegramShortcutMenuController`，菜单打开时隔离背后的读屏 | 已接入，部分模拟器已验 |
| 归档 | 主列表「折叠的聊天」行 | 二级页；标题长按 → 归档设置 / 说明 / 多选 | 模拟器已验 |
| 新建聊天 / 添加朋友 / 扫一扫 / 发朋友圈 / 管理聊天 / 新建频道·私密聊天 | 主列表右上「+」 | 平面菜单 | 已接入 |
| Stories | 发现 → 朋友圈 | 时间线（本地缓存）+ 原查看器；内联点赞/回复 | 已接入 |
| Bot Web Apps | 发现 → 小程序 | 原 WebApp | 已接入 |
| 通话记录 / 频道搜索 | 长按「发现」tab | `ContextController`：通话 / 频道 | 模拟器已验 |
| 添加联系人 / 邀请 / 排序 | 「通讯录」tab 菜单 | 原流程 | 已接入 |
| 侧滑操作（置顶、静音、归档、已读/未读、删除） | 主列表左滑/右滑 | 平面色块；一侧为 标为未读 / 归档 / 删除，其余在另一侧 | 模拟器已验（未点执行） |
| 通话、设备、代理、聊天分组 | 我 → 服务 | WeGram ActionSheet | 已接入 |
| Premium / 商务 / 钱包·星币·TON / 赠礼 / Passport / Watch | 我 → 设置 → 右上「更多设置」 | 上游完整设置页（`PeerInfoScreenImpl` isSettings） | 已接入 |
| 通知 / 隐私 / 存储的完整选项 | 对应 WeGram 设置页右上 ••• | 上游完整页 | 已接入 |
| 帮助与反馈 | 设置 → 帮助与反馈 | 原 support 流程 | 已接入 |
| 语言 | 欢迎页语言按钮；设置 → 语言 | 同一份服务端语言列表，选择后点「完成」才应用 | 欢迎页模拟器已验 |
| 消息反应、翻译、详情、定时删除等 | 消息长按 | 图标网格（复制/转发/收藏/编辑/删除/多选/引用）→「更多」进入原完整菜单；「详情」显示精确时间和状态 | 已接入 |
| 投票、礼物等附件 | 输入栏「+」 | 分页网格（照片/拍摄/视频通话/位置/文件/名片/语音输入/收藏…），「更多」进入原附件菜单 | 已接入 |
| 视频消息、定时消息、自动删除、赠送 Premium、bot 命令、回复键盘、静默发帖、建议帖子、send-as 等 | 长按语音键；VoiceOver 自定义动作 | 原各功能 | 已接入 |
| 发送特效 / 静音发送 | 长按「发送」 | 原发送菜单 | 已接入 |
| 置顶消息（群） | 聊天顶部白色卡片 | 点开展开卡片列表；「移除」→ 确认 | 模拟器已验 |
| 置顶消息（私聊/收藏/频道） | 头像或 ••• 长按菜单；聊天 ••• → 资料 → 更多 | 原置顶列表；联系人设置中有「置顶消息 (N)」 | 收藏、公开频道模拟器已验 |
| 聊天内搜索 | 长按 ••• / 标题；群·频道「聊天信息」→ 查找聊天内容 | WeGram 搜索栏；日期 / 成员 / 显示模式 / 计数收进搜索图标菜单 | 模拟器已验 |
| 按日期跳转 | 搜索图标菜单 → 日历 | 原日期 sheet（已补读屏） | 模拟器已验 |
| 通话加密密钥 | 通话页「+」菜单 | 原密钥展示 | 已接入 |
| 通话最小化 | 通话页最小化 | 72pt 浮窗卡片 | 已接入 |
| 私密聊天 | 联系人资料 •••；资料设置 | 原流程（从当前顶层控制器 present） | 已接入 |
| 群外观 / 完整资料 / 群通话 | 群「聊天信息」→ 更多设置 / 更多菜单 | 上游完整 PeerInfo | 已接入 |
| 群管理（管理员、成员权限、入群申请、日志、反垃圾、解散） | 聊天信息 → 群管理（仅群主/管理员可见） | 原控制器；管理员页为头像网格，••• 进入原列表 | 已接入 |
| 频道静音 / 搜索 / 礼物 / 助推 / 举报 / 相似频道 | 已加入频道 ••• →「聊天信息」；频道 tile 或更多设置 → 完整资料 | 底部栏已移除；未加入的频道保留「加入」栏 | 模拟器已验（未点执行） |
| 频道帖子转发 | 长按 → 转发 | 圆形分享按钮已隐藏 | 模拟器已验 |
| 联系人编辑 / 备忘 | 联系人资料「设置备注」图标 | `WegramRemarkEditorController`；带格式的备忘转交原编辑器 | 已接入（未实际保存） |
| 删除 / 屏蔽 / 举报 / 分享联系人 | 联系人 ••• → `WegramContactSettingsController` | 原流程 | 已接入（未执行） |
| 主题与外观 | 无入口（有意为之） | 已移除所有入口，主题 `tg://` 链接提示不支持 | 有意禁用 |

## 4. 关键设计决策与不显然的约束

### 4.1 颜色与测量

- **参照尺寸**：参考截图为 1206×2622 @3x，即 402×874pt，与 iPhone 17 Pro 模拟器同尺寸，可逐像素比对。
- **色彩空间**：真机截图是 Display P3；模拟器截图和微信的颜色 token 是 sRGB。
  - 灰阶可直接比较；饱和色要先做 P3→sRGB 换算，或直接用 token。例如 07C160 在 P3 截图里读出来约是 57BE6A。
  - 读像素要用 CGContext 取原始分量，不要用 `colorAt`（返回校准过的值，会偏）。
- **颜色来源优先级**：微信的命名颜色 token（明暗两版）> 截图实测 > 估值。参考资料只在本地使用，不进仓库，也不随应用发布。
- **图标**：WeGram 一律用基本图元重绘，不使用微信的 path 数据；描图以 3x 的 IoU / 面积 / 质心对照参考图验收。

### 4.2 主要数值（当前代码）

- **导航**：
  - 44pt 栏高 + `contentTopInset` 7/3pt；标题 Medium 17pt；按屏幕居中，而不是在两侧按钮之间居中。
  - 返回箭头 10×18、1.5pt 线宽；列表箭头 1.5pt 圆头，颜色为黑/白 30%。
- **列表配色**：
  - 浅色：间隔 #EEEEEE、行白、分隔线黑 10%、置顶行 #F0F0F0。
  - 深色：间隔/页面 #111111、行 #191919、分隔线白 10%、置顶行 #202020。
  - 正文 FG_0（黑 90% / 白 80%）。
- **主列表**：
  - 48pt 头像、4pt 圆角；72pt 行，单行摘要。
  - 不画置顶图标、已读勾、分组彩色标签和论坛话题 chip（话题以 `[Topic]` 形式并入摘要）。
  - 头像右上红色未读徽标 #FA5151；静音会话显示红点，摘要中显示「[N条]」，超过 999 显示「[999+条]」。
  - 时间：今天 HH:mm / 昨天 HH:mm / 星期 / M月D日 / 跨年用系统地区格式。
  - 标题「微信(N)」，N 只计未静音会话。
- **侧滑色块**：
  - 浅色 1485EE / FA9D3B / FA5151；深色 0D78CC / C87D2F / FA5151。
  - 最小宽 80pt（标为未读 92pt），白字 16pt；靠删除的一侧禁用「滑到底直接执行」。
- **Tab 栏**：
  - 56pt + 系统底部安全区（竖屏 34pt）。iOS 26 上 `onScreenNavigationHeight` 返回的 20pt 在平面栏分支里映射回系统值。
  - 选中色固定 #07C160，不受主题强调色覆盖。
  - 值为「!」的徽标改画 8pt 红点。
  - 浅色半透明背景使用模糊材质；切换 tab 无动画。
- **消息**：
  - 两侧都显示头像（40pt、r4）；`.wegram` 气泡带 5pt 尾巴，气泡内不显示时间。
  - 居中时间胶囊按时间分组；引用卡片放在气泡下方。
  - 群作者名为基准字号 ×12/17（默认约 12pt），在气泡上方 3pt；有作者行时头像顶高出气泡顶 13pt。
  - 起组消息的头像对齐气泡顶，而不是日期行顶（见 `wegramStartsTimeGroup` / `wegramTopInset`）。
- **气泡色**：
  - 深色：发出 #59B36A；收到 #2C2C2C，不透明。
  - 浅色：发出 #95EC69；收到白色。
  - 发出文字为黑 90%。
  - 默认聊天背景浅色 #EDEDED、深色 #111111，纯色、无图案。
- **聊天页导航栏**：在照片壁纸上是 90% 不透明度叠模糊背景。置顶卡片模式下，这层材质一直延伸到卡片下沿。状态栏颜色跟随主题，不跟随壁纸。
- **照片壁纸上的时间/通知胶囊**：模糊 + 压暗 + `plusL` 提亮层，外加 0.5pt 黑 10% 描边。仅在浅色且壁纸为照片时启用，其余情况保持纯色填充。
- **输入栏**：顺序为 语音 | 输入框 | 表情 | +；有文字时显示绿色「发送」；与附件面板之间有 1 像素分隔线。

### 4.3 主题锁定

- `wegramLockedThemeSettings` 应用在读取设置的入口和 `ChatController` 自身的读取处：
  - 主题固定为内置 dayClassic / night；
  - 清空强调色和气泡设置；
  - 单聊天主题（含礼物主题）恒为 nil。
- 上游自动夜间分支原本会在没有保存强调色时注入 `.blue` 强调色，会产生紫色发出气泡，已删除。
- 主题相关页面（ThemeSettings 等）仍留在代码里，只是没有入口。

### 4.4 品牌替换

- 用户可见文案的品牌替换在 `GenerateStrings` 取值后、格式化前完成，覆盖下载语言包、secondary 和 bundled 三条回退路径。
- URL、@用户名和格式参数内的文字不替换，UTF-16 参数范围保持准确；`LegacyComponents` 使用同一套边界规则。
- 写入系统通讯录的链接标签用 WeGram，读取时同时兼容旧的 Telegram 标签。

### 4.5 折叠的聊天（Telegram Archive）

- 主列表行使用合成 peer 0，所以按 peer 执行的动作不会落到真实聊天上。
- 排序取 `min(最新折叠消息, ChatArchiveSettings.wegramFoldedChatsTimestamp)`：新的折叠消息不会把这一行顶上去，要等用户打开该页后才更新。这是从参考推断的行为。
- 去掉了隐藏/取消隐藏归档的入口；这一行永不隐藏。
- 折叠页不放搜索框，否则 `ListViewIntermediateState` 会把上移的会话插到导航栏下面。

### 4.6 UIKit / AsyncDisplayKit 陷阱

- **present**：`NavigationController.present(_:animated:completion:)` 在 Display 中是无条件 `preconditionFailure()`。UIKit 控制器只能通过 `ViewController.present` 或窗口根控制器展示。
- **被遮挡的来源会静默丢弃 present**：从被盖住的控制器 present 到 `.window(.root)` 不会显示，要从同一导航栈的顶层控制器展示。
- **ComponentFlow 不能跨类型复用**：`ComponentView` 不能在不同 `Component` 类型之间复用视图，否则会在 `as!` 处崩溃（照片预览「完成」按钮因此崩溃过）。要用稳定外壳加按类型区分 identity 的子项（`WegramPhotoToolbarDoneContent`）。
- **导航按钮**：
  - 上游 `NavigationButtonNode` 只认 `customDisplayNode`，`UIBarButtonItem(customView:)` 不会显示。
  - target/action/accessibilityLabel 必须在赋给 `navigationItem` 之前设置好。
  - 语言变化时要重建整个 item。
- **读屏（AX）**：
  - `_ASDisplayView` 会丢弃 `setAccessibilityElements` 传入的数组，节点上重写的 `accessibilityElements` 在 view 侧也不生效。需要显式元素时，用普通 `UIView` 承载。
  - 未读角标代替返回文字时，返回按钮 alpha 为 0，读屏会跳过它；为此另插了透明代理视图 `NavigationBarBackAccessibilityView`。
- **开关**：iOS 26/27 的 `UISwitch` 固定 63pt 宽，所以统一用 `WegramAppearanceSwitch`（51×31 轨道，44pt 点击区）。
- **几何**：`CGRect.width` 会把负宽标准化；要判断负宽得看原始 `size`。
- **生命周期**：
  - `AlertController.dismissAnimated` 不会调用 `willDismiss`，所以菜单和确认框都要有「一次消费」门禁，拒绝过期的按钮动作。
  - 异步回调执行前要重新校验来源视图仍在窗口、仍在栈顶、状态快照一致。
  - SwiftSignalKit 的 `Queue.mainQueue().async` 在已处于主线程时是同步执行的。
- **频道帖子**：
  - 浏览数在 `ChatMessageDateAndStatusNode.Arguments` 里统一去掉（条件 `usesWegramShape`）。
  - `.broadcast` 分享按钮规则在 `usesWegramLayout` 下跳过，其它规则不变。

## 5. 构建、模拟器与测试

### 5.1 构建（Bazel，经 `build-system/Make/Make.py`）

- 本机 Xcode 比上游锁定版本新，需要 `--overrideXcodeVersion`。Bazel 版本由 `versions.json` 固定。
- 生成 Xcode 工程（模拟器开发）：

  ```sh
  python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir=<cache-dir> \
    generateProject --configurationPath=build-input/<config>.json \
    --xcodeManagedCodesigning --disableProvisioningProfiles --disableExtensions
  ```

  模拟器用「Xcode 托管签名 + 禁用描述文件」。自定义 bundle id 下 fake codesigning 会因 APS entitlement 失败。
- 仅主应用的发布构建（无扩展）：

  ```sh
  python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir <cache-dir> \
    --bazelArguments=--//Telegram:disableExtensions build \
    --configurationPath build-input/<release-config>.json \
    --codesigningInformationPath build-input/<signing-dir> \
    --buildNumber=<build-number> --configuration=release_arm64
  ```

  产物为 `bazel-bin/Telegram/Telegram.ipa`。
- 带推送的发布构建：把上面的 `--//Telegram:disableExtensions` 换成 `--//Telegram:notificationServiceExtensionOnly`，只嵌入通知服务扩展（解密推送），其它扩展不打包；两个开关不要同时传。
  - 需要两份描述文件：主应用（含 `aps-environment` 和 App Group）和 `<bundle id>.NotificationService`（含同一 App Group）。App Group 固定为 `group.<bundle id>`，代码按这个名字找共享容器，选错组扩展就读不到账号数据。发布配置里 `enable_app_groups` 为 `true`。
  - Telegram 侧要在 my.telegram.org 为该 api_id 配置 APNs 证书（"Sandbox & Production" SSL 证书转成 PEM）。App Store Connect API 不能创建 APNs 证书和 App Group，这两步只能在开发者网站手动做。
  - 验证过的事实：配置证书后 Telegram 服务器会向自建 bundle id 投递 APNs 推送（用不加密注册的探测构建确认）。
- 发布配置是 git 忽略的 JSON，键由 `build-system/Make/BuildConfiguration.py` 读取，如 `bundle_id`、`team_id`、`enable_app_groups`（描述文件没有 App Group 时设为 `false`，entitlements 不再声明 application-groups）。描述文件不含 `aps-environment` 时构建关闭推送而不是失败。仓库里不提交任何具体值。
- `build-system/Make/tests/test_project_generation.py`：unsigned 标志要同时传给生成和构建；unsigned 工程只生成模拟器 target。
- Bazel 偶发 swiftdoc「File exists」复制错误，原样重跑即可。项目自己的 Bazel CAS 缓存会占满磁盘，可以修剪。

### 5.2 模拟器

- 用一台专用模拟器（`<udid>`）。产物在 DerivedData 的 `bazel-out` 深层目录里，不在顶层 Debug 目录。
- **更新已安装应用**：
  - build number 不变时，`simctl install` 不会替换已装应用。
  - 可以整包覆盖已安装的 `.app` bundle：数据容器路径独立，登录态保留。若构建的 bundle id 与已装应用不同，覆盖后要把 `Info.plist` 的 `CFBundleIdentifier` 改回已装应用的值。
  - 主屏图标有缓存，要刷新图标得用 APFS clone（`cp -c`）后再 `simctl install`。
- 没有 App Group 授权的构建会把数据放在应用自己的容器里；从有 App Group 的构建切换过来，需要迁移数据目录才能保持登录。
- 系统字号要重启应用才生效。HID 键入偶尔失败，可以改用屏幕键盘。

### 5.3 测试

- **宿主 CLI 测试**（`Tests/wegram/*.swift`）：与对应生产 helper 源文件一起用 `swiftc` 编译运行，不需要签名：

  ```sh
  swiftc <helper>.swift Tests/wegram/<X>Tests.swift -o <out> && <out>
  ```

  覆盖：消息时间、通讯录分组、气泡几何、输入栏/附件布局、消息详情、设置页、行布局、搜索 diff、引用卡片、消息布局、header 几何、状态布局、手机号输入、国家列表、聊天标题。
- **Bazel UIKit 测试**：用 `Make.py test --target=<label>` 运行（与 build 相同的配置和签名参数）。主要目标：
  - `//submodules/TelegramPresentationData:WegramNavigationBadgeTests`（主套件）
  - `//submodules/TelegramPresentationData:WegramBubbleImageTests`
  - `//submodules/ChatListUI:ChatListUITests`
- **宿主应用测试**：需要 `UIWindow`、剪贴板或 QR 生成的用例，放在 `Tests/wegram/qr-host` 宿主应用里跑：
  - `WegramQrHostedTests`、`WegramShortcutHostedTests`、`WegramGroupDescriptionHostedTests`、`WegramItemListHostedTests`、`WegramCardBackgroundHostedTests`、`WegramChatListEmptyHostedTests`。
  - `Tests/wegram/settings-host` 用于设置页触控验证。
- **无宿主 XCTest 的限制**：
  - 创建 `UIWindow` 会触发 SIGTRAP；剪贴板不可用；QR 生成返回 nil；`ListViewImpl` 的 CADisplayLink 会崩溃。
  - `UIControl.sendActions` 对 ASDisplayNode 目标不派发，测试里改用 `UIAction` 闭包，或直接调用已注册的 selector。

## 6. 已知缺口 / 待办

- **测试分诊**：上次记录时 `WegramNavigationBadgeTests`、`WegramContactContentTests`、`WegramMeViewTests`、`WegramAttachmentPagingTests` 有一批断言失败，例如栏高测试仍期望 44pt，而实际已改为 44 + 7/3pt。期望值需要更新或分诊。
- **置顶**：
  - 「你移除了一条置顶消息」本地服务胶囊未实现（Telegram 没有对应的服务消息）。
  - 单张折叠卡片上的「移除」仍是上游的撤销 toast。
  - 「移除」文案借用了现成字符串，各语言包显示未核对。
  - 深色模式未对照参考。
- **频道**：
  - 已认证频道仍走 Telegram 完整资料页（与群共用的 `!peer.isVerified` 条件）。
  - 带讨论组或私信的频道、管理员频道、深色模式未检查；评论 footer 未处理。
  - 去掉底部栏后，「滚到底部」按钮贴着安全区底边。
- **搜索**：日期 sheet、搜索结果底部仍是上游外观；空查询分类网格布局是假设，没有同版本参考。
- **视觉上仍是上游外观的页面**：聊天背景选择网格、完整资料页、置顶列表的部分视觉、照片选择的部分状态、管理员深层页面。
- **折叠的聊天**：新的折叠消息不改变行位置这一点未在设备上验证；归档论坛头像的「v」角标未处理；深色行没有参考。
- **联系人资料**：微信的「昵称」行没有 Telegram 数据来源；朋友圈行没有缩略图。
- **数字字体**：返回角标数字用的是 SF 字体，与微信自有字体不同（后者不能随应用发布）。
- **欢迎页**：除中/英文外，其它语言的文案仍用英文 fallback；背景图仍需精修。
- **应用图标**：备用图标仍是 Telegram 的。
- **扩展**：Watch / Siri / 小组件的品牌替换只做了源码层面，未实际运行验证；发布构建只含通知服务扩展；加密推送的通知内容尚未在设备上验证，发送人头像（需 Communication Notifications 权限）和通话推送未处理。
- **普遍缺口**：大量入口只验证了编译接线或组件渲染，仍缺真实账号下的端到端验证（动作执行、权限变化、VoiceOver 连续手势、横屏、大字号、深色），以及同尺寸整页像素对照。
