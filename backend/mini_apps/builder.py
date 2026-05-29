from __future__ import annotations

import json
import re
import uuid
from typing import Any

from .canvas import get_block_registry, materialize_graph, merge_validations
from .models import MiniAppRecord, MiniAppValidation, now_iso


QUESTIONS = [
    "你希望这个学习小软件使用哪些内容？例如手动词表、资料库、错题本、脑图节点，或者先用样例内容启动。",
    "它每天应该怎么练？请说明每日数量、题型或玩法，比如闪卡、选择题、填空、默写、闯关。",
    "答错、复习和提醒怎么处理？例如答错几次给讲解、用 SM2 还是固定复习、几点提醒。",
]


def next_question(answer_count: int) -> str | None:
    if answer_count < len(QUESTIONS):
        return QUESTIONS[answer_count]
    return None


def _contains(text: str, *keywords: str) -> bool:
    lowered = text.lower()
    return any(keyword.lower() in lowered for keyword in keywords)


def infer_app_type(text: str) -> str:
    if _contains(text, "错题", "变式", "刷题", "解题", "mistake"):
        return "mistake_drill"
    if _contains(text, "闯关", "多邻国", "关卡", "地图", "duolingo", "quest"):
        return "quest"
    return "memory"


def infer_template_id(text: str, app_type: str) -> str:
    if _contains(text, "百词斩", "背单词", "词汇", "单词", "vocab", "word"):
        return "baicizhan_vocab"
    if _contains(text, "多邻国", "闯关", "关卡", "duolingo") or app_type == "quest":
        return "duolingo_quest"
    if _contains(text, "错题", "变式", "刷题") or app_type == "mistake_drill":
        return "mistake_variation"
    if _contains(text, "费曼", "讲给", "解释概念", "feynman"):
        return "feynman_explain"
    if _contains(text, "公式", "定理", "方程"):
        return "formula_memory"
    return "recall_cards"


def default_title(app_type: str) -> str:
    return {
        "memory": "背记训练小软件",
        "mistake_drill": "错题变式训练小软件",
        "quest": "知识闯关小软件",
    }.get(app_type, "学习小软件")


def infer_title(initial_request: str, app_type: str) -> str:
    text = re.sub(r"\s+", "", initial_request.strip())
    if not text:
        return default_title(app_type)
    text = re.sub(
        r"^(我想|我要|帮我|请帮我)?(做|创建|设计|弄)?(一个|一款)?",
        "",
        text,
    )
    title = text[:18].rstrip("，。,.？?")
    return title or default_title(app_type)


def _extract_first_int(
    text: str,
    default: int,
    min_value: int = 1,
    max_value: int = 200,
) -> int:
    match = re.search(r"\d+", text)
    if not match:
        return default
    return max(min_value, min(max_value, int(match.group(0))))


