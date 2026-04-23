"""
LectureGeneratorService — 为思维导图节点生成讲义内容并保存到数据库。
"""
from __future__ import annotations

import re
from typing import Generator, Optional

from backend_config import get_config


def _markdown_to_blocks(markdown: str) -> list[dict]:
    """将 Markdown 文本转换为 LectureBlock 格式的 dict 列表。"""
    blocks = []
    lines = markdown.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        # 代码块
        if line.startswith("```"):
            lang = line[3:].strip()
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            blocks.append({"type": "code", "text": "\n".join(code_lines), "language": lang or None})
        # 块级公式 \[...\] 或 $$...$$
        elif line.strip().startswith(r"\[") or line.strip().startswith("$$"):
            delimiter_end = r"\]" if line.strip().startswith(r"\[") else "$$"
            formula_lines = [line.strip().lstrip(r"\[").lstrip("$$")]
            i += 1
            while i < len(lines):
                l = lines[i]
                if delimiter_end in l:
                    formula_lines.append(l.replace(delimiter_end, "").strip())
                    i += 1
                    break
                formula_lines.append(l)
                i += 1
            formula = "\n".join(formula_lines).strip()
            if formula:
                blocks.append({"type": "formula", "text": formula})
            continue
        # 标题
        elif m := re.match(r"^(#{1,4})\s+(.*)", line):
            level = len(m.group(1))
            blocks.append({"type": "heading", "text": m.group(2).strip(), "level": level})
        # 引用
        elif line.startswith("> "):
            blocks.append({"type": "quote", "text": line[2:].strip()})
        # 列表
        elif re.match(r"^[-*+]\s+", line):
            blocks.append({"type": "list", "text": re.sub(r"^[-*+]\s+", "", line).strip()})
        elif re.match(r"^\d+\.\s+", line):
            blocks.append({"type": "list", "text": re.sub(r"^\d+\.\s+", "", line).strip()})
        # 空行跳过
        elif line.strip() == "":
            pass
        # 普通段落
        else:
            blocks.append({"type": "paragraph", "text": line.strip()})
        i += 1
    return blocks


def _retrieve_context(node_title: str, subject_id: int, top_k: int, threshold: float) -> str:
    """用 PGVector 检索与节点标题相关的文档片段，返回拼接后的上下文字符串。"""
    try:
        from services.rag_pipeline import RAGPipeline
        pipeline = RAGPipeline()
        vector_store = pipeline.get_vector_store(subject_id)
        docs_with_scores = vector_store.similarity_search_with_score(node_title, k=top_k)
        chunks = [
            doc.page_content
            for doc, score in docs_with_scores
            if score <= threshold
        ]
        return "\n\n".join(chunks)
    except Exception:
        # 检索失败时降级为无上下文生成
        return ""


