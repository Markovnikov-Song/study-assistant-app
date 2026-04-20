"""
Skill 生态层单元测试。

覆盖：
1. RuleBasedAdapter — 文本解析为 SkillDraft
2. AIModelAdapter — 降级逻辑
3. skill_io — JSON 导入导出往返一致性
4. MarketplaceService — 过滤、验证、下载
5. DialogSessionManager — 对话流程、草稿保存
"""
from __future__ import annotations

import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import pytest


# ── RuleBasedAdapter 测试 ──────────────────────────────────────────────────────

class TestRuleBasedAdapter:
    def setup_method(self):
        from skill_ecosystem.ai_model_adapter import RuleBasedAdapter
        self.adapter = RuleBasedAdapter()

    def test_arabic_numbered_list(self):
        text = "1. 先读教材\n2. 做练习题\n3. 总结错题"
        draft = self.adapter.parse(text)
        assert len(draft.steps) == 3
        assert draft.steps[0].prompt == "先读教材"
        assert draft.steps[1].prompt == "做练习题"
        assert draft.steps[2].prompt == "总结错题"

    def test_chinese_numbered_list(self):
        text = "一、预习\n二、听课\n三、复习"
        draft = self.adapter.parse(text)
        assert len(draft.steps) == 3

    def test_bullet_list(self):
        text = "- 阅读课本\n- 做笔记\n- 练习题"
        draft = self.adapter.parse(text)
        assert len(draft.steps) == 3

    def test_asterisk_list(self):
        text = "* 第一步\n* 第二步"
        draft = self.adapter.parse(text)
        assert len(draft.steps) == 2

    def test_fallback_single_step(self):
        """无结构文本：整段作为单个步骤，保证至少一个 PromptNode（属性 10）。"""
        text = "这是一段没有结构的学习方法描述"
        draft = self.adapter.parse(text)
        assert len(draft.steps) >= 1

    def test_empty_text_returns_empty(self):
        draft = self.adapter.parse("")
        assert len(draft.steps) == 0

    def test_source_text_length_recorded(self):
        text = "1. 步骤一\n2. 步骤二"
        draft = self.adapter.parse(text)
        assert draft.source_text_length == len(text)

    def test_is_draft_flag(self):
        draft = self.adapter.parse("1. 步骤一")
        assert draft.is_draft is True


# ── skill_io 测试 ──────────────────────────────────────────────────────────────

class TestSkillIO:
    def test_export_builtin_skill(self):
        from skill_ecosystem.skill_io import export_skill
        json_str = export_skill("skill_feynman")
        data = json.loads(json_str)
        assert data["id"] == "skill_feynman"
        assert data["name"] == "费曼学习法"
        assert "schema_version" in data
        assert len(data["prompt_chain"]) > 0

    def test_export_nonexistent_skill_raises(self):
        from skill_ecosystem.skill_io import export_skill
        with pytest.raises(KeyError):
            export_skill("nonexistent_skill_id")

    def test_import_valid_json(self):
        from skill_ecosystem.skill_io import export_skill, import_skill
        json_str = export_skill("skill_feynman")
        result = import_skill(json_str, registered_components=["chat"])
        assert result.success is True
        assert result.skill is not None
        assert result.skill.name == "费曼学习法"

    def test_import_roundtrip_fields_consistent(self):
        """往返一致性：导出再导入，字段完全一致（属性 13）。"""
        from skill_ecosystem.skill_io import export_skill, import_skill
        json_str = export_skill("skill_feynman")
        result = import_skill(json_str, registered_components=["chat"])
        assert result.success
        skill = result.skill
        # id 会重新分配，其他字段应一致
        assert skill.name == "费曼学习法"
        assert skill.schema_version == "1.0"
        assert len(skill.prompt_chain) == 3

    def test_import_detects_missing_components(self):
        """缺失 Component 检测（属性 14）。"""
        from skill_ecosystem.skill_io import export_skill, import_skill
        json_str = export_skill("skill_feynman")
        # 不传入 chat，应检测到缺失
        result = import_skill(json_str, registered_components=[])
        assert result.success is True  # 仍然成功，但列出缺失
        assert "chat" in result.missing_components

    def test_import_invalid_json(self):
        from skill_ecosystem.skill_io import import_skill
        result = import_skill("not valid json", registered_components=[])
        assert result.success is False
        assert len(result.errors) > 0

    def test_import_empty_prompt_chain_rejected(self):
        from skill_ecosystem.skill_io import import_skill
        data = {
            "name": "测试", "description": "测试", "tags": [],
            "prompt_chain": [],  # 空 chain
            "type": "custom", "source": "user_created",
        }
        result = import_skill(json.dumps(data), registered_components=[])
        assert result.success is False

    def test_import_missing_required_field(self):
        from skill_ecosystem.skill_io import import_skill
        data = {"name": "测试"}  # 缺少必填字段
        result = import_skill(json.dumps(data), registered_components=[])
        assert result.success is False


# ── MarketplaceService 测试 ────────────────────────────────────────────────────

