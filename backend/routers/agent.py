"""
agent.py — Learning OS Agent 路由
挂载在 /api/agent

端点：
  POST /api/agent/resolve-intent   — 意图解析，返回推荐 Skill 列表
  POST /api/agent/execute-node     — 执行单个 PromptNode
"""
from __future__ import annotations

import json
import time
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import get_current_user

router = APIRouter()

# ── 内置 Skill 定义 ────────────────────────────────────────────────────────────
# 当前阶段：Skill 库硬编码在后端，后续迁移到数据库。
# 每个 Skill 包含 id、name、description、tags、promptChain、requiredComponents。

_BUILTIN_SKILLS: list[dict] = [
    {
        "id": "skill_feynman",
        "name": "费曼学习法",
        "description": "用自己的话解释知识点，暴露理解盲区，强化记忆",
        "tags": ["通用", "理解", "记忆"],
        "promptChain": [
            {
                "id": "node_explain",
                "prompt": "请用最简单的语言解释「{topic}」，假设你在向一个完全不懂的人讲解。",
                "inputMapping": {},
            },
            {
                "id": "node_identify_gaps",
                "prompt": "根据上面的解释，找出哪些地方解释得不够清楚或有逻辑漏洞，列出需要深入学习的点。",
                "inputMapping": {"explanation": "node_explain.content"},
            },
            {
                "id": "node_simplify",
                "prompt": "针对上面找出的薄弱点，用类比或例子重新解释，让解释更完整、更易懂。",
                "inputMapping": {"gaps": "node_identify_gaps.content"},
            },
        ],
        "requiredComponents": ["chat"],
        "version": "1.0.0",
        "type": "builtin",
    },
    {
        "id": "skill_spaced_repetition",
        "name": "间隔重复复习",
        "description": "按艾宾浩斯遗忘曲线安排复习时间，最大化长期记忆效果",
        "tags": ["通用", "记忆", "复习"],
        "promptChain": [
            {
                "id": "node_extract_points",
                "prompt": "从「{content}」中提取 5-10 个核心知识点，每个知识点用一句话概括。",
                "inputMapping": {},
            },
            {
                "id": "node_create_questions",
                "prompt": "针对上面的知识点，为每个点生成一个测试问题（问答题或填空题）。",
                "inputMapping": {"points": "node_extract_points.content"},
            },
            {
                "id": "node_schedule",
                "prompt": "根据间隔重复原理，建议今天、明天、3天后、7天后、14天后各复习哪些知识点。",
                "inputMapping": {"questions": "node_create_questions.content"},
            },
        ],
        "requiredComponents": ["chat", "calendar"],
        "version": "1.0.0",
        "type": "builtin",
    },
    {
        "id": "skill_problem_solving",
        "name": "结构化解题",
        "description": "按「考点→思路→步骤→踩分点→易错点」结构化拆解题目",
        "tags": ["解题", "理工科", "考试"],
        "promptChain": [
            {
                "id": "node_analyze",
                "prompt": "分析题目「{problem}」，识别考查的核心知识点和题型。",
                "inputMapping": {},
            },
            {
                "id": "node_solve",
                "prompt": "按「解题思路 → 详细步骤 → 踩分点 → 易错点」格式给出完整解答。",
                "inputMapping": {"analysis": "node_analyze.content"},
            },
        ],
        "requiredComponents": ["solve", "mistake_book"],
        "version": "1.0.0",
        "type": "builtin",
    },
    {
        "id": "skill_mindmap_learning",
        "name": "思维导图学习",
        "description": "将知识点可视化为思维导图，建立知识网络",
        "tags": ["通用", "理解", "可视化"],
        "promptChain": [
            {
                "id": "node_structure",
                "prompt": "将「{topic}」的知识体系整理为层级结构，识别主干概念和分支概念。",
                "inputMapping": {},
            },
            {
                "id": "node_mindmap",
                "prompt": "根据上面的结构，生成 Markdown 格式的思维导图（用 # ## ### 表示层级）。",
                "inputMapping": {"structure": "node_structure.content"},
            },
        ],
        "requiredComponents": ["mindmap"],
        "version": "1.0.0",
        "type": "builtin",
    },
    {
        "id": "skill_exam_prep",
        "name": "考前冲刺",
        "description": "快速梳理高频考点，生成模拟题，针对性强化训练",
        "tags": ["考试", "复习", "出题"],
        "promptChain": [
            {
                "id": "node_hotspots",
                "prompt": "针对「{subject}」，列出最近三年高频考点，按重要性排序。",
                "inputMapping": {},
            },
            {
                "id": "node_quiz",
                "prompt": "根据上面的高频考点，生成 10 道模拟题（选择题 5 道 + 简答题 5 道）。",
                "inputMapping": {"hotspots": "node_hotspots.content"},
            },
            {
                "id": "node_strategy",
                "prompt": "给出考前 3 天的复习策略，包括时间分配和重点攻克顺序。",
                "inputMapping": {"quiz": "node_quiz.content"},
            },
        ],
        "requiredComponents": ["quiz", "chat"],
        "version": "1.0.0",
        "type": "builtin",
    },
]

