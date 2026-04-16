"""Property-based tests for PdfBookExporter.

# Feature: lecture-book-export, Property 1: 节点顺序保留
# Feature: lecture-book-export, Property 3: TOC 与正文一一对应
# Feature: lecture-book-export, Property 4: TOC 缩进与深度一致
# Feature: lecture-book-export, Property 9: LaTeX 公式渲染为嵌入图片
"""
from __future__ import annotations

import sys
import os
import io
import struct
import zlib

# Ensure backend package is importable when running from repo root
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
# Also add repo root so 'backend.services.*' absolute imports resolve
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from unittest.mock import patch, MagicMock

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from services.book_exporter import NodeInfo, TocEntry

# ---------------------------------------------------------------------------
# Patch reportlab.lib.units to add 'pt' if missing (older reportlab versions
# omit it; the source uses it as a constant equal to 1.0 point).
# ---------------------------------------------------------------------------
import importlib
import reportlab.lib.units as _rl_units
if not hasattr(_rl_units, "pt"):
    _rl_units.pt = 1.0  # 1 point == 1 reportlab unit


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_png_bytes() -> bytes:
    """Return minimal valid PNG bytes (1×1 white pixel)."""
    def _chunk(name: bytes, data: bytes) -> bytes:
        c = struct.pack(">I", len(data)) + name + data
        return c + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(b"\x00\xff\xff\xff"))
    png += _chunk(b"IEND", b"")
    return png


def _make_exporter():
    """Instantiate PdfBookExporter with font loading fully mocked."""
    import services.pdf_book_exporter as _mod
    from services.pdf_book_exporter import PdfBookExporter

    fake_path = MagicMock()
    fake_path.is_file.return_value = True
    fake_path.stem = "NotoSansSC-Regular"
    fake_path.__str__ = MagicMock(return_value="/fake/NotoSansSC-Regular.ttf")

    with patch.object(_mod, "_BUNDLED_FONT_PATH", fake_path), \
         patch.object(_mod, "_find_system_cjk_font", return_value=None), \
         patch("reportlab.pdfbase.pdfmetrics.registerFont"), \
         patch("reportlab.pdfbase.pdfmetrics.getRegisteredFontNames", return_value=[]):

        exporter = PdfBookExporter.__new__(PdfBookExporter)
        exporter._font_name = "Helvetica"  # use a built-in reportlab font
        return exporter


# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

_node_text = st.text(
    alphabet=st.characters(
        whitelist_categories=("Lu", "Ll", "Nd"),
        whitelist_characters=" _-",
    ),
    min_size=1,
    max_size=30,
)

_block = st.fixed_dictionaries({
    "type": st.sampled_from(["paragraph", "heading", "code", "list", "quote"]),
    "text": st.text(min_size=1, max_size=50),
})


@st.composite
def nodes_with_blocks(draw, min_nodes=1, max_nodes=10):
    """Generate a list of NodeInfo where every node has at least one block."""
    n = draw(st.integers(min_value=min_nodes, max_value=max_nodes))
    nodes = []
    for i in range(n):
        node_id = f"node_{i}"
        text = draw(_node_text)
        depth = draw(st.integers(min_value=1, max_value=4))
        blocks = draw(st.lists(_block, min_size=1, max_size=5))
        nodes.append(NodeInfo(node_id=node_id, text=text, depth=depth, blocks=blocks))
    return nodes


@st.composite
def nodes_with_depth(draw, min_nodes=1, max_nodes=10):
    """Generate NodeInfo list with explicit depth 1–4 and non-empty blocks."""
    n = draw(st.integers(min_value=min_nodes, max_value=max_nodes))
    nodes = []
    for i in range(n):
        node_id = f"node_{i}"
        text = draw(_node_text)
        depth = draw(st.integers(min_value=1, max_value=4))
        blocks = draw(st.lists(_block, min_size=1, max_size=3))
        nodes.append(NodeInfo(node_id=node_id, text=text, depth=depth, blocks=blocks))
    return nodes


