"""
思维导图服务 v3：基于学科资料生成 markmap 格式的思维导图。

v3 改进：
  1. 两阶段生成：fast 模型提取结构摘要 → heavy 模型生成完整导图
  2. 输出后处理校验：层级修正、节点截断、非标题行过滤
  3. 结构感知：先用 StructureExtractor 提取骨架（规则驱动，零成本）
  4. 丰富信号：TF-IDF 关键句 + 公式密度 + 重要性评分
  5. 降级策略：有骨架用骨架，无骨架降级为采样；fast 不可用退回单次生成
"""

from __future__ import annotations

import logging
import re
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)


class MindMapService:
    """思维导图生成服务。"""

    def __init__(self, user_id: Optional[int] = None) -> None:
        from services.llm_service import LLMService
        self._llm_service = LLMService()
        self._user_id = user_id

    def generate(self, chunks: List[str], subject_name: str) -> str:
        """
        根据文本块列表生成 markmap 格式思维导图（Markdown 标题层级）。

        :param chunks: 文本块列表
        :param subject_name: 学科名称（作为根节点）
        :raises ValueError: chunks 为空时
        :return: markmap Markdown 文本（已校验）
        """
        if not chunks:
            raise ValueError("所选资料暂无可用内容")

        # ── Step 1: 结构提取（规则驱动，零成本）─────────────────────────
        from services.structure_extractor import StructureExtractor
        extractor = StructureExtractor()
        skeleton = extractor.extract(chunks)

        has_skeleton = len(skeleton.headings) >= 2

        if has_skeleton:
            logger.info(
                "MindMap 结构提取完成：%d 个标题，来源分布：%s",
                len(skeleton.headings),
                _count_sources(skeleton.headings),
            )
            context = skeleton.to_llm_context(subject_name)
            # 补充采样，覆盖骨架之外的内容
            sampled_body = _sample_chunks(chunks, max_chunks=20)
            if sampled_body:
                context += f"\n\n【补充资料内容（均匀采样）】\n{sampled_body}"
        else:
            logger.info("MindMap 未检测到文档结构，降级为均匀采样模式")
            context = _sample_chunks(chunks, max_chunks=60)

        # ── Step 2: 尝试两阶段生成 ──────────────────────────────────────
        raw_result = self._try_two_stage_generate(subject_name, context, has_skeleton)

        if raw_result is None:
            # 两阶段失败或 fast 模型不可用，退回单次生成
            logger.info("MindMap 两阶段生成不可用，退回单次生成")
            messages = self._build_messages(subject_name, context, has_skeleton)
            raw_result = self._llm_service.chat(
                messages,
                user_id=self._user_id,
                endpoint="mindmap",
                track_token=True,
            )

        raw_result = raw_result.strip()

        # ── Step 3: 后处理校验 ──────────────────────────────────────────
        result = _post_process_markmap(raw_result, subject_name)

        logger.info("MindMap 生成完成，共 %d 行", len(result.splitlines()))
        return result

    def generate_from_subject(
        self, subject_id: int, doc_id: Optional[int] = None
    ) -> str:
        from database import get_session, Chunk, Subject

        with get_session() as session:
            subject = session.get(Subject, subject_id)
            subject_name = subject.name if subject else f"学科 {subject_id}"
            query = session.query(Chunk).filter(Chunk.subject_id == subject_id)
            if doc_id is not None:
                query = query.filter(Chunk.document_id == doc_id)
            chunk_rows = query.order_by(Chunk.chunk_index).all()
            chunks = [row.content for row in chunk_rows]

        return self.generate(chunks, subject_name)

    # ── 两阶段生成 ────────────────────────────────────────────────────────

    def _try_two_stage_generate(
        self, subject_name: str, context: str, has_skeleton: bool
    ) -> Optional[str]:
        """
        两阶段生成：
        Stage 1 (fast): 从骨架+摘要中提取关键知识点清单（结构化 JSON）
        Stage 2 (heavy): 基于知识点清单 + 原始上下文生成完整 markmap

        如果 fast 模型不可用或 Stage 1 失败，返回 None 表示退回单次生成。
        """
        try:
            from config import get_config
            cfg = get_config()
            fast_model = getattr(cfg, "LLM_FAST_MODEL", "") or ""
            if not fast_model:
                return None
        except Exception:
            return None

        # ── Stage 1: fast 提取知识点清单 ────────────────────────────────
        stage1_prompt = (
            f"学科：{subject_name}\n\n"
            f"{context}\n\n"
            f"请从以上资料中提取所有关键知识点，输出 JSON 格式：\n"
            f'{{"nodes": [{{"heading": "章节标题", "level": 2, "concepts": ["概念1", "概念2"]}}]}}\n'
            f"要求：\n"
            f"- level 取值 2/3/4，对应 ##/###/####\n"
            f"- heading 必须严格使用原文中的标题\n"
            f"- concepts 是该节下的核心知识点（2-5个），不超过15字\n"
            f"- 标注性质：⭐重点 ⚠️难点 🎯考点 📌基础\n"
            f"- 只输出 JSON，不要代码块标记"
        )

        try:
            stage1_result = self._llm_service.chat(
                [{"role": "user", "content": stage1_prompt}],
                user_id=self._user_id,
                endpoint="mindmap",
                track_token=True,
                model=fast_model,
                max_tokens=1024,
                temperature=0.1,
            )
        except Exception as e:
            logger.warning("Stage 1 fast 模型调用失败: %s", e)
            return None

        # 解析 Stage 1 JSON
        knowledge_nodes = _parse_knowledge_json(stage1_result)
        if not knowledge_nodes:
            logger.warning("Stage 1 JSON 解析失败，退回单次生成")
            return None

        logger.info("Stage 1 提取了 %d 个知识节点", len(knowledge_nodes))

        # ── Stage 2: heavy 生成完整 markmap ────────────────────────────
        stage2_context = _build_stage2_context(subject_name, knowledge_nodes, context)
        messages = self._build_messages(subject_name, stage2_context, has_skeleton=True)

        try:
            return self._llm_service.chat(
                messages,
                user_id=self._user_id,
                endpoint="mindmap",
                track_token=True,
            )
        except Exception as e:
            logger.warning("Stage 2 生成失败: %s", e)
            return None

    # ── 构建 LLM 消息 ────────────────────────────────────────────────────

    def _build_messages(
        self, subject_name: str, context: str, has_skeleton: bool
    ) -> list[dict]:
        """构建发给 LLM 的消息列表。"""
        # 尝试从 SkillRegistry 取 prompt 模板
        try:
            from skill_registry import get_registry
            node = get_registry().get_node("skill_mindmap_learning", "node_mindmap")
            node_prompt = node["prompt"] if node else None
        except Exception:
            node_prompt = None

        system_msg = (
            "你是一个专业的知识结构分析助手。"
            "请严格按照用户指令的格式要求输出，只输出 Markdown 内容，不要代码块标记或说明文字。"
        )

        if node_prompt:
            user_content = (
                node_prompt.replace("{topic}", subject_name).replace("{structure}", "")
                + f"\n\n{'文档骨架已提取，请以此为基础生成思维导图：' if has_skeleton else '请基于以下学习资料生成思维导图：'}\n{context}"
            )
        elif has_skeleton:
            # 有骨架时的专用 prompt（更精准，含信号）
            user_content = (
                f"学科名称：{subject_name}\n\n"
                f"以下是已从学习资料中提取的文档结构骨架、各节关键内容和重要性信号。\n"
                f"请以此骨架为框架，生成完整的 markmap 格式思维导图。\n\n"
                f"输出要求：\n"
                f"1. 使用 Markdown 标题语法（# ## ### ####）表示层级，最多四级\n"
                f"2. 第一行 # 为根节点，内容为「{subject_name}」\n"
                f"3. 严格遵循骨架中的章节结构，不要遗漏任何标题\n"
                f"4. 在各章节下展开 2-5 个核心知识点（### / ####）\n"
                f"5. 用 ⭐ 重点  ⚠️ 难点/易错  🎯 考点  📌 基础 标注性质\n"
                f"6. 利用重要性信号：[公式密集]的章节应展开更多公式相关节点，[含核心定义]的章节应标注定义\n"
                f"7. 每个节点简洁，不超过 15 个字\n"
                f"8. 只输出 Markdown，不要代码块标记或说明文字\n\n"
                f"{context}"
            )
        else:
            # 无骨架时：旧逻辑的降级 prompt
            user_content = (
                f"学科名称：{subject_name}\n\n"
                f"学习资料内容（已均匀采样覆盖全书）：\n{context}"
            )
            system_msg = (
                "你是一个专业的知识结构分析助手。请分析以下学习资料的全部内容，"
                "提炼所有章节的核心知识点，以 Markdown 标题层级格式输出完整思维导图（markmap 格式）。\n\n"
                "输出要求：\n"
                "1. 使用 Markdown 标题语法（# ## ### ####）表示层级\n"
                "2. 第一行用 # 作为根节点，内容为学科名称\n"
                "3. 二级节点（##）对应每个章节，必须覆盖资料中出现的所有章节\n"
                "4. 三级节点（###）对应章节内的核心概念，用 ⭐ ⚠️ 🎯 📌 标注性质\n"
                "5. 四级节点（####）对应具体知识点，最多四级\n"
                "6. 每个节点简洁，不超过 15 个字\n"
                "7. 只输出 Markdown 内容，不要有任何代码块标记或说明文字"
            )

        return [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_content},
        ]


