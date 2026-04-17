// Learning OS — Providers
// Provides the SkillLibrary singleton for the entire app.
// Phase 2: Backed by SkillLibraryImpl with ComponentRegistry validation.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/skill/skill_library.dart';
import '../core/skill/skill_library_impl.dart';
import 'component_registry_provider.dart';

/// Global [SkillLibrary] provider.
///
/// Depends on [componentRegistryProvider] so that Skill validation can check
/// whether required Components are registered.
final skillLibraryProvider = Provider<SkillLibrary>((ref) {
  final registry = ref.watch(componentRegistryProvider);
  return SkillLibraryImpl(registry);
});