# 快速查找索引
_SKILL_INDEX: dict[str, dict] = {s["id"]: s for s in _BUILTIN_SKILLS}


# ── Pydantic 模型 ──────────────────────────────────────────────────────────────


class ResolveIntentIn(BaseModel):
    text: str
    session_id: Optional[str] = None
    subject_id: Optional[int] = None


class SkillRecommendation(BaseModel):
    skill_id: str
    name: str
    description: str
    rationale: str          # ≤ 50 字（需求 2.2）
    match_score: float      # 0.0 – 1.0


class ResolveIntentOut(BaseModel):
    goal: str
    recommended_skills: list[SkillRecommendation]
    recommended_components: list[str]


class ExecuteNodeIn(BaseModel):
    skill_id: str
    node_id: str
    prompt: str
    input: dict[str, Any] = {}
    session_id: Optional[str] = None
    subject_id: Optional[int] = None
    # MCP 工具调用：Skill 的 requiredComponents 中含点号的引用
    # 格式：{"filesystem.read_file": {"path": "/tmp/notes.txt"}}
    mcp_tool_calls: dict[str, dict[str, Any]] = {}


class ExecuteNodeOut(BaseModel):
    node_id: str
    content: str
    metadata: dict[str, Any] = {}
    mcp_results: dict[str, Any] = {}   # MCP 工具调用结果，注入下一节点输入
    degraded: bool = False             # 是否有工具调用走了降级路径（属性 3）


# ── 意图解析 ───────────────────────────────────────────────────────────────────


