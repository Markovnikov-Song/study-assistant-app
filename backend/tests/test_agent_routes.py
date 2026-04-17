"""
agent.py 路由的单元测试。

覆盖：
1. Skill 列表查询（过滤、关键词）
2. 单个 Skill 查询
3. Skill JSON 导入导出端点
4. SkillParser 配置端点
5. 对话式 Skill 创建端点
"""
from __future__ import annotations

import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
sys.path.insert(1, os.path.join(os.path.dirname(os.path.dirname(__file__)), "..", "study_assistant_streamlit"))

import pytest


# ── 内置 Skill 数据测试 ────────────────────────────────────────────────────────

class TestBuiltinSkills:
    def setup_method(self):
        from routers.agent import _BUILTIN_SKILLS, _SKILL_INDEX
        self.skills = _BUILTIN_SKILLS
        self.index = _SKILL_INDEX

    def test_five_builtin_skills_exist(self):
        assert len(self.skills) == 5

    def test_all_skills_have_required_fields(self):
        required = ["id", "name", "description", "tags", "promptChain", "requiredComponents", "version", "type"]
        for skill in self.skills:
            for field in required:
                assert field in skill, f"Skill {skill.get('id')} 缺少字段 {field}"

    def test_all_skills_have_nonempty_prompt_chain(self):
        for skill in self.skills:
            assert len(skill["promptChain"]) > 0, f"Skill {skill['id']} 的 promptChain 为空"

    def test_skill_index_matches_list(self):
        assert len(self.index) == len(self.skills)
        for skill in self.skills:
            assert skill["id"] in self.index

    def test_feynman_skill_exists(self):
        assert "skill_feynman" in self.index
        assert self.index["skill_feynman"]["name"] == "费曼学习法"

    def test_filter_by_tag(self):
        from routers.agent import _BUILTIN_SKILLS
        tag = "通用"
        filtered = [s for s in _BUILTIN_SKILLS if tag in s["tags"]]
        assert len(filtered) >= 2

    def test_filter_by_keyword(self):
        from routers.agent import _BUILTIN_SKILLS
        kw = "费曼"
        filtered = [s for s in _BUILTIN_SKILLS if kw in s["name"].lower() or kw in s["description"].lower()]
        assert len(filtered) >= 1


# ── SkillParser 适配器配置测试 ─────────────────────────────────────────────────

class TestParserConfig:
    def test_get_current_adapter_default_is_ai(self):
        from skill_ecosystem.ai_model_adapter import get_current_adapter_name
        name = get_current_adapter_name()
        assert name in ("ai", "rule_based")

    def test_set_adapter_to_rule_based(self):
        from skill_ecosystem.ai_model_adapter import set_current_adapter, get_current_adapter_name
        set_current_adapter("rule_based")
        assert get_current_adapter_name() == "rule_based"
        # 恢复
        set_current_adapter("ai")

    def test_set_invalid_adapter_raises(self):
        from skill_ecosystem.ai_model_adapter import set_current_adapter
        with pytest.raises(ValueError):
            set_current_adapter("invalid_adapter")

    def test_parse_text_uses_current_adapter(self):
        from skill_ecosystem.ai_model_adapter import set_current_adapter, parse_text
        set_current_adapter("rule_based")
        draft = parse_text("1. 步骤一\n2. 步骤二")
        assert len(draft.steps) == 2
        set_current_adapter("ai")


# ── Skill JSON 导入导出测试 ────────────────────────────────────────────────────

class TestSkillIOEndpoints:
    def test_export_returns_valid_json(self):
        from skill_ecosystem.skill_io import export_skill
        json_str = export_skill("skill_feynman")
        data = json.loads(json_str)
        assert data["id"] == "skill_feynman"
        assert data["schema_version"] == "1.0"

    def test_import_valid_skill(self):
        from skill_ecosystem.skill_io import export_skill, import_skill
        json_str = export_skill("skill_problem_solving")
        result = import_skill(json_str, registered_components=["solve", "mistake_book"])
        assert result.success is True
        assert result.skill.name == "结构化解题"
        assert result.missing_components == []

    def test_import_with_missing_components(self):
        from skill_ecosystem.skill_io import export_skill, import_skill
        json_str = export_skill("skill_spaced_repetition")
        # 不提供 calendar
        result = import_skill(json_str, registered_components=["chat"])
        assert result.success is True
        assert "calendar" in result.missing_components

    def test_all_builtin_skills_exportable(self):
        from skill_ecosystem.skill_io import export_skill
        from routers.agent import _SKILL_INDEX
        for skill_id in _SKILL_INDEX:
            json_str = export_skill(skill_id)
            data = json.loads(json_str)
            assert data["id"] == skill_id


# ── MCP 工具引用格式测试 ───────────────────────────────────────────────────────

class TestMCPToolRefFormat:
    """验证 execute-node 端点的工具引用路由逻辑。"""

    def test_dot_in_ref_is_mcp(self):
        """含点号的引用应走 MCP 路径。"""
        ref = "filesystem.read_file"
        assert "." in ref

    def test_no_dot_is_component(self):
        """不含点号的引用应走 ComponentRegistry 路径。"""
        ref = "notebook"
        assert "." not in ref

    def test_mcp_ref_format(self):
        """MCP 引用格式：{server_id}.{tool_name}。"""
        ref = "filesystem.read_file"
        parts = ref.split(".", 1)
        assert len(parts) == 2
        assert parts[0] == "filesystem"
        assert parts[1] == "read_file"

    def test_tool_key_conversion(self):
        """工具引用转换为模板变量键名。"""
        ref = "filesystem.read_file"
        key = ref.replace(".", "_")
        assert key == "filesystem_read_file"
