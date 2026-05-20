"""
SolveProblemExecutor — 工业级多模态解题执行器。

流水线：
  1. OCR 预处理（仅首次解题；追问时 history 非空则跳过，节省 Token）
     PaddleOCR-VL-1.5 → 降级到通用 LLM 视觉 → 均失败抛 RuntimeError
  2. Prompt 组装（OCR 文本 + 用户补充说明）
  3. 流式推理（LLM_HEAVY_MODEL 优先，回退到 LLM_CHAT_MODEL）
  4. SSE 推送（JSON 化，防止 token 内含换行符导致协议截断）

SSE 格式（所有推送均为 JSON）：
  data: {"content": "<token>"}\n\n
  data: {"content": "[DONE]", "session_id": <session_id>}\n\n
  data: {"content": "[ERROR]", "error": "<message>"}\n\n
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
from datetime import datetime

from fastapi.responses import StreamingResponse

from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

logger = logging.getLogger(__name__)

_STREAM_END = object()


async def _async_iter_sync_stream(sync_gen):
    """将 LLMService.stream_chat 的同步生成器适配为 async for（避免阻塞事件循环）。"""
    loop = asyncio.get_event_loop()
    it = iter(sync_gen)

    def _next() -> object:
        try:
            return next(it)
        except StopIteration:
            return _STREAM_END

    while True:
        item = await loop.run_in_executor(None, _next)
        if item is _STREAM_END:
            break
        yield item


def build_solve_prompt(ocr_text: str, supplement_text: str) -> str:
    """
    组装解题 Prompt（纯函数，便于属性测试）。

    :param ocr_text: OCR 识别文本
    :param supplement_text: 用户补充说明（空字符串时省略该段落）
    :return: 组装后的用户消息内容
    """
    content = f"【题目图片识别内容】\n{ocr_text}"
    if supplement_text:
        content += f"\n\n【补充说明】\n{supplement_text}"
    return content


def _generate_title(ocr_text: str) -> str:
    """
    根据 OCR 文本生成会话标题（纯函数，便于属性测试）。

    - OCR 文本非空时：取前 15 字符，超过 15 字符追加"…"
    - OCR 文本为空/纯空白时：返回 f"解题记录 {datetime.now().strftime('%m-%d %H:%M')}"
    """
    if not ocr_text or not ocr_text.strip():
        return f"解题记录 {datetime.now().strftime('%m-%d %H:%M')}"
    stripped = ocr_text.strip()
    title = stripped[:15]
    if len(stripped) > 15:
        title += "…"
    return title


async def _create_solve_session(user_id: int, ocr_text: str) -> int:
    """
    在 conversation_sessions 表中插入 session_type='solve' 记录。
    标题由 _generate_title(ocr_text) 生成。
    返回新建的 session_id（int）。
    数据库操作在线程池中执行，避免阻塞事件循环。
    """
    from database import ConversationSession, get_session

    title = _generate_title(ocr_text)

    def _db_insert():
        with get_session() as db:
            session = ConversationSession(
                user_id=user_id,
                session_type="solve",
                title=title,
            )
            db.add(session)
            db.flush()
            session_id = session.id
            return session_id

    loop = asyncio.get_event_loop()
    session_id = await loop.run_in_executor(None, _db_insert)
    return session_id


async def _persist_conversation(
    session_id: int,
    user_content: str,
    assistant_content: str,
    images: list[str],
) -> None:
    """
    向 conversation_history 表写入两条记录：
      - role='user'，content=user_content，sources={"images": images}（images 非空时）
      - role='assistant'，content=assistant_content，sources=None
    失败时记录 ERROR 日志，不抛出异常。
    数据库操作在线程池中执行，避免阻塞事件循环。
    """
    from database import ConversationHistory, get_session

    def _db_write():
        sources = {"images": images} if images else None
        with get_session() as db:
            db.add(ConversationHistory(
                session_id=session_id,
                role="user",
                content=user_content,
                sources=sources,
            ))
            db.add(ConversationHistory(
                session_id=session_id,
                role="assistant",
                content=assistant_content,
                sources=None,
            ))

    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _db_write)
    except Exception as e:
        logger.error("持久化对话记录失败 session_id=%s: %s", session_id, e)


_SOLVE_SYSTEM_PROMPT = """你是一位专业的学科辅导老师。请对题目进行详细解析，严格按以下 Markdown 结构输出：

## 考点分析
（分析本题涉及的知识点和考查方向）

## 解题步骤
（逐步详细推导，数学公式使用 LaTeX 格式：行内用 $...$，独立公式用 $$...$$）

## 最终答案
（给出简洁明确的最终结果）

要求：思路清晰，步骤完整，适合学生理解。