@router.post("/resolve-intent", response_model=ResolveIntentOut)
def resolve_intent(body: ResolveIntentIn, user=Depends(get_current_user)):
    """
    解析用户自然语言意图，返回最多 3 个推荐 Skill。

    需求 2.1：3 秒内返回。
    需求 2.2：每个推荐理由 ≤ 50 字。
    需求 2.3：无匹配时返回空列表（前端负责展示 DIY 入口）。
    """
    from services.llm_service import LLMService

    text = body.text.strip()
    if not text:
        raise HTTPException(400, "意图文本不能为空")

    # 构建 Skill 摘要供 LLM 参考
    skill_summaries = "\n".join(
        f"- {s['id']}：{s['name']}（{s['description']}）[标签: {', '.join(s['tags'])}]"
        for s in _BUILTIN_SKILLS
    )

    prompt = f"""你是一个学习助手，根据用户的学习需求，从以下 Skill 列表中推荐最合适的 1-3 个 Skill。

可用 Skill 列表：
{skill_summaries}

用户需求：{text}

请以 JSON 格式返回，结构如下（不要有任何额外文字）：
{{
  "goal": "用一句话概括用户的学习目标",
  "recommendations": [
    {{
      "skill_id": "skill_xxx",
      "rationale": "推荐理由（不超过50字）",
      "match_score": 0.95
    }}
  ],
  "recommended_components": ["component_id1", "component_id2"]
}}

要求：
1. 按匹配度从高到低排序，最多返回 3 个
2. rationale 不超过 50 个字
3. match_score 在 0.0-1.0 之间
4. 如果没有合适的 Skill，recommendations 返回空数组
5. 只返回 JSON，不要 markdown 代码块"""

    try:
        llm = LLMService()
        model = llm.get_model_for_scene("fast")
        raw = llm.chat(
            [{"role": "user", "content": prompt}],
            model=model,
            max_tokens=500,
        )
    except RuntimeError as e:
        raise HTTPException(502, f"AI 服务暂时不可用：{e}")

    # 解析 LLM 返回的 JSON
    try:
        # 去掉可能的 markdown 代码块包裹
        raw = raw.strip()
        if raw.startswith("```"):
            lines = raw.splitlines()
            raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
        data = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        # LLM 返回格式异常时，降级为空结果
        return ResolveIntentOut(
            goal=text,
            recommended_skills=[],
            recommended_components=[],
        )

    # 构建推荐列表，只返回 Skill 库中存在的 Skill
    recommendations: list[SkillRecommendation] = []
    for rec in (data.get("recommendations") or [])[:3]:
        skill_id = rec.get("skill_id", "")
        skill = _SKILL_INDEX.get(skill_id)
        if not skill:
            continue
        rationale = str(rec.get("rationale", ""))[:50]  # 强制截断到 50 字
        recommendations.append(
            SkillRecommendation(
                skill_id=skill_id,
                name=skill["name"],
                description=skill["description"],
                rationale=rationale,
                match_score=float(rec.get("match_score", 0.5)),
            )
        )

    return ResolveIntentOut(
        goal=str(data.get("goal", text)),
        recommended_skills=recommendations,
        recommended_components=list(data.get("recommended_components") or []),
    )


# ── PromptNode 执行 ────────────────────────────────────────────────────────────


@router.post("/execute-node", response_model=ExecuteNodeOut)
def execute_node(body: ExecuteNodeIn, user=Depends(get_current_user)):
    """
    执行 Skill 的单个 PromptNode，支持 Component 和 MCP 工具双路由。

    路由规则（需求 4.2、4.3）：
    - mcp_tool_calls 中含点号的引用（如 "filesystem.read_file"）→ MCP_Client
    - requiredComponents 中不含点号的引用（如 "notebook"）→ ComponentRegistry（不在此处处理，由 Flutter 端调度）

    MCP 工具调用失败/超时时自动触发 FallbackHandler，Skill 执行继续（需求 1.5，属性 3）。
    需求 2.4：按 PromptChain 顺序执行（顺序由 Flutter 端 AgentKernelImpl 保证）。
    需求 2.6：LLM 节点失败时返回 500，Flutter 端抛出 SkillExecutionError。
    """
    from services.llm_service import LLMService
    from mcp_layer.mcp_registry import get_registry
    from mcp_layer.fallback_handler import get_fallback_handler

    # ── 阶段一：执行 MCP 工具调用（在 LLM 调用前，结果注入 prompt） ──────────
    mcp_results: dict[str, Any] = {}
    any_degraded = False

    for tool_ref, tool_args in body.mcp_tool_calls.items():
        # 格式验证：必须含点号（需求 4.2）
        if "." not in tool_ref:
            continue  # 不含点号的引用由 ComponentRegistry 处理，此处跳过

        registry = get_registry()
        result = registry.call_tool(
            tool_ref=tool_ref,
            arguments=tool_args,
            timeout_seconds=10.0,
        )

        if not result.success or result.degraded:
            # 工具失败/超时：触发 FallbackHandler（需求 1.5，属性 3）
            fallback = get_fallback_handler()
            result = fallback.handle(tool_ref, tool_args)
            any_degraded = True

        # 将工具结果注入 mcp_results，供 prompt 模板替换使用
        tool_key = tool_ref.replace(".", "_")  # "filesystem.read_file" → "filesystem_read_file"
        mcp_results[tool_key] = result.data
        if result.degraded:
            any_degraded = True

    # ── 阶段二：渲染 prompt 模板 ──────────────────────────────────────────────
    prompt_template = body.prompt.strip()
    if not prompt_template:
        raise HTTPException(400, "prompt 不能为空")

    # 合并 input 和 mcp_results 作为模板变量
    template_vars = {**body.input}
    for tool_key, tool_data in mcp_results.items():
        # 将工具结果的 text 字段直接注入（最常用的场景）
        if isinstance(tool_data, dict) and "text" in tool_data:
            template_vars[tool_key] = tool_data["text"]
        else:
            template_vars[tool_key] = str(tool_data)

    rendered_prompt = prompt_template
    for key, value in template_vars.items():
        placeholder = f"{{{key}}}"
        if placeholder in rendered_prompt:
            rendered_prompt = rendered_prompt.replace(placeholder, str(value))

    # ── 阶段三：调用 LLM 执行 PromptNode ─────────────────────────────────────
    system_parts = ["你是一个专业的学习助手，帮助学生高效学习。"]
    if body.subject_id:
        try:
            from database import Subject, get_session as db_session
            with db_session() as db:
                subj = db.query(Subject).filter_by(id=body.subject_id).first()
                if subj:
                    system_parts.append(f"当前学科：{subj.name}。")
        except Exception:
            pass

    system_prompt = " ".join(system_parts)

    try:
        llm = LLMService()
        model = llm.get_model_for_scene("heavy")
        content = llm.chat(
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": rendered_prompt},
            ],
            model=model,
            max_tokens=2000,
        )
    except RuntimeError as e:
        # 需求 2.6：节点失败返回 500，Flutter 端会捕获并抛出 SkillExecutionError
        raise HTTPException(500, f"节点执行失败：{e}")

    return ExecuteNodeOut(
        node_id=body.node_id,
        content=content,
        metadata={
            "skill_id": body.skill_id,
            "subject_id": body.subject_id,
        },
        mcp_results=mcp_results,
        degraded=any_degraded,
    )


