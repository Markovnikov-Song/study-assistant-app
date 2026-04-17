// Learning OS — Providers
// Provides the ComponentRegistry singleton for the entire app.
// Phase 2: Registers all six built-in Components on first access.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/component/component_registry.dart';
import '../core/component/component_registry_impl.dart';

/// Global [ComponentRegistry] provider.
///
/// Returns a [ComponentRegistryImpl] pre-loaded with the six built-in
/// Components: Chat, Solve, MindMap, Quiz, Notebook, MistakeBook.
final componentRegistryProvider = Provider<ComponentRegistry>((ref) {
  return createDefaultRegistry();
});
