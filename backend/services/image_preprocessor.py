"""
图像预处理服务：OpenCV 五步流水线。

在 OCR 之前对题目图片进行语义无损的预处理，将手机拍摄的模糊、倾斜、
光照不均的题目照片转化为 AI 可精准理解的标准文档图像。

设计原则：语义绝对保真——所有处理步骤只增强图像可读性，
绝不修改公式结构、文字内容、几何图形的语义信息。

五步流水线（按顺序，每步独立容错）：
  1. EXIF 方向矫正（Pillow）
  2. 2D 倾斜矫正（Canny + 霍夫变换 + 仿射变换）
  3. Retinex 光照均衡 + CLAHE（LAB 色彩空间 L 通道）
  4. NLM 去噪 + Unsharp Mask 锐化
  5. 摩尔纹检测与去除（傅里叶频域滤波）

通过环境变量独立控制各步骤开关：
  PREPROCESS_EXIF_CORRECT    (默认 true)
  PREPROCESS_DESKEW          (默认 true)
  PREPROCESS_RETINEX_CLAHE   (默认 true)
  PREPROCESS_NLM_SHARPEN     (默认 true)
  PREPROCESS_MOIRE_REMOVE    (默认 true)
"""
from __future__ import annotations

import base64
import io
import logging
import os
import time
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)


def _env_bool(key: str, default: bool = True) -> bool:
    """从环境变量读取布尔值，默认 True。"""
    val = os.getenv(key, "true" if default else "false").lower().strip()
    return val not in ("false", "0", "no", "off")


# ── 各步骤开关（运行时读取，支持热更新） ──────────────────────────────────────

def _step_enabled(step: str) -> bool:
    """检查指定步骤是否启用。"""
    key_map = {
        "exif_correct": "PREPROCESS_EXIF_CORRECT",
        "deskew": "PREPROCESS_DESKEW",
        "retinex_clahe": "PREPROCESS_RETINEX_CLAHE",
        "nlm_sharpen": "PREPROCESS_NLM_SHARPEN",
        "moire_remove": "PREPROCESS_MOIRE_REMOVE",
    }
    return _env_bool(key_map.get(step, ""), default=True)


# ── 数据类 ────────────────────────────────────────────────────────────────────

@dataclass
class StepLog:
    """单步骤执行日志。"""
    name: str
    skipped: bool = False
    elapsed_ms: float = 0.0
    reason: str = ""


@dataclass
class PreprocessResult:
    """图像预处理结果。"""
    image_b64: str                              # 处理后的图片 Base64
    step_logs: list[StepLog] = field(default_factory=list)
    total_ms: float = 0.0
    input_size: tuple[int, int] = (0, 0)        # (width, height)
    output_size: tuple[int, int] = (0, 0)
    degraded: bool = False                      # True 表示所有步骤失败，返回原始图片


# ── ImagePreprocessor ─────────────────────────────────────────────────────────

