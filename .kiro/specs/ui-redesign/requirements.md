# Requirements Document

## Introduction

本功能对 Flutter 学习助手应用进行 UI 全面重设计，将交互架构重构为以**对话为主入口**的模式（类比豆包式体验）。底部 4 个 Tab 作为主导航，答疑室（对话页）为默认首页，其余功能通过 Tab 直达或对话内场景识别触发跳转。

---

## Glossary

- **App**：Flutter 学习助手应用整体
- **Bottom_Nav**：底部 4 Tab 主导航栏组件
- **Chat_Page**：通用聊天页 Widget，复用于通用对话、学科专属对话、任务对话三种场景
- **Scene_Card**：场景识别触发后在对话流中插入的确认/跳转卡片组件
- **Toolkit_Page**：工具箱页，桌面图标风格网格布局
- **Course_Space_Page**：课程空间页，展示学科列表及学科详情
- **Profile_Page**：个人中心页
- **Subject**：学科，包含大纲、思维导图、讲义
- **Session**：一次对话会话
- **Spec_Mode**：Spec 规划模式，用于处理大型学习任务
- **Intent_Detector**：场景意图识别模块，分析用户输入并触发对应 UI 流程
- **Router**：应用路由管理模块

---

## Requirements

### Requirement 1：底部主导航

**User Story:** As a 学生用户, I want 通过底部 4 个 Tab 在主功能区之间快速切换, so that 我可以直达任意功能模块而无需多层返回。

#### Acceptance Criteria

1. THE App SHALL 在所有主功能页底部渲染 Bottom_Nav，包含「答疑室」「图书馆」「文具盒」「我的」四个 Tab，图标分别为 `chat_bubble_outline`、`menu_book_outlined`、`edit_outlined`、`person_outline`。
2. WHEN 用户点击 Bottom_Nav 中的某个 Tab，THE Router SHALL 导航至对应路由（`/`、`/course-space`、`/toolkit`、`/profile`）。
3. THE App SHALL 将「答疑室」Tab 设为应用启动后的默认选中项，并渲染 Chat_Page。
4. WHILE 用户处于某个 Tab 对应页面，THE Bottom_Nav SHALL 高亮显示当前选中 Tab。
5. IF 用户未登录，THEN THE Router SHALL 重定向至 `/login`，而非渲染主导航页面。

---

### Requirement 2：通用聊天页（答疑室）

**User Story:** As a 学生用户, I want 在答疑室中自由输入问题并获得 AI 回复, so that 我可以随时获得学习帮助。

#### Acceptance Criteria

1. THE Chat_Page SHALL 在顶栏展示标题「学习助手」及「新建」按钮。
2. THE Chat_Page SHALL 在消息区域以气泡列表形式展示当前 Session 的历史消息，用户消息右对齐，AI 消息左对齐。
3. THE Chat_Page SHALL 在底部输入栏提供图片上传按钮、文字输入框和发送按钮。
4. WHEN 用户点击「新建」按钮，THE Chat_Page SHALL 创建新的 Session 并清空消息列表。
5. WHEN 用户点击发送按钮或按下键盘发送键，THE Chat_Page SHALL 将输入内容作为消息发送，并在消息列表末尾追加用户消息气泡。
6. WHEN 用户点击图片上传按钮，THE Chat_Page SHALL 打开图片选择器，允许用户选择本地图片附加到消息中。
7. WHILE AI 正在生成回复，THE Chat_Page SHALL 在消息列表末尾展示加载状态指示器。
8. IF 消息发送失败，THEN THE Chat_Page SHALL 在对应消息气泡旁展示错误标识，并提供重试入口。

---

### Requirement 3：学科专属对话与任务对话

**User Story:** As a 学生用户, I want 在学科专属对话或任务对话中获得针对性的 AI 辅导, so that 回复内容更贴合我的学习场景。

#### Acceptance Criteria

1. THE Chat_Page SHALL 通过路由参数 `subjectId` 或 `taskId` 区分通用对话、学科专属对话、任务对话三种场景。
2. WHEN 路由包含 `subjectId` 参数，THE Chat_Page SHALL 在顶栏展示对应学科名称作为标题，并显示返回按钮。
3. WHEN 路由包含 `taskId` 参数，THE Chat_Page SHALL 在顶栏展示对应任务名称作为标题，并显示返回按钮。
4. THE Chat_Page SHALL 在学科专属对话场景下，将当前 `subjectId` 附加到每次 AI 请求的上下文中。

---

### Requirement 4：场景意图识别 — 学科意图

**User Story:** As a 学生用户, I want 在通用对话中输入学科相关问题时被引导切换到学科专属对话, so that 我能获得更精准的学科辅导。

#### Acceptance Criteria

1. WHEN Intent_Detector 识别到用户输入包含学科相关意图，THE Chat_Page SHALL 在对话流中插入一张 Scene_Card，展示「检测到 [学科名] 相关问题，切换到专属对话？」及「切换」「继续通用对话」两个操作按钮。
2. WHEN 用户点击 Scene_Card 上的「切换」按钮，THE Router SHALL 导航至 `/chat/:chatId/subject/:subjectId`。
3. WHEN 用户点击 Scene_Card 上的「继续通用对话」按钮，THE Chat_Page SHALL 关闭该 Scene_Card 并保持当前对话。
4. THE Scene_Card SHALL 在同一条消息中最多展示一次，不重复触发。