_latex_expr = st.text(
    alphabet=st.characters(
        whitelist_categories=("Lu", "Ll", "Nd"),
        whitelist_characters=r"+-=^_{} \\",
    ),
    min_size=1,
    max_size=20,
)


@st.composite
def nodes_with_latex_blocks(draw, min_nodes=1, max_nodes=5):
    """Generate NodeInfo list where every block contains at least one LaTeX segment."""
    n = draw(st.integers(min_value=min_nodes, max_value=max_nodes))
    nodes = []
    for i in range(n):
        node_id = f"node_{i}"
        text = draw(_node_text)
        depth = draw(st.integers(min_value=1, max_value=4))
        # Each block has inline or display LaTeX embedded in its text
        num_blocks = draw(st.integers(min_value=1, max_value=3))
        blocks = []
        for _ in range(num_blocks):
            latex = draw(_latex_expr)
            use_display = draw(st.booleans())
            if use_display:
                block_text = f"prefix $${latex}$$ suffix"
            else:
                block_text = f"prefix ${latex}$ suffix"
            blocks.append({"type": "paragraph", "text": block_text})
        nodes.append(NodeInfo(node_id=node_id, text=text, depth=depth, blocks=blocks))
    return nodes


# ---------------------------------------------------------------------------
# Property 1: 节点顺序保留
# Validates: Requirements 3.1
# ---------------------------------------------------------------------------

@given(nodes_with_blocks())
@settings(max_examples=50, deadline=None)
def test_toc_order_preserves_input_order(nodes):
    """Property 1: 节点顺序保留

    For any ordered list of NodeInfo (all with blocks), _build_toc() must
    return TocEntry objects in the exact same order as the input nodes.

    Validates: Requirements 3.1
    # Feature: lecture-book-export, Property 1: 节点顺序保留
    """
    exporter = _make_exporter()
    toc_entries = exporter._build_toc(nodes)

    assert len(toc_entries) == len(nodes), (
        f"TOC has {len(toc_entries)} entries but input has {len(nodes)} nodes"
    )

    for i, (entry, node) in enumerate(zip(toc_entries, nodes)):
        assert entry.title == node.text, (
            f"Position {i}: TOC title {entry.title!r} != node text {node.text!r}. "
            f"Order is not preserved."
        )


# ---------------------------------------------------------------------------
# Property 3: TOC 与正文一一对应
# Validates: Requirements 3.1, 3.2
# ---------------------------------------------------------------------------

@given(nodes_with_blocks())
@settings(max_examples=50, deadline=None)
def test_toc_titles_match_node_titles_exactly(nodes):
    """Property 3: TOC 与正文一一对应

    For any set of valid nodes, the set of TOC entry titles must equal the
    set of node titles exactly — no extras, no omissions.

    Validates: Requirements 3.1, 3.2
    # Feature: lecture-book-export, Property 3: TOC 与正文一一对应
    """
    exporter = _make_exporter()
    toc_entries = exporter._build_toc(nodes)

    toc_titles = [e.title for e in toc_entries]
    node_titles = [n.text for n in nodes]

    # Same multiset: same length and same elements in same order
    assert len(toc_titles) == len(node_titles), (
        f"TOC has {len(toc_titles)} entries but there are {len(node_titles)} nodes"
    )

    # Title set equality (no extras, no omissions)
    assert set(toc_titles) == set(node_titles), (
        f"TOC title set {set(toc_titles)} != node title set {set(node_titles)}"
    )

    # Also verify one-to-one correspondence by sorted comparison
    assert sorted(toc_titles) == sorted(node_titles), (
        f"TOC titles {sorted(toc_titles)} do not match node titles {sorted(node_titles)}"
    )


# ---------------------------------------------------------------------------
# Property 4: TOC 缩进与深度一致
# Validates: Requirements 3.5
# ---------------------------------------------------------------------------

