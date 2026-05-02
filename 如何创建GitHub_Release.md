# 📦 如何创建 GitHub Release 并上传 APK

## 方法一：网页操作（推荐，最简单）

### 步骤 1：打开 GitHub 仓库

在浏览器中打开：
```
https://github.com/Markovnikov-Song/study-assistant-app
```

### 步骤 2：进入 Releases 页面

1. 点击右侧的 **"Releases"** 链接
2. 或直接访问：`https://github.com/Markovnikov-Song/study-assistant-app/releases`

### 步骤 3：创建新 Release

1. 点击 **"Draft a new release"** 按钮（绿色按钮）

### 步骤 4：填写 Release 信息

#### Choose a tag（选择标签）
- 点击下拉菜单，选择 **`v1.2.0`**
- 如果没有，输入 `v1.2.0` 然后选择 "Create new tag: v1.2.0 on publish"

#### Release title（发布标题）
```
伴学 v1.2.0 - API 配置功能
```

#### Describe this release（描述）
复制粘贴以下内容：

```markdown
## ✨ 新功能
- 新增 AI 模型配置功能：支持用户自定义 API Key
- 支持共享配置模式（通过口令使用）

## 🔧 改进
- 移除付费模块，改为开源模式
- 增强 API Key 安全存储
- 优化用户体验

## 🐛 修复
- 修复若干已知问题

## 📥 下载安装

1. 下载下方的 **app-v1.2.0.apk** 文件
2. 在手机上打开 APK 文件
3. 允许安装未知来源应用
4. 完成安装

## 📝 更新说明

如果你已经安装了旧版本，直接安装新版本即可覆盖更新。

---

**完整更新日志**: https://github.com/Markovnikov-Song/study-assistant-app/compare/v1.0.0...v1.2.0
```

### 步骤 5：上传 APK 文件

1. 找到 **"Attach binaries by dropping them here or selecting them."** 区域
2. 点击或拖拽文件：
   ```
   C:\Users\41100\develop\study_assistant_app\backend\downloads\app-v1.2.0.apk
   ```
3. 等待上传完成（131MB，可能需要几分钟）

### 步骤 6：发布

1. 确认信息无误
2. 点击 **"Publish release"** 按钮（绿色）

### 步骤 7：验证

发布后，你会看到：
- Release 出现在 Releases 页面
- APK 文件可以下载
- 用户可以看到更新说明

---

## 方法二：使用 GitHub CLI（自动化）

### 前提条件

1. 安装 GitHub CLI：https://cli.github.com/
2. 登录：`gh auth login`

### 运行脚本

```powershell
.\create_github_release.ps1 -Version "1.2.0"
```

脚本会自动：
- 创建 Release
- 上传 APK
- 设置标题和描述

---

## 📱 用户如何看到更新？

### 自动更新提示

1. **用户打开 App**
2. **App 自动检查更新**（调用 `/api/app/version` 接口）
3. **显示更新对话框**：
   ```
   ┌─────────────────────────────────┐
   │    发现新版本 v1.2.0            │
   ├─────────────────────────────────┤
   │ ✨ 新增 API 配置功能            │
   │ 🔧 移除付费模块                 │
   │ 🔒 增强安全性                   │
   ├─────────────────────────────────┤
   │  [稍后再说]      [立即更新]     │
   └─────────────────────────────────┘
   ```
4. **点击"立即更新"**
5. **下载 APK**（从服务器：`http://47.104.165.105:8000/downloads/app-v1.2.0.apk`）
6. **安装更新**

### 手动下载

用户也可以：
1. 访问 GitHub Releases 页面
2. 下载 APK
3. 手动安装

---

## ⚠️ 注意事项

### APK 文件位置

- **本地**: `backend\downloads\app-v1.2.0.apk`
- **服务器**: `/home/admin/study-assistant-app/backend/downloads/app-v1.2.0.apk`
- **GitHub Release**: 作为附件上传
- **不要提交到 Git 仓库**（已添加到 .gitignore）

### 版本号一致性

确保以下版本号一致：
- ✅ `pubspec.yaml`: `version: 1.2.0+3`
- ✅ `backend/.env`: `APP_VERSION=1.2.0`
- ✅ Git tag: `v1.2.0`
- ✅ GitHub Release: `v1.2.0`
- ✅ APK 文件名: `app-v1.2.0.apk`

### 下载链接

- **服务器下载**（应用内更新）: `http://47.104.165.105:8000/downloads/app-v1.2.0.apk`
- **GitHub 下载**（手动下载）: `https://github.com/Markovnikov-Song/study-assistant-app/releases/download/v1.2.0/app-v1.2.0.apk`

---

## 🎯 完整发布流程总结

```
1. 本地构建 APK
   └─> flutter build apk --release

2. 推送代码到 GitHub
   └─> git push origin master
   └─> git push origin v1.2.0

3. 创建 GitHub Release
   └─> 网页操作或使用 gh CLI
   └─> 上传 APK 文件

4. 部署到服务器
   └─> scp APK 到服务器
   └─> 更新 .env 配置
   └─> 重启后端服务

5. 验证
   └─> 测试版本接口
   └─> 测试 APK 下载
   └─> 用户端测试更新
```

---

## 📞 需要帮助？

如果遇到问题：
1. 检查 APK 文件是否存在
2. 检查 GitHub 是否已登录
3. 检查网络连接
4. 查看 GitHub Release 文档：https://docs.github.com/en/repositories/releasing-projects-on-github

---

**当前版本**: 1.2.0  
**APK 位置**: `backend\downloads\app-v1.2.0.apk`  
**GitHub 仓库**: https://github.com/Markovnikov-Song/study-assistant-app
