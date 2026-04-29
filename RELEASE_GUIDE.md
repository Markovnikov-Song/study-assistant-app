# 发布新版本指南

本指南说明如何发布新版本到 GitHub 和服务器，并让用户看到更新提示。

## 📋 发布前准备

### 1. 确定版本号

版本号格式：`主版本.次版本.修订版本+构建号`

例如：`1.1.0+2` 表示：
- 主版本：1（重大更新）
- 次版本：1（功能更新）
- 修订版本：0（bug 修复）
- 构建号：2（每次构建递增）

**版本号规则：**
- 重大功能变更或架构调整：主版本 +1
- 新增功能：次版本 +1
- Bug 修复：修订版本 +1
- 每次构建：构建号 +1

### 2. 更新版本号

当前版本：`1.1.0+2`（在 `pubspec.yaml` 中）

**修改 `pubspec.yaml`：**
```yaml
version: 1.2.0+3  # 新版本号
```

### 3. 编写更新日志

创建或更新 `CHANGELOG.md`：

```markdown
## [1.2.0] - 2026-04-29

### 新增
- ✨ AI 模型配置功能：支持用户自定义 API Key
- ✨ 共享配置模式：通过口令使用开发者提供的 API

### 改进
- 🔧 移除付费模块，改为开源模式
- 🔒 增强 API Key 安全存储

### 修复
- 🐛 修复若干已知问题
```

## 🔨 构建 APK

### 方法一：使用 Flutter 命令行

```bash
# 1. 清理旧构建
flutter clean

# 2. 获取依赖
flutter pub get

# 3. 构建 Release APK
flutter build apk --release

# APK 位置：build/app/outputs/flutter-apk/app-release.apk
```

### 方法二：构建 App Bundle（推荐用于 Google Play）

```bash
flutter build appbundle --release

# AAB 位置：build/app/outputs/bundle/release/app-release.aab
```

### 构建后重命名

建议重命名 APK 文件以包含版本号：

```bash
# Windows PowerShell
Copy-Item build/app/outputs/flutter-apk/app-release.apk backend/downloads/app-v1.2.0.apk

# Linux/Mac
cp build/app/outputs/flutter-apk/app-release.apk backend/downloads/app-v1.2.0.apk
```

## 📤 推送到 GitHub

### 1. 提交代码

```bash
# 查看修改
git status

# 添加所有修改
git add .

# 提交（使用有意义的提交信息）
git commit -m "feat: 添加 API 配置功能，移除付费模块 (v1.2.0)"

# 推送到 GitHub
git push origin main
```

### 2. 创建 Git Tag（可选但推荐）

```bash
# 创建带注释的标签
git tag -a v1.2.0 -m "版本 1.2.0: 添加 API 配置功能"

# 推送标签到 GitHub
git push origin v1.2.0
```

### 3. 创建 GitHub Release（可选）

1. 访问 GitHub 仓库页面
2. 点击 "Releases" → "Create a new release"
3. 选择刚创建的标签 `v1.2.0`
4. 填写 Release 标题：`v1.2.0 - API 配置功能`
5. 粘贴更新日志内容
6. 上传 APK 文件（可选）
7. 点击 "Publish release"

## 🚀 部署到服务器

### 1. 上传 APK 到服务器

```bash
# 使用 SCP 上传（替换为你的服务器信息）
scp backend/downloads/app-v1.2.0.apk user@your-server:/path/to/backend/downloads/

# 或者直接在服务器上构建（如果服务器有 Flutter 环境）
```

### 2. 更新后端环境变量

编辑服务器上的 `backend/.env` 文件：

```bash
# 在服务器上编辑
nano /path/to/backend/.env
```

添加或修改以下配置：

```bash
# 应用版本配置
APP_VERSION=1.2.0
APP_MIN_VERSION=1.0.0
APP_DOWNLOAD_URL=http://your-server-ip:8000/downloads/app-v1.2.0.apk
APP_CHANGELOG=✨ 新增 API 配置功能\n🔧 移除付费模块\n🔒 增强安全性
```

**配置说明：**
- `APP_VERSION`: 最新版本号（必须与 pubspec.yaml 一致）
- `APP_MIN_VERSION`: 最低支持版本（低于此版本强制更新）
- `APP_DOWNLOAD_URL`: APK 下载地址（完整 URL）
- `APP_CHANGELOG`: 更新说明（使用 `\n` 换行）

### 3. 重启后端服务

```bash
# 方法一：如果使用 systemd
sudo systemctl restart study-assistant

# 方法二：如果使用 PM2
pm2 restart study-assistant

# 方法三：如果使用 screen/tmux
# 先停止旧进程，然后重新启动
cd /path/to/backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 4. 验证部署

```bash
# 测试版本接口
curl http://your-server-ip:8000/api/app/version

