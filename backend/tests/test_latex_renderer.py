"""Unit tests for LatexRenderer.

Tests cover:
- Successful render returns bytes (Requirement 6.3)
- Render failure returns None (Requirement 6.3)
- Cache hit skips re-render (Requirement 6.4)
"""
from __future__ import annotations

import sys
import os

# Ensure backend package is importable when running from repo root
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import io
from unittest.mock import patch, MagicMock

import pytest

from services.latex_renderer import LatexRenderer


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_fake_png() -> bytes:
    """Return a small but non-empty bytes object to simulate PNG output."""
    return b"\x89PNG\r\n\x1a\n" + b"\x00" * 16


def _make_mock_figure(png_bytes: bytes) -> MagicMock:
    """Return a mock matplotlib Figure that writes *png_bytes* on savefig."""
    fig = MagicMock()
    fig.text = MagicMock()

    def fake_savefig(buf, **kwargs):
        buf.write(png_bytes)

    fig.savefig = fake_savefig
    return fig


# ---------------------------------------------------------------------------
# Test: successful render returns bytes
# ---------------------------------------------------------------------------

class TestSuccessfulRender:
    """Requirement 6.3 — renderer returns PNG bytes on success."""

    def test_render_returns_bytes(self):
        """render() returns a non-empty bytes object when matplotlib succeeds."""
        png = _make_fake_png()
        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", return_value=_make_mock_figure(png)), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            result = renderer.render(r"\alpha + \beta")

        assert isinstance(result, bytes)
        assert len(result) > 0

    def test_render_inline_returns_bytes(self):
        """render() with display=False returns bytes."""
        png = _make_fake_png()
        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", return_value=_make_mock_figure(png)), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            result = renderer.render(r"x^2", display=False)

        assert isinstance(result, bytes)

    def test_render_display_returns_bytes(self):
        """render() with display=True returns bytes."""
        png = _make_fake_png()
        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", return_value=_make_mock_figure(png)), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            result = renderer.render(r"\int_0^\infty", display=True)

        assert isinstance(result, bytes)


# ---------------------------------------------------------------------------
# Test: failure returns None
# ---------------------------------------------------------------------------

class TestRenderFailure:
    """Requirement 6.3 — renderer returns None on any exception."""

    def test_render_returns_none_when_matplotlib_raises(self):
        """render() returns None when matplotlib.pyplot.figure raises."""
        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", side_effect=RuntimeError("mock error")), \
             patch("matplotlib.use"):
            result = renderer.render(r"\frac{1}{2}")

        assert result is None

    def test_render_returns_none_when_import_fails(self):
        """render() returns None when matplotlib cannot be imported."""
        renderer = LatexRenderer()

        import builtins
        real_import = builtins.__import__

        def mock_import(name, *args, **kwargs):
            if name == "matplotlib":
                raise ImportError("matplotlib not available")
            return real_import(name, *args, **kwargs)

        with patch("builtins.__import__", side_effect=mock_import):
            result = renderer.render(r"E = mc^2")

        assert result is None

    def test_render_returns_none_when_savefig_raises(self):
        """render() returns None when fig.savefig raises an exception."""
        renderer = LatexRenderer()

        fig = MagicMock()
        fig.text = MagicMock()
        fig.savefig = MagicMock(side_effect=OSError("disk full"))

        with patch("matplotlib.pyplot.figure", return_value=fig), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            result = renderer.render(r"\sqrt{x}")

        assert result is None


# ---------------------------------------------------------------------------
# Test: cache hit skips re-render
# ---------------------------------------------------------------------------

class TestCaching:
    """Requirement 6.4 — identical formulas are only rendered once per instance."""

    def test_cache_hit_skips_rerender(self):
        """Calling render() twice with the same latex string only renders once."""
        png = _make_fake_png()
        render_count = 0

        def counting_figure(*args, **kwargs):
            nonlocal render_count
            render_count += 1
            return _make_mock_figure(png)

        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", side_effect=counting_figure), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            first = renderer.render(r"\pi")
            second = renderer.render(r"\pi")

        assert render_count == 1
        assert first == second

    def test_cache_returns_same_bytes(self):
        """Cached result is byte-for-byte identical to the first render."""
        png = _make_fake_png()
        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", return_value=_make_mock_figure(png)), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            first = renderer.render(r"\theta")

        # Second call — matplotlib is NOT patched; cache must be used
        second = renderer.render(r"\theta")

        assert first is not None
        assert first == second

    def test_different_formulas_each_rendered_once(self):
        """Two distinct formulas each trigger exactly one render call."""
        png = _make_fake_png()
        render_count = 0

        def counting_figure(*args, **kwargs):
            nonlocal render_count
            render_count += 1
            return _make_mock_figure(png)

        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", side_effect=counting_figure), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            renderer.render(r"\alpha")
            renderer.render(r"\beta")
            renderer.render(r"\alpha")  # cache hit
            renderer.render(r"\beta")   # cache hit

        assert render_count == 2

    def test_display_and_inline_cached_separately(self):
        """Same latex string with different display flags are cached independently."""
        png = _make_fake_png()
        render_count = 0

        def counting_figure(*args, **kwargs):
            nonlocal render_count
            render_count += 1
            return _make_mock_figure(png)

        renderer = LatexRenderer()

        with patch("matplotlib.pyplot.figure", side_effect=counting_figure), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            renderer.render(r"\gamma", display=False)
            renderer.render(r"\gamma", display=True)
            renderer.render(r"\gamma", display=False)  # cache hit
            renderer.render(r"\gamma", display=True)   # cache hit

        assert render_count == 2

    def test_failed_render_not_cached(self):
        """A failed render (returns None) is not stored in the cache."""
        renderer = LatexRenderer()
        png = _make_fake_png()
        render_count = 0

        def counting_figure(*args, **kwargs):
            nonlocal render_count
            render_count += 1
            return _make_mock_figure(png)

        # First call fails
        with patch("matplotlib.pyplot.figure", side_effect=RuntimeError("fail")), \
             patch("matplotlib.use"):
            result_fail = renderer.render(r"\delta")

        assert result_fail is None

        # Second call succeeds — should actually render, not return cached None
        with patch("matplotlib.pyplot.figure", side_effect=counting_figure), \
             patch("matplotlib.pyplot.close"), \
             patch("matplotlib.use"):
            result_ok = renderer.render(r"\delta")

        assert result_ok is not None
        assert render_count == 1
