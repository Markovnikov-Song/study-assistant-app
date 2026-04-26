"""
AI 出题服务：边界控制的题目生成。

核心设计：
1. 边界控制：将知识点分为前置/当前/后置三区域，只出范围内的题
2. 题型覆盖：选择、填空、计算、判断
3. 难度分级：L1基础(40%) + L2中等(40%) + L3进阶(20%)
4. 数量控制：单知识点3-5道，章节复习8-15道
"""

import json
import logging
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field
import random
from services.llm_service import LLMService

logger = logging.getLogger(__name__)



# ============================================================================
# Pydantic 模型
# ============================================================================

class QuizGenerateIn(BaseModel):
    """生成题目的请求"""
    node_id: str = Field(..., description="当前知识点 ID")
    node_title: str = Field(..., description="当前知识点标题")
    node_content: Optional[str] = Field(None, description="当前知识点内容")

    # 边界控制
    prerequisite_nodes: List[Dict[str, str]] = Field(
        default_factory=list,
        description="前置知识节点列表 [{node_id, node_title, node_content}]"
    )
    followup_nodes: List[Dict[str, str]] = Field(
        default_factory=list,
        description="后置知识节点列表 [{node_id, node_title, node_content}]"
    )

    # 生成参数
    question_count: int = Field(default=3, ge=1, le=20, description="题目数量")
    question_types: List[str] = Field(
        default=["choice"],
        description="题型列表: choice(选择) | fill(填空) | calc(计算) | judge(判断)"
    )
    difficulty: str = Field(default="mixed", description="难度: L1/L2/L3/mixed")


class ChoiceOption(BaseModel):
    """选择题选项"""
    key: str  # A, B, C, D
    content: str
    is_correct: bool = False


class Question(BaseModel):
    """题目"""
    id: str
    type: str  # choice, fill, calc, judge
    difficulty: str  # L1, L2, L3
    difficulty_label: str  # 基础, 中等, 进阶

    # 题目内容
    question: str
    options: Optional[List[ChoiceOption]] = None  # 选择题选项
    correct_answer: str
    explanation: str

    # 来源
    source_node_id: str
    source_node_title: str
    knowledge_zone: str  # pre(前置), current(当前), post(后置)


class QuizGenerateOut(BaseModel):
    """生成题目结果"""
    success: bool
    total_count: int
    questions: List[Question]
    knowledge_coverage: Dict[str, int]  # {"pre": 1, "current": 2, "post": 0}
    message: str = ""


# ============================================================================
# 题型生成器
# ============================================================================

class QuestionGenerator:
    """题目生成器基类"""

    def __init__(self, difficulty: str = "L1"):
        self.difficulty = difficulty
        self.difficulty_labels = {"L1": "基础", "L2": "中等", "L3": "进阶"}
        self.label = self.difficulty_labels.get(difficulty, "基础")

    def generate(
        self,
        question_id: str,
        content: str,
        node_id: str,
        node_title: str,
        zone: str,
    ) -> Question:
        """生成题目（模板方法）"""
        raise NotImplementedError

    def _create_base_question(
        self,
        question_id: str,
        question_text: str,
        answer: str,
        explanation: str,
        node_id: str,
        node_title: str,
        zone: str,
    ) -> Dict[str, Any]:
        """创建基础题目结构"""
        return {
            "id": question_id,
            "type": self._question_type,
            "difficulty": self.difficulty,
            "difficulty_label": self.label,
            "question": question_text,
            "options": None,
            "correct_answer": answer,
            "explanation": explanation,
            "source_node_id": node_id,
            "source_node_title": node_title,
            "knowledge_zone": zone,
        }


class ChoiceQuestionGenerator(QuestionGenerator):
    """选择题生成器"""
    _question_type = "choice"

    def generate(self, question_id, content, node_id, node_title, zone) -> Question:
        content = content or ""
        question_text = f"关于「{node_title}」，以下说法正确的是？"
        explanation = f"本题考察{self.label}难度的「{node_title}」知识点。"
        snippet = content[:20] if len(content) >= 20 else content
        snippet2 = content[20:40] if len(content) >= 40 else "错误选项"
        options = [
            ChoiceOption(key="A", content=f"{snippet}（正确）" if snippet else f"{node_title}的正确描述", is_correct=True),
            ChoiceOption(key="B", content=snippet2 if snippet2 else "与上述相反的说法"),
            ChoiceOption(key="C", content="相关但错误的说法"),
            ChoiceOption(key="D", content="另一个干扰项"),
        ]
        base = self._create_base_question(question_id, question_text, "A", explanation, node_id, node_title, zone)
        base["options"] = [o.model_dump() for o in options]
        return Question(**base)