def _template_profile(template_id: str, app_type: str) -> dict[str, Any]:
    profiles = {
        "baicizhan_vocab": {
            "name": "百词斩式词汇记忆",
            "description": "先建立词义联想，再通过闪卡、选择题和拼写巩固。",
            "recommended_sequence": ["flashcard", "choice_quiz", "spelling_input"],
            "content_fields": ["word", "meaning", "example", "mnemonic", "image_prompt"],
            "acceptance": ["至少 20 个词条", "每个词条有释义和例句", "错词进入复习队列"],
        },
        "duolingo_quest": {
            "name": "多邻国式闯关练习",
            "description": "把知识拆成小关卡，用短回合、多反馈和 streak 维持动机。",
            "recommended_sequence": ["choice_quiz", "flashcard", "spelling_input"],
            "content_fields": ["prompt", "answer", "distractors", "level", "explanation"],
            "acceptance": ["至少 5 个关卡", "每关有通过条件", "连续错误后降级到讲解"],
        },
        "mistake_variation": {
            "name": "错题变式训练",
            "description": "从错因诊断出发，生成同类题和变式题，直到掌握稳定。",
            "recommended_sequence": ["flashcard", "choice_quiz"],
            "content_fields": ["question", "answer", "wrong_reason", "method", "variation"],
            "acceptance": ["每题有错因", "每题至少一个变式方向", "错题写入错题本"],
        },
        "feynman_explain": {
            "name": "费曼讲解训练",
            "description": "让学生用自己的话解释概念，系统追问漏洞并安排复述。",
            "recommended_sequence": ["flashcard", "choice_quiz"],
            "content_fields": ["concept", "plain_explanation", "counterexample", "check_question"],
            "acceptance": ["概念能被一句话解释", "有反例或易混点", "有追问问题"],
        },
        "formula_memory": {
            "name": "公式记忆与应用",
            "description": "先记公式含义，再用条件识别和小题应用巩固。",
            "recommended_sequence": ["flashcard", "choice_quiz", "spelling_input"],
            "content_fields": ["formula", "meaning", "variables", "example_problem", "answer"],
            "acceptance": ["公式变量解释完整", "至少一个应用题", "能检查默写"],
        },
        "recall_cards": {
            "name": "主动回忆卡片",
            "description": "用问题-答案卡片建立每日主动回忆和间隔复习闭环。",
            "recommended_sequence": ["flashcard"],
            "content_fields": ["front", "back", "tags", "explanation"],
            "acceptance": ["至少 5 个真实学习项", "front/back 完整", "复习参数有效"],
        },
    }
    return profiles.get(template_id) or profiles["recall_cards"]


