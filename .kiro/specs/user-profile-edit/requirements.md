# Requirements Document

## Introduction

为学科学习助手 App 的"我的"页面（ProfilePage）新增用户资料编辑功能，允许已登录用户修改用户名、密码和头像。后端基于 FastAPI + PostgreSQL，前端基于 Flutter + Riverpod。默认头像为用户名首字母的 CircleAvatar；用户可从相册选择自定义头像，头像存储在服务器端。

## Glossary

- **Profile_Page**: Flutter 端"我的"页面，展示用户信息并提供编辑入口
- **Edit_Profile_Page**: 用户资料编辑页面，包含修改用户名和修改密码两个入口
- **Change_Username_Form**: 修改用户名的表单组件
- **Change_Password_Form**: 修改密码的表单组件，需要旧密码验证
- **Profile_API**: FastAPI 后端提供的用户资料编辑接口（`PATCH /users/me/username`、`PATCH /users/me/password`）
- **Auth_State**: Riverpod 管理的登录状态，包含 access_token、user_id、username
- **Password_Hash**: 使用 bcrypt 存储在 PostgreSQL users 表中的密码哈希值
- **Avatar**: 用户头像，默认为用户名首字母的 CircleAvatar；用户上传后替换为自定义图片
- **Avatar_Picker**: Flutter 端调用系统相册的图片选择组件（基于 image_picker）
- **Avatar_API**: FastAPI 后端提供的头像上传与获取接口（`POST /users/me/avatar`、`GET /users/me/avatar`）
- **Avatar_Data**: 存储在 PostgreSQL users 表中的头像数据，以 base64 字符串或文件路径形式保存

---

## Requirements

### Requirement 1: 进入用户资料编辑页

**User Story:** As a logged-in user, I want to access a profile editing page from the "我的" tab, so that I can update my account information.

#### Acceptance Criteria

1. THE Profile_Page SHALL display an "编辑资料" entry that navigates to Edit_Profile_Page.
2. WHEN the user taps the "编辑资料" entry, THE Profile_Page SHALL navigate to Edit_Profile_Page.
3. THE Edit_Profile_Page SHALL display two separate entries: "修改用户名" and "修改密码".

---

### Requirement 2: 修改用户名

**User Story:** As a logged-in user, I want to change my username, so that I can update my display name.

#### Acceptance Criteria

1. WHEN the user taps "修改用户名", THE Edit_Profile_Page SHALL display Change_Username_Form with the current username pre-filled.
2. THE Change_Username_Form SHALL accept a username between 1 and 64 characters in length.
3. IF the user submits an empty username or a username exceeding 64 characters, THEN THE Change_Username_Form SHALL display a validation error message and SHALL NOT submit the request.
4. WHEN the user submits a valid new username, THE Profile_API SHALL send a `PATCH /users/me/username` request with the new username and the current Bearer token.
5. WHEN the Profile_API returns HTTP 200, THE Auth_State SHALL update the stored username to the new value and THE Edit_Profile_Page SHALL display a success message.
6. IF the Profile_API returns HTTP 409 (username already taken), THEN THE Change_Username_Form SHALL display the error message "用户名已被占用".
7. IF the Profile_API returns an error other than 409, THEN THE Change_Username_Form SHALL display a generic error message "修改失败，请稍后重试".
8. WHEN the username is updated successfully, THE Profile_Page SHALL reflect the new username on next render.

---

### Requirement 3: 修改密码

**User Story:** As a logged-in user, I want to change my password with old-password verification, so that my account remains secure.

#### Acceptance Criteria

1. WHEN the user taps "修改密码", THE Edit_Profile_Page SHALL display Change_Password_Form with three fields: "当前密码"、"新密码"、"确认新密码".
2. THE Change_Password_Form SHALL require "新密码" to be at least 6 characters in length.
3. IF the user submits and "新密码" does not match "确认新密码", THEN THE Change_Password_Form SHALL display the error message "两次输入的密码不一致" and SHALL NOT submit the request.
4. IF the user submits and any field is empty, THEN THE Change_Password_Form SHALL display a validation error and SHALL NOT submit the request.
5. WHEN the user submits valid input, THE Profile_API SHALL send a `PATCH /users/me/password` request with the old password and new password, authenticated with the current Bearer token.
6. WHEN the Profile_API returns HTTP 200, THE Change_Password_Form SHALL display a success message "密码修改成功".
7. IF the Profile_API returns HTTP 401 (old password incorrect), THEN THE Change_Password_Form SHALL display the error message "当前密码错误".
8. IF the Profile_API returns an error other than 401, THEN THE Change_Password_Form SHALL display a generic error message "修改失败，请稍后重试".
9. WHILE the Profile_API request is in progress, THE Change_Password_Form SHALL disable the submit button to prevent duplicate submissions.

