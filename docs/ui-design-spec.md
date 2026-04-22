# 伴学 App UI 设计系统规范

## 设计理念

**「静谧学习」** — 一个让用户感到平静、专注且激励的学习环境。界面设计融合现代极简主义与东方美学元素，营造沉浸式学习氛围。

---

## 🎨 色彩系统

### 主色调
| 名称 | 色值 | 用途 |
|------|------|------|
| Primary | `#6366F1` | 主按钮、重点强调 |
| Primary Light | `#818CF8` | 悬停状态、次级强调 |
| Primary Dark | `#4F46E5` | 按下状态 |
| Secondary | `#10B981` | 成功状态、进度指示 |
| Accent | `#F59E0B` | 警告、高亮提示 |

### 背景层次
| 名称 | 色值 | 用途 |
|------|------|------|
| Background | `#F8FAFC` | 页面背景 |
| Surface | `#FFFFFF` | 卡片背景 |
| Surface Elevated | `#FFFFFF` | 悬浮卡片 |
| Surface Container | `#F1F5F9` | 列表背景 |

### 文字层次
| 名称 | 色值 | 用途 |
|------|------|------|
| Text Primary | `#1E293B` | 主要文字 |
| Text Secondary | `#64748B` | 次要文字 |
| Text Tertiary | `#94A3B8` | 辅助文字 |
| Text On Primary | `#FFFFFF` | 主色背景上的文字 |

### 深色模式
| 名称 | 色值 | 用途 |
|------|------|------|
| Background Dark | `#0F172A` | 深色背景 |
| Surface Dark | `#1E293B` | 深色卡片 |
| Surface Elevated Dark | `#334155` | 深色悬浮 |
| Text Primary Dark | `#F1F5F9` | 深色主文字 |
| Text Secondary Dark | `#94A3B8` | 深色次文字 |

---

## 📝 字体系统

### 字体家族
- **中文**: Noto Sans SC (已有)
- **英文**: Inter
- **代码**: JetBrains Mono

### 字体比例
```
Display:   32px / 700 / -0.02em (页面大标题)
Headline:  24px / 600 / -0.01em (卡片标题)
Title:     18px / 600 / 0 (区块标题)
Body:      16px / 400 / 0 (正文)
Caption:   14px / 400 / 0.01em (辅助说明)
Small:     12px / 400 / 0.02em (标签)
```

---

## 📏 间距系统

基于 **4px** 基础单位的比例系统：
```
xs:  4px   (紧凑间距)
sm:  8px   (小间距)
md:  12px  (中间距)
lg:  16px  (标准间距)
xl:  24px  (大间距)
2xl: 32px  (区块间距)
3xl: 48px  (页面间距)
```

---

## 🔲 圆角系统

```
sm:   6px   (小按钮、标签)
md:   12px  (卡片、输入框)
lg:   16px  (大卡片)
xl:   24px  (模态框)
full: 999px (圆形)
```

---

## 🌫 阴影系统

```
shadow-sm:   0 1px 2px rgba(0,0,0,0.05)
shadow-md:   0 4px 6px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.05)
shadow-lg:   0 10px 15px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05)
shadow-xl:   0 20px 25px rgba(0,0,0,0.1), 0 10px 10px rgba(0,0,0,0.04)
shadow-glow: 0 0 20px rgba(99,102,241,0.3) (主色光晕)
```

---

## 🎯 视觉效果

### 渐变背景
- **主渐变**: `linear-gradient(135deg, #6366F1 0%, #818CF8 100%)`
- **温暖渐变**: `linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%)`
- **自然渐变**: `linear-gradient(135deg, #10B981 0%, #34D399 100%)`

### 毛玻璃效果
```dart
BackdropFilter(
  blur: sigmaX: 10, sigmaY: 10,
  color: Colors.white.withOpacity(0.8)
)
```

### 动画时长
```
fast:   150ms (微交互)
normal: 300ms (标准过渡)
slow:   500ms (页面切换)
```

---

## 🧱 组件设计规范

### 卡片组件
- 背景: Surface (#FFFFFF)
- 圆角: 12px
- 阴影: shadow-md
- 内边距: 16px
- 悬停: shadow-lg + translateY(-2px)

### 按钮组件
**主要按钮**
- 背景: Primary 渐变
- 文字: 白色
- 圆角: 8px
- 高度: 48px
- 悬停: 亮度+5%

**次要按钮**
- 背景: 透明
- 边框: 1px Primary
- 文字: Primary
- 圆角: 8px

**文字按钮**
- 无背景无边框
- 文字: Primary
- 悬停: 背景 Primary/10%

### 输入框
- 背景: Surface
- 边框: 1px Outline
- 圆角: 12px
- 内边距: 12px 16px
- 聚焦: 边框 Primary + 阴影 glow

### 底部导航
- 高度: 80px (含安全区)
- 背景: 毛玻璃效果
- 图标大小: 24px
- 标签大小: 12px
- 选中: Primary 颜色 + 图标填充

---

## 🖼 媒体资源清单

### 背景图案
1. `assets/images/bg_gradient_primary.png` - 主色渐变背景
2. `assets/images/bg_pattern_dots.png` - 点状图案
3. `assets/images/bg_pattern_waves.png` - 波浪图案
4. `assets/images/bg_gradient_warm.png` - 暖色渐变
5. `assets/images/bg_gradient_nature.png` - 自然渐变

### 空状态插画
1. `assets/images/empty_chat.svg` - 空对话插画
2. `assets/images/empty_library.svg` - 空图书馆插画
3. `assets/images/empty_toolkit.svg` - 空工具箱插画
4. `assets/images/empty_progress.svg` - 空进度插画

### 图标资源
使用 Flutter 内置 Material Icons，通过主题统一配置颜色和大小。

### Logo
1. `assets/images/logo_app.png` - 应用 Logo
2. `assets/images/logo_icon.png` - 图标版本

---

## 📱 响应式断点

```
Mobile:   320px - 639px   (基础设计)
Tablet:   640px - 1023px  (双栏布局)
Desktop:  1024px - 1279px (侧边导航)
Wide:     1280px+        (最大宽度 1280px)
```

---

## ♿ 可访问性标准

- 色彩对比度: 最低 4.5:1 (WCAG AA)
- 触摸目标: 最小 44x44px
- 焦点指示: 2px Primary 轮廓
- 动画: 支持减少动画偏好