class ImagePreprocessor:
    """
    图像预处理服务，五步流水线，每步独立容错。

    用法：
        result = ImagePreprocessor().process(image_b64)
        if not result.degraded:
            enhanced_b64 = result.image_b64
    """

    def process(self, image_b64: str) -> PreprocessResult:
        """
        执行五步预处理流水线。

        任意步骤失败时记录 WARNING 日志并跳过，继续执行后续步骤。
        所有步骤均失败时返回原始图片（degraded=True）。
        """
        start = time.monotonic()
        step_logs: list[StepLog] = []

        # ── 解码输入图片 ──────────────────────────────────────────────────────
        try:
            from PIL import Image
            img_bytes = base64.b64decode(image_b64)
            pil_img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            input_size = pil_img.size  # (width, height)
        except Exception as e:
            logger.error("ImagePreprocessor: 图片解码失败: %s", e)
            return PreprocessResult(image_b64=image_b64, degraded=True)

        # ── 步骤 1：EXIF 方向矫正 ─────────────────────────────────────────────
        pil_img, log = self._step_exif_correct(pil_img)
        step_logs.append(log)

        # ── 转换为 OpenCV 格式（BGR）─────────────────────────────────────────
        try:
            import cv2
            import numpy as np
            cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        except Exception as e:
            logger.error("ImagePreprocessor: PIL→OpenCV 转换失败: %s", e)
            return PreprocessResult(
                image_b64=image_b64,
                step_logs=step_logs,
                degraded=True,
            )

        # ── 步骤 2：2D 倾斜矫正 ───────────────────────────────────────────────
        cv_img, log = self._step_deskew(cv_img)
        step_logs.append(log)

        # ── 步骤 3：Retinex 光照均衡 + CLAHE ─────────────────────────────────
        cv_img, log = self._step_retinex_clahe(cv_img)
        step_logs.append(log)

        # ── 步骤 4：NLM 去噪 + Unsharp Mask 锐化 ─────────────────────────────
        cv_img, log = self._step_nlm_sharpen(cv_img)
        step_logs.append(log)

        # ── 步骤 5：摩尔纹检测与去除 ─────────────────────────────────────────
        cv_img, log = self._step_moire_remove(cv_img)
        step_logs.append(log)

        # ── 编码输出图片（JPEG 质量 90）──────────────────────────────────────
        try:
            import cv2
            from PIL import Image
            output_pil = Image.fromarray(cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB))
            output_size = output_pil.size
            buf = io.BytesIO()
            output_pil.save(buf, format="JPEG", quality=90)
            result_b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
        except Exception as e:
            logger.error("ImagePreprocessor: 图片编码失败: %s", e)
            result_b64 = image_b64
            output_size = input_size

        total_ms = (time.monotonic() - start) * 1000

        # ── 结构化性能日志 ────────────────────────────────────────────────────
        logger.info(
            "ImagePreprocessor 完成 total_ms=%.1f input=%s output=%s steps=%s",
            total_ms,
            input_size,
            output_size,
            [
                {s.name: {"skipped": s.skipped, "ms": round(s.elapsed_ms, 1), "reason": s.reason}}
                for s in step_logs
            ],
        )

        return PreprocessResult(
            image_b64=result_b64,
            step_logs=step_logs,
            total_ms=total_ms,
            input_size=input_size,
            output_size=output_size,
        )

    # ── 步骤 1：EXIF 方向矫正 ─────────────────────────────────────────────────

    def _step_exif_correct(self, img) -> tuple:
        """步骤 1：读取 EXIF 旋转信息，自动旋转到正向。"""
        from PIL import Image, ExifTags
        log = StepLog(name="exif_correct")
        t = time.monotonic()

        if not _step_enabled("exif_correct"):
            log.skipped = True
            log.reason = "配置禁用"
            log.elapsed_ms = (time.monotonic() - t) * 1000
            return img, log

        try:
            # 获取 EXIF 数据
            exif_data = None
            if hasattr(img, "_getexif"):
                exif_data = img._getexif()
            elif hasattr(img, "getexif"):
                exif_data = img.getexif()

            if exif_data is None:
                log.skipped = True
                log.reason = "无 EXIF 信息"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            # 查找 Orientation 标签
            orientation_key = None
            for k, v in ExifTags.TAGS.items():
                if v == "Orientation":
                    orientation_key = k
                    break

            if orientation_key is None or orientation_key not in exif_data:
                log.skipped = True
                log.reason = "无方向标签"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            orientation = exif_data[orientation_key]

            # EXIF 方向映射表
            _ORIENTATION_MAP = {
                2: Image.FLIP_LEFT_RIGHT,
                3: Image.ROTATE_180,
                4: Image.FLIP_TOP_BOTTOM,
                6: Image.ROTATE_270,
                8: Image.ROTATE_90,
            }
            _ORIENTATION_DOUBLE = {
                5: (Image.FLIP_LEFT_RIGHT, Image.ROTATE_90),
                7: (Image.FLIP_LEFT_RIGHT, Image.ROTATE_270),
            }

            if orientation in _ORIENTATION_MAP:
                img = img.transpose(_ORIENTATION_MAP[orientation])
            elif orientation in _ORIENTATION_DOUBLE:
                ops = _ORIENTATION_DOUBLE[orientation]
                img = img.transpose(ops[0]).transpose(ops[1])
            elif orientation == 1:
                log.skipped = True
                log.reason = "方向正常（orientation=1），无需矫正"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            # 丢弃 EXIF 方向标签，避免后续处理重复旋转
            img.info.pop("exif", None)
            log.reason = f"已矫正 orientation={orientation}"

        except Exception as e:
            logger.warning("ImagePreprocessor: EXIF 矫正失败: %s", e)
            log.reason = str(e)

        log.elapsed_ms = (time.monotonic() - t) * 1000
        return img, log

    # ── 步骤 2：2D 倾斜矫正 ───────────────────────────────────────────────────

    def _step_deskew(self, img) -> tuple:
        """步骤 2：Canny 边缘检测 + 霍夫变换计算倾斜角，仿射变换矫正。"""
        import cv2
        import numpy as np
        log = StepLog(name="deskew")
        t = time.monotonic()

        if not _step_enabled("deskew"):
            log.skipped = True
            log.reason = "配置禁用"
            log.elapsed_ms = (time.monotonic() - t) * 1000
            return img, log

        try:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, 50, 150, apertureSize=3)
            lines = cv2.HoughLinesP(
                edges, 1, np.pi / 180, threshold=100,
                minLineLength=100, maxLineGap=10,
            )

            if lines is None or len(lines) == 0:
                log.skipped = True
                log.reason = "未检测到直线"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            # 计算各直线与水平方向的夹角
            angles = []
            for line in lines:
                x1, y1, x2, y2 = line[0]
                if x2 != x1:
                    angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
                    if -45 < angle < 45:
                        angles.append(angle)

            if not angles:
                log.skipped = True
                log.reason = "无有效角度"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            median_angle = float(np.median(angles))
            abs_angle = abs(median_angle)

            # 智能跳过：倾斜角 < 0.5° 或 > 15°
            if abs_angle < 0.5:
                log.skipped = True
                log.reason = f"倾斜角 {median_angle:.2f}° < 0.5°，无需矫正"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log
            if abs_angle > 15:
                log.skipped = True
                log.reason = f"倾斜角 {median_angle:.2f}° > 15°，可能是竖排文字，跳过"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            # 执行仿射旋转矫正
            h, w = img.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
            img = cv2.warpAffine(
                img, M, (w, h),
                flags=cv2.INTER_LINEAR,
                borderMode=cv2.BORDER_CONSTANT,
                borderValue=(255, 255, 255),
            )
            log.reason = f"已矫正倾斜角 {median_angle:.2f}°"

        except Exception as e:
            logger.warning("ImagePreprocessor: 倾斜矫正失败: %s", e)
            log.reason = str(e)

        log.elapsed_ms = (time.monotonic() - t) * 1000
        return img, log

    # ── 步骤 3：Retinex 光照均衡 + CLAHE ─────────────────────────────────────

    def _step_retinex_clahe(self, img) -> tuple:
        """步骤 3：单尺度 Retinex 光照分量剥离 + CLAHE 自适应对比度增强。"""
        import cv2
        import numpy as np
        log = StepLog(name="retinex_clahe")
        t = time.monotonic()

        if not _step_enabled("retinex_clahe"):
            log.skipped = True
            log.reason = "配置禁用"
            log.elapsed_ms = (time.monotonic() - t) * 1000
            return img, log

        try:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            std_dev = float(np.std(gray))

            if std_dev >= 20:
                # 执行单尺度 Retinex（SSR）：分离光照分量，还原反射信息
                img_float = img.astype(np.float32) + 1.0
                log_img = np.log(img_float)
                blur = cv2.GaussianBlur(img_float, (0, 0), sigmaX=80)
                log_blur = np.log(np.maximum(blur, 1.0))
                retinex = log_img - log_blur
                retinex = cv2.normalize(retinex, None, 0, 255, cv2.NORM_MINMAX)
                img = retinex.astype(np.uint8)
                log.reason = f"Retinex 完成（亮度标准差 {std_dev:.1f}）"
            else:
                log.reason = f"亮度标准差 {std_dev:.1f} < 20，跳过 Retinex，仅做 CLAHE"

            # 执行 CLAHE（LAB 色彩空间 L 通道）
            lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
            l_ch, a_ch, b_ch = cv2.split(lab)
            clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            l_ch = clahe.apply(l_ch)
            lab = cv2.merge([l_ch, a_ch, b_ch])
            img = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

        except Exception as e:
            logger.warning("ImagePreprocessor: Retinex+CLAHE 失败: %s", e)
            log.reason = str(e)

        log.elapsed_ms = (time.monotonic() - t) * 1000
        return img, log

    # ── 步骤 4：NLM 去噪 + Unsharp Mask 锐化 ─────────────────────────────────

    def _step_nlm_sharpen(self, img) -> tuple:
        """步骤 4：非局部均值去噪（保留文字边缘）+ Unsharp Mask 锐化。"""
        import cv2
        import numpy as np
        log = StepLog(name="nlm_sharpen")
        t = time.monotonic()

        if not _step_enabled("nlm_sharpen"):
            log.skipped = True
            log.reason = "配置禁用"
            log.elapsed_ms = (time.monotonic() - t) * 1000
            return img, log

        try:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())

            if laplacian_var <= 500:
                # 执行 NLM 去噪（保留文字边缘，不糊化笔画）
                img = cv2.fastNlMeansDenoisingColored(
                    img, None,
                    h=10, hColor=10,
                    templateWindowSize=7,
                    searchWindowSize=21,
                )
                log.reason = f"NLM 去噪完成（拉普拉斯方差 {laplacian_var:.1f}）"
            else:
                log.reason = f"拉普拉斯方差 {laplacian_var:.1f} > 500，图片清晰，跳过去噪"

            # 执行 Unsharp Mask 锐化（强化文字和公式符号边缘）
            blur = cv2.GaussianBlur(img, (0, 0), sigmaX=1.0)
            img = cv2.addWeighted(img, 2.5, blur, -1.5, 0)

        except Exception as e:
            logger.warning("ImagePreprocessor: NLM+锐化失败: %s", e)
            log.reason = str(e)

        log.elapsed_ms = (time.monotonic() - t) * 1000
        return img, log

    # ── 步骤 5：摩尔纹检测与去除 ─────────────────────────────────────────────

    def _step_moire_remove(self, img) -> tuple:
        """步骤 5：傅里叶频域滤波去除摩尔纹（拍屏幕场景）。"""
        import cv2
        import numpy as np
        log = StepLog(name="moire_remove")
        t = time.monotonic()

        if not _step_enabled("moire_remove"):
            log.skipped = True
            log.reason = "配置禁用"
            log.elapsed_ms = (time.monotonic() - t) * 1000
            return img, log

        try:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
            f = np.fft.fft2(gray)
            fshift = np.fft.fftshift(f)
            magnitude = np.abs(fshift)

            # 排除直流分量（中心 20×20 区域），检测高频峰值
            h, w = magnitude.shape
            ac_magnitude = magnitude.copy()
            cy, cx = h // 2, w // 2
            ac_magnitude[cy - 10:cy + 10, cx - 10:cx + 10] = 0

            total_energy = float(np.sum(ac_magnitude))
            if total_energy == 0:
                log.skipped = True
                log.reason = "频谱能量为零"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            # 计算 99 百分位阈值，检测周期性高频峰值
            nonzero = ac_magnitude[ac_magnitude > 0]
            if len(nonzero) == 0:
                log.skipped = True
                log.reason = "无非零频谱分量"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            threshold = float(np.percentile(nonzero, 99))
            peak_energy = float(np.sum(ac_magnitude[ac_magnitude > threshold]))
            peak_ratio = peak_energy / total_energy

            if peak_ratio < 0.05:
                log.skipped = True
                log.reason = f"峰值能量占比 {peak_ratio:.3f} < 5%，无摩尔纹"
                log.elapsed_ms = (time.monotonic() - t) * 1000
                return img, log

            # 构建陷波滤波器，过滤高频峰值（峰值坐标周围 7×7 区域置 0）
            notch_filter = np.ones_like(fshift, dtype=np.float32)
            peak_coords = np.argwhere(ac_magnitude > threshold)
            for y, x in peak_coords:
                y0, y1 = max(0, y - 3), min(h, y + 4)
                x0, x1 = max(0, x - 3), min(w, x + 4)
                notch_filter[y0:y1, x0:x1] = 0

            # 频域滤波后逆变换回空间域
            fshift_filtered = fshift * notch_filter
            f_ishift = np.fft.ifftshift(fshift_filtered)
            img_back = np.fft.ifft2(f_ishift)
            img_back = np.abs(img_back).clip(0, 255).astype(np.uint8)

            # 将处理后的灰度图转回 BGR（保持与后续步骤一致的格式）
            img = cv2.cvtColor(img_back, cv2.COLOR_GRAY2BGR)
            log.reason = f"摩尔纹去除完成（峰值能量占比 {peak_ratio:.3f}）"

        except Exception as e:
            logger.warning("ImagePreprocessor: 摩尔纹去除失败: %s", e)
            log.reason = str(e)

        log.elapsed_ms = (time.monotonic() - t) * 1000
        return img, log
