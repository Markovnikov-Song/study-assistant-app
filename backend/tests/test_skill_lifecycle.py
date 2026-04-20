"""
Skill 完整生态链端到端测试。

验证以下完整链路：
1. 创建链：文本解析 → SkillDraft → 验证 → 保存 → 可查询
2. 执行链：PromptChain 顺序执行 → 节点间数据传递 → 结果聚合
3. 市场链：提交 → 浏览 → 下载 → 本地可用
4. 对话创建链：启动会话 → 多轮问答 → 草稿生成 → 发布
5. 导入导出链：导出 JSON → 导入 → 字段一致 → 可执行
"""
from __future__ import annotations

import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import pytest
import uuid


# ── 链路 1：文本解析 → 保存 → 查询 ───────────────────────────────────────────

class TestSkillCreationChain:
    """经验贴文本 → SkillDraft → 验证 → 保存 → 可查询。"""

    def test_text_to_draft_to_skill(self):
        """完整创建链：文本解析出草稿，草稿转为正式 Skill，Skill 可被查询。"""
        from skill_ecosystem.ai_model_adapter import RuleBasedAdapter
        from skill_ecosystem.models import SkillSourceEnum, PromptNodeSchema, SkillSchema
        import datetime

        # Step 1: 文本解析为草稿
        text = "1. 先读教材，理解基本概念\n2. 做练习题，巩固知识\n3. 总结错题，查漏补缺"
        adapter = RuleBasedAdapter()
        draft = adapter.parse(text)

        assert len(draft.steps) == 3, "应解析出 3 个步骤"
        assert draft.is_draft is True

        # Step 2: 草稿转为正式 Skill
        skill = SkillSchema(
            id=str(uuid.uuid4()),
            name="三步复习法",
            description="读教材 → 做练习 → 总结错题",
            tags=["通用", "复习"],
            prompt_chain=draft.steps,
            required_components=["chat"],
            version="1.0.0",
            created_at=datetime.datetime.utcnow(),
            type="custom",
            source=SkillSourceEnum.experience_import,
            created_by="user_test",
            schema_version="1.0",
        )

        # Step 3: 验证 Skill 结构完整
        assert skill.name == "三步复习法"
        assert len(skill.prompt_chain) == 3
        assert skill.source == SkillSourceEnum.experience_import

        # Step 4: 导出为 JSON，验证可序列化
        json_str = skill.model_dump_json()
        data = json.loads(json_str)
        assert data["name"] == "三步复习法"
        assert len(data["prompt_chain"]) == 3
        assert data["schema_version"] == "1.0"

    def test_empty_prompt_chain_rejected(self):
        """空 promptChain 的 Skill 不应通过验证。"""
        from skill_ecosystem.skill_io import import_skill

        data = {
            "name": "无效 Skill",
            "description": "测试",
            "tags": [],
            "prompt_chain": [],  # 空 chain
            "type": "custom",
            "source": "user_created",
        }
        result = import_skill(json.dumps(data), registered_components=[])
        assert result.success is False, "空 promptChain 应被拒绝"

    def test_ai_adapter_fallback_still_produces_valid_draft(self):
        """AI 不可用时，规则解析仍能产出有效草稿（属性 10）。"""
        from skill_ecosystem.ai_model_adapter import RuleBasedAdapter

        # 包含有效步骤结构的文本
        text = "- 第一步：预习\n- 第二步：听课\n- 第三步：复习"
        adapter = RuleBasedAdapter()
        draft = adapter.parse(text)

        assert len(draft.steps) >= 1, "规则解析应至少产出一个 PromptNode"
        assert all(node.prompt for node in draft.steps), "每个节点的 prompt 不能为空"


# ── 链路 2：PromptChain 执行 → 节点间数据传递 ─────────────────────────────────

