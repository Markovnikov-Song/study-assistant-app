# 伴学 App 资源清单

## 📁 目录结构

```
assets/images/
├── backgrounds/     # 背景图片
├── icons/          # 图标资源
└── empty_states/   # 空状态插画
```

## 🎨 需要的资源

### 背景图片 (backgrounds/)

| 文件名 | 尺寸 | 说明 |
|--------|------|------|
| `bg_gradient_primary.png` | 1080x1920 | 主色渐变背景 |
| `bg_pattern_dots.png` | 1080x1920 | 点状图案背景 |
| `bg_waves.png` | 1080x1920 | 波浪装饰背景 |

### 图标资源 (icons/)

| 文件名 | 尺寸 | 说明 |
|--------|------|------|
| `logo_app.png` | 512x512 | 应用 Logo |
| `logo_icon.png` | 192x192 | 应用图标 |

### 空状态插画 (empty_states/)

| 文件名 | 尺寸 | 说明 |
|--------|------|------|
| `empty_chat.svg` | 400x400 | 空对话状态 |
| `empty_library.svg` | 400x400 | 空图书馆状态 |
| `empty_toolkit.svg` | 400x400 | 空工具箱状态 |
| `empty_progress.svg` | 400x400 | 空进度状态 |
| `empty_search.svg` | 400x400 | 空搜索结果 |

## 🎨 设计指南

### 配色方案

使用以下主色调（可在 `lib/core/theme/app_colors.dart` 中找到）：

- **Primary**: `#6366F1` (主紫色)
- **Secondary**: `#10B981` (绿色)
- **Accent**: `#F59E0B` (橙色)
- **Background**: `#F8FAFC` (浅灰白)

### 深色模式

- **Background Dark**: `#0F172A`
- **Surface Dark**: `#1E293B`
- **Text Primary Dark**: `#F1F5F9`

## 📝 添加新资源

1. 将图片资源放入对应目录
2. 在 `pubspec.yaml` 中添加资源路径（如果是新增目录）
3. 重启应用以加载新资源

## ⚠️ 注意事项

- PNG 图片建议使用 WebP 格式以获得更好的压缩率
- SVG 图片需要使用 `flutter_svg` 包支持
- 空状态插画建议使用透明背景
