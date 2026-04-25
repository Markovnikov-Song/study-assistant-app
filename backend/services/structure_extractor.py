"""
结构提取器 v2：从纯文本 chunks 中提取文档骨架（标题层级树）。

设计目标：
  - 不修改现有 Chunk 表结构和 RAG 链路，纯计算层
  - 兼容 PDF/Word/PPT/TXT/MD 所有格式的解析输出
  - 规则优先，零 LLM 调用，速度快、成本为零
  - 输出结构化骨架 + 关键句摘要 + 重要性信号供 MindMapService 使用

v2 新增：
  - 英文论文编号：1. Introduction / 2.1 Related Work
  - TF-IDF 关键句提取替代简单前 N 行
  - 每节公式密度 / 关键词频率信号
  - 结构重要性评分（章节篇幅 + 公式密度）
"""

from __future__ import annotations

import math
import re
import logging
from collections import Counter
from dataclasses import dataclass, field
from typing import List, Optional, Tuple, Dict

logger = logging.getLogger(__name__)


@dataclass
class Heading:
    """提取出的标题节点。"""
    level: int           # 层级深度（1=根，递增）
    text: str            # 标题文本
    line_no: int         # 在拼接文本中的行号
    source_type: str     # 来源类型
    importance: float = 0.0  # 重要性评分 0~1（篇幅+公式密度）

    def __repr__(self) -> str:
        return f"Heading(L{self.level}: {self.text!r}, imp={self.importance:.2f})"


@dataclass
class SectionInsight:
    """每个章节的内容洞察。"""
    key_sentences: List[str] = field(default_factory=list)  # TF-IDF 关键句
    formula_count: int = 0        # 公式数量
    content_lines: int = 0        # 内容行数（衡量篇幅）
    keyword_freq: Dict[str, int] = field(default_factory=dict)  # 高频关键词
    has_example: bool = False     # 是否包含例题/例子
    has_definition: bool = False  # 是否包含定义

    @property
    def formula_density(self) -> float:
        """每 10 行内容的公式数。"""
        return self.formula_count / max(self.content_lines / 10, 1)

    @property
    def importance_score(self) -> float:
        """综合重要性评分 0~1。"""
        # 篇幅因子（对数缩放）
        length_score = min(math.log2(max(self.content_lines, 1)) / 8, 1.0)
        # 公式密度因子
        formula_score = min(self.formula_density / 5, 1.0)
        # 定义/例题加分
        bonus = 0.1 * int(self.has_definition) + 0.05 * int(self.has_example)
        return min(length_score * 0.4 + formula_score * 0.4 + bonus, 1.0)


@dataclass
class OutlineSkeleton:
    """文档骨架：标题树 + 每个标题下的内容洞察。"""
    headings: List[Heading] = field(default_factory=list)
    sections: dict[str, SectionInsight] = field(default_factory=dict)

    def to_markdown_outline(self) -> str:
        """将骨架转为 Markdown 格式的层级大纲（含重要性标记）。"""
        if not self.headings:
            return ""
        lines: list[str] = []
        for h in self.headings:
            prefix = "#" * min(h.level, 4)
            # 重要性标记
            if h.importance >= 0.7:
                tag = " [重要]"
            elif h.importance >= 0.4:
                tag = ""
            else:
                tag = ""
            lines.append(f"{prefix} {h.text}{tag}")
        return "\n".join(lines)

    def to_llm_context(self, subject_name: str, max_section_chars: int = 300) -> str:
        """
        构建给 LLM 的上下文：骨架大纲 + 各节关键句摘要 + 重要性信号。

        输出格式经过优化，让 LLM 能精确判断每个章节的核心知识点和重要性。
        """
        parts: list[str] = []
        outline = self.to_markdown_outline()
        if outline:
            parts.append(f"【文档骨架（已标注重要性）】\n{outline}")

        # 各节关键句摘要 + 信号
        summary_parts: list[str] = []
        for h in self.headings:
            insight = self.sections.get(h.text)
            if not insight or not insight.key_sentences:
                continue

            # 关键句
            sentences_text = " | ".join(insight.key_sentences[:4])
            if len(sentences_text) > max_section_chars:
                sentences_text = sentences_text[:max_section_chars] + "..."

            # 信号标签
            signals: list[str] = []
            if insight.formula_density >= 3:
                signals.append(f"公式密集({insight.formula_count}个)")
            if insight.has_definition:
                signals.append("含核心定义")
            if insight.has_example:
                signals.append("含例题")
            if insight.keyword_freq:
                top_kw = sorted(insight.keyword_freq.items(), key=lambda x: -x[1])[:3]
                signals.append("高频词:" + ",".join(k for k, _ in top_kw))

            signal_str = f" [{'; '.join(signals)}]" if signals else ""
            summary_parts.append(f"  - {h.text}：{sentences_text}{signal_str}")

        if summary_parts:
            parts.append("\n【各节关键内容与重要性信号】\n" + "\n".join(summary_parts))

        return "\n".join(parts)


