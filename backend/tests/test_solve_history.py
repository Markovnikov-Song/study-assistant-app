"""
属性测试：解题历史记录相关功能。

包含：
  - 属性 1：会话标题截断不变性 — 对任意非空文本，标题长度 ≤ 16 字符
  - 属性 2：空文本标题格式正确性 — 对任意空白字符串，标题以"解题记录 "开头
  - 属性 5：图片 Base64 存储往返一致性 — 对任意 Base64 列表，JSONB 序列化/反序列化后数据不变

**Validates: Requirements 1.1, 1.4, 3.2, 11.1, 11.2, 11.3**
"""
from __future__ import annotations

import sys
import os
import json

# 确保 backend 包可被导入
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from cas.executors.solve_problem import _generate_title


# ---------------------------------------------------------------------------
# 策略定义
# ---------------------------------------------------------------------------

# 非空文本策略（至少 1 个非空白字符）
_nonempty_text = st.text(min_size=1).filter(lambda s: s.strip())

# 空白文本策略（空字符串或纯空白字符）
_blank_text = st.one_of(
    st.just(""),
    st.text(alphabet=st.characters(whitelist_categories=("Zs",)), min_size=1, max_size=20),
    st.just("   "),
    st.just("\t\n"),
)

# Base64 字符集策略（模拟真实 Base64 编码字符串）
_base64_chars = st.text(
    alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",
    min_size=0,
    max_size=200,
)

# Base64 列表策略（0 到 4 张图片）
_base64_list = st.lists(_base64_chars, min_size=0, max_size=4)


# ---------------------------------------------------------------------------
# 属性 1：会话标题截断不变性
# Validates: Requirements 11.1, 11.3
# ---------------------------------------------------------------------------

@given(_nonempty_text)
@settings(max_examples=200, deadline=None)
def test_title_length_invariant(text: str):
    """属性 1：会话标题截断不变性

    对任意非空文本，_generate_title 返回的标题长度 ≤ 16 字符。
    （15 字符内容 + 最多 1 个省略号"…"）

    **Validates: Requirements 11.1, 11.3**
    """
    title = _generate_title(text)
    assert len(title) <= 16, (
        f"标题长度 {len(title)} 超过 16 字符限制。"
        f"输入文本（前 30 字符）: {repr(text[:30])!r}，"
        f"生成标题: {repr(title)!r}"
    )


@given(_nonempty_text)
@settings(max_examples=200, deadline=None)
def test_title_content_from_nonempty_text(text: str):
    """属性 1 补充：非空文本标题内容来自原文本前 15 字符

    对任意非空文本，标题应以原文本（strip 后）的前 15 字符开头。

    **Validates: Requirements 11.1**
    """
    title = _generate_title(text)
    stripped = text.strip()
    expected_prefix = stripped[:15]
    assert title.startswith(expected_prefix), (
        f"标题 {repr(title)!r} 未以原文本前 15 字符 {repr(expected_prefix)!r} 开头。"
        f"输入文本（前 30 字符）: {repr(text[:30])!r}"
    )


@given(st.text(min_size=16))
@settings(max_examples=200, deadline=None)
def test_title_ellipsis_when_truncated(text: str):
    """属性 1 补充：超过 15 字符时追加省略号

    对任意长度 ≥ 16 的文本（strip 后必然 > 15 字符），标题应以"…"结尾。

    **Validates: Requirements 11.3**
    """
    # 确保 strip 后仍然 > 15 字符（直接生成足够长的文本）
    from hypothesis import assume
    assume(len(text.strip()) > 15)
    title = _generate_title(text)
    assert title.endswith("…"), (
        f"标题 {repr(title)!r} 未以省略号结尾。"
        f"输入文本（前 30 字符）: {repr(text[:30])!r}"
    )


@given(st.text(min_size=1, max_size=15))
@settings(max_examples=200, deadline=None)
def test_title_no_ellipsis_when_short(text: str):
    """属性 1 补充：不超过 15 字符时不追加省略号

    对任意 strip 后长度 ≤ 15 的文本，标题不应以"…"结尾。

    **Validates: Requirements 11.3**
    """
    from hypothesis import assume
    assume(len(text.strip()) <= 15 and len(text.strip()) > 0)
    title = _generate_title(text)
    assert not title.endswith("…"), (
        f"标题 {repr(title)!r} 不应以省略号结尾（文本长度 ≤ 15）。"
        f"输入文本: {repr(text)!r}"
    )


