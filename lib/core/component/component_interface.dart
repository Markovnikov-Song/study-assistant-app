// Learning OS — Component Layer
// ComponentInterface defines the standard contract all Components must implement.
// Phase 1: Interface skeleton only — no business logic.

/// Context passed to a Component when it is opened.
class ComponentContext {
  final String sessionId;
  final String? subjectId;
  final Map<String, dynamic> extra;

  const ComponentContext({
    required this.sessionId,
    this.subjectId,
    this.extra = const {},
  });
}

/// Generic data container for reading/writing Component content.
class ComponentData {
  final String componentId;
  final String dataType;
  final Map<String, dynamic> payload;

  const ComponentData({
    required this.componentId,
    required this.dataType,
    required this.payload,
  });
}

/// Query parameters for reading data from a Component.
class ComponentQuery {
  final Map<String, dynamic> filters;
  final int? limit;
  final String? cursor;

  const ComponentQuery({
    this.filters = const {},
    this.limit,
    this.cursor,
  });
}

/// Standard interface every Learning OS Component must implement.
/// Skill and AgentKernel interact with Components exclusively through this interface.
abstract class ComponentInterface {
  /// Open the component and initialise it with the given [context].
  Future<void> open(ComponentContext context);

  /// Write [data] into the component (e.g. save a note, record a mistake).
  Future<void> write(ComponentData data);

  /// Read data from the component matching [query].
  Future<ComponentData> read(ComponentQuery query);

  /// Close the component and release any held resources.
  Future<void> close();
}
