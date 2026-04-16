# Implementation Plan: Lecture Book Export（讲义导出为书）

## Overview

Backend-first implementation: LaTeX renderer → BookExporter services → API route, then Flutter UI (dialog + service + entry point integration). Property-based tests are co-located with each component.

## Tasks

- [x] 1. Implement `LatexRenderer` service
  - [x] 1.1 Create `backend/services/latex_renderer.py` with `LatexRenderer` class
    - Implement `render(latex: str, display: bool = False) -> bytes | None` using `matplotlib` mathtext
    - Use `io.BytesIO` to capture PNG output; return `None` on any exception
    - Initialize `self._cache: dict[str, bytes] = {}` in `__init__`; check cache before rendering; store result after successful render
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 1.2 Write property test for LaTeX cache idempotency (Property 5)
    - **Property 5: LaTeX 渲染缓存幂等性**
    - Generate random lists of LaTeX strings with duplicates using `hypothesis`; assert `render()` actual render calls == unique string count
    - Tag: `# Feature: lecture-book-export, Property 5: LaTeX 缓存幂等性`
    - **Validates: Requirements 6.4**

  - [x] 1.3 Write unit tests for `LatexRenderer`
    - Test successful render returns `bytes`; test failure returns `None`; test cache hit skips re-render
    - _Requirements: 6.3, 6.4_

- [x] 2. Implement `BookExporter` base and data models
  - [x] 2.1 Create `backend/services/book_exporter.py` with `NodeInfo` dataclass and `BookExporter` abstract base class
    - Define `NodeInfo(node_id: str, text: str, depth: int, blocks: list[dict])`
    - Define `TocEntry(title: str, depth: int, page: int, anchor: str)`
    - Define abstract `build(session_title, nodes, include_toc) -> bytes`
    - Add shared helper `_filter_nodes(nodes)` that removes nodes with empty `blocks`
    - _Requirements: 2.3, 3.1, 3.2_

  - [x] 2.2 Write property test for silent node filtering (Property 2)
    - **Property 2: 无讲义节点静默跳过**
    - Generate random node lists with random subset marked as empty blocks; assert output section count == nodes-with-blocks count and no empty-node titles appear in output
    - Tag: `# Feature: lecture-book-export, Property 2: 无讲义节点静默跳过`
    - **Validates: Requirements 2.3**

- [x] 3. Implement `PdfBookExporter`
  - [x] 3.1 Add Chinese font loading logic in `PdfBookExporter.__init__`
    - Search order: `backend/assets/fonts/NotoSansSC-Regular.ttf` → `/usr/share/fonts/` recursive scan for CJK/Noto/WenQuanYi/SourceHan `.ttf`/`.otf`
    - Raise `RuntimeError("中文字体不可用，无法生成 PDF")` if none found; register font with `reportlab.pdfbase`
    - _Requirements: 4.2, 4.3_

  - [x] 3.2 Implement TOC generation for PDF
    - Build `list[TocEntry]` from filtered `nodes`; render TOC page before body using `reportlab` canvas
    - Apply depth-based indentation: `(depth - 1) * 4` space-equivalents; include page numbers
    - _Requirements: 3.1, 3.2, 3.3, 3.5_

  - [x] 3.3 Implement block-type rendering for PDF
    - `heading`: bold, H1=18pt / H2=15pt / H3=13pt
    - `paragraph`: normal 11pt
    - `code`: monospace font, grey background frame
    - `list`: bullet `•` prefix
    - `quote`: 3pt left vertical rule, italic
    - For each text segment, detect `$...$` (inline) and `$$...$$` (display) LaTeX; call `LatexRenderer.render()`; embed PNG via `reportlab` `Image`; fall back to raw text + `[公式渲染失败，原始代码如下]` label on `None`
    - _Requirements: 4.4, 4.5, 6.1, 6.2, 6.3_

  - [x] 3.4 Implement `PdfBookExporter.build()` wiring
    - Instantiate `LatexRenderer` per call; call `_filter_nodes`; generate TOC if `include_toc`; iterate nodes and render blocks; return `bytes` from `BytesIO`
    - Set A4 page size (210mm × 297mm), margins top/bottom 20mm, left/right 25mm
    - _Requirements: 4.1, 4.4_

  - [x] 3.5 Write property test for node order preservation — PDF (Property 1)
    - **Property 1: 节点顺序保留**
    - Generate random ordered node lists (all with blocks); call `PdfBookExporter.build()`; parse PDF text order; assert chapter titles appear in input order
    - Tag: `# Feature: lecture-book-export, Property 1: 节点顺序保留`
    - **Validates: Requirements 3.1**

  - [x] 3.6 Write property test for TOC ↔ body correspondence — PDF (Property 3)
    - **Property 3: TOC 与正文一一对应**
    - Generate random node sets; assert TOC title set == body section title set (no extras, no omissions)
    - Tag: `# Feature: lecture-book-export, Property 3: TOC 与正文一一对应`
    - **Validates: Requirements 3.1, 3.2**

  - [x] 3.7 Write property test for TOC indentation — PDF (Property 4)
    - **Property 4: TOC 缩进与深度一致**
    - Generate nodes with random depth 1–4; assert TOC indent == `(depth - 1) * 4` space-equivalents
    - Tag: `# Feature: lecture-book-export, Property 4: TOC 缩进与深度一致`
    - **Validates: Requirements 3.5**

  - [x] 3.8 Write property test for LaTeX blocks rendered as images — PDF (Property 9)
    - **Property 9: LaTeX 公式渲染为嵌入图片**
    - Generate blocks containing inline/display LaTeX with renderer mocked as available; assert output PDF contains embedded image elements at those positions
    - Tag: `# Feature: lecture-book-export, Property 9: LaTeX 公式渲染为嵌入图片`
    - **Validates: Requirements 6.1, 6.2**

