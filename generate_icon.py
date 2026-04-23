#!/usr/bin/env python3
"""
学习助手应用图标生成器 - 山东大学版 V4
简约扁平风格
"""

from PIL import Image, ImageDraw
import math
import os

def create_sdu_icon_v4(size=1024, output_path="sdu_icon_v4.png"):
    """山东大学版图标 V4 - 简约扁平风格"""
    
    os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else ".", exist_ok=True)
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # ============ 配色 ============
    SDU_RED = (156, 12, 19)
    RED_LIGHT = (180, 30, 40)
    RED_DARK = (120, 10, 15)
    WHITE = (255, 255, 255)
    GOLD = (255, 200, 50)
    CREAM = (255, 248, 240)
    
    center = size // 2
    radius = size // 2
    
    # ============ 1. 山大红渐变背景 ============
    for i in range(radius, 0, -1):
        ratio = i / radius
        r = int(RED_LIGHT[0] + (RED_DARK[0] - RED_LIGHT[0]) * ratio)
        g = int(RED_LIGHT[1] + (RED_DARK[1] - RED_LIGHT[1]) * ratio)
        b = int(RED_LIGHT[2] + (RED_DARK[2] - RED_LIGHT[2]) * ratio)
        alpha = int(255 * (0.6 + 0.4 * ratio))
        draw.ellipse(
            [center - i, center - i, center + i, center + i],
            fill=(r, g, b, alpha)
        )
    
    # ============ 2. "山"字图案 - 更隐晦的设计 ============
    # 山字缩小、位置上移、降低透明度
    m_top = int(size * 0.12)      # 山顶位置更靠上
    m_bottom = int(size * 0.30)   # 山底位置也上移，尺寸缩小
    m_height = m_bottom - m_top
    m_width = int(size * 0.38)    # 山字宽度缩小
    
    # 线宽
    stroke_w = max(3, size // 40)  # 线条变细
    
    # 左右山峰的顶点
    left_peak_x = center - int(m_width * 0.42)
    left_peak_y = m_top + int(m_height * 0.20)
    
    right_peak_x = center + int(m_width * 0.42)
    right_peak_y = left_peak_y
    
    # 山底
    left_base_x = center - m_width // 2
    right_base_x = center + m_width // 2
    base_y = m_bottom
    
    # 中间人字形的顶点
    mid_peak_x = center
    mid_peak_y = m_top
    
    # 山字透明度降低 - 用较淡的白色
    mountain_color = (*WHITE, 180)  # 降低透明度
    
    # 绘制左山峰
    draw.polygon([
        (left_base_x, base_y),
        (left_peak_x, left_peak_y),
        (center - int(m_width * 0.18), m_top + int(m_height * 0.60)),
        (left_base_x + int(m_width * 0.08), base_y),
    ], fill=mountain_color)
    
    # 绘制右山峰
    draw.polygon([
        (right_base_x, base_y),
        (right_peak_x, right_peak_y),
        (center + int(m_width * 0.18), m_top + int(m_height * 0.60)),
        (right_base_x - int(m_width * 0.08), base_y),
    ], fill=mountain_color)
    
    # 中间人字形（缩小）
    draw.polygon([
        (mid_peak_x - stroke_w//2, mid_peak_y),
        (mid_peak_x + stroke_w//2, mid_peak_y),
        (mid_peak_x + int(m_width * 0.06), base_y - int(m_height * 0.15)),
        (mid_peak_x - int(m_width * 0.06), base_y - int(m_height * 0.15)),
    ], fill=mountain_color)
    
    # 底部横线（淡化）
    draw.rectangle([
        (left_base_x, base_y - stroke_w//2),
        (right_base_x, base_y + stroke_w//2)
    ], fill=mountain_color)
    
    # ============ 3. 书本图标（有翻开拱起感）============
    book_center_y = int(size * 0.62)  # 回到原来位置
    book_h = int(size * 0.30)
    book_w = int(size * 0.26)
    
    # 书本拱起效果 - 中间高，两边低
    arch_h = int(size * 0.04)  # 拱起高度
    
    # 左页（拱起）
    left_page_points = [
        (center - book_w, book_center_y + book_h//2),  # 左下
        (center - book_w, book_center_y - book_h//2 + arch_h),  # 左上
        (center - int(book_w * 0.3), book_center_y - book_h//2),  # 左拱起
        (center, book_center_y - book_h//2 - arch_h),  # 书脊顶部（最高）
        (center, book_center_y + book_h//2),  # 书脊底部
    ]
    draw.polygon(left_page_points, fill=(*CREAM, 255))
    
    # 右页（拱起）
    right_page_points = [
        (center + book_w, book_center_y + book_h//2),  # 右下
        (center + book_w, book_center_y - book_h//2 + arch_h),  # 右上
        (center + int(book_w * 0.3), book_center_y - book_h//2),  # 右拱起
        (center, book_center_y - book_h//2 - arch_h),  # 书脊顶部
        (center, book_center_y + book_h//2),  # 书脊底部
    ]
    draw.polygon(right_page_points, fill=(*CREAM, 255))
    
    # 书脊线
    spine_w = max(3, size // 100)
    draw.line(
        [(center, book_center_y - book_h//2 - arch_h),
         (center, book_center_y + book_h//2)],
        fill=(*SDU_RED, 220), width=spine_w
    )
    
    # 书页效果线（跟随拱起）
    for i in range(3):
        y_offset = -int(book_h * 0.2) + i * int(book_h * 0.22)
        arch_offset = int(arch_h * (1 - abs(y_offset) / (book_h * 0.5)))
        
        y = book_center_y + y_offset
        
        # 左页线（弧形）
        draw.line(
            [(center - book_w + int(size * 0.03), y + arch_offset//2),
             (center - int(size * 0.05), y - arch_offset//3)],
            fill=(220, 210, 200, 160), width=max(1, size // 400)
        )
        # 右页线（弧形）
        draw.line(
            [(center + book_w - int(size * 0.03), y + arch_offset//2),
             (center + int(size * 0.05), y - arch_offset//3)],
            fill=(220, 210, 200, 160), width=max(1, size // 400)
        )
    
    # ============ 4. 金色五角星（标准五角星）============
    star_y = int(size * 0.05)
    draw_star(draw, center, star_y, int(size * 0.05), (*GOLD, 255))
    
    # 两边小星星
    draw_star(draw, int(size * 0.20), int(size * 0.09), int(size * 0.018), (*GOLD, 180))
    draw_star(draw, int(size * 0.80), int(size * 0.09), int(size * 0.018), (*GOLD, 180))
    
    # ============ 5. 保存 ============
    img.save(output_path, 'PNG')
    print(f"[OK] V4 Icon saved: {output_path}")
    
    sizes = [512, 256, 192, 128, 96, 72, 48, 36]
    for s in sizes:
        resized = img.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(f"generated-images/sdu_icon_v4_{s}x{s}.png", 'PNG')
        print(f"  [OK] {s}x{s}")
    
    return output_path


def draw_star(draw, cx, cy, size, color):
    """绘制标准五角星"""
    points = []
    for i in range(10):
        angle = math.pi * i / 5 - math.pi / 2
        r = size if i % 2 == 0 else size * 0.38
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        points.append((x, y))
    draw.polygon(points, fill=color)


if __name__ == "__main__":
    print("=" * 50)
    print("SDU Icon V4 - Simple Flat Style")
    print("=" * 50)
    
    create_sdu_icon_v4(1024, "generated-images/sdu_icon_v4_1024.png")
    
    print("\nDone!")
