// Learning OS — Component Layer
// MindMapComponent wraps the existing MindMapPage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for MindMap.

import '../../core/component/component_interface.dart';

/// Component ID used for registration in ComponentRegistry.
const kMindMapComponentId = 'mindmap';

/// Wraps the MindMap (思维导图) feature as a Learning OS Component.
///
/// open()  — initialises the mindmap context (subjectId, mindmapId).
/// write() — saves mindmap content (Markdown or node data) to the component.
/// read()  — retrieves mindmap data matching the query filters.
/// close() — clears the active context.
class MindMapComponent implements ComponentInterface {
  ComponentContext? _context;

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  @override
  Future<void> write(ComponentData data) async {
    // Payload keys:
    //   'content'    (String) — Markdown or serialised node tree
    //   'mindmap_id' (String) — target mindmap identifier
    assert(
      _context != null,
      'MindMapComponent.write() called before open()',
    );
    // Business logic will be wired in Phase 3.
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'MindMapComponent.read() called before open()',
    );
    return ComponentData(
      componentId: kMindMapComponentId,
      dataType: 'mindmap_content',
      payload: const {},
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
