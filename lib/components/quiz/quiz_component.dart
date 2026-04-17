// Learning OS — Component Layer
// QuizComponent wraps the existing QuizPage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for Quiz.

import '../../core/component/component_interface.dart';

/// Component ID used for registration in ComponentRegistry.
const kQuizComponentId = 'quiz';

/// Wraps the Quiz (出题) feature as a Learning OS Component.
///
/// open()  — initialises the quiz context (subjectId, sessionId).
/// write() — submits quiz configuration or records a generated paper.
/// read()  — retrieves generated quiz content matching the query filters.
/// close() — clears the active context.
class QuizComponent implements ComponentInterface {
  ComponentContext? _context;

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  @override
  Future<void> write(ComponentData data) async {
    // Payload keys:
    //   'question_types' (List<String>) — selected question types
    //   'difficulty'     (String)       — '简单' | '中等' | '困难'
    //   'result'         (String)       — generated paper Markdown
    assert(
      _context != null,
      'QuizComponent.write() called before open()',
    );
    // Business logic will be wired in Phase 3.
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'QuizComponent.read() called before open()',
    );
    return ComponentData(
      componentId: kQuizComponentId,
      dataType: 'quiz_result',
      payload: const {},
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