class FillQuestionGenerator(QuestionGenerator):
    """填空题生成器"""
    _question_type = "fill"

    def generate(self, question_id, content, node_id, node_title, zone) -> Question:
        content = content or ""
        question_text = f"「{node_title}」是指什么？请填写空白处：_____"
        explanation = f"本题考察对「{node_title}」概念的理解。"
        answer = content[:20] if content else node_title
        base = self._create_base_question(question_id, question_text, answer, explanation, node_id, node_title, zone)
        return Question(**base)


class JudgeQuestionGenerator(QuestionGenerator):
    """判断题生成器"""
    _question_type = "judge"

    def generate(self, question_id, content, node_id, node_title, zone) -> Question:
        is_true = random.choice([True, False])
        question_text = f"「{node_title}」的相关说法：正确还是错误？"
        explanation = f"本题考察{self.label}难度的「{node_title}」。"
        base = self._create_base_question(
            question_id, question_text, "T" if is_true else "F",
            explanation, node_id, node_title, zone
        )
        return Question(**base)


class CalcQuestionGenerator(QuestionGenerator):
    """计算题生成器"""
    _question_type = "calc"

    def generate(self, question_id, content, node_id, node_title, zone) -> Question:
        question_text = f"根据「{node_title}」的原理，计算以下问题："
        explanation = f"本题考察{self.label}难度的「{node_title}」应用。"
        base = self._create_base_question(question_id, question_text, "略", explanation, node_id, node_title, zone)
        return Question(**base)


# ============================================================================
# 出题服务
# ============================================================================