# ── 正则预编译 ──────────────────────────────────────────────────────────────

# Markdown 标题
_RE_MD_HEADING = re.compile(r"^(#{1,6})\s+(.+)$")

# 中文编号：第X章/节/部分/篇/编/单元/讲/课
_RE_CN_CHAPTER = re.compile(
    r"^(第[一二三四五六七八九十百零\d]+[章节部分篇编单元讲课])\s*(.*)"
)

# 数字编号：1. / 1.1 / 1.1.1 / 1) / (1) 等
_RE_DIGIT_NUMBER = re.compile(
    r"^(\d+(?:\.\d+){0,3})[\.\)、\s]+(.+)$"
)

# 英文论文编号：1. Introduction / 2.1 Related Work / 3.2.1 Experimental Setup
_RE_EN_PAPER = re.compile(
    r"^(\d+(?:\.\d+)*)\s+([A-Z][A-Za-z\s\-:]{2,60})$"
)

# 中文数字编号：一、二、三、/ （一）/ Ⅰ、Ⅱ、
_RE_CN_NUMBER = re.compile(
    r"^([（(]?(?:[一二三四五六七八九十]+|Ⅰ+|Ⅱ+|Ⅲ+|Ⅳ+|Ⅴ+|Ⅵ+|Ⅶ+|Ⅷ+|Ⅸ+|Ⅹ+)[)）、]?)\s*(.+)$"
)

# 短行启发式标题的排除模式
_RE_EXCLUDE = re.compile(
    r"^[\s\d\-\*\.\+\=\|#\"\"''``$@]{0,5}$"   # 纯符号/空行
    r"|^(?:图|表|式|附图|附表|注|解|答|例)\s*[\d\.]"  # 图表公式编号
    r"|(?:http|www\.|ftp)"                         # URL
    r"|(?:Copyright|©|版权)"                       # 版权信息
    r"|(?:Page|页)\s*\d"                           # 页码
    r"|^\d{1,2}[\/\-\.]"                           # 日期开头
    r"|^(?:Abstract|Keywords?|References?|Bibliography|Acknowledgement|Appendix|Table of Contents)\s*$"  # 英文论文固定节
)

# 公式检测（LaTeX 或纯数学表达式）
_RE_FORMULA = re.compile(
    r"\$\$.+?\$\$"                      # LaTeX 块级公式
    r"|\$.+?\$"                          # LaTeX 行内公式
    r"|[=≠≤≥±±×÷∑∏∫∂√∞≈≈∈∉⊂⊃∪∩∧∨]"  # 数学符号
    r"|\\(?:frac|sum|prod|int|sqrt|alpha|beta|gamma|sigma|omega|theta|lambda|pi|Delta|nabla)"  # LaTeX 命令
)

# 定义/概念检测
_RE_DEFINITION = re.compile(
    r"(?:定义|概念|定理|公理|法则|原理|定律|推论|引理|命题|性质)"
    r"|(?:definition|theorem|axiom|lemma|proposition|corollary|property)"
)

# 例题/例子检测
_RE_EXAMPLE = re.compile(
    r"(?:例题|例\s*\d|例如|比如|举例|练习题|思考题|习题)"
    r"|(?:example|instance|exercise|problem|illustrat)"
)