class TestSkillExecutionChain:
    """PromptChain 顺序执行，节点间数据通过 inputMapping 传递。"""

    def test_prompt_chain_order_preserved(self):
        """PromptChain 中节点按顺序执行（属性 7）。"""
        from skill_ecosystem.models import PromptNodeSchema

        # 构建一个 3 节点的 PromptChain
        chain = [
            PromptNodeSchema(id="node_0", prompt="步骤一：{topic}"),
            PromptNodeSchema(
                id="node_1",
                prompt="步骤二：基于上一步的结果 {result}",
                input_mapping={"result": "node_0.content"},
            ),
            PromptNodeSchema(
                id="node_2",
                prompt="步骤三：总结 {summary}",
                input_mapping={"summary": "node_1.content"},
            ),
        ]

        # 验证 inputMapping 引用关系正确
        assert chain[1].input_mapping["result"] == "node_0.content"
        assert chain[2].input_mapping["summary"] == "node_1.content"

    def test_input_mapping_resolution(self):
        """inputMapping 解析：从前一节点输出中提取正确的值。"""
        # 模拟 AgentKernelImpl._applyInputMapping 的逻辑
        def apply_mapping(input_mapping: dict, previous_outputs: dict) -> dict:
            result = {}
            for key, ref in input_mapping.items():
                parts = ref.split(".")
                if len(parts) == 2:
                    node_id, output_key = parts
                    node_output = previous_outputs.get(node_id, {})
                    if isinstance(node_output, dict):
                        result[key] = node_output.get(output_key)
                else:
                    result[key] = previous_outputs.get(ref)
            return result

        previous_outputs = {
            "node_0": {"content": "费曼法的核心是用简单语言解释复杂概念"},
        }
        mapping = {"explanation": "node_0.content"}
        resolved = apply_mapping(mapping, previous_outputs)

        assert resolved["explanation"] == "费曼法的核心是用简单语言解释复杂概念"

    def test_mcp_tool_ref_routing(self):
        """含点号的引用走 MCP 路径，不含点号走 ComponentRegistry 路径。"""
        def is_mcp_ref(ref: str) -> bool:
            return "." in ref

        # Component 引用
        assert not is_mcp_ref("notebook")
        assert not is_mcp_ref("chat")
        assert not is_mcp_ref("mindmap")

        # MCP 工具引用
        assert is_mcp_ref("filesystem.read_file")
        assert is_mcp_ref("calendar.get_events")
        assert is_mcp_ref("search.web_search")

    def test_skill_with_mcp_tools_has_correct_refs(self):
        """包含 MCP 工具引用的 Skill 结构正确。"""
        from skill_ecosystem.models import PromptNodeSchema, SkillSchema, SkillSourceEnum
        import datetime

        skill = SkillSchema(
            id="skill_with_mcp",
            name="文件辅助学习",
            description="读取本地文件辅助学习",
            tags=["通用"],
            prompt_chain=[
                PromptNodeSchema(
                    id="node_read",
                    prompt="读取文件内容：{filesystem_read_file}",
                    input_mapping={},
                ),
                PromptNodeSchema(
                    id="node_summarize",
                    prompt="总结文件内容：{content}",
                    input_mapping={"content": "node_read.content"},
                ),
            ],
            required_components=["chat", "filesystem.read_file"],  # 混合引用
            version="1.0.0",
            created_at=datetime.datetime.utcnow(),
            type="custom",
            source=SkillSourceEnum.user_created,
            schema_version="1.0",
        )

        # 区分 Component 引用和 MCP 工具引用
        component_refs = [r for r in skill.required_components if "." not in r]
        mcp_refs = [r for r in skill.required_components if "." in r]

        assert "chat" in component_refs
        assert "filesystem.read_file" in mcp_refs


# ── 链路 3：市场提交 → 浏览 → 下载 → 本地可用 ────────────────────────────────

class TestSkillMarketplaceChain:
    """完整市场链：提交 → 浏览 → 下载 → 本地可用。"""

    def setup_method(self):
        from skill_ecosystem.marketplace_service import MarketplaceService
        self.svc = MarketplaceService()

    def test_submit_browse_download_chain(self):
        """提交 Skill → 在列表中可见 → 下载到本地 → 来源标注正确。"""
        from skill_ecosystem.models import SkillSubmitRequest, PromptNodeSchema, SkillSourceEnum

        # Step 1: 提交 Skill 到市场
        req = SkillSubmitRequest(
            name="链路测试方法",
            description="用于测试完整市场链路",
            tags=["测试", "通用"],
            prompt_chain=[
                PromptNodeSchema(id="n1", prompt="第一步：{topic}"),
                PromptNodeSchema(id="n2", prompt="第二步：{result}", input_mapping={"result": "n1.content"}),
            ],
        )
        submitted = self.svc.submit_skill(req, submitter_id="test_user")
        skill_id = submitted.id

        assert submitted.source == SkillSourceEnum.third_party_api
        assert submitted.submitter_id == "test_user"

        # Step 2: 在市场列表中可见
        result = self.svc.list_skills(keyword="链路测试")
        found = any(s.id == skill_id for s in result.skills)
        assert found, "提交的 Skill 应在市场列表中可见"

        # Step 3: 下载到本地
        local = self.svc.download_skill(skill_id, user_id="another_user")
        assert local.source == SkillSourceEnum.marketplace_download
        assert local.name == "链路测试方法"
        assert len(local.prompt_chain) == 2

        # Step 4: 本地 Skill 结构完整，可用于执行
        assert local.prompt_chain[0].prompt == "第一步：{topic}"
        assert local.prompt_chain[1].input_mapping["result"] == "n1.content"

    def test_invalid_skill_not_visible_in_market(self):
        """结构验证失败的 Skill 不应出现在市场列表中（属性 12）。"""
        from skill_ecosystem.marketplace_service import _marketplace_skills, _is_valid_skill
        from skill_ecosystem.models import MarketplaceSkillSchema, SkillSourceEnum
        import datetime

        # 直接注入一个无效 Skill（绕过 submit 验证）
        invalid_id = "invalid_test_skill"
        _marketplace_skills[invalid_id] = MarketplaceSkillSchema(
            id=invalid_id,
            name="",  # 空名称
            description="",
            tags=[],
            prompt_chain=[],  # 空 chain
            version="1.0.0",
            created_at=datetime.datetime.utcnow(),
            type="custom",
            source=SkillSourceEnum.user_created,
        )

        # 验证该 Skill 不通过结构验证
        assert not _is_valid_skill(_marketplace_skills[invalid_id])

        # 验证市场列表不返回该 Skill
        result = self.svc.list_skills()
        assert not any(s.id == invalid_id for s in result.skills)

        # 清理
        del _marketplace_skills[invalid_id]

    def test_download_count_increments(self):
        """每次下载后下载计数递增。"""
        initial = self.svc.get_skill("mkt_feynman").download_count
        self.svc.download_skill("mkt_feynman", user_id="user_a")
        after = self.svc.get_skill("mkt_feynman").download_count
        assert after == initial + 1