class QuizGeneratorService:
    """AI 出题服务"""

    # 难度分布权重
    DIFFICULTY_WEIGHTS = {
        "L1": 0.4,  # 基础 40%
        "L2": 0.4,  # 中等 40%
        "L3": 0.2,  # 进阶 20%
    }

    # 题型到生成器的映射
    GENERATOR_MAP = {
        "choice": ChoiceQuestionGenerator,
        "fill": FillQuestionGenerator,
        "judge": JudgeQuestionGenerator,
        "calc": CalcQuestionGenerator,
    }

    def __init__(self):
        self.llm = LLMService()

    def generate_quiz(self, request: QuizGenerateIn, user_id: Optional[int] = None) -> QuizGenerateOut:
        """
        生成练习题。
        """
        # 1. 构建 Prompt 上下文
        context_parts = []
        if request.prerequisite_nodes:
            context_parts.append("### 前置知识点")
            for n in request.prerequisite_nodes:
                context_parts.append(f"- {n['node_title']}: {n.get('node_content', '')}")
        
        context_parts.append(f"### 当前核心知识点\n- {request.node_title}: {request.node_content or ''}")
        
        if request.followup_nodes:
            context_parts.append("### 后置/延伸知识点")
            for n in request.followup_nodes:
                context_parts.append(f"- {n['node_title']}: {n.get('node_content', '')}")

        context_str = "\n".join(context_parts)

        # 2. 调用 LLM
        prompt = f"""你是一个专业的教育专家，请基于以下知识点上下文，为学生生成高质量的练习题。

{context_str}

### 任务要求：
1. 总共生成 {request.question_count} 道题目。
2. 题型必须在以下范围内：{', '.join(request.question_types)}。
3. 难度要求：{request.difficulty}（L1基础, L2中等, L3进阶, mixed混合）。
4. 题目必须严格基于知识点内容，考察深度要符合难度级别。
5. 必须返回合法的 JSON 数组，格式如下：
[
  {{
    "type": "choice/fill/calc/judge",
    "difficulty": "L1/L2/L3",
    "difficulty_label": "基础/中等/进阶",
    "question": "题目正文",
    "options": [
      {{"key": "A", "content": "选项内容", "is_correct": true}},
      {{"key": "B", "content": "选项内容", "is_correct": false}},
      ...
    ],
    "correct_answer": "A 或 填空答案 或 正确/错误",
    "explanation": "详细的解析",
    "source_node_id": "{request.node_id}",
    "source_node_title": "{request.node_title}",
    "knowledge_zone": "current"
  }}
]

注意：
- 选择题必须有 4 个选项。
- 填空/计算/判断题的 options 为空列表或 null。
- 答案和解析要准确。
- 如果是计算题，请在解析中写明步骤。
"""

        try:
            response_text = self.llm.chat(
                messages=[
                    {"role": "system", "content": "你是一个只输出 JSON 数据的教育出题助手。"},
                    {"role": "user", "content": prompt}
                ],
                user_id=user_id,
                endpoint="quiz_generate",
                track_token=False,  # 出题不走 token 统计，避免统计服务异常影响出题
            )
            
            # 清洗并解析 JSON — 兼容多种 LLM 输出格式
            text = response_text.strip()
            # 去除 markdown 代码块
            if "```json" in text:
                text = text.split("```json", 1)[1]
                text = text.rsplit("```", 1)[0].strip()
            elif "```" in text:
                text = text.split("```", 1)[1]
                text = text.rsplit("```", 1)[0].strip()
            # 找到第一个 [ 和最后一个 ]
            start = text.find('[')
            end = text.rfind(']')
            if start != -1 and end != -1 and end > start:
                text = text[start:end+1]
            
            questions_data = json.loads(text)
            if not isinstance(questions_data, list):
                raise ValueError("LLM 返回的不是 JSON 数组")
            
            # 转换为 Question 模型列表
            questions = []
            knowledge_coverage = {"pre": 0, "current": 0, "post": 0}
            
            for idx, q in enumerate(questions_data):
                # 注入 ID
                q["id"] = f"q_{idx + 1}"
                # 补全缺失字段
                if "difficulty_label" not in q:
                    q["difficulty_label"] = {"L1": "基础", "L2": "中等", "L3": "进阶"}.get(q.get("difficulty", "L1"), "基础")
                if "source_node_id" not in q:
                    q["source_node_id"] = request.node_id
                if "source_node_title" not in q:
                    q["source_node_title"] = request.node_title
                if "knowledge_zone" not in q:
                    q["knowledge_zone"] = "current"
                if q.get("options") is None:
                    q["options"] = []
                # 统计覆盖情况
                zone = q.get("knowledge_zone", "current")
                knowledge_coverage[zone] = knowledge_coverage.get(zone, 0) + 1
                
                questions.append(Question(**q))

            return QuizGenerateOut(
                success=True,
                total_count=len(questions),
                questions=questions,
                knowledge_coverage=knowledge_coverage,
                message=f"成功生成 {len(questions)} 道 AI 练习题"
            )

        except Exception as e:
            logger.error(f"AI Quiz Generation failed: {type(e).__name__}: {e}", exc_info=True)
            # 降级方案：使用原有模板逻辑生成
            return self._generate_fallback(request)

    def _generate_fallback(self, request: QuizGenerateIn) -> QuizGenerateOut:
        """原有模板逻辑作为降级方案"""
        questions: List[Question] = []
        knowledge_coverage = {"pre": 0, "current": 0, "post": 0}
        
        all_nodes = []
        for node in request.prerequisite_nodes:
            all_nodes.append({**node, "zone": "pre"})
        all_nodes.append({
            "node_id": request.node_id,
            "node_title": request.node_title,
            "node_content": request.node_content or "",
            "zone": "current"
        })
        for node in request.followup_nodes:
            all_nodes.append({**node, "zone": "post"})

        for i in range(request.question_count):
            node = random.choice(all_nodes)
            q_type = random.choice(request.question_types) if request.question_types else "choice"
            generator_class = self.GENERATOR_MAP.get(q_type, ChoiceQuestionGenerator)
            generator = generator_class(difficulty="L1")
            content = node.get("node_content") or node.get("node_title", "")
            
            q = generator.generate(
                f"fallback_{i}",
                content,
                node["node_id"],
                node["node_title"],
                node["zone"]
            )
            questions.append(q)
            knowledge_coverage[node["zone"]] += 1

        return QuizGenerateOut(
            success=True,
            total_count=len(questions),
            questions=questions,
            knowledge_coverage=knowledge_coverage,
            message="生成完成（降级模式）"
        )



# ============================================================================
# 便捷函数
# ============================================================================

def generate_quiz(
    node_id: str,
    node_title: str,
    node_content: Optional[str] = None,
    prerequisite_nodes: Optional[List[Dict[str, str]]] = None,
    followup_nodes: Optional[List[Dict[str, str]]] = None,
    question_count: int = 3,
    question_types: Optional[List[str]] = None,
    difficulty: str = "mixed",
) -> Dict[str, Any]:
    """
    便捷函数：生成练习题。

    示例：
    ```python
    result = generate_quiz(
        node_id="node_001",
        node_title="二次函数",
        node_content="形如 y=ax²+bx+c (a≠0) 的函数叫二次函数",
        question_count=5,
        question_types=["choice", "judge"],
    )
    ```
    """
    if prerequisite_nodes is None:
        prerequisite_nodes = []
    if followup_nodes is None:
        followup_nodes = []
    if question_types is None:
        question_types = ["choice"]

    request = QuizGenerateIn(
        node_id=node_id,
        node_title=node_title,
        node_content=node_content,
        prerequisite_nodes=prerequisite_nodes,
        followup_nodes=followup_nodes,
        question_count=question_count,
        question_types=question_types,
        difficulty=difficulty,
    )

    service = QuizGeneratorService()
    result = service.generate_quiz(request)

    return result.model_dump()
