// Learning OS — Component Layer
// ChatComponent wraps the existing ChatPage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for Chat.

import '../../core/component/component_interface.dart';

/// Component ID used for registration in ComponentRegistry.
const kChatComponentId = 'chat';

/// Wraps the Chat (问答) feature as a Learning OS Component.
///
/// open()  — initialises the chat session context (subjectId, sessionId).
/// write() — sends a message payload into the chat session.
/// read()  — retrieves chat history matching the query filters.
/// close() — clears the active session context.
class ChatComponent implements ComponentInterface {
  ComponentContext? _context;

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  @override
  Future<void> write(ComponentData data) async {
    // Payload keys:
    //   'message' (String) — the text message to record
    //   'role'    (String) — 'user' | 'assistant'
    assert(
      _context != null,
      'ChatComponent.write() called before open()',
    );
    // Business logic will be wired in Phase 3 when AgentKernel dispatches Skills.
    // For now the method is a no-op stub that satisfies the interface contract.
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'ChatComponent.read() called before open()',
    );
    // Returns an empty payload stub; full implementation in Phase 3.
    return ComponentData(
      componentId: kChatComponentId,
      dataType: 'chat_history',
      payload: const {},
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
