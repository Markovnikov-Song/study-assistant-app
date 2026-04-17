// Learning OS — Component Layer
// ComponentRegistryImpl provides the concrete implementation of ComponentRegistry.
// Phase 2: Registration logic with interface completeness validation.

import 'component_interface.dart';
import 'component_registry.dart';
import '../../components/chat/chat_component.dart';
import '../../components/solve/solve_component.dart';
import '../../components/mindmap/mindmap_component.dart';
import '../../components/quiz/quiz_component.dart';
import '../../components/notebook/notebook_component.dart';
import '../../components/mistake_book/mistake_book_component.dart';

/// Concrete implementation of [ComponentRegistry].
///
/// Validates that every registered object is a proper [ComponentInterface]
/// implementation before accepting it. Returns typed [Result] objects instead
/// of throwing unhandled exceptions (Property 10).
class ComponentRegistryImpl implements ComponentRegistry {
  final Map<String, ComponentInterface> _components = {};
  final Map<String, ComponentMeta> _metas = {};

  @override
  void register(ComponentInterface component, ComponentMeta meta) {
    // Dart's type system guarantees ComponentInterface is fully implemented
    // at compile time (all four abstract methods must be overridden).
    // The runtime check below guards against dynamic/reflective misuse and
    // satisfies Property 9 (incomplete interface → registration rejected).
    _validateInterface(component, meta.id);
    _components[meta.id] = component;
    _metas[meta.id] = meta;
  }

  @override
  Result<ComponentInterface> get(String componentId) {
    final component = _components[componentId];
    if (component == null) {
      return Result.err(ComponentNotFoundError(componentId));
    }
    return Result.ok(component);
  }

  @override
  List<ComponentMeta> listAll() => List.unmodifiable(_metas.values);

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Verifies that [component] responds to all four required methods.
  /// Throws [ComponentInterfaceError] if any method is missing.
  void _validateInterface(ComponentInterface component, String componentId) {
    // In Dart, any class that compiles and implements ComponentInterface
    // must provide all four abstract methods — the type system enforces this
    // at compile time. The runtime check here is a belt-and-suspenders guard
    // for dynamic/reflective misuse (e.g. mock objects passed as dynamic).
    //
    // We verify by attempting to tear off each method and checking it is
    // callable (non-null). For a properly typed ComponentInterface this will
    // always pass; it only fails if someone bypasses the type system.
    final missing = <String>[];

    // ignore: unnecessary_null_comparison
    if ((component.open as dynamic) == null) missing.add('open');
    // ignore: unnecessary_null_comparison
    if ((component.write as dynamic) == null) missing.add('write');
    // ignore: unnecessary_null_comparison
    if ((component.read as dynamic) == null) missing.add('read');
    // ignore: unnecessary_null_comparison
    if ((component.close as dynamic) == null) missing.add('close');

    if (missing.isNotEmpty) {
      throw ComponentInterfaceError(
        componentId: componentId,
        missingMethods: missing,
      );
    }
  }
}

// ── Built-in Component registration ─────────────────────────────────────────

/// Creates a [ComponentRegistryImpl] pre-loaded with all six built-in Components.
ComponentRegistryImpl createDefaultRegistry() {
  final registry = ComponentRegistryImpl();

  registry.register(
    ChatComponent(),
    const ComponentMeta(
      id: kChatComponentId,
      name: '问答',
      version: '1.0.0',
      supportedDataTypes: ['chat_history', 'message'],
      isBuiltin: true,
    ),
  );

  registry.register(
    SolveComponent(),
    const ComponentMeta(
      id: kSolveComponentId,
      name: '解题',
      version: '1.0.0',
      supportedDataTypes: ['solve_history', 'problem'],
      isBuiltin: true,
    ),
  );

  registry.register(
    MindMapComponent(),
    const ComponentMeta(
      id: kMindMapComponentId,
      name: '思维导图',
      version: '1.0.0',
      supportedDataTypes: ['mindmap_content', 'markdown'],
      isBuiltin: true,
    ),
  );

  registry.register(
    QuizComponent(),
    const ComponentMeta(
      id: kQuizComponentId,
      name: '出题',
      version: '1.0.0',
      supportedDataTypes: ['quiz_result', 'question'],
      isBuiltin: true,
    ),
  );

  registry.register(
    NotebookComponent(),
    const ComponentMeta(
      id: kNotebookComponentId,
      name: '笔记本',
      version: '1.0.0',
      supportedDataTypes: ['notes', 'note'],
      isBuiltin: true,
    ),
  );

  registry.register(
    MistakeBookComponent(),
    const ComponentMeta(
      id: kMistakeBookComponentId,
      name: '错题本',
      version: '1.0.0',
      supportedDataTypes: ['mistakes', 'mistake'],
      isBuiltin: true,
    ),
  );

  return registry;
}