# ---------------------------------------------------------------------------
# 属性 2：空文本标题格式正确性
# Validates: Requirements 11.2
# ---------------------------------------------------------------------------

@given(_blank_text)
@settings(max_examples=100, deadline=None)
def test_blank_text_title_format(text: str):
    """属性 2：空文本标题格式正确性

    对任意空白字符串（空字符串或纯空白），_generate_title 返回的标题
    应以"解题记录 "开头。

    **Validates: Requirements 11.2**
    """
    title = _generate_title(text)
    assert title.startswith("解题记录 "), (
        f"空白文本标题 {repr(title)!r} 未以'解题记录 '开头。"
        f"输入文本: {repr(text)!r}"
    )


@given(_blank_text)
@settings(max_examples=100, deadline=None)
def test_blank_text_title_datetime_format(text: str):
    """属性 2 补充：空文本标题包含正确的日期时间格式

    对任意空白字符串，标题格式应为"解题记录 MM-DD HH:mm"。

    **Validates: Requirements 11.2**
    """
    import re
    title = _generate_title(text)
    # 匹配 "解题记录 MM-DD HH:mm" 格式
    pattern = r"^解题记录 \d{2}-\d{2} \d{2}:\d{2}$"
    assert re.match(pattern, title), (
        f"空白文本标题 {repr(title)!r} 不符合'解题记录 MM-DD HH:mm'格式。"
        f"输入文本: {repr(text)!r}"
    )


# ---------------------------------------------------------------------------
# 属性 5：图片 Base64 存储往返一致性
# Validates: Requirements 1.4, 3.2
# ---------------------------------------------------------------------------

@given(_base64_list)
@settings(max_examples=200, deadline=None)
def test_images_base64_roundtrip(images: list[str]):
    """属性 5：图片 Base64 存储往返一致性

    对任意 Base64 字符串列表，通过 JSON 序列化/反序列化（模拟 JSONB 存储）
    后，数据应与原始数据完全一致。

    **Validates: Requirements 1.4, 3.2**
    """
    # 模拟 JSONB 存储结构
    sources = {"images": images} if images else None

    # 序列化（模拟写入数据库）
    serialized = json.dumps(sources, ensure_ascii=False)

    # 反序列化（模拟从数据库读取）
    deserialized = json.loads(serialized)

    if images:
        assert deserialized is not None, "非空图片列表序列化后不应为 None"
        assert "images" in deserialized, "反序列化结果应包含 'images' 键"
        recovered_images = deserialized["images"]
        assert recovered_images == images, (
            f"图片列表往返不一致。"
            f"原始: {images[:2]}...，"
            f"恢复: {recovered_images[:2]}..."
        )
        assert len(recovered_images) == len(images), (
            f"图片数量不一致：原始 {len(images)}，恢复 {len(recovered_images)}"
        )
    else:
        assert deserialized is None, (
            f"空图片列表应序列化为 None，实际得到: {deserialized!r}"
        )


@given(_base64_list.filter(lambda lst: len(lst) > 0))
@settings(max_examples=200, deadline=None)
def test_images_base64_order_preserved(images: list[str]):
    """属性 5 补充：图片顺序在序列化往返后保持不变

    对任意非空 Base64 列表，序列化/反序列化后图片顺序应与原始顺序一致。

    **Validates: Requirements 1.4**
    """
    sources = {"images": images}
    serialized = json.dumps(sources, ensure_ascii=False)
    deserialized = json.loads(serialized)

    recovered_images = deserialized["images"]
    for i, (original, recovered) in enumerate(zip(images, recovered_images)):
        assert original == recovered, (
            f"第 {i} 张图片数据不一致。"
            f"原始（前 20 字符）: {repr(original[:20])!r}，"
            f"恢复（前 20 字符）: {repr(recovered[:20])!r}"
        )
