# Playwright 自动化验收计划

本计划记录 Web 端 Playwright 业务验收。机器可读测试矩阵见 `docs/manifests/test_matrix.json`。

## 基础设施

| 项目 | 当前状态 |
| --- | --- |
| 配置 | `playwright.config.ts` |
| 测试目录 | `tests/playwright/` |
| 默认 Web 地址 | `http://127.0.0.1:8099` |
| 默认服务方式 | `npx serve -s build/web -l tcp://127.0.0.1:8099` |
| 项目 | `chrome-desktop`、`chrome-mobile` |

常用命令：

```powershell
npm run web:build
npm run test:web-smoke
```

## 测试分层

| 层级 | 名称 | 依赖 | 目的 |
| --- | --- | --- | --- |
| L0 | 静态/构建门禁 | Flutter analyze、pytest、Flutter test | 挡住编译和合约错误 |
| L1 | Mock UI smoke | Playwright + API mock | 页面可打开、无 fatal error、核心控件可见 |
| L2 | Mock 交互流 | Playwright + 精准 API mock | 验证前端状态、弹窗、按钮、错误态和请求体 |
| L3 | 真实后端 E2E | Playwright + FastAPI + 测试数据 | 验证真实接口和数据回写 |
| L4 | 视觉回归 | Playwright screenshot | 防止关键页面布局崩坏 |
| L5 | 真机/平台验收 | Android/iOS/ADB/手动 | 验证通知、锁屏、悬浮窗、应用锁、后台保活 |

Playwright 主要覆盖 L1-L4，不能替代 L5。

## 当前已覆盖业务

| 范围 | 已覆盖 | 主要文件 | 状态 |
| --- | --- | --- | --- |
| 解题助手闭环 | 文本解题、SSE、保存笔记、加入错题、历史恢复、错误态 | `tests/playwright/solve_flow.spec.ts`、`backend/tests/test_review_note_contracts.py` | 已通过 |
| 账号和主壳 | 受保护路由、四个主入口渲染 | `tests/playwright/web_smoke.spec.ts` | 已通过 |
| 工具箱入口 | 日历、错题、笔记、出题、去练习、软件工坊入口 | `tests/playwright/web_smoke.spec.ts` | 已通过 |
| 日历 | 创建学习事件、提醒测试面板 | `tests/playwright/calendar_flow.spec.ts` | 已通过 |
| 番茄钟 | 启动、展开、暂停、继续、结束、写学习 session、防打扰入口 | `tests/playwright/calendar_flow.spec.ts` | 已通过 |
| 出题 | 选择科目、资料出题、请求体和结果渲染 | `tests/playwright/quiz_flow.spec.ts` | 已通过 |
| 去练习 | 按科目进入做题弹层、生成题目、提交答案、上下文传递 | `tests/playwright/practice_flow.spec.ts` | 已通过 |
| 错题复盘 | 待复盘列表、进入复盘、提交复盘质量 | `tests/playwright/mistake_flow.spec.ts` | 已通过 |
| 笔记 | 详情、AI 润色、导入资料库、保存请求 | `tests/playwright/notebook_flow.spec.ts` | 已通过 |
| 科目和资源 | 新建科目、资料库状态、重建索引 | `tests/playwright/subject_resource_flow.spec.ts` | 已通过 |
| RAG 来源 | SSE `[SOURCES]` 帧解析到 assistant 消息 | `test/providers/chat_provider_sources_test.dart` | 已通过 |
| 软件工坊 | 四入口展示、运行最近小工具、从首页改造已有小工具 | `test/features/workshop/workshop_page_test.dart` | 已通过 |

## 仍需补强

| 范围 | 原因 | 下一步 |
| --- | --- | --- |
| 软件工坊深层运行器 | 四入口 MVP 已有自动化，选择题、错题训练、资料问答等运行器仍需扩展 | 为每种 runtime renderer 补 L2/L3 用例 |
| 真实后端 E2E | 多数 Playwright 仍用 mock，能验前端业务流，但不能完全证明真实数据链路 | 将关键 L2 用例升级为 L3 |
| 文件上传细节 | Web 文件选择器、单文档菜单和原生权限需要更稳定语义 | 补语义 key 后继续自动化 |
| 锁屏通知和应用锁 | 属于 L5 平台能力，Playwright 无法证明锁屏弹出、悬浮窗或跨应用限制 | Android/iOS 真机验收 |
| 视觉回归 | 当前偏业务流，截图基线不足 | 为首页、解题、日历、科目空间、错题、软件工坊补 L4 |

## 平台能力验收边界

| 能力 | 建议方式 |
| --- | --- |
| Android 锁屏通知 | 真机/模拟器 + 权限授权 + ADB 或手动 |
| iOS 系统通知 | 真机/模拟器 + 手动 |
| Android 悬浮窗应用锁 | 真机/模拟器 + 使用情况访问 + 悬浮窗权限 |
| 后台保活 | 真机长时间测试 |
| 文件选择器原生权限 | Playwright 可 mock 部分，最终仍需真机 |

## 缺陷处理策略

| 缺陷类型 | 处理方式 |
| --- | --- |
| 阻断主流程 | 立即修复，再继续测试 |
| 数据写错或接口合约错 | 立即修复，并补合约测试 |
| UI 文案/布局小问题 | 记录到本轮缺陷清单，集中修 |
| 偶发超时 | 先重跑一次；复现后增加等待条件或修性能 |
| 平台限制 | 标注为非 Playwright 范围，转真机验收 |

## 建议执行顺序

1. 运行 `npm run web:build`。
2. 运行 `npm run test:web-smoke`。
3. 运行 Flutter 合同测试和后端合约测试。
4. 将软件工坊 WORKSHOP-P2-01 从 Widget 测试扩展为 Web/真实后端 E2E。
5. 将日历、资源、练习、错题中的关键 mock 用例升级为真实后端 E2E。
6. 补 L4 截图基线。
7. 最后做 L5 真机平台能力验收。
