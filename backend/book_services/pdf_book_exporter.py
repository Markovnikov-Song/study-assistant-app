"""PDF book exporter — uses reportlab Platypus for proper layout, page numbers, and TOC."""

from __future__ import annotations

import io
import re
from pathlib import Path

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
    KeepTogether,
)
from reportlab.platypus.tableofcontents import TableOfContents
from reportlab.platypus.flowables import Flowable

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
# Inline image flowable for LaTeX
# ---------------------------------------------------------------------------

class _InlineImage(Flowable):
    """A small inline image (for LaTeX rendered as PNG)."""

    def __init__(self, png_bytes: bytes, height_pt: float = 14):
        super().__init__()
        from PIL import Image as PILImage
        img = PILImage.open(io.BytesIO(png_bytes))
        w, h = img.size
        scale = height_pt / h if h > 0 else 1
        self.img_bytes = png_bytes
        self.img_width = w * scale
        self.img_height = height_pt
        self.width = self.img_width
        self.height = self.img_height

    def draw(self):
        from reportlab.lib.utils import ImageReader
        self.canv.drawImage(
            ImageReader(io.BytesIO(self.img_bytes)),
            0, 0, self.img_width, self.img_height,
        )


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
    # Text → Paragraph (handles **bold**, *italic*, inline LaTeX)
    # ------------------------------------------------------------------

    @staticmethod
    def _escape(text: str) -> str:
        """Escape XML special chars for Paragraph."""
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    def _text_to_xml(self, text: str, latex_renderer: LatexRenderer, font_name: str) -> str:
        """Convert text with **bold**, *italic*, $latex$ to reportlab XML markup."""
        # First handle LaTeX: replace with [公式] placeholder (images can't go inline in Paragraph)
        # We'll render LaTeX as separate flowables for display math,
        # and inline as [公式] text for inline math (limitation of Platypus)
        result = []
        # 支持 $$...$$, \[...\], \(...\), $...$
        pattern = re.compile(
            r"\$\$(.+?)\$\$"
            r"|\\\[(.+?)\\\]"
            r"|\\\((.+?)\\\)"
            r"|\$(.+?)\$",
            re.DOTALL,
        )
        last = 0
        for m in pattern.finditer(text):
            plain = text[last:m.start()]
            result.append(self._apply_inline_markup(plain))
            if m.group(1) is not None:
                latex_src, is_display = m.group(1), True
            elif m.group(2) is not None:
                latex_src, is_display = m.group(2), True
            elif m.group(3) is not None:
                latex_src, is_display = m.group(3), False
            else:
                latex_src, is_display = m.group(4), False
            png = latex_renderer.render(latex_src, display=is_display)
            if png is None:
                result.append(f'<font color="#cc0000">[公式: {self._escape(latex_src)}]</font>')
            else:
                import base64
                b64 = base64.b64encode(png).decode()
                h = 16 if not is_display else 20
                result.append(f'<img src="data:image/png;base64,{b64}" height="{h}"/>')
            last = m.end()
        result.append(self._apply_inline_markup(text[last:]))
        return "".join(result)

    @staticmethod
    def _apply_inline_markup(text: str) -> str:
        """Convert **bold** and *italic* markdown to reportlab XML tags.
        
        只处理 **bold** 和 `code`，不处理 *italic*（避免误匹配下划线）。
        """
        # Escape XML first
        text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        # Bold: **text**
        text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
        # Inline code: `text`
        text = re.sub(r"`(.+?)`", r'<font name="Courier">\1</font>', text)
        return text

    # ------------------------------------------------------------------
    # Block → Flowables
    # ------------------------------------------------------------------

    def _block_to_flowables(
        self,
        block: dict,
        styles: dict,
        latex_renderer: LatexRenderer,
    ) -> list:
        btype = block.get("type", "paragraph")
        text = block.get("text", "") or block.get("content", "") or ""
        fn = self._font_name
        flowables = []

        if btype == "heading":
            level = block.get("level", 1)
            style_key = {1: "h1", 2: "h2", 3: "h3"}.get(level, "h3")
            xml = self._text_to_xml(text, latex_renderer, fn)
            flowables.append(Paragraph(xml, styles[style_key]))

        elif btype == "paragraph":
            xml = self._text_to_xml(text, latex_renderer, fn)
            flowables.append(Paragraph(xml, styles["body"]))

        elif btype == "code":
            # Code blocks: preserve newlines, use Courier
            lines = text.splitlines() or [""]
            escaped = "<br/>".join(
                l.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                for l in lines
            )
            flowables.append(Paragraph(escaped, styles["code"]))

        elif btype == "list":
            xml = self._text_to_xml(text, latex_renderer, fn)
            flowables.append(Paragraph(f"• {xml}", styles["bullet"]))

        elif btype == "quote":
            xml = self._text_to_xml(text, latex_renderer, fn)
            flowables.append(HRFlowable(width="2pt", color=colors.grey, spaceAfter=0))
            flowables.append(Paragraph(xml, styles["quote"]))

        else:
            xml = self._text_to_xml(text, latex_renderer, fn)
            flowables.append(Paragraph(xml, styles["body"]))

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
        # 副标题
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
            toc.dotsMinLevel = 0  # 所有级别都显示点线
            toc.levelStyles = [
                styles["toc0"],
                styles["toc1"],
                styles["toc2"],
            ]
            story.append(toc)
            story.append(PageBreak())

        # --- Body ---
        for node in filtered:
            # Chapter heading
            story.append(Paragraph(self._escape(node.text), styles["chapter"]))
            story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor("#cccccc"), spaceAfter=6))

            for block in node.blocks:
                flowables = self._block_to_flowables(block, styles, latex_renderer)
                story.extend(flowables)

            story.append(Spacer(1, 6 * mm))
            story.append(PageBreak())

        doc.multiBuild(story)
        buf.seek(0)
        return buf.read()
