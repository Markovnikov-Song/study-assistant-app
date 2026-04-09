# Implementation Plan: user-profile-edit

## Overview

按照设计文档，分层实现用户资料编辑功能：先完成后端接口和数据库变更，再实现 Flutter 服务层与状态管理，最后构建 UI 组件并完成路由接入。

## Tasks

- [x] 1. 数据库与后端基础层
  - [x] 1.1 为 `users` 表新增 `avatar` 字段并更新 ORM 模型
    - 在 `backend/models/user.py`（或对应 ORM 文件）中为 `User` 添加 `avatar = Column(Text, nullable=True)`
    - 编写 Alembic migration 或直接执行 `ALTER TABLE users ADD COLUMN avatar TEXT`
    - _Requirements: 6.10_

  - [x] 1.2 新建 `backend/routers/users.py` 并注册路由
    - 创建 `APIRouter(prefix="/users")`
    - 定义 `UsernameUpdateIn`、`PasswordUpdateIn`、`AvatarUpdateIn`、`UserOut` Schema
    - 在 `main.py` 中 `include_router`
    - _Requirements: 4.1, 5.1, 6.10_

- [x] 2. 后端用户名修改接口
  - [x] 2.1 实现 `PATCH /users/me/username`
    - 依赖 `get_current_user`；校验长度 1–64；检查用户名唯一性；更新数据库；返回 `UserOut`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ]* 2.2 为 Property 5 编写 pytest 属性测试
    - **Property 5: 后端用户名接口验证长度并更新**
    - **Validates: Requirements 4.2, 4.5**
    - 使用 `hypothesis` 生成长度 1–64 的字符串验证 200；生成长度 0 或 >64 的字符串验证 422

  - [ ]* 2.3 为 `PATCH /users/me/username` 编写单元测试
    - 覆盖：合法用户名 → 200；重复用户名 → 409；无 token → 401；非法长度 → 422
    - _Requirements: 4.1–4.5_

- [x] 3. 后端密码修改接口
  - [x] 3.1 实现 `PATCH /users/me/password`
    - 依赖 `get_current_user`；bcrypt 验证旧密码；校验新密码长度 ≥ 6；哈希新密码并更新数据库；返回 HTTP 200
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]* 3.2 为 Property 6 编写 pytest 属性测试
    - **Property 6: 后端密码接口验证旧密码并更新哈希**
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5**
    - 使用 `hypothesis` 生成正确旧密码 + 长度 ≥ 6 新密码验证 200 及哈希更新；错误旧密码验证 401；新密码长度 < 6 验证 422

  - [ ]* 3.3 为 `PATCH /users/me/password` 编写单元测试
    - 覆盖：正确旧密码 → 200；错误旧密码 → 401；新密码过短 → 422；无 token → 401
    - _Requirements: 5.1–5.6_

- [x] 4. 后端头像与用户信息接口
  - [x] 4.1 实现 `POST /users/me/avatar` 和 `GET /users/me`
    - `POST /users/me/avatar`：接收 `AvatarUpdateIn`，将 base64 存入 `users.avatar`，返回 HTTP 200 含 `UserOut`
    - `GET /users/me`：返回当前用户的 `UserOut`（含 `avatar_base64`）
    - _Requirements: 6.10, 6.11_

  - [ ]* 4.2 为头像接口编写单元测试
    - 覆盖：合法 base64 → 200；无 token → 401；`GET /users/me` 返回含 avatar 的用户信息
    - _Requirements: 6.10, 6.11_

- [x] 5. Checkpoint — 确保后端所有测试通过
  - 确保所有 pytest 测试通过，如有问题请向用户说明。

- [x] 6. Flutter 常量与模型层
  - [x] 6.1 在 `lib/core/constants/api_constants.dart` 新增 API 路径常量
    - 新增 `userMe`、`userMeUsername`、`userMePassword`、`userMeAvatar` 四个常量
    - _Requirements: 2.4, 3.5, 6.5_

  - [x] 6.2 更新 `lib/models/user.dart`，新增 `avatarBase64` 字段
    - 在 `User` 类中添加 `final String? avatarBase64`
    - 更新 `fromJson` / `copyWith` 等方法
    - _Requirements: 6.1_

- [x] 7. Flutter 状态管理层
  - [x] 7.1 更新 `lib/providers/auth_provider.dart`
    - `AuthNotifier` 新增 `updateUsername(String newUsername)` 和 `updateAvatar(String base64)` 方法，更新 `AuthState.user`
    - _Requirements: 2.5, 2.8, 6.6_

  - [ ]* 7.2 为 Property 2 编写属性测试
    - **Property 2: 成功修改用户名后 AuthState 同步更新**
    - **Validates: Requirements 2.5, 2.8**
    - 使用 `glados` 或 `fast_check` 生成合法用户名，验证 `updateUsername` 后 `state.user.username` 等于新值