class LectureGeneratorService:
    def __init__(self):
        self._cfg = get_config()

    def generate(
        self,
        node_id: str,
        node_title: str,
        subject_id: int,
        session_id: int,
        user_id: int,
        resource_scope: Optional[dict] = None,
    ) -> dict:
        """同步生成节点讲义，保存到数据库，返回 {"id": lecture_id}。"""
        from services.llm_service import LLMService
        from database import NodeLecture, get_session as db_session

        cfg = self._cfg
        context = _retrieve_context(
            node_title, subject_id,
            top_k=cfg.TOP_K,
            threshold=cfg.SIMILARITY_THRESHOLD,
        )
        prompt = self._build_prompt(node_title, context)
        content_text = LLMService().chat(
            messages=[{"role": "user", "content": prompt}],
            temperature=cfg.LLM_LECTURE_TEMPERATURE,
            max_tokens=cfg.LLM_LECTURE_MAX_TOKENS,
            heavy=True,
        )
        blocks = _markdown_to_blocks(content_text)
        content = {"blocks": blocks}
        with db_session() as db:
            existing = (
                db.query(NodeLecture)
                .filter_by(user_id=user_id, session_id=session_id, node_id=node_id)
                .first()
            )
            if existing:
                existing.content = content
                db.flush()
                lecture_id = existing.id
            else:
                lecture = NodeLecture(
                    user_id=user_id,
                    session_id=session_id,
                    node_id=node_id,
                    content=content,
                    resource_scope=resource_scope,
                )
                db.add(lecture)
                db.flush()
                lecture_id = lecture.id
        return {"id": lecture_id}

    def generate_stream(
        self,
        node_id: str,
        node_title: str,
        subject_id: int,
        session_id: int,
        resource_scope: Optional[dict] = None,
    ) -> Generator[str, None, None]:
        """流式生成节点讲义（只 yield token，保存由调用方负责）。"""
        from services.llm_service import LLMService

        cfg = self._cfg
        context = _retrieve_context(
            node_title, subject_id,
            top_k=cfg.TOP_K,
            threshold=cfg.SIMILARITY_THRESHOLD,
        )
        prompt = self._build_prompt(node_title, context)

        yield from LLMService().chat_stream(
            messages=[{"role": "user", "content": prompt}],
            temperature=cfg.LLM_LECTURE_TEMPERATURE,
            max_tokens=cfg.LLM_LECTURE_MAX_TOKENS,
            heavy=True,
        )

    def save_stream_result(
        self,
        full_markdown: str,
        node_id: str,
        session_id: int,
        user_id: int,
        resource_scope: Optional[dict] = None,
    ) -> int:
        """将流式生成的完整 markdown 保存到数据库，返回 lecture_id。"""
        from database import NodeLecture, get_session as db_session

        blocks = _markdown_to_blocks(full_markdown)
        content = {"blocks": blocks}
        with db_session() as db:
            existing = (
                db.query(NodeLecture)
                .filter_by(user_id=user_id, session_id=session_id, node_id=node_id)
                .first()
            )
            if existing:
                existing.content = content
                db.flush()
                return existing.id
            else:
                lecture = NodeLecture(
                    user_id=user_id,
                    session_id=session_id,
                    node_id=node_id,
                    content=content,
                    resource_scope=resource_scope,
                )
                db.add(lecture)
                db.flush()
                return lecture.id

    def _build_prompt(self, node_title: str, context: str, node_depth: int = 4) -> str:
        """
        根据节点层级生成对应深度的讲义 prompt。
        node_depth: 1=根/全书概览, 2=部分/模块, 3=章, 4=节/知识点(默认), 5=细节要点
        """
        # 根据层级决定讲义风格和字数目标
        depth_config = {
            1: ("全书概览", "800-1200字", "全书框架、章节关系、学习路线"),
            2: ("模块导览", "600-1000字", "本部分核心问题、章节递进逻辑"),
            3: ("章节讲义", "1500-2500字", "概念引入→核心内容→例题→总结"),
            4: ("知识点讲义", "800-1500字", "定义→推导→公式→应用→注意事项"),
            5: ("要点卡片", "300-600字", "核心结论→记忆口诀→常见错误"),
        }
        style, word_count, focus = depth_config.get(node_depth, depth_config[4])

        base = (
            f"你是一位专业的教学助手，擅长用生动易懂的方式讲解知识点。\n"
            f"请为知识点「{node_title}」生成一份{style}（目标字数：{word_count}）。\n\n"
            f"讲义重点：{focus}\n\n"
            "## 讲义六大要求\n\n"
            "### 1. 小白友好叙事（必须）\n"
            "在正式定义之前，先回答三个问题：\n"
            "- **为什么要学这个？** 用生活场景或工程问题引入，让读者感到「这个问题值得解决」\n"
            "- **这个概念从哪来的？** 2-3句话说明历史背景或提出动机\n"
            "- **学了能干啥？** 一句话说明掌握后的实际能力\n\n"
            "### 2. 类比先行（必须）\n"
            "每个核心概念先给一个日常生活类比建立直觉，再给精确定义。\n"
            "格式：> 🌊 **类比**：{类比内容}\\n> 但严格来说，{精确区别}\n\n"
            "### 3. 前后文衔接（必须）\n"
            "- 开头：「在上一个知识点...中，我们学会了...。但...还不够——...就是要回答的问题。」\n"
            "- 结尾：「现在我们知道了...。但...还不够——下一步...将回答这个问题。」\n\n"
            "### 4. 公式与推导（如有）\n"
            "- 行内公式用 $...$，块级公式用 $$...$$\n"
            "- 每步推导附一句「这一步在干什么」的人话解释\n"
            "- 列出各符号含义和适用条件\n\n"
            "### 5. 注意事项（必须）\n"
            "列出 2-3 个最常见的错误或易混淆点，格式：⚠️ {错误描述}\n\n"
            "### 6. 推荐继续探索（必须）\n"
            "讲义末尾用表格列出 2-3 个推荐节点：\n"
            "| 方向 | 节点 | 为什么推荐 |\n"
            "|-----|------|----------|\n"
            "| 📌 深入 | {子节点} | {理由} |\n"
            "| 🔗 关联 | {关联节点} | {关联类型} |\n\n"
            "## 输出格式\n\n"
            "使用 Markdown，结构如下：\n"
            f"# 💡 {node_title}\n\n"
            "## 🎯 为什么要学这个\n"
            "## 🌊 直觉类比\n"
            "## 定义\n"
            "## 核心原理 / 推导\n"
            "## 典型例题（如有）\n"
            "## ⚠️ 注意事项\n"
            "## 本节小结\n"
            "## 💡 推荐继续探索\n\n"
        )
        if context:
            base += f"## 参考资料\n\n{context}\n\n"
        base += f"请生成「{node_title}」的讲义（严格按照上述六大要求和输出格式）："
        return base