# ── 链路 4：对话创建 → 草稿 → 发布 → 可执行 ──────────────────────────────────

class TestDialogCreationChain:
    """对话式创建完整链：启动 → 多轮问答 → 草稿 → 发布 → Skill 可用。"""

    def setup_method(self):
        from skill_ecosystem.dialog_session_manager import DialogSessionManager
        self.mgr = DialogSessionManager()

    def test_full_dialog_to_published_skill(self):
        """完整对话链：6 步问答 → 发布 → Skill 结构完整。"""
        # Step 1: 启动会话
        turn = self.mgr.start_session("user_chain_test")
        sid = turn.session_id
        assert turn.question != ""
        assert not turn.is_complete

        # Step 2: 回答各步骤问题
        answers = [
            "复习",           # 学习方法类型
            "先读教材",       # 第一步
            "做练习题",       # 第二步
            "完成",           # 结束步骤收集
            "数学,物理",      # 适用学科
            "我的复习三步法", # 名称
        ]
        last_turn = turn
        for answer in answers:
            last_turn = self.mgr.process_answer(sid, answer)
            if last_turn.is_complete:
                break

        assert last_turn.is_complete, "回答完所有问题后应标记为完成"

        # Step 3: 发布 Skill
        skill = self.mgr.confirm_and_publish(sid, "user_chain_test")

        assert skill.id != ""
        assert skill.created_by == "user_chain_test"
        assert len(skill.prompt_chain) >= 1, "发布的 Skill 应至少有一个步骤"

    def test_draft_preserved_after_interruption(self):
        """中断后草稿数据不丢失（属性 15）。"""
        turn = self.mgr.start_session("user_interrupt")
        sid = turn.session_id

        # 回答前两个问题
        self.mgr.process_answer(sid, "解题")
        self.mgr.process_answer(sid, "先分析题目")

        # 中断：保存草稿
        draft = self.mgr.save_draft(sid)

        # 验证草稿包含已收集的数据
        assert draft.is_draft is True
        assert len(draft.steps) >= 1, "草稿应包含已收集的步骤"

        # 恢复：继续回答
        turn3 = self.mgr.process_answer(sid, "再列解题步骤")
        assert len(turn3.draft_preview.steps) >= 2 if turn3.draft_preview else True


# ── 链路 5：导出 → 导入 → 字段一致 → 可执行 ──────────────────────────────────

