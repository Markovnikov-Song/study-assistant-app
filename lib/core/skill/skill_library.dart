// Learning OS — Skill Layer
// SkillLibrary is the central store for all Skill definitions.
// Phase 1: Interface skeleton only — no business logic.

import 'package:study_assistant_app/core/skill/skill_model.dart';

/// Thrown when a Skill fails structural validation before being saved.
class SkillValidationError implements Exception {
  final String skillId;
  final List<String> fieldErrors;

  const SkillValidationError({
    required this.skillId,
    required this.fieldErrors,
  });

  @override
  String toString() =>
      'SkillValidationError for "$skillId": ${fieldErrors.join(', ')}';
}

/// Filter parameters for querying the Skill library.
class SkillFilter {
  final List<String>? tags;
  final String? nameKeyword;
  final SkillType? type;
  final SkillSource? source;

  const SkillFilter({
    this.tags,
    this.nameKeyword,
    this.type,
    this.source,
  });
}

/// Central repository for all Skill definitions.
/// Validates Skills on save and supports filtered queries.
abstract class SkillLibrary {
  /// Persist a [skill] after validation.
  /// Throws [SkillValidationError] if:
  ///   - promptChain is empty
  ///   - any requiredComponent is not registered in ComponentRegistry
  Future<void> save(Skill skill);

  /// Retrieve a Skill by [id]. Returns null if not found.
  Future<Skill?> get(String id);

  /// List all Skills, optionally filtered by [filter].
  Future<List<Skill>> list({SkillFilter? filter});

  /// Delete a Skill by [id].
  /// Throws if the Skill is currently in use by an active Session,
  /// or if the caller attempts to delete a builtin Skill.
  Future<void> delete(String id);

  /// Convenience filter by [tags] and/or [nameKeyword].
  Future<List<Skill>> filter({List<String>? tags, String? nameKeyword});
}
