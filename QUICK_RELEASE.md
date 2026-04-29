# 🚀 快速发布参考

## 方法一：使用自动化脚本（推荐）

```powershell
# 发布新版本（例如 1.2.0）
.\release.ps1 -Version "1.2.0" -BuildNumber 3 -Changelog "✨ 新增 API 配置功能\n🔧 移除付费模块"

# 测试版本 API
.\test_version_api.ps1
```

## 方法二：手动发布

### 1️⃣ 更新版本号
编辑 `pubspec.yaml`：
```yaml
version: 1.2.0+3
```

### 2️⃣ 构建 APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 3️⃣ 复制 APK
```powershell
Copy-Item build/app/outputs/flutter-apk/app-release.apk backend/downloads/app-v1.2.0.apk
```

### 4️⃣ 更新 backend/.env
```bash
APP_VERSION=1.2.0
APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v1.2.0.apk
APP_CHANGELOG=✨ 新增功能\n🔧 改进\n🐛 修复
```

### 5️⃣ 提交到 Git
```bash
git add .
git commit -m "release: v1.2.0"
git tag -a v1.2.0 -m "版本 1.2.0"
git push origin main
git push origin v1.2.0
```

### 6️⃣ 部署到服务器
```bash
# 上传 APK
scp backend/downloads/app-v1.2.0.apk user@47.104.165.105:/path/to/backend/downloads/

# SSH 到服务器
ssh user@47.104.165.105

# 更新 .env（或直接复制本地 .env）
nano /path/to/backend/.env

# 重启服务
sudo systemctl restart study-assistant
# 或
pm2 restart study-assistant
```

### 7️⃣ 验证
```bash
curl http://47.104.165.105:8000/api/app/version
```

## 📱 用户端更新流程

1. **用户打开 App** → 自动检查更新
2. **发现新版本** → 显示更新对话框
3. **点击更新** → 下载 APK
4. **下载完成** → 提示安装
5. **安装完成** → 重启 App

## ⚠️ 重要提醒

- ✅ 确保版本号一致（pubspec.yaml 和 .env）
- ✅ 测试 APK 下载链接可访问
- ✅ 更新日志使用 `\n` 换行
- ✅ 推送前先在本地测试

## 🔗 服务器信息

- **IP**: 47.104.165.105
- **端口**: 8000
- **APK 目录**: `/path/to/backend/downloads/`
- **版本接口**: http://47.104.165.105:8000/api/app/version

## 📝 版本号规则

- **主版本**（1.x.x）：重大更新
- **次版本**（x.1.x）：新功能
- **修订版本**（x.x.1）：Bug 修复
- **构建号**（+2）：每次构建递增

当前版本：**1.1.0+2**  
建议下一版本：**1.2.0+3**
