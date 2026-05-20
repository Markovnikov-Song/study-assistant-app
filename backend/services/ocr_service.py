"""
OCR 服务：优先使用 PaddleOCR-VL-1.5（via LLMService）识别图片文字，
失败时降级到通用 LLM 视觉能力，最终降级到 pytesseract。

新增接口：
  - extract_text_from_base64(image_b64: str) -> str   单张 Base64 图片 OCR
  - extract_text_from_base64_list(images: list[str]) -> str  多张并发 OCR

向后兼容接口（签名不变）：
  - extract_text(image_path: str) -> str
  - extract_text_from_pdf_page(pdf_path: str, page_num: int) -> str
"""

from __future__ import annotations

import asyncio
import base64
import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

# 默认可用的视觉模型回退链（去重后按顺序尝试）
_DEFAULT_VISION_FALLBACKS = (
    "Qwen/Qwen2.5-VL-7B-Instruct",
    "deepseek-ai/deepseek-vl2",
)


def _vision_model_chain(config) -> list[str]:
    """主模型 → 配置的降级模型 → 内置备选，去重保序。"""
    candidates = [
        getattr(config, "LLM_VISION_MODEL", None),
        getattr(config, "LLM_VISION_FALLBACK_MODEL", None),
        *_DEFAULT_VISION_FALLBACKS,
    ]
    seen: set[str] = set()
    chain: list[str] = []
    for m in candidates:
        if m and m not in seen:
            seen.add(m)
            chain.append(m)
    return chain


# OCR 提示词：要求严格 LaTeX 格式输出数学公式，禁止输出解答
_OCR_PROMPT = (
    "提取图片中所有文本内容。"
    "若包含数学公式，严格使用标准 LaTeX 格式输出："
    "行内公式用 $...$，独立公式用 $$...$$。"
    "禁止输出任何解答、分析或额外说明，只输出原文。"
)