- [x] 4. Implement `DocxBookExporter`
  - [x] 4.1 Implement TOC generation for Word
    - Build TOC section using `python-docx`; add bookmark hyperlinks (`node_{depth}_{title}` anchors) per `TocEntry`; apply depth-based indentation
    - _Requirements: 3.1, 3.2, 3.4, 3.5_

  - [x] 4.2 Implement block-type rendering for Word
    - `heading`: map to `Heading 1/2/3` built-in styles; set font to `宋体`
    - `paragraph`: `Normal` style, font `宋体`
    - `code`: monospace font, light-grey paragraph shading
    - `list`: `List Bullet` style
    - `quote`: indented paragraph + left border
    - Detect and render LaTeX segments same as PDF; embed PNG via `python-docx` `add_picture`; fall back to raw text on `None`
    - Insert section break between each node's content
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3_

  - [x] 4.3 Implement `DocxBookExporter.build()` wiring
    - Instantiate `LatexRenderer` per call; call `_filter_nodes`; generate TOC if `include_toc`; iterate nodes and render blocks; return `bytes` from `BytesIO`
    - _Requirements: 5.1_

  - [x] 4.4 Write property test for Word Chinese font and heading styles (Property 8)
    - **Property 8: Word 中文字体与标题样式**
    - Generate random block lists with all block types; call `DocxBookExporter.build()`; parse docx XML; assert all paragraph fonts are `宋体` or `微软雅黑`; assert heading blocks map to correct `Heading N` style
    - Tag: `# Feature: lecture-book-export, Property 8: Word 中文字体与标题样式`
    - **Validates: Requirements 5.2, 5.3, 5.4**

  - [x] 4.5 Write property test for node order preservation — Docx (Property 1, Docx variant)
    - **Property 1 (Docx): 节点顺序保留**
    - Same as 3.5 but for `DocxBookExporter`; parse docx paragraph order to assert chapter title sequence
    - Tag: `# Feature: lecture-book-export, Property 1: 节点顺序保留 (docx)`
    - **Validates: Requirements 3.1**

- [x] 5. Checkpoint — backend services
  - Ensure all backend unit and property tests pass. Ask the user if questions arise.

- [x] 6. Add export-book API route
  - [x] 6.1 Define `ExportBookIn` Pydantic model in `backend/routers/library.py`
    - Fields: `node_ids: list[str]`, `format: Literal["pdf", "docx"]`, `include_toc: bool = True`
    - Add `@field_validator("node_ids")` rejecting empty list with `"node_ids 不能为空"`
    - Add `@field_validator("format")` rejecting non-pdf/docx with `"不支持的导出格式"`
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 6.2 Implement `POST /api/library/sessions/{session_id}/export-book` route handler
    - Verify session ownership (current user); return 404 `"大纲不存在"` on failure
    - Batch-query `node_lectures` for `node_ids`; preserve input order; filter nodes without lecture content
    - If all filtered → 422 `"所选节点均无讲义内容"`
    - Instantiate `PdfBookExporter` or `DocxBookExporter` based on `format`; call `build()`
    - Return `StreamingResponse` with `Content-Disposition: attachment; filename="book_{session_id}.{ext}"`
    - Catch `RuntimeError` from font loading → 500 with message
    - _Requirements: 4.1, 4.6, 5.1, 5.6, 7.1, 7.5, 7.6_

  - [x] 6.3 Write property test for invalid request rejection (Property 6)
    - **Property 6: 非法请求体被拒绝且不触发生成**
    - Generate empty `node_ids` arrays and random invalid `format` strings; assert route returns 422 and `BookExporter.build()` is never called (use `unittest.mock.patch`)
    - Tag: `# Feature: lecture-book-export, Property 6: 非法请求体被拒绝且不触发生成`
    - **Validates: Requirements 7.3, 7.4**

  - [x] 6.4 Write property test for session ownership (Property 7)
    - **Property 7: Session 所有权校验**
    - Generate random session IDs not belonging to authenticated user; assert route returns 404 and no lecture data is queried
    - Tag: `# Feature: lecture-book-export, Property 7: Session 所有权校验`
    - **Validates: Requirements 7.5**

