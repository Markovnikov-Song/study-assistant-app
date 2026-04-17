// Learning OS — Skill Layer
// SkillParser is a pluggable interface for converting unstructured text
// (e.g. a study experience article) into a structured SkillDraft.
// Swap the underlying AI model by providing a different implementation.
// Phase 1: Interface + default no-op implementation.

import 'package:study_assistant_app/core/skill/skill_model.dart';

/// Thrown when the parser cannot extract a valid Skill structure from the input.
class ParseError implements Exception {
  final String reason;
  const ParseError(this.reason);

  @override
  String toString() => 'ParseError: $reason';
}

/// Pluggable parser that converts free-form text into a [SkillDraft].
/// Implement this interface to inject different AI models.
abstract class SkillParser {
  /// Parse [text] and return a [SkillDraft].
  /// Throws [ParseError] if the text is too short, off-topic, or cannot
  /// yield at least one [PromptNode].
  Future<SkillDraft> parse(String text);
}

/// Default no-op implementation — returns an empty draft.
/// Replace with a real AI-backed implementation in Phase 3.
class DefaultSkillParser implements SkillParser {
  const DefaultSkillParser();

  @override
  Future<SkillDraft> parse(String text) async {
    return SkillDraft.empty();
  }
}