---

### Requirement 5：场景意图识别 — 规划意图

**User Story:** As a 学生用户, I want 在表达备考或学习目标时被引导生成学习计划, so that 我能获得结构化的复习安排。

#### Acceptance Criteria

1. WHEN Intent_Detector 识别到用户输入包含规划意图，THE Chat_Page SHALL 触发多轮追问流程，收集考试时间、学科范围等必要信息。
2. WHEN 多轮追问完成后，THE Chat_Page SHALL 在对话流中插入一张 Scene_Card，展示「已为你生成 [计划名称]」及「查看计划」「稍后再说」两个操作按钮。
3. WHEN 用户点击「查看计划」按钮，THE Router SHALL 导航至 `/chat/:chatId/task/:taskId`。
4. WHEN 用户点击「稍后再说」按钮，THE Chat_Page SHALL 关闭该 Scene_Card 并保持当前对话。

---

### Requirement 6：场景意图识别 — 工具意图

**User Story:** As a 学生用户, I want 在对话中表达笔记或错题需求时被引导跳转到对应工具, so that 我能快速使用专项工具而无需手动切换 Tab。

#### Acceptance Criteria

1. WHEN Intent_Detector 识别到用户输入包含工具使用意图（如笔记、错题），THE Chat_Page SHALL 在对话流中插入一张 Scene_Card，展示「跳转到 [工具名]？」及「一键跳转」「在对话中继续」两个操作按钮。
2. WHEN 用户点击「一键跳转」按钮，THE Router SHALL 导航至对应工具路由（如 `/toolkit/notebooks`、`/toolkit/mistake-book`），并在目标页右下角展示悬浮返回按钮。
3. WHEN 用户点击悬浮返回按钮，THE Router SHALL 返回跳转前的对话 Session 页面。
4. WHEN 用户点击「在对话中继续」按钮，THE Chat_Page SHALL 关闭该 Scene_Card 并保持当前对话。

---

### Requirement 7：场景意图识别 — Spec 模式

**User Story:** As a 学生用户, I want 在输入大型学习目标时被引导进入 Spec 规划模式, so that 复杂学习任务能被系统性地拆解和管理。

#### Acceptance Criteria

1. WHEN Intent_Detector 识别到用户输入包含大型学习任务意图，THE Chat_Page SHALL 在对话流中插入一张 Scene_Card，展示「检测到大型学习任务，启动 Spec 规划模式？」及「启动」「普通对话」两个操作按钮。
2. WHEN 用户点击「启动」按钮，THE Router SHALL 导航至 `/spec`。
3. WHEN 用户点击「普通对话」按钮，THE Chat_Page SHALL 关闭该 Scene_Card 并保持当前对话。

---

### Requirement 8：工具箱页

**User Story:** As a 学生用户, I want 在工具箱页以桌面图标风格浏览并进入各学习工具, so that 我能快速找到并使用所需工具。

#### Acceptance Criteria

1. THE Toolkit_Page SHALL 以 4 列网格布局展示工具卡片，初始包含「错题本」「笔记本」「解题」「出题」四个工具。
2. THE Toolkit_Page SHALL 为每个工具卡片渲染圆角方形图标和下方文字标签，样式与手机桌面 App 图标一致。
3. WHEN 用户点击「错题本」卡片，THE Router SHALL 导航至 `/toolkit/mistake-book`。
4. WHEN 用户点击「笔记本」卡片，THE Router SHALL 导航至 `/toolkit/notebooks`。
5. WHEN 用户点击「解题」卡片，THE Router SHALL 导航至 `/toolkit/solve`。
6. WHEN 用户点击「出题」卡片，THE Router SHALL 导航至 `/toolkit/quiz`。
7. THE Toolkit_Page SHALL 支持在不修改网格布局代码的情况下，通过数据配置扩展新工具卡片。

---

### Requirement 9：解题页

**User Story:** As a 学生用户, I want 在解题页提交题目并获得结构化的 AI 解析, so that 我能系统地理解解题过程和易错点。

#### Acceptance Criteria

1. THE Solve_Page SHALL 在顶栏展示「解题」标题及返回按钮。
2. THE Solve_Page SHALL 在底部输入栏提供图片上传按钮、题目输入框和发送按钮。
3. WHEN AI 返回解题回复，THE Solve_Page SHALL 按「考点 → 解题思路 → 解题步骤 → 踩分点 → 易错点」的结构化格式渲染回复内容。
4. IF 用户提交的题目图片无法识别，THEN THE Solve_Page SHALL 展示错误提示并允许用户重新上传。

---

### Requirement 10：出题页

**User Story:** As a 学生用户, I want 在出题页生成预测试卷或自定义题目, so that 我能进行针对性的自测练习。

#### Acceptance Criteria