class OCRService:
    """
    OCR 识别服务。

    新增多模态解题路径：
      PaddleOCR-VL-1.5 (LLM_VISION_MODEL)
          ↓ 超时 / HTTP 错误
      通用 LLM 视觉能力 (LLM_CHAT_MODEL)
          ↓ 均失败
      raise RuntimeError

    原有路径（向后兼容）：
      LLM 视觉 → pytesseract
    """

    # 并发限流：最多同时 2 个视觉 API 请求，防止触发 SiliconFlow 429 速率限制
    _semaphore = asyncio.Semaphore(2)

    def __init__(self) -> None:
        from services.llm_service import LLMService
        self._llm_service = LLMService()

    # ──────────────────────────────────────────────────────────────────
    # 新增：Base64 接口（供 SolveProblemExecutor 调用）
    # ──────────────────────────────────────────────────────────────────

    async def extract_text_from_base64(self, image_b64: str) -> str:
        """
        单张 Base64 图片 OCR，返回识别文本（含 LaTeX 格式公式）。

        优先调用 PaddleOCR-VL-1.5，超时/失败时降级到通用 LLM 视觉，
        均失败则抛 RuntimeError。

        当 SOLVE_IMAGE_PREPROCESS_ENABLED=True 时，在调用视觉 API 前
        先对图片执行 OpenCV 五步预处理，提升识别率。

        :param image_b64: Base64 编码的 JPEG/PNG 图片字符串
        :raises RuntimeError: 所有 OCR 方式均失败时
        :return: 识别出的文字内容（数学公式为 LaTeX 格式）
        """
        from backend_config import get_config
        config = get_config()

        # ── 图像预处理（可通过配置开关控制）────────────────────────────────
        if getattr(config, "SOLVE_IMAGE_PREPROCESS_ENABLED", False):
            try:
                from services.image_preprocessor import ImagePreprocessor
                preprocess_result = ImagePreprocessor().process(image_b64)
                if not preprocess_result.degraded:
                    image_b64 = preprocess_result.image_b64
                else:
                    logger.warning(
                        "OCRService: 图像预处理降级，使用原始图片 preprocess_degraded=True"
                    )
            except Exception as e:
                logger.warning(
                    "OCRService: 图像预处理异常，使用原始图片 preprocess_degraded=True: %s", e
                )

        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{image_b64}",
                            "detail": "high",
                        },
                    },
                    {"type": "text", "text": _OCR_PROMPT},
                ],
            }
        ]

        models = _vision_model_chain(config)
        loop = asyncio.get_event_loop()
        last_error: Exception | None = None

        # 并发限流：async with 保证同时最多 2 个视觉 API 请求
        async with self._semaphore:
            for model in models:
                try:
                    result = await asyncio.wait_for(
                        loop.run_in_executor(
                            None,
                            lambda m=model: self._llm_service.chat(
                                messages, model=m
                            ),
                        ),
                        timeout=config.SOLVE_OCR_TIMEOUT_SECONDS,
                    )
                    text = (result or "").strip()
                    if text:
                        if model != models[0]:
                            logger.info("OCRService: 使用备选视觉模型 %s 成功", model)
                        return text
                    logger.warning("OCRService: 模型 %s 返回空文本，尝试下一个", model)
                except asyncio.TimeoutError as e:
                    last_error = e
                    logger.warning(
                        "OCRService: 模型 %s 超时（>%ds），尝试下一个",
                        model,
                        config.SOLVE_OCR_TIMEOUT_SECONDS,
                    )
                except Exception as e:
                    last_error = e
                    logger.warning("OCRService: 模型 %s 失败（%s），尝试下一个", model, e)

            # 最后尝试 chat_with_vision（显式传入与主模型不同的备选）
            for model in models[1:]:
                try:
                    result = await loop.run_in_executor(
                        None,
                        lambda m=model: self._llm_service.chat_with_vision(
                            [{"role": "user", "content": _OCR_PROMPT}],
                            image_b64,
                            model=m,
                        ),
                    )
                    text = (result or "").strip()
                    if text:
                        logger.info("OCRService: chat_with_vision 备选模型 %s 成功", model)
                        return text
                except Exception as e:
                    last_error = e
                    logger.warning(
                        "OCRService: chat_with_vision 模型 %s 失败（%s）", model, e
                    )

        raise RuntimeError(
            "图片识别暂时失败，请换一张更清晰的照片后重试；若持续失败请稍后再试。"
        ) from last_error

    async def extract_text_from_base64_list(self, images: list[str]) -> str:
        """
        多张 Base64 图片并发 OCR，结果以 \\n---\\n 分隔拼接。

        :param images: Base64 图片字符串列表
        :return: 各图片识别文本，以 '\\n---\\n' 分隔
        """
        if not images:
            return ""
        results = await asyncio.gather(
            *[self.extract_text_from_base64(img) for img in images]
        )
        return "\n---\n".join(results)

    # ──────────────────────────────────────────────────────────────────
    # 向后兼容：原有接口，签名不变
    # ──────────────────────────────────────────────────────────────────

    def extract_text(self, image_path: str) -> str:
        """
        从图片文件中提取文字。

        优先调用 LLM 视觉能力（chat_with_vision），失败时静默降级到
        pytesseract（lang='chi_sim+eng'）。两者均失败时抛出 RuntimeError。

        :param image_path: 图片文件路径
        :raises RuntimeError: LLM 和 pytesseract 均失败时
        :return: 识别出的文字内容
        """
        # 1. 尝试 LLM OCR
        try:
            return self._llm_ocr(image_path)
        except Exception as e:
            logger.warning("LLM OCR 失败，降级到 pytesseract：%s", e)

        # 2. 降级到 pytesseract
        try:
            return self._tesseract_ocr(image_path)
        except Exception as e:
            raise RuntimeError(f"OCR 识别失败（LLM 和 pytesseract 均不可用）：{e}") from e

    def extract_text_from_pdf_page(self, pdf_path: str, page_num: int) -> str:
        """
        将 PDF 指定页转为图片后提取文字。

        优先使用 pdf2image 将页面转为图片再调用 extract_text；
        若 pdf2image 不可用，则直接用 pytesseract 处理 PDF。

        :param pdf_path: PDF 文件路径
        :param page_num: 页码（从 0 开始）
        :raises RuntimeError: 所有方式均失败时
        :return: 识别出的文字内容
        """
        # 1. 尝试 pdf2image 转图片后 OCR
        try:
            return self._pdf_via_image(pdf_path, page_num)
        except ImportError:
            logger.warning("pdf2image 不可用，降级到 pytesseract 直接处理 PDF")
        except Exception as e:
            logger.warning("pdf2image 转换失败，降级到 pytesseract 直接处理 PDF：%s", e)

        # 2. 降级：pytesseract 直接处理 PDF
        try:
            return self._tesseract_pdf(pdf_path, page_num)
        except Exception as e:
            raise RuntimeError(f"PDF 第 {page_num} 页 OCR 失败：{e}") from e

    # ──────────────────────────────────────────────────────────────────
    # 私有辅助方法
    # ──────────────────────────────────────────────────────────────────

    def _llm_ocr(self, image_path: str) -> str:
        """读取图片为 base64，调用 LLM 视觉接口识别文字。"""
        with open(image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")

        messages = [
            {
                "role": "system",
                "content": "你是一个专业的 OCR 助手，请准确识别图片中的所有文字，保持原有格式。",
            }
        ]
        return self._llm_service.chat_with_vision(messages, image_b64)

    def _tesseract_ocr(self, image_path: str) -> str:
        """使用 pytesseract 识别图片文字（中英文）。"""
        import pytesseract
        from PIL import Image

        image = Image.open(image_path)
        return pytesseract.image_to_string(image, lang="chi_sim+eng")

    def _pdf_via_image(self, pdf_path: str, page_num: int) -> str:
        """使用 pdf2image 将 PDF 指定页转为图片，再调用 extract_text。"""
        import tempfile
        import os
        from pdf2image import convert_from_path

        # convert_from_path 页码从 1 开始
        pages = convert_from_path(
            pdf_path,
            first_page=page_num + 1,
            last_page=page_num + 1,
        )
        if not pages:
            raise RuntimeError(f"PDF 第 {page_num} 页转换结果为空")

        page_image = pages[0]
        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
                tmp_path = tmp.name
            page_image.save(tmp_path, format="PNG")
            return self.extract_text(tmp_path)
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)

    def _tesseract_pdf(self, pdf_path: str, page_num: int) -> str:
        """直接用 pytesseract 处理 PDF（pdf2image 不可用时的降级方案）。"""
        import pytesseract
        from PIL import Image

        # Pillow 可以直接打开 PDF（需要 Ghostscript），按页读取
        image = Image.open(pdf_path)
        image.seek(page_num)
        return pytesseract.image_to_string(image, lang="chi_sim+eng")