def _sample_items(app_type: str, initial_request: str) -> list[dict[str, Any]]:
    template_id = infer_template_id(initial_request, app_type)
    if template_id == "baicizhan_vocab":
        return [
            {"id": "word_1", "front": "abandon", "back": "放弃；例句：Do not abandon your plan.", "tags": ["vocab", "sample"], "explanation": "可联想为离开原本阵营。"},
            {"id": "word_2", "front": "benefit", "back": "好处；受益；例句：Daily review benefits memory.", "tags": ["vocab", "sample"], "explanation": "注意名词和动词两种用法。"},
            {"id": "word_3", "front": "contrast", "back": "对比；差异；例句：Contrast the two methods.", "tags": ["vocab", "sample"], "explanation": "常与 with 连用。"},
            {"id": "word_4", "front": "derive", "back": "获得；源自；例句：The word derives from Latin.", "tags": ["vocab", "sample"], "explanation": "derive from 表示来源。"},
            {"id": "word_5", "front": "evidence", "back": "证据；例句：Give evidence for your answer.", "tags": ["vocab", "sample"], "explanation": "常作为不可数名词。"},
        ]
    if template_id == "duolingo_quest":
        return [
            {"id": "level_1", "front": "第一关：识别核心概念", "back": "完成基础辨认题后进入下一关。", "tags": ["level", "recognition"]},
            {"id": "level_2", "front": "第二关：选择正确解释", "back": "从多个解释中选出最准确的一项。", "tags": ["level", "choice"]},
            {"id": "level_3", "front": "第三关：易混点辨析", "back": "比较相似概念，并说出关键差异。", "tags": ["level", "contrast"]},
            {"id": "level_4", "front": "第四关：迁移应用", "back": "换一个场景使用同一个知识点。", "tags": ["level", "transfer"]},
            {"id": "level_5", "front": "终局挑战：混合小测", "back": "综合前置知识完成一次短测。", "tags": ["level", "challenge"]},
        ]
    if template_id == "mistake_variation":
        return [
            {"id": "mistake_1", "front": "错题样例：为什么这一步不能直接约分？", "back": "先检查分母是否为零，再讨论可约条件。", "tags": ["mistake", "diagnosis"]},
            {"id": "mistake_2", "front": "错因定位：这题错在概念、计算还是审题？", "back": "把题目拆成条件、目标、方法三部分。", "tags": ["diagnosis"]},
            {"id": "mistake_3", "front": "变式方向：如果条件改成相反会怎样？", "back": "保持核心方法一致，只改变约束条件。", "tags": ["variation"]},
            {"id": "mistake_4", "front": "复盘提示：下次看到什么信号要警惕？", "back": "记录触发错误的关键词或题型结构。", "tags": ["reflection"]},
            {"id": "mistake_5", "front": "再练触发：错后多久复习？", "back": "进入短间隔复习，掌握前反复出现。", "tags": ["review"]},
        ]
    if template_id == "formula_memory":
        return [
            {"id": "formula_1", "front": "公式的适用条件是什么？", "back": "先写清变量含义、单位和适用前提。", "tags": ["formula"]},
            {"id": "formula_2", "front": "这个公式解决哪类问题？", "back": "描述输入条件和要求的目标量。", "tags": ["application"]},
            {"id": "formula_3", "front": "变量 A 改变时结果如何变化？", "back": "用正相关、负相关或不变描述。", "tags": ["understanding"]},
            {"id": "formula_4", "front": "默写公式并解释每个符号", "back": "不仅写形式，还要说明符号意义。", "tags": ["recall"]},
            {"id": "formula_5", "front": "用一道小题验证公式", "back": "代入前统一单位，最后检查量纲。", "tags": ["practice"]},
        ]
    if template_id == "feynman_explain":
        return [
            {"id": "concept_1", "front": "用一句话解释这个概念", "back": "像讲给低年级同学一样，不使用术语堆砌。", "tags": ["explain"]},
            {"id": "concept_2", "front": "举一个生活例子", "back": "例子必须对应概念的关键条件。", "tags": ["example"]},
            {"id": "concept_3", "front": "说出一个反例", "back": "反例用来暴露概念边界。", "tags": ["counterexample"]},
            {"id": "concept_4", "front": "最容易混淆的点是什么？", "back": "列出相似概念，并比较差异。", "tags": ["contrast"]},
            {"id": "concept_5", "front": "被追问时如何补充？", "back": "补上原因、条件或推导步骤。", "tags": ["followup"]},
        ]
    topic = initial_request[:12] or "学习内容"
    return [
        {"id": "item_1", "front": f"{topic} 样例卡片 1", "back": "在内容包中替换为真实答案。", "tags": ["sample"]},
        {"id": "item_2", "front": f"{topic} 样例卡片 2", "back": "可以从资料库、笔记或手动列表导入。", "tags": ["sample"]},
        {"id": "item_3", "front": f"{topic} 样例卡片 3", "back": "答错后会进入复习队列。", "tags": ["sample"]},
        {"id": "item_4", "front": f"{topic} 样例卡片 4", "back": "可以改成例句、公式、概念解释或题目解析。", "tags": ["sample"]},
        {"id": "item_5", "front": f"{topic} 样例卡片 5", "back": "正式使用前替换为真实教材或错题内容。", "tags": ["sample"]},
    ]


def _module_catalog(app_type: str, template_id: str) -> list[dict[str, Any]]:
    profile = _template_profile(template_id, app_type)
    return [
        {
            "id": "teaching_template",
            "name": "教学模板",
            "selected": profile["name"],
            "editable_fields": ["template.id", "app.goal", "screens", "practice.sequence"],
            "quality_rule": "必须说明学生每天先看什么、练什么、错了怎么办、何时结束。",
        },
        {
            "id": "content_pack",
            "name": "教学内容",
            "selected": "manual_learning_items",
            "editable_fields": ["content.source", "content.items"],
            "quality_rule": "每个学习项必须有 id/front/back，正式内容建议补 tags、difficulty、explanation。",
        },
        {
            "id": "practice_method",
            "name": "练习方法",
            "selected": " -> ".join(profile["recommended_sequence"]),
            "editable_fields": ["practice.sequence"],
            "quality_rule": "练习顺序必须能把 LearningItemBatch 转成 AnswerEventBatch。",
        },
        {
            "id": "feedback_policy",
            "name": "反馈策略",
            "selected": "hint_then_explanation_then_mistake_book",
            "editable_fields": ["assessment.wrong_before_explanation"],
            "quality_rule": "答错后先提示，连续错误后讲解并写入错题本。",
        },
        {
            "id": "review_algorithm",
            "name": "推送/复习算法",
            "selected": "daily_fixed_or_sm2",
            "editable_fields": ["scheduler.type", "scheduler.new_items_per_day", "scheduler.max_reviews_per_day"],
            "quality_rule": "调度参数必须是正数，并且输出可进入 review_scheduler。",
        },
    ]