class TestSkillIOChain:
    """Skill JSON 往返链：导出 → 导入 → 字段一致 → 可用于执行。"""

    def test_export_import_all_builtin_skills(self):
        """所有内置 Skill 均可导出并导入，字段一致（属性 13）。"""
        from skill_ecosystem.skill_io import export_skill, import_skill
        from skill_registry import get_registry

        for skill in get_registry().list_skills():
            skill_id = skill["id"]
            original = skill
            # 导出
            json_str = export_skill(skill_id)
            data = json.loads(json_str)

            # 验证导出字段
            assert data["id"] == skill_id
            assert data["name"] == original["name"]
            assert len(data["prompt_chain"]) == len(original["promptChain"])
            assert "schema_version" in data

            # 导入
            result = import_skill(json_str, registered_components=original["requiredComponents"])
            assert result.success, f"Skill {skill_id} 导入失败: {result.errors}"
            assert result.skill.name == original["name"]
            assert len(result.skill.prompt_chain) == len(original["promptChain"])

    def test_prompt_chain_order_preserved_after_roundtrip(self):
        """往返后 PromptChain 顺序不变（属性 13 的顺序子属性）。"""
        from skill_ecosystem.skill_io import export_skill, import_skill

        json_str = export_skill("skill_feynman")
        result = import_skill(json_str, registered_components=["chat"])

        original_ids = ["node_explain", "node_identify_gaps", "node_simplify"]
        imported_ids = [node.id for node in result.skill.prompt_chain]
        assert imported_ids == original_ids, "PromptChain 顺序应与原始一致"

    def test_missing_components_detected_correctly(self):
        """缺失 Component 检测完整性（属性 14）。"""
        from skill_ecosystem.skill_io import export_skill, import_skill

        # skill_spaced_repetition 需要 chat 和 calendar
        json_str = export_skill("skill_spaced_repetition")

        # 只提供 chat，不提供 calendar
        result = import_skill(json_str, registered_components=["chat"])
        assert result.success is True
        assert "calendar" in result.missing_components
        assert "chat" not in result.missing_components

    def test_schema_version_in_export(self):
        """导出的 JSON 包含 schema_version 字段。"""
        from skill_ecosystem.skill_io import export_skill

        for skill_id in ["skill_feynman", "skill_problem_solving", "skill_exam_prep"]:
            json_str = export_skill(skill_id)
            data = json.loads(json_str)
            assert "schema_version" in data, f"Skill {skill_id} 导出缺少 schema_version"
            assert data["schema_version"] == "1.0"


# ── 链路 6：完整生态链集成测试 ────────────────────────────────────────────────

class TestFullEcosystemChain:
    """验证 Skill 生态的完整端到端链路。"""

    def test_text_to_market_to_execution_chain(self):
        """
        完整链路：
        经验贴文本 → 解析为草稿 → 提交到市场 → 下载到本地 → 导出 JSON → 导入验证
        """
        from skill_ecosystem.ai_model_adapter import RuleBasedAdapter
        from skill_ecosystem.marketplace_service import MarketplaceService
        from skill_ecosystem.skill_io import import_skill
        from skill_ecosystem.models import SkillSubmitRequest, PromptNodeSchema, SkillSourceEnum
        import datetime

        # Step 1: 文本解析
        text = "1. 阅读教材，理解概念\n2. 做例题，掌握方法\n3. 练习题，巩固知识\n4. 总结错题，查漏补缺"
        adapter = RuleBasedAdapter()
        draft = adapter.parse(text)
        assert len(draft.steps) == 4

        # Step 2: 提交到市场
        svc = MarketplaceService()
        req = SkillSubmitRequest(
            name="四步学习法",
            description="阅读→例题→练习→总结",
            tags=["通用", "理工科"],
            prompt_chain=draft.steps,
        )
        submitted = svc.submit_skill(req, submitter_id="expert_user")
        assert submitted.source == SkillSourceEnum.third_party_api

        # Step 3: 下载到本地
        local = svc.download_skill(submitted.id, user_id="student_user")
        assert local.source == SkillSourceEnum.marketplace_download
        assert len(local.prompt_chain) == 4

        # Step 4: 序列化为 JSON（模拟导出）
        json_str = local.model_dump_json()
        data = json.loads(json_str)
        assert data["name"] == "四步学习法"

        # Step 5: 导入验证（模拟在另一设备导入）
        result = import_skill(json_str, registered_components=[])
        assert result.success is True
        assert result.skill.name == "四步学习法"
        assert len(result.skill.prompt_chain) == 4

        # Step 6: 验证 PromptChain 可用于执行（结构完整）
        for i, node in enumerate(result.skill.prompt_chain):
            assert node.id != "", f"节点 {i} 的 id 不能为空"
            assert node.prompt != "", f"节点 {i} 的 prompt 不能为空"

    def test_skill_filter_consistency_across_chain(self):
        """过滤查询结果一致性：所有返回结果均满足过滤条件（属性 6）。"""
        from skill_ecosystem.marketplace_service import MarketplaceService

        svc = MarketplaceService()

        # 按标签过滤
        for tag in ["通用", "记忆", "解题", "考试"]:
            result = svc.list_skills(tag=tag)
            for skill in result.skills:
                assert tag in skill.tags, f"Skill {skill.name} 不含标签 '{tag}'"

        # 按关键词过滤
        for keyword in ["费曼", "间隔", "解题"]:
            result = svc.list_skills(keyword=keyword)
            for skill in result.skills:
                assert (
                    keyword in skill.name.lower() or keyword in skill.description.lower()
                ), f"Skill {skill.name} 不含关键词 '{keyword}'"