# ── 后处理校验 ──────────────────────────────────────────────────────────────

# Markdown 标题行正则
_RE_HEADING_LINE = re.compile(r"^(#{1,6})\s+(.+)$")

# emoji 标记前缀（允许在标题中出现）
_RE_EMOJI_PREFIX = re.compile(
    r"^[\u2b50\u26a0\ufe0f\ud83c\udfaf\ud83d\udccc\u2192\u27a1\ufe0f\u2714\ufe0f]\s*"
)

# 非内容行（LLM 有时输出的废话）
_RE_NOISE_LINE = re.compile(
    r"^(?:以下是|这是|以上|好了|总结|备注|注意|提示|说明|注)"
    r"|(?:Here|Below|Above|Note|Summary|Conclusion)"
    r"|(?:```|---|\*\*\*)"
)


def _post_process_markmap(raw: str, subject_name: str) -> str:
    """
    对 LLM 输出的 markmap 进行后处理校验。

    1. 去除代码块包裹
    2. 过滤噪音行（说明文字、非标题行）
    3. 修正层级跳跃（#### 不能出现在 ## 之前）
    4. 截断过长节点（>20字）
    5. 确保第一行是 # 根节点
    6. 去除重复标题
    """
    # 去除代码块包裹
    text = raw.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        # 去掉首行 ```markdown 和末行 ```
        start = 1
        end = len(lines)
        if lines[-1].strip() == "```":
            end -= 1
        text = "\n".join(lines[start:end]).strip()

    lines = text.splitlines()
    processed: list[str] = []
    last_level = 0
    seen_titles: set[str] = set()
    has_root = False

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        # 清理嵌套标题标记（如 "#### #### text" → "#### text"）
        stripped = re.sub(r'^(#+)\s+(#+\s+)', r'\1 ', stripped)

        # 检查是否是标题行
        m = _RE_HEADING_LINE.match(stripped)
        if not m:
            # 非标题行：跳过（LLM 常输出的说明文字、空行等）
            # 但保留可能的简短知识点（纯文本，≤15字，不含标点结尾）
            if (len(stripped) <= 15
                    and not _RE_NOISE_LINE.match(stripped)
                    and stripped[-1] not in "。？！.?!;;"
                    and not re.match(r'^[\s\-\*\#\`\|]+$', stripped)  # 纯符号行
                    and not stripped.startswith('```')):  # 代码块残留

                if last_level >= 4:
                    processed.append(f"#### {stripped}")
                elif last_level >= 2:
                    next_level = min(last_level + 1, 4)
                    processed.append(f"{'#' * next_level} {stripped}")
                    last_level = next_level
            continue

        hashes = m.group(1)
        text = m.group(2).strip()
        level = len(hashes)

        # 去除噪音前缀
        text = re.sub(r"^(?:以下是|这是|以上|好了)[：:]?\s*", "", text).strip()
        if not text:
            continue

        # 去除 emoji 标记前缀（保留用于重排）
        has_emoji = bool(_RE_EMOJI_PREFIX.match(text))
        emoji_match = _RE_EMOJI_PREFIX.match(text)
        emoji_prefix = emoji_match.group(0) if has_emoji else ""
        clean_text = text
        if has_emoji:
            clean_text = _RE_EMOJI_PREFIX.sub("", text).strip()

        # 截断过长节点
        if len(clean_text) > 20:
            clean_text = clean_text[:18] + "..."
        text = emoji_prefix + clean_text

        if not text or text == emoji_prefix:
            continue

        # 层级修正：不允许跳跃超过 1 级
        if last_level > 0 and level > last_level + 1:
            level = last_level + 1
        level = min(level, 4)
        level = max(level, 1)

        # 确保根节点
        if not has_root:
            level = 1
            has_root = True
            # 如果根节点文本不含学科名，强制设置
            if subject_name not in text and subject_name not in stripped:
                text = subject_name

        # 去除连续重复标题
        key = f"L{level}:{text}"
        if key in seen_titles:
            continue
        seen_titles.add(key)

        processed.append(f"{'#' * level} {text}")
        last_level = level

    # 如果完全没有有效行，返回一个基本结构
    if not processed:
        return f"# {subject_name}\n\n## 知识点\n\n### 待整理\n"

    return "\n".join(processed)