---

### Requirement 4: 后端用户名修改接口

**User Story:** As the system, I want a secure API endpoint for username updates, so that only authenticated users can change their own username.

#### Acceptance Criteria

1. THE Profile_API SHALL expose `PATCH /users/me/username` requiring a valid Bearer token.
2. WHEN a valid request is received with a new username between 1 and 64 characters, THE Profile_API SHALL update the username in the users table and return HTTP 200 with the updated username.
3. IF the requested username is already taken by another user, THEN THE Profile_API SHALL return HTTP 409 with a descriptive error message.
4. IF the request does not include a valid Bearer token, THEN THE Profile_API SHALL return HTTP 401.
5. IF the new username is empty or exceeds 64 characters, THEN THE Profile_API SHALL return HTTP 422.

---

### Requirement 5: 后端密码修改接口

**User Story:** As the system, I want a secure API endpoint for password updates that verifies the old password, so that unauthorized password changes are prevented.

#### Acceptance Criteria

1. THE Profile_API SHALL expose `PATCH /users/me/password` requiring a valid Bearer token.
2. WHEN a valid request is received, THE Profile_API SHALL verify the provided old password against the stored Password_Hash using bcrypt.
3. IF the old password does not match the stored Password_Hash, THEN THE Profile_API SHALL return HTTP 401 with the error message "当前密码错误".
4. WHEN the old password is verified and the new password is at least 6 characters, THE Profile_API SHALL hash the new password with bcrypt and update the Password_Hash in the users table, then return HTTP 200.
5. IF the new password is fewer than 6 characters, THEN THE Profile_API SHALL return HTTP 422.
6. IF the request does not include a valid Bearer token, THEN THE Profile_API SHALL return HTTP 401.

---

### Requirement 6: 头像上传

**User Story:** As a logged-in user, I want to upload a custom avatar from my photo library, so that my profile displays a personalized image instead of the default initial.

#### Acceptance Criteria

1. THE Profile_Page SHALL display the Avatar in the user info area; if no custom Avatar has been uploaded, THE Profile_Page SHALL render a CircleAvatar showing the first character of the username.
2. THE Edit_Profile_Page SHALL display the current Avatar and a "更换头像" button.
3. WHEN the user taps "更换头像", THE Avatar_Picker SHALL display a bottom sheet with two options: "拍照" and "从相册选择".
4. WHEN the user selects "拍照", THE Avatar_Picker SHALL open the device camera for photo capture; WHEN the user selects "从相册选择", THE Avatar_Picker SHALL open the system photo library.
4. WHEN the user selects an image, THE Avatar_Picker SHALL compress the image to a maximum of 512×512 pixels before uploading.
5. WHEN a compressed image is ready, THE Avatar_API SHALL send a `POST /users/me/avatar` request with the image encoded as a base64 string and authenticated with the current Bearer token.
6. WHEN the Avatar_API returns HTTP 200, THE Edit_Profile_Page SHALL update the displayed Avatar to the newly uploaded image without requiring a page reload.
7. WHEN the Avatar_API returns HTTP 200, THE Profile_Page SHALL display the updated Avatar on next render.
8. IF the selected image exceeds 5 MB after compression, THEN THE Avatar_Picker SHALL display the error message "图片过大，请选择小于 5MB 的图片" and SHALL NOT submit the request.
9. IF the Avatar_API returns an error, THEN THE Edit_Profile_Page SHALL display the error message "头像上传失败，请稍后重试".
10. THE Avatar_API SHALL expose `POST /users/me/avatar` requiring a valid Bearer token, accept a base64-encoded image string, store the Avatar_Data in the users table, and return HTTP 200 with the stored avatar URL or base64 string.
11. IF the request to `POST /users/me/avatar` does not include a valid Bearer token, THEN THE Avatar_API SHALL return HTTP 401.
