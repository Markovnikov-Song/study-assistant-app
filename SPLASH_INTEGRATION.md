# 开屏动画集成说明

## 集成完成 ✅

已成功将 `splash_demo` 中的开屏动画集成到项目中。

## 集成内容

### 1. 文件结构
```
lib/
├── screens/
│   └── splash_screen.dart          # 开屏动画主页面
└── widgets/
    └── splash/
        ├── animated_text.dart      # 动画文字组件
        ├── dust_painter.dart       # 尘埃粒子效果
        └── ink_bleed_painter.dart  # 水墨晕染效果
```

### 2. 字体文件
已复制以下字体到 `assets/fonts/`：
- `LXGWWenKai-Regular.ttf` - 霞鹜文楷（次要文字）
- `LXGWWenKai-Medium.ttf` - 霞鹜文楷中粗体
- `YanshiYouran-Regular.ttf` - 演示悠然小楷（核心文字"学""伴"）
- `ZhiMangXing-Regular.ttf` - 智莽行书

### 3. 路由配置
- 初始路由设置为 `/splash`
- 动画完成后自动跳转到主页 `/`
- 使用 `go_router` 进行页面导航

### 4. 暗黑模式支持 🌓

**项目已有完善的暗黑模式支持：**

#### 检测方式
```dart
final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
```

#### 主题配置位置
- **主题模式**：`lib/app.dart` 中设置 `themeMode: ThemeMode.system`
- **动态主题**：通过 `BackgroundStyle` 系统自动生成浅色/深色主题
- **自动跟随**：跟随系统设置自动切换

#### Splash Screen 的暗黑模式适配
开屏动画已完全适配暗黑模式，会根据系统主题自动调整：

**浅色模式（白天）：**
- 背景：清秀宣纸色 `#F7F9F7` → `#E2EBE5`
- 雾气：淡绿色 `#CDE0D5`
- 次要文字：灰绿色 `#9EBAAB`
- 核心文字：竹青色 `#759A87` → `#32654D`

**深色模式（夜晚）：**
- 背景：幽深墨砚色 `#1A1D1A` → `#101211`
- 雾气：暗幽绿 `#26362D`
- 次要文字：暗幽绿 `#5C7A6A`
- 核心文字：发光玉色 `#4A6B59` → `#9CC9B0`

### 5. 动画效果
- **时长**：5.5秒
- **效果**：
  - 水墨晕染扩散
  - 尘埃粒子漂浮
  - 文字移动和缩放
  - 阴影淡入
  - 震动反馈（90%进度时）
- **转场**：1.2秒淡出过渡到主页

### 6. 显示文字
- 核心文字：**学** **伴**（使用悠然小楷）
- 次要文字：**如微光** **以清风**（使用霞鹜文楷）

## 使用方法

### 测试开屏动画
```bash
flutter run
```

应用启动时会自动显示开屏动画，5.5秒后自动跳转到主页。

### 修改动画时长
在 `lib/screens/splash_screen.dart` 中修改：
```dart
_mainController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 5500), // 修改这里
);
```

### 修改显示文字
在 `_buildTextLayer` 方法中修改文字内容：
```dart
AnimatedSplashText(
  text: "学",  // 修改这里
  // ...
)
```

## 技术特点

1. **响应式设计**：根据屏幕尺寸自动调整布局
2. **性能优化**：使用 CustomPainter 绘制复杂效果
3. **流畅动画**：多个动画控制器协同工作
4. **暗黑模式**：完全适配系统主题
5. **无缝转场**：使用 PageRouteBuilder 实现丝滑过渡

## 注意事项

1. 字体文件较大（约 50MB），首次加载可能需要时间
2. 动画使用了震动反馈，需要设备支持
3. 如需跳过开屏动画，可以在路由配置中修改 `initialLocation`

## 暗黑模式测试

### 在模拟器中测试
- **iOS**: Settings → Developer → Dark Appearance
- **Android**: Settings → Display → Dark theme

### 在代码中强制测试
在 `lib/app.dart` 中临时修改：
```dart
// 强制浅色模式
themeMode: ThemeMode.light,

// 强制深色模式
themeMode: ThemeMode.dark,

// 跟随系统（默认）
themeMode: ThemeMode.system,
```
