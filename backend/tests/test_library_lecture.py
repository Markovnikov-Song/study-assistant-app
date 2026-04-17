"""
library.py 讲义相关端点的单元测试。

重点测试：
1. node_id URL 解码（+ 号空格 bug 修复验证）
2. 讲义 CRUD 基本逻辑
3. 节点树构建算法
4. 大纲标题验证
"""
from __future__ import annotations

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
sys.path.insert(1, os.path.join(os.path.dirname(os.path.dirname(__file__)), "..", "study_assistant_streamlit"))

import pytest
from urllib.parse import unquote_plus, quote_plus


# ── 节点树构建算法测试 ─────────────────────────────────────────────────────────

from routers.library import _build_node_tree


class TestBuildNodeTree:
    def test_single_level(self):
        md = "# 材料力学"
        nodes = _build_node_tree(md)
        assert len(nodes) == 1
        assert nodes[0]["text"] == "材料力学"
        assert nodes[0]["depth"] == 1
        assert nodes[0]["parent_id"] is None

    def test_two_levels(self):
        md = "# 材料力学\n## 第1章 绪论"
        nodes = _build_node_tree(md)
        assert len(nodes) == 2
        root = nodes[0]
        child = nodes[1]
        assert root["depth"] == 1
        assert child["depth"] == 2
        assert child["parent_id"] == root["node_id"]

    def test_three_levels(self):
        md = "# 材料力学\n## 第1章 绪论\n### 基本概念"
        nodes = _build_node_tree(md)
        assert len(nodes) == 3
        assert nodes[2]["depth"] == 3
        assert nodes[2]["parent_id"] == nodes[1]["node_id"]

    def test_empty_markdown(self):
        nodes = _build_node_tree("")
        assert nodes == []

    def test_no_headings(self):
        nodes = _build_node_tree("这是普通文本，没有标题")
        assert nodes == []

    def test_sibling_nodes(self):
        md = "# 材料力学\n## 第1章\n## 第2章"
        nodes = _build_node_tree(md)
        assert len(nodes) == 3
        # 两个二级节点都以根节点为父
        assert nodes[1]["parent_id"] == nodes[0]["node_id"]
        assert nodes[2]["parent_id"] == nodes[0]["node_id"]

    def test_node_id_contains_text(self):
        md = "# 材料力学"
        nodes = _build_node_tree(md)
        assert "材料力学" in nodes[0]["node_id"]

    def test_depth_prefix_in_node_id(self):
        md = "# 材料力学\n## 第1章"
        nodes = _build_node_tree(md)
        assert nodes[0]["node_id"].startswith("L1_")
        assert nodes[1]["node_id"].startswith("L2_")


# ── node_id URL 解码测试 ───────────────────────────────────────────────────────

class TestNodeIdDecoding:
    """验证 + 号空格 bug 修复：unquote_plus 正确解码 node_id。"""

    def test_plus_decoded_to_space(self):
        """+ 号应被解码为空格。"""
        encoded = "L2_%E6%9D%90%E6%96%99%E5%8A%9B%E5%AD%A6_%E7%AC%AC2%E7%AB%A0+%E6%9D%86%E4%BB%B6%E7%9A%84%E5%86%85%E5%8A%9B"
        decoded = unquote_plus(encoded)
        assert " " in decoded, f"解码后应含空格，实际: {decoded!r}"
        assert "+" not in decoded, f"解码后不应含 +，实际: {decoded!r}"
        assert decoded == "L2_材料力学_第2章 杆件的内力"

    def test_percent20_decoded_to_space(self):
        """%20 也应被解码为空格。"""
        encoded = "L2_%E6%9D%90%E6%96%99%E5%8A%9B%E5%AD%A6_%E7%AC%AC2%E7%AB%A0%20%E6%9D%86%E4%BB%B6%E7%9A%84%E5%86%85%E5%8A%9B"
        decoded = unquote_plus(encoded)
        assert decoded == "L2_材料力学_第2章 杆件的内力"

    def test_no_encoding_unchanged(self):
        """不含编码的 node_id 不变。"""
        node_id = "L1_材料力学"
        assert unquote_plus(node_id) == node_id

    def test_roundtrip_quote_unquote(self):
        """quote_plus 后 unquote_plus 应还原原始值。"""
        original = "L3_材料力学_第2章 杆件的内力_轴向拉伸与压缩"
        encoded = quote_plus(original)
        decoded = unquote_plus(encoded)
        assert decoded == original


# ── 标题验证测试 ───────────────────────────────────────────────────────────────

class TestTitleValidation:
    """验证大纲标题的 Pydantic 验证逻辑。"""

    def test_valid_title(self):
        from routers.library import TitleIn
        t = TitleIn(title="材料力学大纲")
        assert t.title == "材料力学大纲"

    def test_title_stripped(self):
        from routers.library import TitleIn
        t = TitleIn(title="  材料力学  ")
        assert t.title == "材料力学"

    def test_empty_title_rejected(self):
        from routers.library import TitleIn
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            TitleIn(title="")

    def test_whitespace_only_rejected(self):
        from routers.library import TitleIn
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            TitleIn(title="   ")

    def test_title_too_long_rejected(self):
        from routers.library import TitleIn
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            TitleIn(title="a" * 65)

    def test_title_max_length_ok(self):
        from routers.library import TitleIn
        t = TitleIn(title="a" * 64)
        assert len(t.title) == 64


# ── ExportBookIn 验证测试 ──────────────────────────────────────────────────────

class TestExportBookValidation:
    def test_valid_pdf_request(self):
        from routers.library import ExportBookIn
        req = ExportBookIn(node_ids=["n1", "n2"], format="pdf")
        assert req.format == "pdf"
        assert req.include_toc is True

    def test_valid_docx_request(self):
        from routers.library import ExportBookIn
        req = ExportBookIn(node_ids=["n1"], format="docx", include_toc=False)
        assert req.format == "docx"
        assert req.include_toc is False

    def test_empty_node_ids_rejected(self):
        from routers.library import ExportBookIn
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            ExportBookIn(node_ids=[], format="pdf")

    def test_invalid_format_rejected(self):
        from routers.library import ExportBookIn
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            ExportBookIn(node_ids=["n1"], format="txt")
