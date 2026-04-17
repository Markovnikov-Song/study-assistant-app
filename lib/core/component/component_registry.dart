// Learning OS — Component Layer
// ComponentRegistry manages all registered Components and provides a unified
// discovery interface for AgentKernel and Skills.
// Phase 1: Interface skeleton only — no business logic.

import 'package:study_assistant_app/core/component/component_interface.dart';

/// Metadata stored in the registry for each Component.
class ComponentMeta {
  final String id;
  final String name;
  final String version;
  final List<String> supportedDataTypes;
  final bool isBuiltin;

  const ComponentMeta({
    required this.id,
    required this.name,
    required this.version,
    required this.supportedDataTypes,
    required this.isBuiltin,
  });
}

/// Thrown when a requested Component is not found in the registry.
class ComponentNotFoundError implements Exception {
  final String componentId;
  const ComponentNotFoundError(this.componentId);

  @override
  String toString() => 'ComponentNotFoundError: component "$componentId" is not registered.';
}

/// Thrown when a Component does not fully implement [ComponentInterface].
class ComponentInterfaceError implements Exception {
  final String componentId;
  final List<String> missingMethods;

  const ComponentInterfaceError({
    required this.componentId,
    required this.missingMethods,
  });

  @override
  String toString() =>
      'ComponentInterfaceError: component "$componentId" is missing methods: $missingMethods';
}

/// Result wrapper — either a value or an error.
class Result<T> {
  final T? value;
  final Exception? error;

  const Result.ok(T this.value) : error = null;
  const Result.err(Exception this.error) : value = null;

  bool get isOk => error == null;
}

/// Registry that manages all Learning OS Components.
/// Callers use [get] to obtain a Component instance without knowing its implementation.
abstract class ComponentRegistry {
  /// Register a [component] with its [meta].
  /// Throws [ComponentInterfaceError] if the component does not implement
  /// [ComponentInterface] completely.
  void register(ComponentInterface component, ComponentMeta meta);

  /// Retrieve a registered Component by [componentId].
  /// Returns [Result.err] with [ComponentNotFoundError] if not found —
  /// never throws an unhandled exception.
  Result<ComponentInterface> get(String componentId);

  /// List metadata for all registered Components.
  List<ComponentMeta> listAll();
}
