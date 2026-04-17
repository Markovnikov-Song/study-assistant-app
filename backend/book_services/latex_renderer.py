"""LaTeX renderer using matplotlib mathtext — no full LaTeX installation required."""

from __future__ import annotations

import io
from pathlib import Path

# ---------------------------------------------------------------------------
# CJK font configuration for matplotlib mathtext
# ---------------------------------------------------------------------------

_BUNDLED_FONT_PATH = Path(__file__).parent.parent / "assets" / "fonts" / "NotoSansSC-Regular.ttf"
_CJK_KEYWORDS = ("cjk", "noto", "wenquanyi", "sourcehan", "source han", "simhei", "simsun", "msyh")
_cjk_font_configured = False


def _find_system_cjk_font() -> Path | None:
    """Search /usr/share/fonts for a CJK-capable TTF/OTF font."""
    base = Path("/usr/share/fonts")
    if not base.is_dir():
        return None
    for p in base.rglob("*"):
        if p.suffix.lower() not in (".ttf", ".otf"):
            continue
        if any(kw in p.name.lower() for kw in _CJK_KEYWORDS):
            return p
    return None


def _configure_cjk_font() -> None:
    """Configure matplotlib to use a CJK font for mathtext rendering.

    Called once per process; subsequent calls are no-ops.
    """
    global _cjk_font_configured
    if _cjk_font_configured:
        return

    try:
        import matplotlib
        import matplotlib.font_manager as fm

        font_path: Path | None = None
        if _BUNDLED_FONT_PATH.is_file():
            font_path = _BUNDLED_FONT_PATH
        if font_path is None:
            font_path = _find_system_cjk_font()

        if font_path is not None:
            # Register the font with matplotlib's font manager
            fm.fontManager.addfont(str(font_path))
            font_name = fm.FontProperties(fname=str(font_path)).get_name()

            matplotlib.rcParams["font.family"] = "sans-serif"
            matplotlib.rcParams["font.sans-serif"] = [font_name, "DejaVu Sans"]
            # mathtext.fontset 'custom' lets us override the roman/sans/tt fonts
            matplotlib.rcParams["mathtext.fontset"] = "custom"
            matplotlib.rcParams["mathtext.rm"] = font_name
            matplotlib.rcParams["mathtext.it"] = font_name
            matplotlib.rcParams["mathtext.bf"] = font_name
            matplotlib.rcParams["axes.unicode_minus"] = False

        _cjk_font_configured = True
    except Exception:
        # Non-fatal: fall back to default fonts (warnings may still appear)
        _cjk_font_configured = True


class LatexRenderer:
    """Render LaTeX strings to PNG bytes using matplotlib mathtext.

    Results are cached per instance so identical formulas within the same
    export request are only rendered once (Requirement 6.4).
    """

    def __init__(self) -> None:
        self._cache: dict[str, bytes] = {}

    def render(self, latex: str, display: bool = False) -> bytes | None:
        """Render *latex* to a PNG and return the raw bytes.

        Parameters
        ----------
        latex:
            The LaTeX source string (without surrounding ``$`` delimiters).
        display:
            When *True* the formula is rendered in display (block) style at a
            larger font size; when *False* it is rendered inline.

        Returns
        -------
        bytes | None
            PNG bytes on success, ``None`` on any rendering failure.
        """
        cache_key = f"{'display' if display else 'inline'}:{latex}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        try:
            import matplotlib
            matplotlib.use("Agg")  # non-interactive backend, safe for threads
            import matplotlib.pyplot as plt

            # Configure CJK-capable font so Chinese characters inside LaTeX
            # expressions (e.g. labels like "（抗扭截面系数）") render correctly
            # instead of producing "Font 'rm' does not have a glyph" warnings.
            _configure_cjk_font()

            fontsize = 14 if display else 11
            fig = plt.figure(figsize=(0.01, 0.01))
            fig.text(0, 0, f"${latex}$", fontsize=fontsize)

            buf = io.BytesIO()
            fig.savefig(buf, format="png", bbox_inches="tight", pad_inches=0.1, dpi=150)
            plt.close(fig)

            buf.seek(0)
            result = buf.read()
            self._cache[cache_key] = result
            return result
        except Exception:
            return None