def infer_content_binding(session: dict[str, Any], answers: list[str], full_text: str) -> dict[str, Any]:
    subject_id = session.get("subject_id")
    document_ids: list[int] = []
    if _contains(full_text, "资料库", "讲义", "pdf", "文档", "上传", "library", "document", "教材", "笔记"):
        return {
            "source_type": "document",
            "source": {
                "subject_id": subject_id,
                "document_ids": document_ids,
                "include_secondary": False,
            },
            "pipeline": [
                "document_source_loader",
                "chunk_batch_processor",
                "flashcard_synthesizer",
            ],
            "generation": {
                "style": "qa",
                "cards_per_1000_tokens": 4.0,
                "cards_per_section": 2.0,
                "min_cards": 8,
                "max_cards": 120,
                "max_cards_per_unit": 3,
                "merge_under_tokens": 120,
                "max_units": 48,
            },
            "source_label": answers[0] if answers else "学科资料库（已解析文档）",
        }
    return {
        "source_type": "manual",
        "source": answers[0] if answers else "样例内容，稍后替换为真实学习内容",
        "pipeline": ["manual_card_loader"],
        "generation": {},
        "source_label": answers[0] if answers else "手动维护",
    }


def build_spec(session: dict[str, Any]) -> dict[str, Any]:
    initial = str(session.get("initial_request") or "")
    answers = [str(item) for item in session.get("answers", [])]
    full_text = initial + "\n" + "\n".join(answers)
    content_binding = infer_content_binding(session, answers, full_text)
    app_type = infer_app_type(full_text)
    template_id = infer_template_id(full_text, app_type)
    template = _template_profile(template_id, app_type)
    daily_answer = answers[1] if len(answers) > 1 else ""
    review_answer = answers[2] if len(answers) > 2 else ""
    daily_new = _extract_first_int(daily_answer, 20)
    max_reviews = max(daily_new * 2, _extract_first_int(review_answer, 50))
    scheduler_type = "sm2" if _contains(review_answer, "SM2", "间隔", "spaced") else "daily_fixed"

    return {
        "schema_version": "miniapp.v1",
        "app": {
            "type": app_type,
            "title": infer_title(initial, app_type),
            "subject_id": session.get("subject_id"),
            "goal": initial,
        },
        "template": {
            "id": template_id,
            "name": template["name"],
            "description": template["description"],
            "content_fields": template["content_fields"],
            "acceptance": template["acceptance"],
        },
        "content": {
            "source_type": content_binding["source_type"],
            "source": content_binding["source"],
            "pipeline": content_binding["pipeline"],
            "generation": content_binding["generation"],
            "source_label": content_binding["source_label"],
            "item_schema": {"id": "string", "front": "string", "back": "string", "tags": "string[]"},
            "items": []
            if content_binding["source_type"] == "document"
            else _sample_items(app_type, initial),
        },
        "screens": ["daily_home", "card_practice", "answer_feedback", "summary"],
        "flow": {
            "daily_start": ["load_due_items", "load_new_items", "show_daily_home"],
            "practice_item": ["show_card", "collect_answer", "update_mastery"],
            "answer_wrong": ["show_hint", "schedule_soon_review"],
            "daily_complete": ["show_summary", "write_progress"],
        },
        "scheduler": {
            "type": scheduler_type,
            "new_items_per_day": daily_new,
            "max_reviews_per_day": max_reviews,
            "wrong_answer_review_after_minutes": 10,
        },
        "assessment": {
            "mastered_threshold": 0.85,
            "wrong_before_explanation": 2,
            "metrics": ["accuracy", "streak", "last_review_result"],
        },
        "practice": {
            "sequence": template["recommended_sequence"],
            "interaction_contract": {
                "input": "LearningItemBatch",
                "output": "AnswerEventBatch",
                "required_item_fields": ["id", "front", "back"],
            },
        },
        "modules": _module_catalog(app_type, template_id),
        "runtime": {
            "engine": "flashcard_runtime",
            "safe_blocks": [
                "document_source_loader",
                "chunk_batch_processor",
                "flashcard_synthesizer",
                "manual_card_loader",
                "daily_quota_scheduler",
                "flashcard_practice",
                "exact_match_grader",
                "answer_gate",
                "show_hint",
                "wrong_count_gate",
                "explanation_provider",
                "mistake_book_writer",
                "mastery_updater",
                "review_scheduler",
                "summary_report",
            ],
        },
    }


