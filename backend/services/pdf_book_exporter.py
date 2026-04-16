"""PDF book exporter using reportlab with Chinese font support."""

from __future__ import annotations

import io
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import pt
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image

from backend.services.book_exporter import BookExporter, NodeInfo, TocEntry
from backend.services.latex_renderer import LatexRenderer

# Keyword fragments used to identify CJK-capable fonts during system scan
_CJK_KEYWORDS = ("cjk", "noto", "wenquanyi", "sourcehan", "source han")

# Path to the project-bundled font (relative to repo root)
_BUNDLED_FONT_PATH = Path(__file__).parent.parent / "assets" / "fonts" / "NotoSansSC-Regular.ttf"


def _find_system_cjk_font() -> Path | None:
    """Recursively scan /usr/share/fonts/ for a CJK-compatible font file.

    Returns the first matching Path, or None if the directory does not exist
    or no matching font is found.
    """
    base = Path("/usr/share/fonts")
    if not base.is_dir():
        return None

    for font_path in base.rglob("*"):
        if font_path.suffix.lower() not in (".ttf", ".otf"):
            continue
        name_lower = font_path.name.lower()
        if any(kw in name_lower for kw in _CJK_KEYWORDS):
            return font_path

    return None


class PdfBookExporter(BookExporter):
    """Generates a PDF book from lecture nodes using reportlab.

    Chinese font loading happens in ``__init__`` so that a missing font
    raises ``RuntimeError`` before any generation work begins (Req 4.2, 4.3).
    """

    def __init__(self) -> None:
        # 1. Try project-bundled font first
        font_path: Path | None = None
        if _BUNDLED_FONT_PATH.is_file():
            font_path = _BUNDLED_FONT_PATH

        # 2. Fall back to system CJK font scan
        if font_path is None:
            font_path = _find_system_cjk_font()

        # 3. No font available → hard error
        if font_path is None:
            raise RuntimeError("中文字体不可用，无法生成 PDF")

        # Derive a stable font name from the file stem so repeated
        # instantiations with the same file don't re-register under a
        # different name.
        font_name = font_path.stem  # e.g. "NotoSansSC-Regular"

        # Register only if not already registered (avoids reportlab warnings
        # on repeated instantiation within the same process).
        if font_name not in pdfmetrics.getRegisteredFontNames():
            pdfmetrics.registerFont(TTFont(font_name, str(font_path)))

        self._font_name: str = font_name

    # ------------------------------------------------------------------
    # TOC helpers
    # ------------------------------------------------------------------

    def _build_toc(self, nodes: list[NodeInfo]) -> list[TocEntry]:
        """Build TOC entries from filtered nodes.

        Each node becomes one TocEntry.  Page numbers are placeholders
        (a full two-pass render is wired in task 3.4); we assign
        sequential page numbers starting at 2 (page 1 is the TOC itself).

        Parameters
        ----------
        nodes:
            Already-filtered list (all nodes have non-empty blocks).

        Returns
        -------
        list[TocEntry]
            One entry per node, in input order.
        """
        entries: list[TocEntry] = []
        # TOC occupies page 1; body starts at page 2.
        for page_offset, node in enumerate(nodes, start=2):
            anchor = f"node_L{node.depth}_{node.text}"
            entries.append(
                TocEntry(
                    title=node.text,
                    depth=node.depth,
                    page=page_offset,
                    anchor=anchor,
                )
            )
        return entries

    def _render_toc_page(self, canvas, toc_entries: list[TocEntry]) -> None:  # type: ignore[type-arg]
        """Draw the Table of Contents page onto *canvas*.

        Layout
        ------
        - Title "目录" centred at the top.
        - Each entry on its own line, indented by ``(depth - 1) * 4``
          space-equivalents (1 space-equivalent ≈ 6 pt).
        - Page number right-aligned at the right margin.
        - A new page is started after the TOC so the body begins fresh.

        Parameters
        ----------
        canvas:
            A ``reportlab.pdfgen.canvas.Canvas`` instance positioned at
            the start of a blank page.
        toc_entries:
            Ordered list of TOC entries to render.
        """
        page_width, page_height = A4

        # Convert mm margins to points (1 mm ≈ 2.8346 pt)
        MM = 2.8346
        left = 25 * MM
        right = page_width - 25 * MM
        top = page_height - 20 * MM

        font_name = self._font_name
        indent_unit = 4 * 6 * pt  # 4 space-equivalents × ~6 pt each

        # --- Title ---
        canvas.setFont(font_name, 16)
        canvas.drawCentredString(page_width / 2, top, "目录")

        y = top - 30  # start below title
        line_height = 18  # points between lines

        canvas.setFont(font_name, 11)

        for entry in toc_entries:
            if y < 40:  # near bottom — start a new page
                canvas.showPage()
                canvas.setFont(font_name, 11)
                y = page_height - 20 * MM

            indent = (entry.depth - 1) * indent_unit
            x = left + indent

            # Entry title
            canvas.drawString(x, y, entry.title)

            # Page number right-aligned
            page_str = str(entry.page)
            canvas.drawRightString(right, y, page_str)

            y -= line_height

        # Finish the TOC page and advance to a new page for the body.
        canvas.showPage()

    # ------------------------------------------------------------------
    # LaTeX / text helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _parse_latex_segments(text: str) -> list[dict]:
        """Split *text* into alternating plain-text and LaTeX segments.

        Returns a list of dicts with keys:
        - ``{"type": "text", "content": str}``
        - ``{"type": "latex", "content": str, "display": bool}``

        Display LaTeX (``$$...$$``) is detected before inline (``$...$``)
        to avoid the inner ``$`` being consumed first.
        """
        segments: list[dict] = []
        # Pattern: display ($$...$$) takes priority over inline ($...$)
        pattern = re.compile(r"\$\$(.+?)\$\$|\$(.+?)\$", re.DOTALL)
        last_end = 0
        for m in pattern.finditer(text):
            if m.start() > last_end:
                segments.append({"type": "text", "content": text[last_end : m.start()]})
            if m.group(1) is not None:
                # display math $$...$$
                segments.append({"type": "latex", "content": m.group(1), "display": True})
            else:
                # inline math $...$
                segments.append({"type": "latex", "content": m.group(2), "display": False})
            last_end = m.end()
        if last_end < len(text):
            segments.append({"type": "text", "content": text[last_end:]})
        return segments

    # ------------------------------------------------------------------
    # Block rendering
    # ------------------------------------------------------------------

    def _draw_text_with_latex(
        self,
        canvas,  # type: ignore[type-arg]
        text: str,
        x: float,
        y: float,
        font_name: str,
        font_size: float,
        latex_renderer: LatexRenderer,
        max_width: float,
        page_height: float,
        bottom_margin: float,
    ) -> float:
        """Draw *text* (which may contain LaTeX) starting at (*x*, *y*).

        Inline LaTeX segments are rendered as PNG images embedded at the
        current cursor position.  Returns the new *y* after all content.
        """
        segments = self._parse_latex_segments(text)
        cursor_x = x
        line_height = font_size * 1.4

        for seg in segments:
            if seg["type"] == "text":
                # Simple word-wrap for plain text
                words = seg["content"].split(" ")
                for word in words:
                    if not word:
                        continue
                    word_width = canvas.stringWidth(word + " ", font_name, font_size)
                    if cursor_x + word_width > x + max_width and cursor_x > x:
                        y -= line_height
                        if y < bottom_margin:
                            canvas.showPage()
                            y = page_height - 20 * 2.8346
                        cursor_x = x
                    canvas.setFont(font_name, font_size)
                    canvas.drawString(cursor_x, y, word + " ")
                    cursor_x += word_width
            else:
                # LaTeX segment
                png_bytes = latex_renderer.render(seg["content"], display=seg["display"])
                if png_bytes is None:
                    # Fallback: raw text + label
                    fallback = f"[公式渲染失败，原始代码如下] ${seg['content']}$"
                    canvas.setFont(font_name, font_size)
                    canvas.drawString(cursor_x, y, fallback)
                    cursor_x += canvas.stringWidth(fallback, font_name, font_size)
                else:
                    img_buf = io.BytesIO(png_bytes)
                    img = Image(img_buf)
                    # Scale image to fit line height
                    scale = line_height / img.imageHeight if img.imageHeight > 0 else 1
                    img_w = img.imageWidth * scale
                    img_h = img.imageHeight * scale
                    if cursor_x + img_w > x + max_width and cursor_x > x:
                        y -= line_height
                        if y < bottom_margin:
                            canvas.showPage()
                            y = page_height - 20 * 2.8346
                        cursor_x = x
                    img.drawOn(canvas, cursor_x, y - img_h * 0.2)
                    cursor_x += img_w

        return y - line_height

    def _render_block(
        self,
        canvas,  # type: ignore[type-arg]
        block: dict,
        y: float,
        page_width: float,
        page_height: float,
        left_margin: float,
        right_margin: float,
        latex_renderer: LatexRenderer,
    ) -> float:
        """Render a single *block* onto *canvas* at vertical position *y*.

        Returns the new *y* position after the block has been drawn.
        Page overflow is handled by calling ``canvas.showPage()`` and
        resetting *y* to the top margin.
        """
        MM = 2.8346
        bottom_margin = 20 * MM
        top_y = page_height - 20 * MM
        text_width = right_margin - left_margin
        font_name = self._font_name
        block_type = block.get("type", "paragraph")
        content = block.get("content", "") or block.get("text", "")
        line_height_base = 11 * 1.4

        def check_overflow(current_y: float, needed: float = line_height_base) -> float:
            if current_y - needed < bottom_margin:
                canvas.showPage()
                return top_y
            return current_y

        if block_type == "heading":
            level = block.get("level", 1)
            size = {1: 18, 2: 15, 3: 13}.get(level, 13)
            lh = size * 1.4
            y = check_overflow(y, lh + 6)
            canvas.setFont(f"{font_name}-Bold" if f"{font_name}-Bold" in pdfmetrics.getRegisteredFontNames() else font_name, size)
            canvas.drawString(left_margin, y, content)
            y -= lh + 4  # extra spacing after heading

        elif block_type == "paragraph":
            y = check_overflow(y)
            canvas.setFont(font_name, 11)
            y = self._draw_text_with_latex(
                canvas, content, left_margin, y, font_name, 11,
                latex_renderer, text_width, page_height, bottom_margin,
            )

        elif block_type == "code":
            lines = content.splitlines() or [""]
            lh = 11 * 1.4
            box_padding = 4
            box_height = len(lines) * lh + box_padding * 2
            y = check_overflow(y, box_height)
            # Grey background rectangle
            canvas.setFillColor(colors.Color(0.93, 0.93, 0.93))
            canvas.rect(left_margin, y - box_height + lh, text_width, box_height, fill=1, stroke=0)
            canvas.setFillColor(colors.black)
            canvas.setFont("Courier", 10)
            text_y = y
            for line in lines:
                canvas.drawString(left_margin + box_padding, text_y, line)
                text_y -= lh
                if text_y < bottom_margin:
                    canvas.showPage()
                    text_y = top_y
            y = text_y - box_padding

        elif block_type == "list":
            y = check_overflow(y)
            bullet_text = f"• {content}"
            canvas.setFont(font_name, 11)
            y = self._draw_text_with_latex(
                canvas, bullet_text, left_margin + 8, y, font_name, 11,
                latex_renderer, text_width - 8, page_height, bottom_margin,
            )

        elif block_type == "quote":
            y = check_overflow(y)
            quote_indent = left_margin + 12
            lh = 11 * 1.4
            # Draw 3pt left vertical rule
            canvas.setStrokeColor(colors.Color(0.5, 0.5, 0.5))
            canvas.setLineWidth(3)
            canvas.line(left_margin + 2, y - lh * 0.2, left_margin + 2, y + lh * 0.8)
            canvas.setLineWidth(1)
            canvas.setStrokeColor(colors.black)
            # Italic text — reportlab doesn't have a generic italic variant for
            # CJK fonts, so we draw normally but offset slightly for visual cue
            canvas.setFont(font_name, 11)
            y = self._draw_text_with_latex(
                canvas, content, quote_indent, y, font_name, 11,
                latex_renderer, text_width - 12, page_height, bottom_margin,
            )

        else:
            # Unknown block type — render as paragraph
            y = check_overflow(y)
            canvas.setFont(font_name, 11)
            y = self._draw_text_with_latex(
                canvas, content, left_margin, y, font_name, 11,
                latex_renderer, text_width, page_height, bottom_margin,
            )

        return y

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def build(
        self,
        session_title: str,
        nodes: list[NodeInfo],
        include_toc: bool = True,
    ) -> bytes:
        """Generate a PDF book from *nodes* and return the raw bytes.

        Requirements: 4.1, 4.4
        """
        from reportlab.pdfgen.canvas import Canvas

        # A4 dimensions in points (1 mm = 2.8346 pt)
        MM = 2.8346
        page_width, page_height = A4  # 595.27 × 841.89 pt
        left_margin = 25 * MM
        right_margin = page_width - 25 * MM
        top_margin = page_height - 20 * MM
        bottom_margin = 20 * MM

        # One LatexRenderer per build() call (per-request cache, Req 6.4)
        latex_renderer = LatexRenderer()

        # Filter out nodes with no lecture content (Req 2.3)
        filtered = self._filter_nodes(nodes)

        buf = io.BytesIO()
        canvas = Canvas(buf, pagesize=A4)

        # --- TOC page (optional) ---
        if include_toc and filtered:
            toc_entries = self._build_toc(filtered)
            self._render_toc_page(canvas, toc_entries)

        # --- Body pages ---
        y = top_margin
        for node in filtered:
            # Chapter heading (node title)
            canvas.setFont(self._font_name, 18)
            if y < bottom_margin + 30:
                canvas.showPage()
                y = top_margin
            canvas.drawString(left_margin, y, node.text)
            y -= 18 * 1.6  # heading line height + extra spacing

            # Render each block
            for block in node.blocks:
                y = self._render_block(
                    canvas,
                    block,
                    y,
                    page_width,
                    page_height,
                    left_margin,
                    right_margin,
                    latex_renderer,
                )

            # Extra spacing between nodes
            y -= 12
            if y < bottom_margin:
                canvas.showPage()
                y = top_margin

        canvas.save()
        buf.seek(0)
        return buf.read()