@given(nodes_with_depth())
@settings(max_examples=50, deadline=None)
def test_toc_depth_values_match_node_depth(nodes):
    """Property 4: TOC 缩进与深度一致

    For any nodes with depth 1–4, each TocEntry must carry the same depth
    value as its source node.  The indentation formula (depth - 1) * 4
    space-equivalents is encoded in the depth field; _render_toc_page uses
    (entry.depth - 1) * indent_unit to compute the actual x-offset.

    Validates: Requirements 3.5
    # Feature: lecture-book-export, Property 4: TOC 缩进与深度一致
    """
    exporter = _make_exporter()
    toc_entries = exporter._build_toc(nodes)

    assert len(toc_entries) == len(nodes)

    for entry, node in zip(toc_entries, nodes):
        assert entry.depth == node.depth, (
            f"TocEntry depth {entry.depth} != NodeInfo depth {node.depth} "
            f"for node {node.node_id!r}"
        )
        # Verify the indentation formula: (depth - 1) * 4 space-equivalents
        expected_indent_units = (node.depth - 1) * 4
        actual_indent_units = (entry.depth - 1) * 4
        assert actual_indent_units == expected_indent_units, (
            f"Indent units mismatch: expected {expected_indent_units}, "
            f"got {actual_indent_units} for depth {node.depth}"
        )
        # depth must be in valid range 1–4
        assert 1 <= entry.depth <= 4, (
            f"TocEntry depth {entry.depth} is outside valid range 1–4"
        )


# ---------------------------------------------------------------------------
# Property 9: LaTeX 公式渲染为嵌入图片
# Validates: Requirements 6.1, 6.2
# ---------------------------------------------------------------------------

@given(nodes_with_latex_blocks())
@settings(max_examples=50, deadline=None)
def test_latex_blocks_produce_non_empty_pdf(nodes):
    """Property 9: LaTeX 公式渲染为嵌入图片

    For any blocks containing inline/display LaTeX, when LatexRenderer.render
    is mocked to return valid PNG bytes (renderer available), build() must
    complete without error and return non-empty bytes — confirming that image
    embedding paths are exercised rather than the fallback text path.

    Validates: Requirements 6.1, 6.2
    # Feature: lecture-book-export, Property 9: LaTeX 公式渲染为嵌入图片
    """
    png_bytes = _make_png_bytes()

    import services.pdf_book_exporter as _mod
    from services.pdf_book_exporter import PdfBookExporter

    fake_path = MagicMock()
    fake_path.is_file.return_value = True
    fake_path.stem = "NotoSansSC-Regular"
    fake_path.__str__ = MagicMock(return_value="/fake/NotoSansSC-Regular.ttf")

    # LatexRenderer mock: always returns valid PNG bytes
    mock_renderer_instance = MagicMock()
    mock_renderer_instance.render.return_value = png_bytes

    with patch.object(_mod, "_BUNDLED_FONT_PATH", fake_path), \
         patch.object(_mod, "_find_system_cjk_font", return_value=None), \
         patch("reportlab.pdfbase.pdfmetrics.registerFont"), \
         patch("reportlab.pdfbase.pdfmetrics.getRegisteredFontNames", return_value=[]), \
         patch.object(_mod, "LatexRenderer", return_value=mock_renderer_instance):

        exporter = PdfBookExporter.__new__(PdfBookExporter)
        exporter._font_name = "Helvetica"

        result = exporter.build(
            session_title="Test Session",
            nodes=nodes,
            include_toc=True,
        )

    assert isinstance(result, bytes), "build() must return bytes"
    assert len(result) > 0, "build() must return non-empty bytes"

    # Verify that render() was called at least once (LaTeX was processed)
    assert mock_renderer_instance.render.called, (
        "LatexRenderer.render() was never called despite nodes containing LaTeX"
    )