class StructureExtractor:
    """从纯文本 chunks 中提取文档结构骨架。"""

    def __init__(
        self,
        max_heading_length: int = 60,
        heuristic_min_length: int = 2,
        heuristic_max_length: int = 40,
        heuristic_surrounding_lines: int = 3,
    ) -> None:
        self._max_heading_length = max_heading_length
        self._heuristic_min = heuristic_min_length
        self._heuristic_max = heuristic_max_length
        self._heuristic_ctx = heuristic_surrounding_lines

    def extract(self, chunks: List[str]) -> OutlineSkeleton:
        """
        从 chunks 列表中提取文档骨架。

        :param chunks: 文本块列表（通常来自 Chunk 表）
        :return: OutlineSkeleton
        """
        if not chunks:
            return OutlineSkeleton()

        # 1. 拼接所有 chunks 为完整文本
        full_text = "\n\n".join(chunks)
        lines = full_text.splitlines()

        # 2. 第一遍：用规则识别所有标题行
        raw_headings = self._extract_headings(lines)

        # 3. 第二遍：去重合并
        headings = self._deduplicate_headings(raw_headings)

        # 4. 第三遍：启发式补充（短行标题，适用于 PPT/扫描版 PDF）
        headings = self._heuristic_pass(lines, headings)

        # 5. 构建层级关系
        headings = self._assign_levels(headings)

        # 6. 提取各节内容洞察（关键句 + 信号）
        sections = self._extract_section_insights(lines, headings)

        # 7. 计算标题重要性评分
        headings = self._compute_heading_importance(headings, sections)

        return OutlineSkeleton(headings=headings, sections=sections)

    # ── 第一步：规则提取 ─────────────────────────────────────────────────

    def _extract_headings(self, lines: list[str]) -> List[Heading]:
        """用正则规则识别标题行。"""
        results: List[Heading] = []
        used_lines: set[int] = set()

        for line_no, line in enumerate(lines):
            stripped = line.strip()
            if not stripped or len(stripped) > self._max_heading_length:
                continue
            if line_no in used_lines:
                continue

            heading: Optional[Heading] = None

            # Markdown 标题（最高优先级）
            m = _RE_MD_HEADING.match(stripped)
            if m:
                level = len(m.group(1))
                text = m.group(2).strip()
                if text:
                    heading = Heading(level=level, text=text, line_no=line_no,
                                      source_type="md_heading")

            # 中文编号：第X章/节
            if not heading:
                m = _RE_CN_CHAPTER.match(stripped)
                if m:
                    prefix = m.group(1)
                    text = (m.group(2) or "").strip()
                    if text:
                        level = 2 if "章" in prefix or "篇" in prefix or "编" in prefix else 3
                        heading = Heading(level=level, text=f"{prefix} {text}",
                                          line_no=line_no,
                                          source_type="cn_chapter" if level == 2 else "cn_section")

            # 英文论文编号：1. Introduction / 2.1 Related Work
            if not heading:
                m = _RE_EN_PAPER.match(stripped)
                if m:
                    number = m.group(1)
                    text = m.group(2).strip()
                    if text:
                        dots = number.count(".")
                        level = dots + 2
                        level = max(2, min(level, 4))
                        heading = Heading(level=level, text=f"{number} {text}",
                                          line_no=line_no, source_type="en_paper")

            # 数字编号：1.1.1 xxx
            if not heading:
                m = _RE_DIGIT_NUMBER.match(stripped)
                if m:
                    number = m.group(1)
                    text = m.group(2).strip()
                    if text:
                        dots = number.count(".")
                        level = dots + 2
                        level = max(2, min(level, 4))
                        heading = Heading(level=level, text=f"{number} {text}",
                                          line_no=line_no, source_type="digit_number")

            # 中文数字编号：一、xxx
            if not heading:
                m = _RE_CN_NUMBER.match(stripped)
                if m:
                    number = m.group(1)
                    text = (m.group(2) or "").strip()
                    if text:
                        level = 3
                        heading = Heading(level=level, text=f"{number} {text}",
                                          line_no=line_no, source_type="cn_number")

            if heading:
                results.append(heading)
                used_lines.add(line_no)

        return results

    # ── 第二步：去重合并 ─────────────────────────────────────────────────

    def _deduplicate_headings(self, headings: List[Heading]) -> List[Heading]:
        """合并连续出现的重复/语义重复标题。"""
        if not headings:
            return headings

        deduped: List[Heading] = [headings[0]]
        for h in headings[1:]:
            prev = deduped[-1]
            if h.text == prev.text and (h.line_no - prev.line_no) <= 2:
                continue
            if prev.text in h.text and (h.line_no - prev.line_no) <= 3:
                deduped[-1] = h
                continue
            deduped.append(h)
        return deduped

    # ── 第三步：启发式补充 ───────────────────────────────────────────────

    def _heuristic_pass(
        self, lines: list[str], existing: List[Heading]
    ) -> List[Heading]:
        """启发式补充：识别未被规则捕获的短行标题。"""
        used_lines = {h.line_no for h in existing}
        new_headings: List[Heading] = []

        for line_no, line in enumerate(lines):
            if line_no in used_lines:
                continue

            stripped = line.strip()
            length = len(stripped)

            if length < self._heuristic_min or length > self._heuristic_max:
                continue

            if _RE_EXCLUDE.match(stripped):
                continue

            if stripped[-1] in "。？！.?!；;,，、：:":
                continue

            alpha_ratio = sum(1 for c in stripped if c.isalnum() or '\u4e00' <= c <= '\u9fff') / max(length, 1)
            if alpha_ratio < 0.5:
                continue

            ctx_before = lines[max(0, line_no - self._heuristic_ctx):line_no]
            ctx_after = lines[line_no + 1:line_no + 1 + self._heuristic_ctx]

            has_empty_before = any(l.strip() == "" for l in ctx_before)
            has_empty_after = any(l.strip() == "" for l in ctx_after)

            if not has_empty_before and not has_empty_after:
                all_long = all(len(l.strip()) > 50 for l in ctx_before + ctx_after if l.strip())
                if not all_long:
                    continue

            new_headings.append(Heading(
                level=0,
                text=stripped,
                line_no=line_no,
                source_type="heuristic",
            ))
            used_lines.add(line_no)

        combined = existing + new_headings
        combined.sort(key=lambda h: h.line_no)
        return combined

    # ── 第四步：层级分配 ─────────────────────────────────────────────────

    def _assign_levels(self, headings: List[Heading]) -> List[Heading]:
        """统一分配层级深度。"""
        if not headings:
            return headings

        ruled = [h for h in headings if h.level > 0]

        for h in headings:
            if h.level > 0:
                continue

            closest_before = None
            closest_after = None

            for r in ruled:
                if r.line_no < h.line_no:
                    if closest_before is None or r.line_no > closest_before.line_no:
                        closest_before = r
                elif r.line_no > h.line_no:
                    if closest_after is None or r.line_no < closest_after.line_no:
                        closest_after = r

            if closest_before:
                h.level = min(closest_before.level + 1, 4)
            elif closest_after:
                h.level = max(closest_after.level - 1, 2)
            else:
                h.level = 2

        return headings

    # ── 第五步：内容洞察提取（v2 核心升级）──────────────────────────────

    def _extract_section_insights(
        self, lines: list[str], headings: List[Heading]
    ) -> dict[str, SectionInsight]:
        """
        提取每个章节的内容洞察：
        - TF-IDF 关键句（替代简单前 N 行）
        - 公式密度
        - 高频关键词
        - 是否含定义/例题
        """
        sections: dict[str, SectionInsight] = {}
        if not headings:
            return sections

        heading_lines = {h.line_no for h in headings}

        # 全局词频统计（用于 IDF 计算）
        global_word_freq: Counter = Counter()
        doc_freq: Counter = Counter()  # 每个词出现在多少个"行"中
        all_content_lines: list[list[str]] = []  # 按 section 分组

        for i, heading in enumerate(headings):
            start = heading.line_no + 1
            end = headings[i + 1].line_no if i + 1 < len(headings) else len(lines)

            content: list[str] = []
            for j in range(start, end):
                if j in heading_lines:
                    continue
                stripped = lines[j].strip()
                if stripped and len(stripped) > 3:
                    content.append(stripped)

            all_content_lines.append(content)
            for line in content:
                words = self._tokenize(line)
                word_set = set(words)
                global_word_freq.update(words)
                doc_freq.update(word_set)

        # 计算 IDF
        total_lines = sum(len(c) for c in all_content_lines)
        idf: Dict[str, float] = {}
        for word, df in doc_freq.items():
            idf[word] = math.log((total_lines + 1) / (df + 1)) + 1

        # 对每个 section 提取关键句
        for idx, heading in enumerate(headings):
            content = all_content_lines[idx]
            if not content:
                sections[heading.text] = SectionInsight()
                continue

            insight = SectionInsight()
            insight.content_lines = len(content)

            # 公式计数
            for line in content:
                insight.formula_count += len(_RE_FORMULA.findall(line))

            # 定义/例题检测
            for line in content:
                if _RE_DEFINITION.search(line):
                    insight.has_definition = True
                if _RE_EXAMPLE.search(line):
                    insight.has_example = True

            # TF-IDF 关键句提取
            insight.key_sentences = self._extract_key_sentences(content, global_word_freq, idf)

            # 高频关键词（取该节内 TF 最高的词）
            section_word_freq: Counter = Counter()
            for line in content:
                section_word_freq.update(self._tokenize(line))
            # 排除停用词
            stop_words = self._get_stop_words()
            for sw in stop_words:
                section_word_freq.pop(sw, None)
            insight.keyword_freq = dict(section_word_freq.most_common(5))

            sections[heading.text] = insight

        return sections

    def _extract_key_sentences(
        self,
        lines: list[str],
        global_freq: Counter,
        idf: Dict[str, float],
        top_n: int = 3,
    ) -> List[str]:
        """
        用 TF-IDF 从一个 section 的内容行中提取最重要的 N 句。
        """
        if not lines:
            return []

        # 计算每句的 TF-IDF 分数
        sentence_scores: List[Tuple[float, str]] = []
        for line in lines:
            words = self._tokenize(line)
            if len(words) < 2:
                continue
            score = 0.0
            for w in words:
                tf = words.count(w) / len(words)
                score += tf * idf.get(w, 1.0)
            sentence_scores.append((score, line))

        # 按分数降序，取 top_n，然后按原始行顺序返回
        sentence_scores.sort(key=lambda x: -x[0])
        selected = sentence_scores[:top_n]
        selected.sort(key=lambda x: lines.index(x[1]) if x[1] in lines else 0)

        return [s[1][:80] for s in selected]

    def _compute_heading_importance(
        self, headings: List[Heading], sections: dict[str, SectionInsight]
    ) -> List[Heading]:
        """基于内容洞察计算每个标题的重要性评分。"""
        for h in headings:
            insight = sections.get(h.text)
            if insight:
                h.importance = insight.importance_score
        return headings

    # ── 文本处理工具 ───────────────────────────────────────────────────

    @staticmethod
    def _tokenize(text: str) -> List[str]:
        """
        中英文混合分词（无需外部依赖）。
        - 中文：提取 2-4 字连续中文片段，再用频率去重
        - 英文：按空格分词
        """
        tokens: List[str] = []
        # 提取英文单词
        en_words = re.findall(r'[a-zA-Z]{2,}', text)
        tokens.extend(w.lower() for w in en_words)
        # 提取中文：按标点和空白切分后取 2-4 字片段
        cn_segments = re.findall(r'[\u4e00-\u9fff]+', text)
        for seg in cn_segments:
            # 优先取 2 字和 3 字组合（中文词大部分 2-3 字）
            if len(seg) >= 2:
                for i in range(len(seg) - 1):
                    tokens.append(seg[i:i+2])  # 2-gram
            if len(seg) >= 3:
                for i in range(len(seg) - 2):
                    tokens.append(seg[i:i+3])  # 3-gram
            if len(seg) >= 4:
                for i in range(len(seg) - 3):
                    tokens.append(seg[i:i+4])  # 4-gram
        return tokens

    @staticmethod
    def _get_stop_words() -> set[str]:
        """返回中英文停用词集合。"""
        return {
            # 中文停用词
            "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都",
            "一", "一个", "上", "也", "很", "到", "说", "要", "去", "你",
            "会", "着", "没有", "看", "好", "自己", "这", "他", "她", "它",
            "那么", "因为", "所以", "但是", "如果", "可以", "已经", "可能",
            "这个", "那个", "什么", "怎么", "如何", "就是", "还是", "或者",
            "以及", "通过", "进行", "使得", "其中", "关于", "对于", "根据",
            # 英文停用词
            "the", "a", "an", "is", "are", "was", "were", "be", "been",
            "being", "have", "has", "had", "do", "does", "did", "will",
            "would", "could", "should", "may", "might", "can", "shall",
            "of", "in", "to", "for", "with", "on", "at", "from", "by",
            "and", "or", "but", "not", "no", "so", "if", "as", "it",
            "this", "that", "these", "those", "which", "who", "what",
            "when", "where", "how", "than", "then", "there", "here",
        }
