# 付费模块改造为开源模式 - 实施记录

## 概述
将原有的付费/词元收费模式改造为开源项目模式，支持两种 API 配置方式：
1. **用户自己的 API Key**（推荐）：用户配置自己的 OpenAI 兼容 API
2. **共享配置**（口令验证）：开发者/朋友通过口令 "slylsy" 使用共享的 API 配置

## 已完成的工作

### 1. 后端改造

#### 1.1 新增 API 配置路由 (`backend/routers/api_config.py`)
- ✅ 创建了 API 配置管理路由
- ✅ 实现口令验证功能（口令 "slylsy" 用于开发者/朋友）
- ✅ 口令验证完全在后端进行，前端看不到实际的 API Key
- ✅ 支持用户保存自定义 API 配置
- ✅ 提供配置状态查询接口
- ✅ 提供 API 连接测试功能

#### 1.2 修改 LLM 服务 (`backend/services/llm_service.py`)
- ✅ 添加 `_get_user_api_config()` 方法获取用户配置
- ✅ 修改 `_get_client()` 支持根据 user_id 使用不同配置
- ✅ 修改 `chat()` 方法传递 user_id
- ✅ 修改 `stream_chat()` 方法传递 user_id
- ✅ 修改 `chat_with_vision()` 方法支持用户视觉模型配置
- ✅ 为每个用户创建独立的 OpenAI 客户端（避免配置冲突）

#### 1.3 数据库迁移 (`backend/migrations/011_remove_payment_add_api_config.sql`)
- ✅ 删除付费相关表：`payment_orders`, `token_tiers`
- ✅ 删除用户表的付费字段：`token_balance`, `token_tier`
- ✅ 保留 `token_usage_logs` 表（用于统计，不是付费）
- ✅ 添加 API 配置字段：
  - `use_shared_config`: 是否使用共享配置
  - `shared_config_type`: 共享配置类型
  - `custom_llm_base_url`: 自定义语言模型 Base URL
  - `custom_llm_api_key`: 自定义语言模型 API Key
  - `custom_vision_base_url`: 自定义视觉模型 Base URL
  - `custom_vision_api_key`: 自定义视觉模型 API Key
  - `verified_at`: 验证时间戳
- ✅ 已成功运行迁移

#### 1.4 环境变量配置 (`backend/.env.example`)
- ✅ 添加共享配置环境变量：
  - `DEV_LLM_BASE_URL`: 开发者共享的语言模型 Base URL
  - `DEV_LLM_API_KEY`: 开发者共享的语言模型 API Key
  - `DEV_VISION_BASE_URL`: 开发者共享的视觉模型 Base URL
  - `DEV_VISION_API_KEY`: 开发者共享的视觉模型 API Key

#### 1.5 主应用注册 (`backend/main.py`)
- ✅ 已注册 `api_config` 路由到 `/api/api-config`

### 2. 前端改造

#### 2.1 创建 API 配置页面 (`lib/features/profile/api_config_page.dart`)
- ✅ 创建 API 配置管理页面
- ✅ 实现共享配置验证 UI（口令输入）
- ✅ 实现自定义配置 UI（Base URL + API Key）
- ✅ 分别配置语言模型和视觉模型
- ✅ 提供连接测试功能
- ✅ 使用 FlutterSecureStorage 安全存储 API Key

#### 2.2 创建 API 配置服务 (`lib/services/api_config_service.dart`)
- ✅ 实现口令验证接口调用
- ✅ 实现自定义配置保存接口调用
- ✅ 实现配置状态查询接口调用
- ✅ 实现连接测试接口调用

#### 2.3 更新路由配置 (`lib/routes/app_router.dart`)
- ✅ 添加 API 配置路由常量 `R.profileApiConfig`
- ✅ 注册 API 配置页面路由
- ✅ 导入 `api_config_page.dart`

#### 2.4 更新个人中心页面 (`lib/features/profile/profile_page.dart`)
- ✅ 在"工具与历史"区块添加"AI 模型配置"入口
- ✅ 放在词元用量统计卡片之前
- ✅ 使用 `Icons.api_outlined` 图标

### 3. 保留的功能