def validate_spec(spec: dict[str, Any]) -> MiniAppValidation:
    errors: list[str] = []
    warnings: list[str] = []

    if spec.get("schema_version") != "miniapp.v1":
        errors.append("schema_version 必须是 miniapp.v1")

    app = spec.get("app") or {}
    if not app.get("title"):
        errors.append("app.title 不能为空")
    if not app.get("type"):
        errors.append("app.type 不能为空")

    content = spec.get("content") or {}
    items = content.get("items")
    source_type = content.get("source_type", "manual")
    if source_type == "document":
        source = content.get("source") if isinstance(content.get("source"), dict) else {}
        subject_id = source.get("subject_id") or (spec.get("app") or {}).get("subject_id")
        if not subject_id:
            errors.append("资料管线需要 content.source.subject_id 或 app.subject_id")
        if not isinstance(items, list):
            errors.append("content.items 必须是数组")
        elif not items:
            warnings.append("尚未从资料生成闪卡，保存后可在运行页点击「从资料生成闪卡」。")
        else:
            for index, item in enumerate(items):
                if not isinstance(item, dict):
                    errors.append(f"content.items[{index}] 必须是对象")
                    continue
                if not item.get("front") or not item.get("back"):
                    errors.append(f"content.items[{index}] 需要 front 和 back")
    elif not isinstance(items, list) or not items:
        errors.append("content.items 至少需要 1 个学习项目")
    elif isinstance(items, list):
        for index, item in enumerate(items):
            if not isinstance(item, dict):
                errors.append(f"content.items[{index}] 必须是对象")
                continue
            if not item.get("front") or not item.get("back"):
                errors.append(f"content.items[{index}] 需要 front 和 back")

    screens = spec.get("screens")
    if not isinstance(screens, list) or "card_practice" not in screens:
        errors.append("screens 必须包含 card_practice")

    scheduler = spec.get("scheduler") or {}
    if scheduler.get("new_items_per_day", 0) <= 0:
        errors.append("scheduler.new_items_per_day 必须大于 0")
    if scheduler.get("max_reviews_per_day", 0) < 0:
        errors.append("scheduler.max_reviews_per_day 不能小于 0")

    if not errors and source_type != "document" and len(items or []) < 5:
        warnings.append("当前内容较少，适合预览；正式使用前建议补充更多学习项目。")
    if scheduler.get("type") == "daily_fixed":
        warnings.append("当前使用固定每日复习；后续可以切换到 SM2 间隔重复。")

    return MiniAppValidation(ok=not errors, errors=errors, warnings=warnings)


