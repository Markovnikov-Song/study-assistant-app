"""PDF book exporter — uses reportlab Platypus for proper layout, page numbers, and TOC."""

from __future__ import annotations

import io
import re
import tempfile
import os
from pathlib import Path
from typing import Any

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate,
    Paragraph, Spacer, PageBreak, HRFlowable,
    KeepTogether, Image,
)
from reportlab.platypus.tableofcontents import TableOfContents

from book_services.book_exporter import BookExporter, NodeInfo, TocEntry
from book_services.latex_renderer import LatexRenderer

_CJK_KEYWORDS = ("cjk", "noto", "wenquanyi", "sourcehan", "source han")
_BUNDLED_FONT_PATH = Path(__file__).parent.parent / "assets" / "fonts" / "NotoSansSC-Regular.ttf"


def _find_system_cjk_font() -> Path | None:
    base = Path("/usr/share/fonts")
    if not base.is_dir():
        return None
    for font_path in base.rglob("*"):
        if font_path.suffix.lower() not in (".ttf", ".otf"):
            continue
        if any(kw in font_path.name.lower() for kw in _CJK_KEYWORDS):
            return font_path
    return None


def _register_font(font_name: str, font_path: Path) -> None:
    if font_name not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont(font_name, str(font_path)))
    # 注册 Bold 别名，避免 <b> 标签回退到 Helvetica 导致中文乱码
    bold_name = f"{font_name}-Bold"
    if bold_name not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont(bold_name, str(font_path)))


# ---------------------------------------------------------------------------
# Page template with header/footer and page numbers
# ---------------------------------------------------------------------------

class _BookDocTemplate(BaseDocTemplate):
    """Document template that draws page numbers in the footer."""

    def __init__(self, buf, font_name: str, session_title: str, **kwargs):
        super().__init__(buf, **kwargs)
        self._font_name = font_name
        self._session_title = session_title

        left = 25 * mm
        right = 25 * mm
        top = 20 * mm
        bottom = 20 * mm
        pw, ph = A4

        frame = Frame(left, bottom, pw - left - right, ph - top - bottom, id="main")
        template = PageTemplate(id="main", frames=[frame], onPage=self._draw_page)
        self.addPageTemplates([template])

    def _draw_page(self, canvas, doc):
        canvas.saveState()
        pw, ph = A4
        fn = self._font_name

        # Footer: page number centered
        canvas.setFont(fn, 9)
        canvas.setFillColor(colors.grey)
        canvas.drawCentredString(pw / 2, 12 * mm, str(doc.page))

        # Footer: session title on left
        canvas.drawString(25 * mm, 12 * mm, self._session_title)

        canvas.restoreState()

    def afterFlowable(self, flowable):
        """Notify TOC of headings and add PDF bookmarks."""
        if isinstance(flowable, Paragraph):
            style = flowable.style.name
            text = flowable.getPlainText()
            if style == "ChapterHeading":
                key = f"ch_{id(flowable)}"
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(text, key, level=0)
                self.notify("TOCEntry", (0, text, self.page, key))
            elif style == "SectionHeading1":
                key = f"h1_{id(flowable)}"
                self.canv.bookmarkPage(key)
                self.notify("TOCEntry", (1, text, self.page, key))
            elif style == "SectionHeading2":
                key = f"h2_{id(flowable)}"
                self.canv.bookmarkPage(key)
                self.notify("TOCEntry", (2, text, self.page, key))


# ---------------------------------------------------------------------------
# LaTeX rendering helpers
# ---------------------------------------------------------------------------

# 临时文件列表，导出完成后清理
_temp_files: list[str] = []


def _png_to_temp_file(png_bytes: bytes) -> str:
    """Write PNG bytes to a temp file and return the path."""
    fd, path = tempfile.mkstemp(suffix=".png")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(png_bytes)
    except Exception:
        os.close(fd)
        raise
    _temp_files.append(path)
    return path


def _cleanup_temp_files() -> None:
    """Remove all temp PNG files created during export."""
    for path in _temp_files:
        try:
            os.unlink(path)
        except OSError:
            pass
    _temp_files.clear()


# ---------------------------------------------------------------------------
# PdfBookExporter
# ---------------------------------------------------------------------------