# ── Skill 查询（供 Flutter SkillLibrary 使用）─────────────────────────────────


@router.get("/skills")
def list_skills(
    tag: Optional[str] = None,
    keyword: Optional[str] = None,
    user=Depends(get_current_user),
):
    """
    查询 Skill 列表，支持按标签和关键词过滤。
    需求 1.6：支持按学科标签、名称关键词过滤。
    """
    skills = list(_BUILTIN_SKILLS)

    if tag:
        skills = [s for s in skills if tag in s["tags"]]

    if keyword:
        kw = keyword.lower()
        skills = [
            s for s in skills
            if kw in s["name"].lower() or kw in s["description"].lower()
        ]

    return {"skills": skills, "total": len(skills)}


@router.get("/skills/{skill_id}")
def get_skill(skill_id: str, user=Depends(get_current_user)):
    """获取单个 Skill 详情。"""
    skill = _SKILL_INDEX.get(skill_id)
    if not skill:
        raise HTTPException(404, f"Skill '{skill_id}' 不存在")
    return skill


# ── SkillParser 适配器配置 ─────────────────────────────────────────────────────


class ParserConfigOut(BaseModel):
    adapter: str  # "ai" | "rule_based"


class ParserConfigIn(BaseModel):
    adapter: str  # "ai" | "rule_based"


@router.get("/parser/config", response_model=ParserConfigOut)
def get_parser_config(user=Depends(get_current_user)):
    """
    获取当前 SkillParser 适配器配置。
    需求 5.2：支持运行时切换 AI_Model_Adapter 实现。
    """
    from skill_ecosystem.ai_model_adapter import get_current_adapter_name
    return ParserConfigOut(adapter=get_current_adapter_name())


