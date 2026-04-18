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

        # 使用 Computer Modern 数学字体（LaTeX 标准字体，视觉最专业）
        # 同时注册 CJK 字体用于公式中的中文字符
        matplotlib.rcParams["mathtext.fontset"] = "cm"
        matplotlib.rcParams["axes.unicode_minus"] = False

        # 注册 CJK 字体，用于公式中出现中文时的 fallback
        font_path: Path | None = None
        if _BUNDLED_FONT_PATH.is_file():
            font_path = _BUNDLED_FONT_PATH
        if font_path is None:
            font_path = _find_system_cjk_font()

        if font_path is not None:
            fm.fontManager.addfont(str(font_path))
            font_name = fm.FontProperties(fname=str(font_path)).get_name()
            # 设置 sans-serif fallback，让中文字符能渲染
            matplotlib.rcParams["font.sans-serif"] = [font_name, "DejaVu Sans"]

        _cjk_font_configured = True
    except Exception:
        _cjk_font_configured = True


class LatexRenderer:
    """Render LaTeX strings to PNG bytes using matplotlib mathtext.

    Results are cached per instance so identical formulas within the same
    export request are only rendered once.
    """

    def __init__(self) -> None:
        self._cache: dict[str, bytes] = {}

    def render(self, latex: str, display: bool = False) -> bytes | None:
        """Render *latex* to a PNG and return the raw bytes.

        Parameters
        ----------
        latex:
            The LaTeX source string (without surrounding $ delimiters).
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
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt

            _configure_cjk_font()

            # Display math uses larger font and more padding for readability
            fontsize = 16 if display else 12
            dpi = 200  # higher DPI for sharper output in PDF

            fig = plt.figure(figsize=(0.01, 0.01))
            # Use white background so the image blends into the PDF page
            fig.patch.set_facecolor("white")
            fig.text(
                0, 0,
                f"${latex}$",
                fontsize=fontsize,
                color="black",
                verticalalignment="bottom",
            )

            buf = io.BytesIO()
            fig.savefig(
                buf,
                format="png",
                bbox_inches="tight",
                pad_inches=0.08 if display else 0.04,
                dpi=dpi,
                facecolor="white",
            )
            plt.close(fig)

            buf.seek(0)
            result = buf.read()
            self._cache[cache_key] = result
            return result
        except Exception:
            return None