- [x] 8. Flutter ProfileService
  - [x] 8.1 新建 `lib/services/profile_service.dart`
    - 实现 `changeUsername(String newUsername)`、`changePassword(String oldPwd, String newPwd)`、`uploadAvatar(Uint8List bytes)` 三个方法
    - 所有方法携带 Bearer token，调用对应 API 常量路径
    - `uploadAvatar` 将字节数组 base64 编码后发送
    - _Requirements: 2.4, 3.5, 6.5_

  - [ ]* 8.2 为 Property 4 编写属性测试
    - **Property 4: 提交有效密码时发送正确的 HTTP 请求**
    - **Validates: Requirements 3.5**
    - mock Dio，生成合法（旧密码，新密码）组合，验证请求 URL、headers、body 字段

  - [ ]* 8.3 为 Property 9 编写属性测试
    - **Property 9: 头像上传编码正确性**
    - **Validates: Requirements 6.5**
    - 生成任意字节数组，验证 `uploadAvatar` 发送的 base64 解码后与原始字节相等（round-trip）

  - [ ]* 8.4 为 ProfileService 编写单元测试
    - mock Dio，验证 `changeUsername` / `changePassword` / `uploadAvatar` 的请求构造
    - _Requirements: 2.4, 3.5, 6.5_

- [x] 9. Flutter 头像选择组件
  - [x] 9.1 新建 `lib/features/profile/avatar_picker.dart`
    - 底部弹窗含"拍照"和"从相册选择"两个选项，调用 `image_picker`
    - 选图后压缩至最大 512×512 像素，JPEG quality=85
    - 压缩后超过 5 MB 则显示 SnackBar 错误，不发请求
    - 压缩成功后调用 `ProfileService.uploadAvatar`，成功后调用 `AuthNotifier.updateAvatar`
    - _Requirements: 6.3, 6.4, 6.5, 6.6, 6.8, 6.9_

  - [ ]* 9.2 为 Property 7 编写属性测试
    - **Property 7: 头像展示规则**
    - **Validates: Requirements 6.1**
    - 生成非空 `avatarBase64` 验证渲染 `Image` 组件；生成 null/空字符串验证渲染首字母 `CircleAvatar`

  - [ ]* 9.3 为 Property 8 编写属性测试
    - **Property 8: 图片压缩约束**
    - **Validates: Requirements 6.5**
    - 生成任意尺寸图片，验证压缩后宽高均不超过 512 像素

- [x] 10. Flutter 表单组件
  - [x] 10.1 新建 `lib/features/profile/change_username_form.dart`
    - 含当前用户名预填充的输入框和提交按钮
    - 本地验证：空或超过 64 字符显示 inline 错误，不发请求
    - 提交中禁用按钮；成功显示成功提示；409 显示"用户名已被占用"；其他错误显示"修改失败，请稍后重试"
    - 成功后调用 `AuthNotifier.updateUsername`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [ ]* 10.2 为 Property 1 编写属性测试
    - **Property 1: 用户名验证器接受合法长度，拒绝非法长度**
    - **Validates: Requirements 2.2, 2.3**
    - 生成长度 1–64 的字符串验证验证器返回 null；生成长度 0 或 >64 的字符串验证返回非 null 错误信息

  - [x] 10.3 新建 `lib/features/profile/change_password_form.dart`
    - 含"当前密码"、"新密码"、"确认新密码"三个字段
    - 本地验证：任意字段为空、新密码 < 6 字符、两次密码不一致均显示 inline 错误，不发请求
    - 提交中禁用按钮；成功显示"密码修改成功"；401 显示"当前密码错误"；其他错误显示"修改失败，请稍后重试"
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9_

  - [ ]* 10.4 为 Property 3 编写属性测试
    - **Property 3: 密码验证器——长度与一致性**
    - **Validates: Requirements 3.2, 3.3**
    - 生成长度 < 6 的新密码验证验证器拒绝；生成两个不相等字符串验证确认密码验证器返回"两次输入的密码不一致"

- [x] 11. Flutter EditProfilePage 与 ProfilePage 更新
  - [x] 11.1 新建 `lib/features/profile/edit_profile_page.dart`
    - 展示当前头像（有则显示图片，无则显示首字母 CircleAvatar）和"更换头像"按钮
    - 包含"修改用户名"和"修改密码"两个入口，点击展开对应表单
    - 头像更换成功后即时更新页面显示
    - _Requirements: 1.3, 6.2, 6.6, 6.7, 6.9_

  - [x] 11.2 更新 `lib/features/profile/profile_page.dart`
    - 用户信息区域展示头像：有 `avatarBase64` 则显示图片，否则显示首字母 CircleAvatar
    - 新增"编辑资料"入口，点击导航至 `/profile/edit`
    - _Requirements: 1.1, 1.2, 6.1_

- [x] 12. 路由接入
  - [x] 12.1 在 `lib/routes/app_router.dart` 新增 `/profile/edit` 路由
    - 在 `/profile` 路由下添加子路由 `/profile/edit` 指向 `EditProfilePage`
    - 路由结构与 ui-redesign.md 中定义的 `/profile/edit` 保持一致
    - _Requirements: 1.1, 1.2_

- [x] 13. Final Checkpoint — 确保所有测试通过
  - 确保所有 Flutter 和后端测试通过，如有问题请向用户说明。

## Notes

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 进度
- 每个任务均引用具体需求条款以保证可追溯性
- 属性测试验证跨输入的普遍正确性，单元测试验证具体示例和边界条件
- 后端属性测试使用 `hypothesis`，Flutter 属性测试使用 `glados` 或 `fast_check`
- 路由结构遵循 ui-redesign.md 中定义的 `/profile/edit` 路径