class PdfBookExporter(BookExporter):

    def __init__(self) -> None:
        font_path: Path | None = None
        if _BUNDLED_FONT_PATH.is_file():
            font_path = _BUNDLED_FONT_PATH
        if font_path is None:
            font_path = _find_system_cjk_font()
        if font_path is None:
            raise RuntimeError("中文字体不可用，无法生成 PDF")

        self._font_name = font_path.stem
        _register_font(self._font_name, font_path)
        # 注册字体族，让 <b> 标签正确使用同一字体的 Bold 别名
        from reportlab.pdfbase.pdfmetrics import registerFontFamily
        registerFontFamily(
            self._font_name,
            normal=self._font_name,
            bold=f"{self._font_name}-Bold",
            italic=self._font_name,
            boldItalic=f"{self._font_name}-Bold",
        )

    # ------------------------------------------------------------------
    # Styles
    # ------------------------------------------------------------------

    def _make_styles(self) -> dict:
        fn = self._font_name
        base = getSampleStyleSheet()

        def s(name, parent="Normal", **kw):
            return ParagraphStyle(name, parent=base[parent], fontName=fn, **kw)

        return {
            "title":    s("DocTitle",       fontSize=22, leading=28, alignment=TA_CENTER, spaceAfter=6),
            "toc_h":    s("TOCHeading",     fontSize=16, leading=22, alignment=TA_CENTER, spaceAfter=12),
            "toc0":     s("TOCLevel0",      fontSize=12, leading=20, leftIndent=0,  spaceAfter=2,
                          textColor=colors.HexColor("#1a1a1a")),
            "toc1":     s("TOCLevel1",      fontSize=11, leading=18, leftIndent=16, spaceAfter=1,
                          textColor=colors.HexColor("#333333")),
            "toc2":     s("TOCLevel2",      fontSize=10, leading=16, leftIndent=32, spaceAfter=1,
                          textColor=colors.HexColor("#555555")),
            "chapter":  s("ChapterHeading", fontSize=16, leading=22, spaceBefore=6, spaceAfter=6,
                          textColor=colors.HexColor("#1a1a1a")),
            "h1":       s("SectionHeading1", fontSize=14, leading=20, spaceBefore=10, spaceAfter=4,
                          textColor=colors.HexColor("#1a1a1a")),
            "h2":       s("SectionHeading2", fontSize=12, leading=18, spaceBefore=8,  spaceAfter=4,
                          textColor=colors.HexColor("#1a1a1a")),
            "h3":       s("SectionHeading3", fontSize=11, leading=16, spaceBefore=6,  spaceAfter=3,
                          textColor=colors.HexColor("#1a1a1a")),
            "body":     s("BodyText",        fontSize=11, leading=18, spaceAfter=4),
            "code":     ParagraphStyle("CodeBlock", fontName="Courier", fontSize=10, leading=14,
                                       backColor=colors.HexColor("#f5f5f5"),
                                       leftIndent=8, rightIndent=8, spaceBefore=4, spaceAfter=4,
                                       borderPad=4),
            "bullet":   s("BulletText",      fontSize=11, leading=18, leftIndent=16,
                          bulletIndent=4, spaceAfter=2),
            "quote":    s("QuoteText",       fontSize=11, leading=18, leftIndent=20,
                          textColor=colors.HexColor("#555555"), spaceAfter=4),
        }

    # ------------------------------------------------------------------
    # LaTeX pattern
    # ------------------------------------------------------------------

    # 匹配 display math: \[...\] 或 $$...$$（独占一行或跨行）
    # 匹配 inline math:  \(...\) 或 $...$
    _LATEX_PATTERN = re.compile(
        r"\$\$(.+?)\$\$"        # $$...$$  display
        r"|\\\[(.+?)\\\]"       # \[...\]  display
        r"|\\\((.+?)\\\)"       # \(...\)  inline
        r"|\$([^$\n]+?)\$",     # $...$    inline (no newlines, no empty)
        re.DOTALL,
    )

    # ------------------------------------------------------------------
    # Text → mixed flowables (Paragraph + Image for display math)
    # ------------------------------------------------------------------

    @staticmethod
    def _escape(text: str) -> str:
        """Escape XML special chars for Paragraph."""
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    @staticmethod
    def _apply_inline_markup(text: str) -> str:
        """Convert **bold** and `code` markdown to reportlab XML tags."""
        text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
        text = re.sub(r"`(.+?)`", r'<font name="Courier">\1</font>', text)
        return text

    def _text_to_flowables(
        self,
        text: str,
        latex_renderer: LatexRenderer,
        style: Any,
        page_width_pt: float = 160 * mm,
    ) -> list:
        """
        Convert a text string (possibly containing LaTeX) into a list of flowables.

        Strategy:
        - Display math (display math): rendered as PNG -> standalone Image flowable,
          centered, with vertical spacing.
        - Inline math (inline math): rendered as PNG -> written to temp file ->
          embedded via <img src="path"> inside the Paragraph XML.
        - Plain text + **bold** + `code`: converted to reportlab XML markup.

        If the text contains no LaTeX, returns a single Paragraph.
        """
        # Split text into segments: (content, is_display_latex, is_inline_latex)
        segments: list[tuple[str, bool, bool]] = []  # (text, is_display, is_latex)
        last = 0

        for m in self._LATEX_PATTERN.finditer(text):
            # Plain text before this match
            before = text[last:m.start()]
            if before:
                segments.append((before, False, False))

            if m.group(1) is not None:
                segments.append((m.group(1), True, True))   # $$...$$
            elif m.group(2) is not None:
                segments.append((m.group(2), True, True))   # \[...\]
            elif m.group(3) is not None:
                segments.append((m.group(3), False, True))  # \(...\)
            else:
                segments.append((m.group(4), False, True))  # $...$

            last = m.end()

        # Remaining plain text
        tail = text[last:]
        if tail:
            segments.append((tail, False, False))

        # If no LaTeX at all, return a single Paragraph
        if not any(is_latex for _, _, is_latex in segments):
            xml = self._apply_inline_markup(text)
            return [Paragraph(xml, style)]

        # Build flowables
        flowables = []
        # Accumulate inline segments (plain + inline math) into one Paragraph
        inline_xml_parts: list[str] = []

        def _flush_inline():
            """Flush accumulated inline XML into a Paragraph."""
            if inline_xml_parts:
                xml = "".join(inline_xml_parts)
                if xml.strip():
                    flowables.append(Paragraph(xml, style))
                inline_xml_parts.clear()

        for content, is_display, is_latex in segments:
            if not is_latex:
                # Plain text — add to inline buffer
                inline_xml_parts.append(self._apply_inline_markup(content))
            elif is_display:
                # Display math — flush inline buffer first, then add image
                _flush_inline()
                png = latex_renderer.render(content.strip(), display=True)
                if png is None:
                    # Fallback: show formula source in red
                    fallback = f'<font color="#cc0000">[公式: {self._escape(content.strip())}]</font>'
                    flowables.append(Paragraph(fallback, style))
                else:
                    try:
                        path = _png_to_temp_file(png)
                        # Scale image to fit page width, max 80% of page width
                        from PIL import Image as PILImage
                        img = PILImage.open(io.BytesIO(png))
                        w_px, h_px = img.size
                        dpi = 200  # 与 LatexRenderer 渲染 DPI 一致
                        w_pt = w_px / dpi * 72
                        h_pt = h_px / dpi * 72
                        max_w = page_width_pt * 0.8
                        if w_pt > max_w:
                            scale = max_w / w_pt
                            w_pt *= scale
                            h_pt *= scale
                        img_flowable = Image(path, width=w_pt, height=h_pt)
                        img_flowable.hAlign = "CENTER"
                        flowables.append(Spacer(1, 4))
                        flowables.append(img_flowable)
                        flowables.append(Spacer(1, 4))
                    except Exception:
                        fallback = f'<font color="#cc0000">[公式渲染失败: {self._escape(content.strip())}]</font>'
                        flowables.append(Paragraph(fallback, style))
            else:
                # Inline math — render as PNG, embed via <img src="path">
                png = latex_renderer.render(content.strip(), display=False)
                if png is None:
                    inline_xml_parts.append(
                        f'<font color="#cc0000">[{self._escape(content.strip())}]</font>'
                    )
                else:
                    try:
                        path = _png_to_temp_file(png)
                        # Compute display height in points (match body font size ~11pt)
                        from PIL import Image as PILImage
                        img = PILImage.open(io.BytesIO(png))
                        w_px, h_px = img.size
                        dpi = 200  # 与 LatexRenderer 渲染 DPI 一致
                        h_pt = min(h_px / dpi * 72, 14)  # cap at 14pt for inline (matches 11pt body text)
                        w_pt = w_px / dpi * 72 * (h_pt / (h_px / dpi * 72))
                        # reportlab <img> in Paragraph supports file paths
                        inline_xml_parts.append(
                            f'<img src="{path}" width="{w_pt:.1f}" height="{h_pt:.1f}"/>'
                        )
                    except Exception:
                        inline_xml_parts.append(
                            f'<font color="#cc0000">[{self._escape(content.strip())}]</font>'
                        )

        _flush_inline()
        return flowables

    # ------------------------------------------------------------------
    # Block → Flowables
    # ------------------------------------------------------------------

    def _block_to_flowables(
        self,
        block: dict,
        styles: dict,
        latex_renderer: LatexRenderer,
        page_width_pt: float = 160 * mm,
    ) -> list:
        btype = block.get("type", "paragraph")
        text = block.get("text", "") or block.get("content", "") or ""
        flowables = []

        if btype == "heading":
            level = block.get("level", 1)
            style_key = {1: "h1", 2: "h2", 3: "h3"}.get(level, "h3")
            flowables.extend(
                self._text_to_flowables(text, latex_renderer, styles[style_key], page_width_pt)
            )

        elif btype == "paragraph":
            flowables.extend(
                self._text_to_flowables(text, latex_renderer, styles["body"], page_width_pt)
            )

        elif btype == "code":
            # Code blocks: preserve newlines, use Courier — no LaTeX processing
            lines = text.splitlines() or [""]
            escaped = "<br/>".join(
                l.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                for l in lines
            )
            flowables.append(Paragraph(escaped, styles["code"]))

        elif btype == "list":
            # Bullet items may contain inline math
            sub = self._text_to_flowables(text, latex_renderer, styles["bullet"], page_width_pt)
            # Prepend bullet character to first paragraph
            if sub and isinstance(sub[0], Paragraph):
                # Access the internal XML string stored in Paragraph
                first_xml = getattr(sub[0], "text", "") or ""
                sub[0] = Paragraph(f"• {first_xml}", styles["bullet"])
            elif not sub:
                # Fallback: plain bullet
                sub = [Paragraph(f"• {self._escape(text)}", styles["bullet"])]
            flowables.extend(sub)

        elif btype == "quote":
            flowables.append(HRFlowable(width="2pt", color=colors.grey, spaceAfter=0))
            flowables.extend(
                self._text_to_flowables(text, latex_renderer, styles["quote"], page_width_pt)
            )

        else:
            flowables.extend(
                self._text_to_flowables(text, latex_renderer, styles["body"], page_width_pt)
            )

        return flowables

    # ------------------------------------------------------------------
    # build()
    # ------------------------------------------------------------------

    def build(
        self,
        session_title: str,
        nodes: list[NodeInfo],
        include_toc: bool = True,
    ) -> bytes:
        filtered = self._filter_nodes(nodes)
        if not filtered:
            raise ValueError("没有可导出的节点")

        latex_renderer = LatexRenderer()
        styles = self._make_styles()
        fn = self._font_name

        # Page content width (A4 minus margins)
        page_width_pt = A4[0] - 50 * mm  # 25mm each side

        buf = io.BytesIO()
        doc = _BookDocTemplate(
            buf,
            font_name=fn,
            session_title=session_title,
            pagesize=A4,
            leftMargin=25 * mm,
            rightMargin=25 * mm,
            topMargin=20 * mm,
            bottomMargin=20 * mm,
        )

        story = []

        # --- Document title ---
        story.append(Spacer(1, 20 * mm))
        story.append(Paragraph(self._escape(session_title), styles["title"]))
        from datetime import date as _date
        today = _date.today().strftime("%Y 年 %m 月 %d 日")
        subtitle_style = ParagraphStyle(
            "Subtitle", parent=styles["body"],
            fontSize=12, leading=18,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#888888"),
            spaceAfter=4,
        )
        story.append(Paragraph("为您量身定制", subtitle_style))
        story.append(Paragraph(today, subtitle_style))
        story.append(Spacer(1, 10 * mm))

        # --- TOC ---
        if include_toc:
            story.append(Paragraph("目录", styles["toc_h"]))
            toc = TableOfContents()
            toc.dotsMinLevel = 0
            toc.levelStyles = [
                styles["toc0"],
                styles["toc1"],
                styles["toc2"],
            ]
            story.append(toc)
            story.append(PageBreak())

        # --- Body ---
        try:
            for node in filtered:
                # Chapter heading
                story.append(Paragraph(self._escape(node.text), styles["chapter"]))
                story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor("#cccccc"), spaceAfter=6))

                for block in node.blocks:
                    flowables = self._block_to_flowables(block, styles, latex_renderer, page_width_pt)
                    story.extend(flowables)

                story.append(Spacer(1, 6 * mm))
                story.append(PageBreak())

            doc.multiBuild(story)
        finally:
            # Always clean up temp PNG files
            _cleanup_temp_files()

        buf.seek(0)
        return buf.read()