@router.put("/parser/config", response_model=ParserConfigOut)
def update_parser_config(body: ParserConfigIn, user=Depends(get_current_user)):
    """
    运行时切换 SkillParser 适配器。
    body: {"adapter": "ai" | "rule_based"}
    需求 5.2：支持运行时切换 AI_Model_Adapter 实现。
    """
    from skill_ecosystem.ai_model_adapter import set_current_adapter, get_current_adapter_name
    try:
        set_current_adapter(body.adapter)
    except ValueError as e:
        raise HTTPException(400, str(e))
    return ParserConfigOut(adapter=get_current_adapter_name())


# ── Skill JSON 导入导出 ────────────────────────────────────────────────────────


class SkillImportIn(BaseModel):
    json_str: str
    registered_components: list[str] = []


@router.get("/skills/{skill_id}/export")
def export_skill_endpoint(skill_id: str, user=Depends(get_current_user)):
    """
    导出 Skill 为 JSON 字符串（含 schema_version）。
    需求 8.1、8.2。
    """
    from skill_ecosystem.skill_io import export_skill
    try:
        json_str = export_skill(skill_id)
    except KeyError:
        raise HTTPException(404, f"Skill '{skill_id}' 不存在")
    return {"skill_id": skill_id, "json_str": json_str}


@router.post("/skills/import")
def import_skill_endpoint(body: SkillImportIn, user=Depends(get_current_user)):
    """
    导入 Skill JSON，返回 SkillImportResult（含缺失 Component 列表）。
    需求 8.4、8.5。
    """
    from skill_ecosystem.skill_io import import_skill
    result = import_skill(body.json_str, body.registered_components)
    return result


# ── 对话式 Skill 创建 ──────────────────────────────────────────────────────────


class DialogStartIn(BaseModel):
    user_id: str


class DialogAnswerIn(BaseModel):
    answer: str


@router.post("/dialog-skill/start")
def dialog_skill_start(body: DialogStartIn, user=Depends(get_current_user)):
    """
    启动 Dialog_Session，返回第一个引导问题。
    需求 9.1。
    """
    from skill_ecosystem.dialog_session_manager import get_session_manager
    mgr = get_session_manager()
    turn = mgr.start_session(body.user_id)
    return turn


@router.post("/dialog-skill/{session_id}/answer")
def dialog_skill_answer(
    session_id: str,
    body: DialogAnswerIn,
    user=Depends(get_current_user),
):
    """
    提交用户回答，返回下一个问题或草稿预览。
    需求 9.2、9.3。
    """
    from skill_ecosystem.dialog_session_manager import get_session_manager
    mgr = get_session_manager()
    try:
        turn = mgr.process_answer(session_id, body.answer)
    except KeyError:
        raise HTTPException(404, "Dialog session not found")
    return turn


@router.get("/dialog-skill/{session_id}/draft")
def dialog_skill_draft(session_id: str, user=Depends(get_current_user)):
    """
    获取当前草稿（支持中断恢复）。
    需求 9.5。
    """
    from skill_ecosystem.dialog_session_manager import get_session_manager
    mgr = get_session_manager()
    try:
        draft = mgr.save_draft(session_id)
    except KeyError:
        raise HTTPException(404, "Dialog session not found")
    return draft


@router.post("/dialog-skill/{session_id}/confirm")
def dialog_skill_confirm(session_id: str, user=Depends(get_current_user)):
    """
    确认草稿，调用 SkillLibrary 保存并发布。
    需求 9.4、9.6。
    """
    from skill_ecosystem.dialog_session_manager import get_session_manager
    mgr = get_session_manager()
    try:
        skill = mgr.confirm_and_publish(session_id, str(user["id"]))
    except KeyError:
        raise HTTPException(404, "Dialog session not found")
    return skill


@router.delete("/dialog-skill/{session_id}")
def dialog_skill_delete(session_id: str, user=Depends(get_current_user)):
    """
    放弃当前 Dialog_Session。
    需求 9.6。
    """
    from skill_ecosystem.dialog_session_manager import get_session_manager
    mgr = get_session_manager()
    try:
        mgr.delete_session(session_id)
    except KeyError:
        raise HTTPException(404, "Dialog session not found")
    return {"deleted": True, "session_id": session_id}
