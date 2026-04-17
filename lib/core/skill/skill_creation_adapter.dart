// Learning OS — Skill Layer
// SkillCreationAdapter unifies the three Skill creation paths:
//   1. Conversational (dialog-guided)
//   2. Experience-import (paste article → AI parses)
//   3. Manual (fill in fields directly)
// Phase 1: Interface skeleton only — no business logic.

import 'package:study_assistant_app/core/skill/skill_model.dart';

/// Unified adapter interface for all Skill creation paths.
/// All three paths produce a [SkillDraft] that the user can review before
/// saving to [SkillLibrary].
abstract class SkillCreationAdapter {
  /// Start a guided conversational flow where the Agent asks the user
  /// questions one at a time to build a Skill draft.
  /// No technical terminology is exposed to the user during this flow.
  Future<SkillDraft> createFromDialog();

  /// Parse a free-form learning experience [text] (e.g. a study tips article)
  /// and return a structured Skill draft for user review.
  Future<SkillDraft> createFromText(String text);

  /// Open a manual editor where the user fills in Skill fields directly.
  Future<SkillDraft> createManually();
}