- [x] 7. Download NotoSansSC font asset
  - [x] 7.1 Download `NotoSansSC-Regular.ttf` to `backend/assets/fonts/`
    - Add the font file (or a download script) so `PdfBookExporter` finds it at path `backend/assets/fonts/NotoSansSC-Regular.ttf`
    - If automated download is not feasible, implement and verify the system CJK font fallback path
    - _Requirements: 4.2, 4.3_

- [x] 8. Implement `BookExportService` (Flutter)
  - [x] 8.1 Create `lib/services/book_export_service.dart`
    - Implement `exportBook({required int sessionId, required List<String> nodeIds, required String format, bool includeToc = true}) -> Future<Uint8List>`
    - Use `Dio` with `responseType: ResponseType.bytes` and `connectTimeout` / `receiveTimeout` of 120 seconds
    - Throw typed exceptions for HTTP errors (pass through backend error message) and `DioExceptionType.receiveTimeout`
    - _Requirements: 7.1, 8.1, 8.5_

  - [x] 8.2 Write unit tests for `BookExportService` (mock Dio)
    - Verify request URL, body params, and `responseType` are constructed correctly
    - Verify timeout exception is surfaced as expected type
    - _Requirements: 8.1, 8.5_

- [x] 9. Implement `ExportBookDialog` (Flutter)
  - [x] 9.1 Create `lib/features/library/lecture/export_book_dialog.dart` with `ExportBookDialog` widget
    - Accept `sessionId`, `sessionTitle`, `nodes: List<TreeNode>`, `hasLectureNodeIds: Set<String>`
    - Initialize `_selected` as full set of all node IDs; initialize `_format = ExportFormat.pdf`
    - _Requirements: 1.1, 1.2_

  - [x] 9.2 Implement tree checkbox UI with lecture status dots
    - Render nodes as indented tree; each row: checkbox + green dot (has lecture) or grey dot (no lecture) + node title
    - Parent checkbox toggles all descendants (Requirements 1.3)
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 9.3 Implement select-all / select-none and warning display
    - Add "全选" and "全不选" buttons
    - Count selected nodes with no lecture; show warning `"X 个节点暂无讲义，导出时将跳过"` when count > 0
    - Disable export button and show `"请至少选择一个节点"` when `_selected.isEmpty`
    - _Requirements: 1.5, 1.6, 2.1, 2.2_

  - [x] 9.4 Implement format selector and export button with loading state
    - Add PDF / DOCX format toggle (SegmentedButton or RadioListTile)
    - On export tap: set `_isExporting = true`, disable button; call `BookExportService.exportBook()`
    - On success: call `FileSaver` with filename `{sessionTitle}_{format}.{ext}`; close dialog; show SnackBar `"导出成功"`
    - On backend error: show error SnackBar with backend message; reset `_isExporting = false`
    - On timeout: show SnackBar `"导出超时，请减少选择的节点数量后重试"`; reset `_isExporting = false`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 9.5 Write widget tests for `ExportBookDialog`
    - Test: select-all / select-none button behavior
    - Test: parent node check cascades to children
    - Test: export button disabled when no nodes selected
    - Test: warning text shown when selected nodes include nodes without lectures
    - _Requirements: 1.3, 1.5, 1.6, 2.1, 2.2_

- [x] 10. Implement `ExportBookDialog` filename property test (Flutter)
  - [x] 10.1 Write property test for export filename format (Property 10)
    - **Property 10: 导出文件名格式**
    - Generate random session title strings and valid format values (`"pdf"`, `"docx"`); assert the filename passed to `FileSaver` matches `{sessionTitle}_{format}.{ext}`
    - Tag: `# Feature: lecture-book-export, Property 10: 导出文件名格式`
    - **Validates: Requirements 8.2**

- [x] 11. Integrate "导出为书" entry into `LecturePage`
  - [x] 11.1 Add "导出为书 (.pdf/.docx)" option to `LecturePage._showExportMenu()`
    - Import and show `ExportBookDialog` as a full-screen or large bottom sheet
    - Pass current `sessionId`, `sessionTitle`, full node tree, and `hasLectureNodeIds` set
    - Disable the option while lecture content is loading (`_isLoading == true`)
    - _Requirements: 9.1, 9.2, 9.3_

- [x] 12. Final checkpoint — full stack
  - Ensure all backend and Flutter tests pass. Verify the export flow end-to-end with a real session. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Property tests use `hypothesis` (backend) and equivalent property testing for Flutter
- Each property test is tagged `# Feature: lecture-book-export, Property N: ...` for traceability
- `LatexRenderer` is instantiated once per `build()` call so the per-request cache is naturally scoped
- Font asset (task 7) can be done in parallel with tasks 3–4