# 应该返回：
# {
#   "version": "1.2.0",
#   "min_version": "1.0.0",
#   "download_url": "http://your-server-ip:8000/downloads/app-v1.2.0.apk",
#   "changelog": "✨ 新增 API 配置功能\n🔧 移除付费模块\n🔒 增强安全性"
# }

# 测试 APK 下载
curl -I http://your-server-ip:8000/downloads/app-v1.2.0.apk
# 应该返回 200 OK
```

## 📱 用户端更新流程

### 自动更新检查

用户打开 App 时会自动检查更新：

1. **启动检查**：App 启动时调用 `/api/app/version` 接口
2. **版本比较**：
   - 如果服务器版本 > 本地版本：显示更新提示
   - 如果本地版本 < 最低支持版本：强制更新
3. **更新提示**：显示对话框，包含更新日志和下载按钮
4. **下载安装**：用户点击下载后，自动下载并提示安装

### 更新对话框示例

```
┌─────────────────────────────────┐
│      发现新版本 v1.2.0          │
├─────────────────────────────────┤
│ ✨ 新增 API 配置功能            │
│ 🔧 移除付费模块                 │
│ 🔒 增强安全性                   │
├─────────────────────────────────┤
│  [稍后再说]      [立即更新]     │
└─────────────────────────────────┘
```

### 强制更新（当版本过低时）

```
┌─────────────────────────────────┐
│      需要更新到 v1.2.0          │
├─────────────────────────────────┤
│ 当前版本过低，需要更新后才能    │
│ 继续使用。                      │
│                                 │
│ ✨ 新增 API 配置功能            │
│ 🔧 移除付费模块                 │
├─────────────────────────────────┤
│            [立即更新]           │
└─────────────────────────────────┘
```

## 🔍 检查更新机制的代码位置

### 后端
- **版本接口**：`backend/main.py` 中的 `/api/app/version`
- **APK 存储**：`backend/downloads/` 目录
- **环境变量**：`backend/.env` 中的 `APP_VERSION` 等

### 前端
- **更新服务**：`lib/services/update_service.dart`
- **更新检查**：`lib/features/home/responsive_shell.dart` 的 `_checkForUpdate()`
- **版本信息**：`pubspec.yaml` 中的 `version`

## 📝 完整发布流程示例

假设要发布 v1.2.0 版本：

```bash
# 1. 更新版本号
# 编辑 pubspec.yaml: version: 1.2.0+3

# 2. 编写更新日志
# 编辑 CHANGELOG.md

# 3. 构建 APK
flutter clean
flutter pub get
flutter build apk --release

# 4. 重命名并复制 APK
Copy-Item build/app/outputs/flutter-apk/app-release.apk backend/downloads/app-v1.2.0.apk

# 5. 提交到 Git
git add .
git commit -m "feat: 添加 API 配置功能 (v1.2.0)"
git tag -a v1.2.0 -m "版本 1.2.0"
git push origin main
git push origin v1.2.0

# 6. 上传到服务器
scp backend/downloads/app-v1.2.0.apk user@server:/path/to/backend/downloads/

# 7. 更新服务器环境变量
# SSH 到服务器
ssh user@server
cd /path/to/backend
nano .env
# 修改 APP_VERSION=1.2.0 等配置

# 8. 重启后端
sudo systemctl restart study-assistant

# 9. 验证
curl http://server-ip:8000/api/app/version
```

## ⚠️ 注意事项

1. **版本号一致性**：
   - `pubspec.yaml` 中的版本号
   - `.env` 中的 `APP_VERSION`
   - APK 文件名
   - Git tag
   - 必须保持一致！

2. **APK 文件大小**：
   - Release APK 通常 20-50MB
   - 确保服务器有足够空间
   - 考虑清理旧版本 APK

3. **下载 URL**：
   - 必须是完整的 HTTP/HTTPS URL
   - 确保服务器防火墙允许访问
   - 测试下载链接是否可访问

4. **更新日志格式**：
   - 使用 `\n` 换行
   - 使用 emoji 增加可读性
   - 保持简洁明了

5. **最低版本控制**：
   - `APP_MIN_VERSION` 用于强制更新
   - 谨慎设置，避免强制所有用户更新
   - 通常只在有重大 bug 或安全问题时使用

## 🎯 快速命令参考

```bash
# 构建 APK
flutter build apk --release

# 提交代码
git add . && git commit -m "feat: 描述" && git push

# 创建标签
git tag -a v1.2.0 -m "版本 1.2.0" && git push origin v1.2.0

# 上传到服务器
scp backend/downloads/app-v1.2.0.apk user@server:/path/

# 测试版本接口
curl http://server-ip:8000/api/app/version
```

## 📚 相关文档

- [Flutter 构建和发布](https://docs.flutter.dev/deployment/android)
- [语义化版本](https://semver.org/lang/zh-CN/)
- [Git 标签](https://git-scm.com/book/zh/v2/Git-基础-打标签)

---

**当前版本**：1.1.0+2  
**下一个版本**：1.2.0+3（建议）  
**服务器地址**：需要在 `.env` 中配置