def build_documents(spec: dict[str, Any], answers: list[str]) -> dict[str, str]:
    app = spec["app"]
    content = spec["content"]
    scheduler = spec["scheduler"]
    assessment = spec["assessment"]
    template = spec.get("template") or {}
    app_type_label = {
        "memory": "背记类",
        "mistake_drill": "错题训练类",
        "quest": "闯关类",
    }.get(app["type"], app["type"])

    requirements = "\n".join([
        "# 需求说明",
        "",
        f"名称：{app['title']}",
        f"类型：{app_type_label}学习小软件",
        f"目标：{app.get('goal') or '帮助用户形成稳定的学科学习闭环。'}",
        "",
        "## 成功标准",
        "- 用户可以每天打开小软件完成一组学习项目。",
        "- 系统记录正确/错误并更新掌握度。",
        "- 错误项目会进入复习队列。",
        "- 文档和配置可以继续修改并重新校验。",
    ])

    pedagogy = "\n".join([
        "# 教学设计",
        "",
        f"模板：{template.get('name', '')}",
        f"说明：{template.get('description', '')}",
        "",
        "## 教学路径",
        "1. 每天加载新项目和到期复习项目。",
        "2. 使用卡片或题目进行主动回忆。",
        "3. 用户作答后立即反馈。",
        "4. 答错项目进入短间隔复习。",
        "5. 达到掌握阈值后降低出现频率。",
        "",
        "## 用户补充",
        *(f"- {answer}" for answer in answers),
    ])

    content_doc = "\n".join([
        "# 内容结构",
        "",
        f"内容来源：{content.get('source')}",
        "",
        "## 内容单元字段",
        "- id：唯一标识",
        "- front：展示给用户的问题、词、概念或题干",
        "- back：答案、解释或讲解",
        "- tags：分类标签",
        "",
        f"当前样例内容数：{len(content.get('items') or [])}",
    ])

    assembly = "\n".join([
        "# 积木装配",
        "",
        f"运行引擎：{spec['runtime']['engine']}",
        "",
        "## 页面积木",
        *(f"- {screen}" for screen in spec["screens"]),
        "",
        "## 安全积木",
        *(f"- {block}" for block in spec["runtime"]["safe_blocks"]),
    ])

    scheduler_doc = "\n".join([
        "# 推送与复习策略",
        "",
        f"算法：{scheduler['type']}",
        f"每日新项目：{scheduler['new_items_per_day']}",
        f"每日复习上限：{scheduler['max_reviews_per_day']}",
        f"答错后复习间隔：{scheduler['wrong_answer_review_after_minutes']} 分钟",
        f"掌握阈值：{assessment['mastered_threshold']}",
        f"连续答错讲解阈值：{assessment['wrong_before_explanation']}",
    ])

    acceptance = "\n".join([
        "# 运行验收",
        "",
        "场景 1：进入运行页时，展示第一个待学习项目。",
        "场景 2：点击“已掌握”后进入下一项，并在结束后展示总结。",
        "场景 3：点击“待复习”后计入错误/复习统计。",
        "场景 4：配置缺少内容项时，校验失败并提示补充 content.items。",
    ])

    return {
        "requirements.md": requirements,
        "pedagogy.md": pedagogy,
        "content_structure.md": content_doc,
        "block_assembly.md": assembly,
        "review_strategy.md": scheduler_doc,
        "acceptance.md": acceptance,
        "runtime_config.json": json.dumps(spec, ensure_ascii=False, indent=2),
        "invisible_canvas.json": json.dumps(materialize_graph(spec)[0], ensure_ascii=False, indent=2),
        "block_registry.json": json.dumps(get_block_registry().as_dict(), ensure_ascii=False, indent=2),
    }