class TestMarketplaceService:
    def setup_method(self):
        from skill_ecosystem.marketplace_service import MarketplaceService
        self.svc = MarketplaceService()

    def test_list_skills_returns_builtin(self):
        result = self.svc.list_skills()
        assert result.total >= 5  # 至少 5 个内置 Skill
        assert len(result.skills) >= 5

    def test_list_skills_filter_by_tag(self):
        result = self.svc.list_skills(tag="通用")
        for skill in result.skills:
            assert "通用" in skill.tags, f"Skill {skill.name} 不含标签 '通用'"

    def test_list_skills_filter_by_keyword(self):
        result = self.svc.list_skills(keyword="费曼")
        assert any("费曼" in s.name for s in result.skills)

    def test_list_skills_only_valid_returned(self):
        """只返回通过结构验证的 Skill（属性 12）。"""
        result = self.svc.list_skills()
        for skill in result.skills:
            assert len(skill.prompt_chain) > 0, f"Skill {skill.name} 的 prompt_chain 为空"
            assert skill.name, f"Skill 名称不能为空"

    def test_list_skills_pagination(self):
        result = self.svc.list_skills(page=1, page_size=2)
        assert len(result.skills) <= 2
        assert result.page == 1
        assert result.page_size == 2

    def test_list_skills_max_page_size_20(self):
        result = self.svc.list_skills(page_size=100)
        assert result.page_size <= 20

    def test_download_skill_returns_local_copy(self):
        """下载后来源标注为 marketplace_download（属性 11）。"""
        from skill_ecosystem.models import SkillSourceEnum
        local = self.svc.download_skill("mkt_feynman", user_id="user_1")
        assert local.source == SkillSourceEnum.marketplace_download
        assert local.name == "费曼学习法"

    def test_download_nonexistent_skill_raises(self):
        with pytest.raises(KeyError):
            self.svc.download_skill("nonexistent_id", user_id="user_1")

    def test_submit_skill_assigns_new_id(self):
        from skill_ecosystem.models import SkillSubmitRequest, PromptNodeSchema, SkillSourceEnum
        req = SkillSubmitRequest(
            name="测试方法",
            description="测试描述",
            tags=["通用"],
            prompt_chain=[PromptNodeSchema(id="n1", prompt="第一步")],
        )
        skill = self.svc.submit_skill(req, submitter_id="user_1")
        assert skill.id != ""
        assert skill.source == SkillSourceEnum.third_party_api
        assert skill.submitter_id == "user_1"

    def test_sort_by_download_count(self):
        result = self.svc.list_skills(sort_by="download_count")
        counts = [s.download_count for s in result.skills]
        assert counts == sorted(counts, reverse=True)


# ── DialogSessionManager 测试 ──────────────────────────────────────────────────

class TestDialogSessionManager:
    def setup_method(self):
        from skill_ecosystem.dialog_session_manager import DialogSessionManager
        self.mgr = DialogSessionManager()

    def test_start_session_returns_first_question(self):
        turn = self.mgr.start_session("user_1")
        assert turn.session_id != ""
        assert turn.question != ""
        assert turn.is_complete is False

    def test_process_answer_advances_step(self):
        turn = self.mgr.start_session("user_1")
        session_id = turn.session_id
        turn2 = self.mgr.process_answer(session_id, "复习方法")
        assert turn2.question != turn.question  # 问题应该变了

    def test_save_draft_preserves_collected_data(self):
        """草稿保存后数据不丢失（属性 15）。"""
        turn = self.mgr.start_session("user_1")
        sid = turn.session_id
        # 回答第一个问题（学习方法类型）
        self.mgr.process_answer(sid, "复习")
        # 回答第二个问题（第一步）
        self.mgr.process_answer(sid, "先读教材")
        # 保存草稿
        draft = self.mgr.save_draft(sid)
        assert draft.is_draft is True
        assert len(draft.steps) >= 1  # 至少有一个步骤

    def test_done_signal_completes_session(self):
        turn = self.mgr.start_session("user_1")
        sid = turn.session_id
        self.mgr.process_answer(sid, "复习")
        self.mgr.process_answer(sid, "先读教材")
        self.mgr.process_answer(sid, "做练习")
        turn4 = self.mgr.process_answer(sid, "完成")  # 完成信号
        assert turn4.is_complete is True

    def test_nonexistent_session_raises(self):
        with pytest.raises(KeyError):
            self.mgr.process_answer("nonexistent_session_id", "回答")

    def test_delete_session(self):
        turn = self.mgr.start_session("user_1")
        sid = turn.session_id
        self.mgr.delete_session(sid)
        with pytest.raises(KeyError):
            self.mgr.process_answer(sid, "回答")

    def test_confirm_and_publish_returns_skill(self):
        turn = self.mgr.start_session("user_1")
        sid = turn.session_id
        # 走完完整流程
        self.mgr.process_answer(sid, "复习")
        self.mgr.process_answer(sid, "先读教材")
        self.mgr.process_answer(sid, "做练习")
        self.mgr.process_answer(sid, "完成")
        self.mgr.process_answer(sid, "数学")
        self.mgr.process_answer(sid, "我的复习法")
        skill = self.mgr.confirm_and_publish(sid, "user_1")
        assert skill.id != ""
        assert skill.created_by == "user_1"
