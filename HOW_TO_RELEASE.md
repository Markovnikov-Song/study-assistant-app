# 📦 如何发布新版本 - 详细步骤

## 📍 在哪里运行？

**在项目根目录运行**（就是包含 `pubspec.yaml` 的目录）

当前目录：`C:\Users\41100\develop\study_assistant_app`

## 🚀 方法一：使用自动化脚本（最简单）

### 步骤 1：打开 PowerShell

在项目根目录右键 → 选择 "在终端中打开" 或 "Open in Windows Terminal"

或者：
```powershell
# 打开 PowerShell，然后进入项目目录
cd C:\Users\41100\develop\study_assistant_app
```

### 步骤 2：运行发布脚本

```powershell
.\release.ps1 -Version "1.2.0" -BuildNumber 3 -Changelog "✨ 新增 API 配置功能\n🔧 移除付费模块\n🔒 增强安全性"
```

**参数说明：**
- `-Version "1.2.0"` - 新版本号（主.次.修订）
- `-BuildNumber 3` - 构建号（每次递增）
- `-Changelog "..."` - 更新说明（使用 `\n` 换行）

### 步骤 3：按提示操作

脚本会自动完成：
1. ✅ 更新 pubspec.yaml 版本号
2. ✅ 清理旧构建
3. ✅ 获取依赖
4. ✅ 构建 Release APK
5. ✅ 复制 APK 到 downloads 目录
6. ✅ 更新 .env 文件
7. ✅ 提交到 Git
8. ❓ 询问是否推送到 GitHub（输入 y 或 n）

### 步骤 4：上传到服务器

脚本完成后，会显示下一步操作提示。你需要手动：

```powershell
# 上传 APK 到服务器（替换 user 和路径）
scp backend\downloads\app-v1.2.0.apk user@47.104.165.105:/path/to/backend/downloads/
```

### 步骤 5：更新服务器

SSH 到服务器：
```bash
ssh user@47.104.165.105
```

更新 .env 文件（或直接复制本地的 .env）：
```bash
cd /path/to/backend
nano .env
# 修改 APP_VERSION=1.2.0 等配置
```

重启后端服务：
```bash
sudo systemctl restart study-assistant
# 或
pm2 restart study-assistant
```

### 步骤 6：验证

```powershell
# 在本地运行测试脚本
.\test_version_api.ps1
```

## 🔧 方法二：手动发布（更灵活）

### 1. 更新版本号

编辑 `pubspec.yaml`：
```yaml
version: 1.2.0+3  # 改这里
```

### 2. 构建 APK

在项目根目录运行：
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

### 3. 复制 APK

```powershell
# 创建 downloads 目录（如果不存在）
New-Item -ItemType Directory -Force -Path backend\downloads

# 复制并重命名 APK
Copy-Item build\app\outputs\flutter-apk\app-release.apk backend\downloads\app-v1.2.0.apk
```

### 4. 更新 backend/.env

编辑 `backend\.env` 文件，修改以下内容：
```bash
APP_VERSION=1.2.0
APP_MIN_VERSION=1.0.0
APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v1.2.0.apk
APP_CHANGELOG=✨ 新增 API 配置功能\n🔧 移除付费模块\n🔒 增强安全性
```

### 5. 提交到 Git

```powershell
git add .
git commit -m "release: v1.2.0 - 添加 API 配置功能"
git tag -a v1.2.0 -m "版本 1.2.0"
git push origin main
git push origin v1.2.0
```

### 6. 上传到服务器并重启

（同方法一的步骤 4-6）

## 📝 完整示例

假设你要发布 v1.2.0 版本：

```powershell
# 1. 确保在项目根目录
cd C:\Users\41100\develop\study_assistant_app

# 2. 运行发布脚本
.\release.ps1 -Version "1.2.0" -BuildNumber 3 -Changelog "✨ 新增 API 配置功能\n🔧 移除付费模块"

# 3. 当询问是否推送时，输入 y
# 是否推送到 GitHub? (y/n): y

# 4. 上传到服务器（需要替换实际的用户名和路径）
scp backend\downloads\app-v1.2.0.apk root@47.104.165.105:/root/study_assistant/backend/downloads/

# 5. SSH 到服务器
ssh root@47.104.165.105

# 6. 在服务器上更新 .env 并重启
cd /root/study_assistant/backend
nano .env  # 修改 APP_VERSION 等
sudo systemctl restart study-assistant

# 7. 退出服务器，在本地测试
exit
.\test_version_api.ps1
```

## ⚠️ 常见问题

### Q1: 脚本无法运行，提示"无法加载"

**解决方法：**
```powershell
# 临时允许运行脚本
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 然后再运行
.\release.ps1 -Version "1.2.0" -BuildNumber 3 -Changelog "更新说明"
```

### Q2: Flutter 命令找不到

**解决方法：**
确保 Flutter 已添加到系统 PATH，或使用完整路径：
```powershell
C:\path\to\flutter\bin\flutter.bat build apk --release
```

### Q3: Git 推送失败

**可能原因：**
- 没有配置 Git 远程仓库
- 没有权限

**解决方法：**
```powershell
# 查看远程仓库
git remote -v

# 如果没有，添加远程仓库
git remote add origin https://github.com/yourusername/your-repo.git

# 配置 Git 用户信息
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### Q4: 服务器上传失败

**可能原因：**
- SSH 密钥未配置
- 路径不正确

**解决方法：**
```powershell
# 使用密码方式上传（会提示输入密码）
scp backend\downloads\app-v1.2.0.apk user@47.104.165.105:/path/

# 或配置 SSH 密钥（一次性配置）
ssh-keygen
ssh-copy-id user@47.104.165.105
```

## 🎯 快速命令参考

```powershell
# 发布新版本
.\release.ps1 -Version "1.2.0" -BuildNumber 3 -Changelog "更新说明"

# 测试版本 API
.\test_version_api.ps1

# 查看当前版本
Get-Content pubspec.yaml | Select-String "version:"

# 查看 Git 状态
git status

# 查看最新标签
git tag -l | Select-Object -Last 5
```

## 📞 需要帮助？

如果遇到问题：
1. 检查是否在项目根目录（`C:\Users\41100\develop\study_assistant_app`）
2. 检查 Flutter 是否正确安装（`flutter --version`）
3. 检查 Git 是否正确配置（`git --version`）
4. 查看详细文档：`RELEASE_GUIDE.md`

---

**当前版本**：1.1.0+2  
**建议下一版本**：1.2.0+3  
**项目目录**：C:\Users\41100\develop\study_assistant_app