你可以调用 python_executor 工具进行精确数值计算，避免手动计算出错。
适用场景：积分、方程求解、矩阵运算、数值模拟、绘制函数图像。
调用格式：工具名 python_executor.execute，参数 {"code": "Python代码字符串"}
支持的库：sympy（符号计算）、numpy（数值计算）、scipy（科学计算）、matplotlib（图表生成）。
注意：禁止在代码中访问文件系统和网络。"""


async def _handle_python_tool_call(tool_arguments: dict) -> dict:
    """
    处理 python_executor function calling 工具调用。
    调用 MCPRegistry 执行 Python 代码，返回执行结果。
    失败时返回含降级提示的错误结构，不抛出异常。
    """
    try:
        from mcp_layer.mcp_registry import get_registry
        registry = get_registry()
        result = registry.call_tool(
            "python_executor.execute",
            arguments=tool_arguments,
            timeout_seconds=12.0,
        )
        if result.success:
            text = result.data.get("text", "{}")
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                return {"stdout": text, "stderr": "", "image_base64": None}
        else:
            return {
                "stdout": "",
                "stderr": f"工具调用失败：{result.error_message}，请改用纯文字推理",
                "image_base64": None,
            }
    except Exception as e:
        logger.warning("solve_problem: python_executor 调用异常: %s", e)
        return {
            "stdout": "",
            "stderr": f"工具调用异常：{e}，请改用纯文字推理",
            "image_base64": None,
        }


@register_executor("solve_problem")
async def solve_problem_executor(params: dict, user_id: int) -> StreamingResponse:
    """
    多模态解题执行器，返回 SSE 流式响应。

    params 字段：
      - images: list[str]       Base64 图片列表（首次解题时必须）
      - supplement_text: str    用户补充说明（可选）
      - history: list[dict]     追问历史消息（追问时非空，跳过 OCR）
      - session_id: int|None    会话 ID（首次解题时为 None，追问时传入已有 session_id）
    """
    from backend_config import get_config
    from services.llm_service import LLMService
    from services.ocr_service import OCRService

    config = get_config()
    images: list[str] = params.get("images") or []
    supplement_text: str = params.get("supplement_text") or ""
    history: list[dict] = params.get("history") or []
    # session_id 可能为 None（首次解题）或 int（追问时复用）
    session_id: int | None = params.get("session_id") or None

    # ── 1. OCR 阶段 ──────────────────────────────────────────────────────────
    # 追问时 history 非空，跳过 OCR，直接复用历史上下文，节省大量 Token 成本
    ocr_text = ""
    ocr_ms = 0.0
    if not history and images:
        ocr_start = time.monotonic()
        try:
            ocr_service = OCRService()
            ocr_text = await ocr_service.extract_text_from_base64_list(images)
        except RuntimeError as e:
            # OCR 完全失败时，通过 SSE 推送错误并关闭流
            error_msg = str(e)
            logger.error("solve_problem: OCR 失败 session=%s error=%s", session_id, error_msg)

            async def _error_stream():
                yield f"data: {json.dumps({'content': '[ERROR]', 'error': error_msg}, ensure_ascii=False)}\n\n"

            return StreamingResponse(_error_stream(), media_type="text/event-stream")
        ocr_ms = (time.monotonic() - ocr_start) * 1000
        logger.info(
            "solve_problem: OCR完成 session=%s images=%d ocr_ms=%.1f",
            session_id, len(images), ocr_ms,
        )

    # ── 1.5 会话管理 ─────────────────────────────────────────────────────────
    # 首次解题（session_id 为 None）：OCR 完成后创建会话
    # 追问时（session_id 非 None）：直接复用传入的 session_id
    if session_id is None:
        try:
            session_id = await _create_solve_session(user_id, ocr_text)
            logger.info("solve_problem: 创建会话 session_id=%s user_id=%s", session_id, user_id)
        except Exception as e:
            logger.error("solve_problem: 创建会话失败 user_id=%s error=%s", user_id, e)
            # 创建会话失败时继续流程，session_id 保持 None，不中断 SSE 流

    # ── 2. Prompt 组装 ────────────────────────────────────────────────────────
    if not history:
        # 首次解题：用 OCR 文本 + 补充说明组装用户消息
        user_content = build_solve_prompt(ocr_text, supplement_text)
    else:
        # 追问：直接使用用户追问文字，历史上下文已含原题信息
        user_content = supplement_text or "请继续解答"

    # ── 3. 构建消息列表 ───────────────────────────────────────────────────────
    messages: list[dict] = [{"role": "system", "content": _SOLVE_SYSTEM_PROMPT}]
    messages.extend(history)          # 追问历史（首次解题时为空列表）
    messages.append({"role": "user", "content": user_content})

    # ── 4. 流式推理 + SSE 推送 ────────────────────────────────────────────────
    heavy_model = config.LLM_HEAVY_MODEL or config.LLM_CHAT_MODEL

    # 捕获 session_id 到闭包（可能在创建会话失败时为 None）
    _session_id = session_id

    async def generate_sse():
        reasoning_start = time.monotonic()
        token_count = 0
        full_response_parts: list[str] = []
        # 代码块检测缓冲区（用于检测 ```python ... ``` 块）
        code_block_buffer = ""
        in_code_block = False

        try:
            stream = LLMService().stream_chat(
                messages,
                model=heavy_model,
                max_tokens=config.SOLVE_REASONING_MAX_TOKENS,
            )
            async for token in _async_iter_sync_stream(stream):
                # ── Function calling 路径 ────────────────────────────────────
                # 部分 LLM 服务会在 token 中返回 function_call 结构
                if isinstance(token, dict) and token.get("type") == "function_call":
                    tool_name = token.get("name", "")
                    tool_args = token.get("arguments", {})
                    if tool_name in ("python_executor.execute", "execute"):
                        tool_result = await _handle_python_tool_call(tool_args)
                        # 推送图表事件
                        if tool_result.get("image_base64"):
                            chart_event = {
                                "content": "[CHART]",
                                "image_base64": tool_result["image_base64"],
                            }
                            yield f"data: {json.dumps(chart_event, ensure_ascii=False)}\n\n"
                        # 将执行结果注入消息上下文（追加 tool 角色消息）
                        tool_output = f"计算结果：\n{tool_result.get('stdout', '')}"
                        if tool_result.get("stderr"):
                            tool_output += f"\n错误：{tool_result['stderr']}"
                        messages.append({"role": "assistant", "content": tool_output})
                    continue

                # ── 普通 token 路径 ──────────────────────────────────────────
                token_str = token if isinstance(token, str) else str(token)
                token_count += 1
                full_response_parts.append(token_str)

                # ── 代码块检测路径 ───────────────────────────────────────────
                # 检测 ```python ... ``` 块，自动执行并注入结果
                code_block_buffer += token_str
                if "```python" in code_block_buffer and not in_code_block:
                    in_code_block = True
                if in_code_block and "```" in code_block_buffer.split("```python", 1)[-1]:
                    # 提取代码块内容
                    try:
                        code_section = code_block_buffer.split("```python", 1)[1]
                        if "```" in code_section:
                            code = code_section.split("```", 1)[0].strip()
                            if code:
                                tool_result = await _handle_python_tool_call({"code": code})
                                if tool_result.get("image_base64"):
                                    chart_event = {
                                        "content": "[CHART]",
                                        "image_base64": tool_result["image_base64"],
                                    }
                                    yield f"data: {json.dumps(chart_event, ensure_ascii=False)}\n\n"
                                # 将执行结果追加到输出
                                if tool_result.get("stdout"):
                                    result_token = f"\n\n**计算结果：**\n```\n{tool_result['stdout']}\n```\n"
                                    full_response_parts.append(result_token)
                                    yield f"data: {json.dumps({'content': result_token}, ensure_ascii=False)}\n\n"
                    except Exception as e:
                        logger.warning("solve_problem: 代码块检测执行失败: %s", e)
                    in_code_block = False
                    code_block_buffer = ""

                # ⚠️ 强制 JSON 序列化：防止 token 内含换行符导致 SSE 协议截断
                yield f"data: {json.dumps({'content': token_str}, ensure_ascii=False)}\n\n"

            reasoning_ms = (time.monotonic() - reasoning_start) * 1000
            logger.info(
                "solve_problem: 推理完成 session=%s tokens=%d "
                "ocr_ms=%.1f reasoning_ms=%.1f image_count=%d",
                _session_id, token_count, ocr_ms, reasoning_ms, len(images),
            )

            # [DONE] 事件携带 session_id 字段
            done_payload = {"content": "[DONE]", "session_id": _session_id}
            yield f"data: {json.dumps(done_payload, ensure_ascii=False)}\n\n"

            # SSE 流完成后异步持久化，不阻塞 SSE 流
            if _session_id is not None:
                assistant_content = "".join(full_response_parts)
                asyncio.create_task(
                    _persist_conversation(
                        session_id=_session_id,
                        user_content=user_content,
                        assistant_content=assistant_content,
                        images=images,
                    )
                )

        except Exception as e:
            logger.error("solve_problem: 推理异常 session=%s error=%s", _session_id, e)
            # SSE 流出错时跳过持久化
            yield f"data: {json.dumps({'content': '[ERROR]', 'error': str(e)}, ensure_ascii=False)}\n\n"

    return StreamingResponse(generate_sse(), media_type="text/event-stream")