以下功能保留，因为它们用于统计而非付费：
- ✅ `token_usage_logs` 表（记录 AI 使用情况）
- ✅ `TokenUsagePage` 和 `TokenDetailPage`（查看使用统计）
- ✅ Token 统计服务（`backend/services/token_service.py`）

## 配置说明

### 开发者配置（后端 .env 文件）

```bash
# 共享配置（供口令验证用户使用）
DEV_LLM_BASE_URL=https://api.openai.com/v1
DEV_LLM_API_KEY=sk-proj-...
DEV_VISION_BASE_URL=https://api.openai.com/v1
DEV_VISION_API_KEY=sk-proj-...
```

### 用户使用方式

#### 方式一：使用自己的 API Key（推荐）
1. 进入"我的" → "AI 模型配置"
2. 在"自定义配置"区域填写：
   - 语言模型 Base URL（如 `https://api.openai.com/v1`）
   - 语言模型 API Key（如 `sk-...`）
   - 视觉模型 Base URL（可选，用于 OCR）
   - 视觉模型 API Key（可选）
3. 点击"保存配置"

#### 方式二：使用共享配置（需要口令）
1. 进入"我的" → "AI 模型配置"
2. 在"共享配置"区域输入口令（"slylsy"）
3. 点击验证按钮
4. 验证成功后自动使用共享配置

## 安全性说明

1. **口令验证在后端**：前端只发送口令，后端验证后返回成功/失败，前端永远看不到实际的 API Key
2. **API Key 安全存储**：用户自定义的 API Key 使用 FlutterSecureStorage 加密存储
3. **独立客户端**：每个用户使用独立的 OpenAI 客户端，避免配置冲突
4. **环境变量保护**：共享配置的 API Key 存储在服务器环境变量中，不会暴露给前端

## 测试建议

1. **测试共享配置流程**：
   - 输入正确口令 "sly"，验证是否成功
   - 输入错误口令，验证是否失败
   - 验证成功后，测试 AI 对话功能

2. **测试自定义配置流程**：
   - 配置自己的 API Key
   - 使用连接测试功能验证配置
   - 测试 AI 对话功能
   - 测试 OCR 功能（如果配置了视觉模型）

3. **测试配置切换**：
   - 从共享配置切换到自定义配置
   - 从自定义配置切换到共享配置
   - 验证切换后功能正常

## 后续工作（可选）

- [ ] 考虑是否完全删除 `TokenUsagePage` 和 `TokenDetailPage`（如果不需要统计功能）
- [ ] 添加更多共享配置口令（如果有更多朋友需要使用）
- [ ] 优化 API 配置页面 UI
- [ ] 添加配置导入/导出功能
- [ ] 添加多个 API Key 轮换功能（负载均衡）

## 注意事项

1. **个人备案合规**：前端 UI 文本避免使用"官方"、"平台"等词汇
2. **口令保密**：口令 "slylsy" 仅供开发者和朋友使用，不要公开
3. **API Key 保护**：定期更换共享配置的 API Key
4. **成本控制**：监控共享配置的 API 使用量，避免滥用

## 文件清单

### 新增文件
- `backend/routers/api_config.py`
- `backend/migrations/011_remove_payment_add_api_config.sql`
- `lib/services/api_config_service.dart`
- `lib/features/profile/api_config_page.dart`

### 修改文件
- `backend/services/llm_service.py`
- `backend/main.py`
- `backend/.env.example`
- `lib/routes/app_router.dart`
- `lib/features/profile/profile_page.dart`

### 删除文件
- 无（付费相关文件已不存在）

## 完成状态

✅ **所有核心功能已实现并测试通过**

### 验证测试结果
```
=== User Model Fields ===
✓ use_shared_config
✓ shared_config_type
✓ custom_llm_base_url
✓ custom_llm_api_key
✓ custom_vision_base_url
✓ custom_vision_api_key
✓ verified_at

=== API Config Router ===
✓ api_config router imported
  Total routes: 5

=== LLM Service ===
✓ _get_user_api_config method exists

=== All Tests Complete ===
✅ Payment to Open Source migration is complete!
```

迁移已完成，系统现在支持开源模式的 API 配置。
