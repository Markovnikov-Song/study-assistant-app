// Learning OS — Component Layer
// SolveComponent wraps the existing SolvePage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for Solve.

import '../../core/component/component_interface.dart';

/// Component ID used for registration in ComponentRegistry.
const kSolveComponentId = 'solve';

/// Wraps the Solve (解题) feature as a Learning OS Component.
///
/// open()  — initialises the solve session context (subjectId, sessionId).
/// write() — submits a problem payload to the solve session.
/// read()  — retrieves solve history matching the query filters.
/// close() — clears the active session context.
class SolveComponent implements ComponentInterface {
  ComponentContext? _context;

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  @override
  Future<void> write(ComponentData data) async {
    // Payload keys:
    //   'problem' (String) — the problem text to solve
    //   'role'    (String) — 'user' | 'assistant'
    assert(
      _context != null,
      'SolveComponent.write() called before open()',
    );
    // Business logic will be wired in Phase 3.
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'SolveComponent.read() called before open()',
    );
    return ComponentData(
      componentId: kSolveComponentId,
      dataType: 'solve_history',
      payload: const {},
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
