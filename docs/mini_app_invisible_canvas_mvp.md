# Mini App Invisible Canvas MVP

This MVP turns a document-driven learning mini app into a typed, headless block graph.

## Pipeline

```text
conversation / documents
  -> miniapp.v1 spec
  -> miniapp.graph.v1 invisible canvas
  -> graph validation
  -> runtime preview / frontend runtime
```

## Runtime Documents

- Markdown documents are human-facing design documents.
- `runtime_config.json` is the executable spec.
- `invisible_canvas.json` is the compiled headless block graph.
- `block_registry.json` is the available safe block catalog.
- `canvas_summary.md` is a readable projection of the current hidden graph.

## Block Model

Each block is a typed function:

```text
Block<InputPorts, Params, OutputPorts>
```

The registry lives in `backend/mini_apps/canvas.py`.

Current MVP blocks:

- `document_source_loader` — load parsed library chunks (`ChunkBatch`)
- `chunk_batch_processor` — merge/split units, estimate dynamic card budget
- `flashcard_synthesizer` — LLM/heuristic Q→A cards (`LearningItemBatch`)
- `manual_card_loader`
- `daily_quota_scheduler`
- `flashcard_practice`
- `choice_quiz`
- `spelling_input`
- `exact_match_grader`
- `answer_gate`
- `show_hint`
- `wrong_count_gate`
- `explanation_provider`
- `mistake_book_writer`
- `mastery_updater`
- `review_scheduler`
- `summary_report`

## Message Types

Current graph messages:

- `LearningItemBatch`
- `AnswerEventBatch`
- `GradeEventBatch`
- `FeedbackEventBatch`
- `MasterySignalBatch`
- `StudyTaskBatch`
- `ProgressEventBatch`

## Validation Rules

The graph validator checks:

- entry node exists
- all nodes use registered blocks
- params match block schemas
- edge output/input ports exist
- edge types match, or an explicit adapter is declared
- graph has no illegal cycles
- all nodes are reachable from entry
- learning items satisfy required fields

This is the safety mechanism: combinations are not tested one by one. They are accepted only when the graph satisfies the block contracts.

## API Surface

- `GET /api/mini-apps/blocks` returns the typed block registry.
- `POST /api/mini-apps/generate-cards` runs the document → chunk → card pipeline.
- `POST /api/mini-apps/{app_id}/generate-cards` runs the pipeline and writes `content.items` into the app spec.
- `POST /api/mini-apps/validate` validates a `miniapp.v1` spec and returns the compiled graph.
- `POST /api/mini-apps/graph/validate` validates an arbitrary graph against the block contracts.
- `GET /api/mini-apps/{app_id}/graph` returns a saved app's hidden graph.
- `POST /api/mini-apps/{app_id}/graph/preview` runs a deterministic server-side preview.
- `POST /api/mini-apps/{app_id}/runs/start` starts a tracked run session.
- `GET /api/mini-apps/runs/{run_id}` reads a run session and its event log.
- `POST /api/mini-apps/runs/{run_id}/events` appends a node-level runtime event.

## Current Graph

The current MVP graph is a directed acyclic graph with conditional feedback branches:

```text
manual_card_loader
  -> daily_quota_scheduler
  -> flashcard_practice / choice_quiz / spelling_input
  -> exact_match_grader
  -> answer_gate
      correct -> mastery_updater
      incorrect -> wrong_count_gate
          low wrong count -> show_hint -> mastery_updater
          high wrong count -> explanation_provider -> mastery_updater
          high wrong count -> mistake_book_writer -> mastery_updater
  -> mastery_updater
  -> review_scheduler
  -> summary_report
```

The next expansion should add stateful run sessions, persisted event logs, and richer adapters so more learning methods can share the same typed contracts.

## Runtime Events

The frontend runtime now starts a backend run session when the user opens a generated mini app. Practice actions append node-level events such as:

- `answer_known`
- `answer_unknown`
- `session_completed`

This keeps the user-facing interaction simple while giving the invisible canvas a durable execution trace.
