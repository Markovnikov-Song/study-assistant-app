# 项目知识库

## 项目概述
- 项目名称：学伴 App (study_assistant_app)
- 技术栈：Flutter + FastAPI
- 项目路径：`C:\Users\41100\develop\study_assistant_app`

## 架构
- Flutter 前端：`lib/` 目录
- API 服务：`api/` 目录（FastAPI）
- 后端服务：`backend/` 目录（FastAPI）
- 部署环境：学校服务器 222.206.4.177:8000，CentOS7+conda+Neon PG

## 安全配置（重要）
- JWT_SECRET：必须设置环境变量，至少32字符
- CORS_ALLOWED_ORIGINS：生产环境需配置允许的域名列表
- 支付回调需验证签名和来源IP

### 安全状态（2026-04-25 审计后）
- ✅ 已完成安全审计，修复7个漏洞
- ✅ 新增 `api/security.py`（管理员验证+限流）
- ✅ 新增 `api/security_headers.py`（安全响应头）
- ✅ 完整报告见 `docs/SECURITY_AUDIT_REPORT.md`

## 技术债务
- 需要添加用户角色表到数据库，支持管理员权限管理
- LLM API 限流机制待完善
- 支付签名验证需接入支付宝/微信 SDK

## MindMap 生成架构（2026-04-25）
- `structure_extractor.py`：规则驱动的文档骨架提取（零LLM调用）
  - 支持：Markdown、中文编号(第X章)、数字编号(1.1.1)、英文论文(1. Introduction)、PPT短行启发式
  - TF-IDF关键句提取、公式密度/定义/例题检测、章节重要性评分
- `mindmap_service.py`：两阶段生成（fast→JSON → heavy→markmap）+ 后处理校验
  - 降级策略：fast不可用→单次生成，无骨架→均匀采样
  - 后处理：层级修正、节点截断、噪音过滤、去重
- 零外部依赖（无jieba），纯标准库实现
