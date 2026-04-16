"""Property-based tests for LatexRenderer.

# Feature: lecture-book-export, Property 5: LaTeX 缓存幂等性
"""
from __future__ import annotations

import sys
import os

# Ensure backend package is importable when running from repo root
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from unittest.mock import patch, MagicMock
import io

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from services.latex_renderer import LatexRenderer


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_png_bytes() -> bytes:
    """Return minimal valid PNG bytes (1×1 white pixel) for mock returns."""
    import struct, zlib

    def _chunk(name: bytes, data: bytes) -> bytes:
        c = struct.pack(">I", len(data)) + name + data
        return c + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(b"\x00\xff\xff\xff"))
    png += _chunk(b"IEND", b"")
    return png


# ---------------------------------------------------------------------------
# Strategy: lists of LaTeX strings that contain deliberate duplicates
# ---------------------------------------------------------------------------

_latex_chars = st.text(
    alphabet=st.characters(
        whitelist_categories=("Lu", "Ll", "Nd"),
        whitelist_characters=r"+-=^_{} ",
    ),
    min_size=1,
    max_size=20,
)

# Build a list that is guaranteed to have duplicates:
# pick 1–5 unique strings, then repeat them to form a list of 2–15 items.
@st.composite
def latex_list_with_duplicates(draw):
    unique_strings = draw(
        st.lists(_latex_chars, min_size=1, max_size=5, unique=True)
    )
    # Repeat each string at least once so duplicates are present
    repeated = unique_strings * 2  # guarantees every string appears ≥ 2 times
    # Optionally shuffle
    order = draw(st.permutations(repeated))
    return order, unique_strings


# ---------------------------------------------------------------------------
# Property 5: LaTeX 渲染缓存幂等性
# Validates: Requirements 6.4
# ---------------------------------------------------------------------------

@given(latex_list_with_duplicates())
@settings(max_examples=100, deadline=None)
def test_latex_cache_idempotency(latex_data):
    """Property 5: LaTeX 渲染缓存幂等性

    For any list of LaTeX strings that contains duplicates, the number of
    *actual* render calls (matplotlib figure creations) must equal the number
    of *unique* strings in the list.  Duplicate strings must be served from
    the cache without triggering a second render.

    Validates: Requirements 6.4
    # Feature: lecture-book-export, Property 5: LaTeX 缓存幂等性
    """
    latex_list, unique_strings = latex_data

    png = _make_png_bytes()
    render_call_count = 0

    original_figure = None
    try:
        import matplotlib.pyplot as _plt
        original_figure = _plt.figure
    except Exception:
        pass

    def mock_figure(*args, **kwargs):
        nonlocal render_call_count
        render_call_count += 1
        fig = MagicMock()
        buf_holder = {}

        def fake_savefig(buf, **kw):
            buf.write(png)

        fig.text = MagicMock()
        fig.savefig = fake_savefig
        return fig

    with patch("matplotlib.pyplot.figure", side_effect=mock_figure), \
         patch("matplotlib.pyplot.close"):
        renderer = LatexRenderer()
        for latex in latex_list:
            renderer.render(latex, display=False)

    expected_unique = len(set(f"inline:{s}" for s in latex_list))
    assert render_call_count == expected_unique, (
        f"Expected {expected_unique} render calls for "
        f"{len(latex_list)} strings ({len(unique_strings)} unique), "
        f"but got {render_call_count}."
    )
