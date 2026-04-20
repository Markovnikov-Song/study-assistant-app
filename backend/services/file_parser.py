"""
file_parser.py — 公共文件解析工具，供 DocumentService 和 ExamService 共用。
"""
from __future__ import annotations

import logging
import os

logger = logging.getLogger(__name__)


def parse_file(tmp_path: str, filename: str) -> str:
    """解析文件为纯文本，根据扩展名分发。"""
    ext = os.path.splitext(filename)[1].lower()
    if ext == ".pdf":
        return _parse_pdf(tmp_path)
    elif ext == ".docx":
        return _parse_docx(tmp_path)
    elif ext == ".pptx":
        return _parse_pptx(tmp_path)
    elif ext in (".txt", ".md"):
        return _parse_text(tmp_path)
    else:
        raise ValueError(f"不支持的文件格式：{ext}")


def _parse_pdf(tmp_path: str) -> str:
    import pdfplumber
    pages: list[str] = []
    with pdfplumber.open(tmp_path) as pdf:
        for i, page in enumerate(pdf.pages):
            text = page.extract_text() or ""
            if not text.strip():
                logger.warning("第 %d 页无文字内容，跳过", i)
            pages.append(text)
    return "\n".join(pages)


def _parse_docx(tmp_path: str) -> str:
    from docx import Document
    doc = Document(tmp_path)
    return "\n".join(p.text for p in doc.paragraphs)


def _parse_pptx(tmp_path: str) -> str:
    from pptx import Presentation
    prs = Presentation(tmp_path)
    texts: list[str] = []
    for slide in prs.slides:
        for shape in slide.shapes:
            if shape.has_text_frame:
                for para in shape.text_frame.paragraphs:
                    texts.append(para.text)
    return "\n".join(texts)


def _parse_text(tmp_path: str) -> str:
    with open(tmp_path, "r", encoding="utf-8") as f:
        return f.read()