1. THE Quiz_Page SHALL 展示「预测试卷」和「自定义出题」两个子 Tab。
2. WHEN 用户选择「预测试卷」Tab，THE Quiz_Page SHALL 提供一键生成按钮，点击后以 Markdown 格式展示生成的试卷内容。
3. WHERE 预测试卷已生成，THE Quiz_Page SHALL 提供导出功能，允许用户将试卷导出为文件。
4. WHEN 用户选择「自定义出题」Tab，THE Quiz_Page SHALL 提供题型多选、各题型数量与分值设置、难度选择、考点输入等配置项。
5. WHEN 用户提交自定义出题配置，THE Quiz_Page SHALL 根据配置生成对应题目并展示。

---

### Requirement 11：课程空间页

**User Story:** As a 学生用户, I want 在课程空间浏览我的学科并查看大纲、思维导图和讲义, so that 我能系统地管理和学习各学科内容。

#### Acceptance Criteria

1. THE Course_Space_Page SHALL 以卡片列表形式展示用户已添加的所有学科。
2. WHEN 用户点击某个学科卡片，THE Router SHALL 导航至 `/course-space/:subjectId`，并展示包含「大纲」「思维导图」「讲义」三个子 Tab 的学科详情页。
3. WHEN 用户选择「大纲」Tab，THE Course_Space_Page SHALL 以树形结构展示该学科的知识点大纲。
4. WHEN 用户选择「思维导图」Tab，THE Course_Space_Page SHALL 展示基于大纲节点生成的思维导图及历史导图列表。
5. WHEN 用户选择「讲义」Tab，THE Course_Space_Page SHALL 展示该学科的讲义内容，并提供生成新讲义的入口。
6. WHEN 用户在「思维导图」Tab 触发生成操作，THE Course_Space_Page SHALL 基于当前大纲节点生成新的思维导图并追加至历史列表。

---

### Requirement 12：个人中心页

**User Story:** As a 学生用户, I want 在个人中心查看个人信息、管理学科和查看对话历史, so that 我能维护自己的学习档案。

#### Acceptance Criteria

1. THE Profile_Page SHALL 展示用户头像、用户名和注册时间。
2. THE Profile_Page SHALL 提供「学科管理」入口，点击后导航至 `/profile/subjects`。
3. THE Profile_Page SHALL 提供「对话历史」入口，点击后导航至 `/profile/history`。
4. THE Profile_Page SHALL 提供「退出登录」按钮。
5. WHEN 用户点击「退出登录」，THE App SHALL 清除本地登录状态，并将 Router 重定向至 `/login`。
6. THE Profile_Page 的「对话历史」页 SHALL 以列表形式展示用户的历史 Session，每条记录显示会话标题和最后更新时间。

---

### Requirement 13：路由结构

**User Story:** As a 开发者, I want 应用具备完整且一致的路由结构, so that 各功能页面可通过明确的路径访问和跳转。

#### Acceptance Criteria

1. THE Router SHALL 支持以下路由路径：`/login`、`/register`、`/`、`/chat/:chatId`、`/chat/:chatId/subject/:subjectId`、`/chat/:chatId/task/:taskId`、`/spec`、`/toolkit`、`/toolkit/mistake-book`、`/toolkit/mistake-book/:mistakeId`、`/toolkit/notebooks`、`/toolkit/notebooks/:notebookId`、`/toolkit/notebooks/:notebookId/notes/:noteId`、`/toolkit/solve`、`/toolkit/solve/:chatId`、`/toolkit/quiz`、`/toolkit/quiz/:chatId`、`/course-space`、`/course-space/:subjectId`、`/course-space/:subjectId/outline/:outlineNodeId`、`/course-space/:subjectId/mindmap/:outlineNodeId`、`/course-space/:subjectId/lecture/:outlineNodeId`、`/profile`、`/profile/subjects`、`/profile/history`。
2. IF 用户访问未定义路由，THEN THE Router SHALL 重定向至 `/`。
3. THE Router SHALL 按模块拆分路由配置文件：`auth_routes.dart`、`chat_routes.dart`、`course_space_routes.dart`、`toolkit_routes.dart`。

---

### Requirement 14：全局状态管理

**User Story:** As a 开发者, I want 应用具备统一的全局状态管理, so that 学科选择、登录状态、对话 Session 等跨页面状态能被一致地读取和更新。

#### Acceptance Criteria

1. THE App SHALL 通过 `currentSubjectProvider`（`StateProvider<Subject?>`）在全局共享当前选中学科状态。
2. THE App SHALL 通过 `authProvider`（`StateNotifierProvider<AuthNotifier, AuthState>`）管理登录状态，所有需要鉴权的页面均依赖此 Provider。
3. THE App SHALL 通过 `subjectsProvider`（`FutureProvider<List<Subject>>`）异步加载并缓存学科列表。
4. THE App SHALL 通过 `chatProvider(chatId)`（`StateNotifierProviderFamily`）独立管理每个对话 Session 的状态。
5. THE App SHALL 通过 `currentSessionProvider`（`StateProvider<Session?>`）追踪当前活跃 Session。
6. WHEN `authProvider` 状态变为未登录，THE App SHALL 自动清除 `currentSessionProvider` 和 `currentSubjectProvider` 的状态。
