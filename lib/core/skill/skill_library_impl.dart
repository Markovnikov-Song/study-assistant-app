// Learning OS — Skill Layer
// SkillLibraryImpl provides the concrete implementation of SkillLibrary.
// Phase 2: Save/query/filter/delete logic with validation.

import 'skill_library.dart';
import 'skill_model.dart';
import '../component/component_registry.dart';

/// In-memory implementation of [SkillLibrary].
///
/// Validates Skills on save (Property 2, 3) and supports filtered queries
/// (Property 5). Rejects deletion of builtin Skills or Skills in active use.
class SkillLibraryImpl implements SkillLibrary {
  final ComponentRegistry _componentRegistry;
  final Map<String, Skill> _skills = {};

  /// [componentRegistry] is used to validate that all requiredComponents exist.
  SkillLibraryImpl(this._componentRegistry);

  @override
  Future<void> save(Skill skill) async {
    final errors = <String>[];

    // Requirement 1.2: promptChain must contain at least one node (Property 2).
    if (skill.promptChain.isEmpty) {
      errors.add('promptChain is empty');
    }

    // Requirement 1.3: all requiredComponents must be registered (Property 3).
    for (final componentId in skill.requiredComponents) {
      final result = _componentRegistry.get(componentId);
      if (!result.isOk) {
        errors.add('component "$componentId" is not registered');
      }
    }

    if (errors.isNotEmpty) {
      throw SkillValidationError(skillId: skill.id, fieldErrors: errors);
    }

    _skills[skill.id] = skill;
  }

  @override
  Future<Skill?> get(String id) async => _skills[id];

  @override
  Future<List<Skill>> list({SkillFilter? filter}) async {
    var results = _skills.values.toList();

    if (filter == null) return results;

    // Filter by tags (Requirement 1.6, Property 5).
    if (filter.tags != null && filter.tags!.isNotEmpty) {
      results = results.where((s) {
        return filter.tags!.any((tag) => s.tags.contains(tag));
      }).toList();
    }

    // Filter by name keyword (Requirement 1.6, Property 5).
    if (filter.nameKeyword != null && filter.nameKeyword!.isNotEmpty) {
      final keyword = filter.nameKeyword!.toLowerCase();
      results = results.where((s) {
        return s.name.toLowerCase().contains(keyword) ||
            s.description.toLowerCase().contains(keyword);
      }).toList();
    }

    // Filter by type (builtin | custom).
    if (filter.type != null) {
      results = results.where((s) => s.type == filter.type).toList();
    }

    // Filter by source.
    if (filter.source != null) {
      results = results.where((s) => s.source == filter.source).toList();
    }

    return results;
  }

  @override
  Future<void> delete(String id) async {
    final skill = _skills[id];
    if (skill == null) return;

    // Requirement 7.2: cannot delete builtin Skills.
    if (skill.type == SkillType.builtin) {
      throw Exception('Cannot delete builtin Skill "$id"');
    }

    // Requirement 7.4: cannot delete Skills in active use.
    // (Session check will be implemented in Phase 3 when SessionService exists.)

    _skills.remove(id);
  }

  @override
  Future<List<Skill>> filter({List<String>? tags, String? nameKeyword}) async {
    return list(
      filter: SkillFilter(tags: tags, nameKeyword: nameKeyword),
    );
  }
}