def build_quality_documents(spec: dict[str, Any]) -> dict[str, str]:
    template = spec.get("template") or {}
    modules = [m for m in spec.get("modules", []) if isinstance(m, dict)]
    content = spec.get("content") or {}
    items = [item for item in content.get("items", []) if isinstance(item, dict)]
    practice = spec.get("practice") or {}
    scheduler = spec.get("scheduler") or {}
    assessment = spec.get("assessment") or {}

    template_doc = "\n".join([
        "# 教学方法模板",
        "",
        f"模板：{template.get('name', '主动回忆卡片')}",
        "",
        str(template.get("description", "")),
        "",
        "## 推荐练习顺序",
        *[f"- {step}" for step in practice.get("sequence", [])],
        "",
        "## 必填内容字段",
        *[f"- {field}" for field in template.get("content_fields", [])],
        "",
        "## 验收标准",
        *[f"- {rule}" for rule in template.get("acceptance", [])],
    ])

    module_doc = "# 模块清单\n\n" + "\n\n".join(
        "\n".join([
            f"## {module.get('name', module.get('id', '模块'))}",
            f"- ID: `{module.get('id', '')}`",
            f"- 当前选择：{module.get('selected', '')}",
            f"- 可改字段：{', '.join(module.get('editable_fields') or [])}",
            f"- 质量规则：{module.get('quality_rule', '')}",
        ])
        for module in modules
    )

    item_rows = [
        f"| {item.get('id', '')} | {str(item.get('front', ''))[:40]} | {str(item.get('back', ''))[:50]} | {', '.join(item.get('tags') or [])} |"
        for item in items
    ]
    content_doc = "\n".join([
        "# 内容包",
        "",
        f"来源：{content.get('source', '')}",
        f"当前条目数：{len(items)}",
        "",
        "| ID | Front | Back | Tags |",
        "| --- | --- | --- | --- |",
        *item_rows,
        "",
        "## 发布前",
        "- 将样例项目替换为真实教材、词表、题目或笔记内容。",
        "- 预览至少保留 5 项，真实每日使用建议至少 20 项。",
        "- 当答案本身不足以学习时，补充 explanation。",
    ])

    qa_doc = "\n".join([
        "# 发布质量检查",
        "",
        "## 内容",
        "- [ ] 学习目标具体到学科和能力。",
        "- [ ] `content.items` 是真实学习项，不是占位项。",
        "- [ ] 每个项目都有 `id`、`front`、`back`。",
        "- [ ] 重点项目包含标签和解释。",
        "",
        "## 运行",
        f"- [ ] 练习顺序有明确意图：{practice.get('sequence', [])}",
        f"- [ ] 每日新项目数量合理：{scheduler.get('new_items_per_day')}",
        f"- [ ] 复习上限合理：{scheduler.get('max_reviews_per_day')}",
        f"- [ ] 连续错误讲解阈值清楚：{assessment.get('wrong_before_explanation')}",
        "",
        "## 安全",
        "- [ ] 隐形画布校验无错误。",
        "- [ ] 小软件能完整跑完一次练习。",
        "- [ ] 通过文档修订后不会破坏图谱校验。",
    ])

    return {
        "learning_method_template.md": template_doc,
        "module_catalog.md": module_doc,
        "content_pack.md": content_doc,
        "release_quality_checklist.md": qa_doc,
    }


def build_app_from_session(user_id: int | str, session: dict[str, Any]) -> MiniAppRecord:
    spec = build_spec(session)
    graph, graph_validation = materialize_graph(spec)
    validation = merge_validations(validate_spec(spec), graph_validation)
    created = now_iso()
    documents = build_documents(spec, [str(item) for item in session.get("answers", [])])
    documents.update(build_quality_documents(spec))
    return MiniAppRecord(
        id=f"mini_{uuid.uuid4().hex[:12]}",
        user_id=str(user_id),
        title=spec["app"]["title"],
        app_type=spec["app"]["type"],
        subject_id=spec["app"].get("subject_id"),
        status="validated" if validation.ok else "draft",
        documents=documents,
        spec=spec,
        graph=graph,
        validation=validation,
        created_at=created,
        updated_at=created,
    )