# ── 两阶段辅助函数 ──────────────────────────────────────────────────────────

def _parse_knowledge_json(raw: str) -> List[dict]:
    """
    解析 Stage 1 输出的 JSON。
    容错：允许被 ```json 包裹、允许尾部有逗号。
    """
    import json

    text = raw.strip()
    # 去除代码块
    if text.startswith("```"):
        lines = text.splitlines()
        start = 1
        end = len(lines)
        if lines[-1].strip() == "```":
            end -= 1
        text = "\n".join(lines[start:end]).strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        # 尝试修复尾部逗号
        text = re.sub(r',\s*([}\]])', r'\1', text)
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            return []

    nodes = data.get("nodes") or []
    if not isinstance(nodes, list):
        return []

    # 过滤无效节点
    valid = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        heading = node.get("heading", "")
        concepts = node.get("concepts") or []
        if heading and isinstance(concepts, list):
            valid.append(node)

    return valid


def _build_stage2_context(
    subject_name: str,
    knowledge_nodes: List[dict],
    original_context: str,
) -> str:
    """
    构建 Stage 2 的上下文：将 Stage 1 的知识点清单与原始上下文合并。

    知识点清单在前（结构清晰），原始内容在后（补充细节）。
    """
    parts: list[str] = []

    parts.append(f"学科：{subject_name}")
    parts.append("\n【AI 提取的知识结构（请严格遵循）】")

    for node in knowledge_nodes:
        heading = node.get("heading", "")
        level = node.get("level", 2)
        concepts = node.get("concepts") or []
        prefix = "#" * min(level, 4)
        parts.append(f"{prefix} {heading}")
        for c in concepts:
            if c:
                parts.append(f"{'#' * min(level + 1, 4)} {c}")

    # 截断原始上下文避免太长
    if original_context and len(original_context) > 3000:
        original_context = original_context[:3000] + "\n...（内容已截断）"

    if original_context:
        parts.append(f"\n【原始资料内容（供补充细节）】\n{original_context}")

    return "\n".join(parts)


# ── 通用辅助函数 ────────────────────────────────────────────────────────────


def _sample_chunks(chunks: List[str], max_chunks: int = 60) -> str:
    """均匀采样 chunks，返回拼接后的文本。"""
    if len(chunks) <= max_chunks:
        return "\n\n".join(chunks)

    indices = [round(i * (len(chunks) - 1) / (max_chunks - 1)) for i in range(max_chunks)]
    indices = sorted(set(indices))
    return "\n\n".join(chunks[i] for i in indices)


def _count_sources(headings: list) -> str:
    """统计标题来源分布。"""
    from collections import Counter
    counts = Counter(h.source_type for h in headings)
    return ", ".join(f"{k}={v}" for k, v in counts.items())