def summary_description(app: MiniAppRecord) -> str:
    scheduler = app.spec.get("scheduler", {}) if isinstance(app.spec, dict) else {}
    daily = scheduler.get("new_items_per_day", "?")
    count = len(app.spec.get("content", {}).get("items", []) or [])
    template = (app.spec.get("template") or {}).get("name")
    prefix = f"{template}，" if template else ""
    return f"{prefix}{count} 个学习项目，每日 {daily} 个新项目"


def revise_spec(spec: dict[str, Any], instruction: str) -> tuple[dict[str, Any], list[str]]:
    revised = json.loads(json.dumps(spec, ensure_ascii=False))
    changed: list[str] = []
    text = instruction.strip()
    lowered = text.lower()

    app = revised.setdefault("app", {})
    content = revised.setdefault("content", {})
    practice = revised.setdefault("practice", {})
    scheduler = revised.setdefault("scheduler", {})
    assessment = revised.setdefault("assessment", {})

    title_match = re.search(r"(?:标题|名称|名字|叫做|改名为)[:：为叫做\s]+([^，。?\n]{2,30})", text)
    if title_match:
        app["title"] = title_match.group(1).strip()
        changed.append("app.title")

    daily_match = re.search(r"(?:每天|每日|daily|new items|new cards|new words)[^\d]{0,10}(\d+)", lowered)
    if daily_match:
        scheduler["new_items_per_day"] = _extract_first_int(daily_match.group(1), 20)
        changed.append("scheduler.new_items_per_day")

    review_match = re.search(r"(?:复习上限|最多复习|review limit|max reviews)[^\d]{0,10}(\d+)", lowered)
    if review_match:
        scheduler["max_reviews_per_day"] = _extract_first_int(review_match.group(1), 50)
        changed.append("scheduler.max_reviews_per_day")

    if _contains(text, "sm2", "间隔重复", "间隔复习"):
        scheduler["type"] = "sm2"
        changed.append("scheduler.type")
    elif _contains(text, "固定复习", "每天固定"):
        scheduler["type"] = "daily_fixed"
        changed.append("scheduler.type")

    sequence: list[str] = []
    if _contains(text, "flashcard", "card", "闪卡"):
        sequence.append("flashcard")
    if _contains(text, "choice", "quiz", "选择题", "选择"):
        sequence.append("choice_quiz")
    if _contains(text, "spelling", "dictation", "拼写", "默写", "听写"):
        sequence.append("spelling_input")
    if sequence:
        practice["sequence"] = list(dict.fromkeys(sequence))
        changed.append("practice.sequence")

    wrong_match = re.search(r"(?:答错|错误|错)[^\d]{0,8}(\d+)[^\d]{0,8}(?:次|回|遍).*?(?:讲解|解释)", text)
    if wrong_match:
        assessment["wrong_before_explanation"] = _extract_first_int(wrong_match.group(1), 2)
        changed.append("assessment.wrong_before_explanation")

    threshold_match = re.search(r"(?:掌握阈值|掌握率|mastered)[^\d]{0,8}(\d+(?:\.\d+)?)", lowered)
    if threshold_match:
        raw = float(threshold_match.group(1))
        assessment["mastered_threshold"] = raw / 100 if raw > 1 else raw
        changed.append("assessment.mastered_threshold")

    items = content.setdefault("items", [])
    added = 0
    for line in text.splitlines():
        line = line.strip().lstrip("-*0123456789. ")
        if not line:
            continue
        separator = "=>"
        if "=>" not in line and "：" in line:
            separator = "："
        elif "=>" not in line and ":" in line:
            separator = ":"
        if separator not in line:
            continue
        front, back = [part.strip() for part in line.split(separator, 1)]
        if not front or not back:
            continue
        items.append({
            "id": f"item_{len(items) + 1}",
            "front": front,
            "back": back,
            "tags": ["用户补充"],
        })
        added += 1
    if added:
        changed.append(f"content.items(+{added})")

    if changed:
        revised.setdefault("revision_log", []).append({
            "instruction": instruction,
            "changed": changed,
            "updated_at": now_iso(),
        })
    return revised, changed
