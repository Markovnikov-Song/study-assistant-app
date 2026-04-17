// Learning OS — Skill Creation Adapter Implementation
// Phase 3: Three Skill creation paths — dialog, text import, manual.

import 'package:uuid/uuid.dart';
import 'skill_creation_adapter.dart';
import 'skill_model.dart';
import 'skill_parser.dart';
import 'skill_library.dart';

const _uuid = Uuid();

/// Concrete implementation of [SkillCreationAdapter].
///
/// Three creation paths (Requirement 8.1, 8.2, 7.1):
///   1. [createFromDialog]  — conversational guided flow (AI-driven, Phase 3 stub)
///   2. [createFromText]    — parse a learning experience article via [SkillParser]
///   3. [createManually]    — return an empty draft for the user to fill in
///
/// All paths produce a [SkillDraft] that the caller reviews before saving
/// to [SkillLibrary]. No technical terminology is exposed to the user
/// (Requirement 8.1.6).
class SkillCreationAdapterImpl implements SkillCreationAdapter {
  final SkillParser _parser;
  final SkillLibrary _library;

  SkillCreationAdapterImpl({
    required SkillParser parser,
    required SkillLibrary library,
  })  : _parser = parser,
        _library = library;

  // ── createFromDialog ───────────────────────────────────────────────────────

  /// Requirement 8.1: guided conversational flow.
  ///
  /// In Phase 3 this is a stub that returns an empty draft — the full
  /// dialog UI will be wired in the UI layer (a Flutter dialog/page that
  /// calls this adapter and iterates on the draft with the user).
  @override
  Future<SkillDraft> createFromDialog() async {
    // The dialog flow is orchestrated by the UI layer; this method returns
    // the initial empty draft that the UI populates step by step.
    return const SkillDraft(
      isDraft: true,
    );
  }

  // ── createFromText ─────────────────────────────────────────────────────────

  /// Requirement 8.2: parse a learning experience article into a SkillDraft.
  ///
  /// Delegates to [SkillParser.parse]. If parsing fails, [ParseError] is
  /// propagated to the caller (Requirement 8.2.3).
  ///
  /// On success, records [sourceTextLength] in the draft metadata
  /// (Requirement 8.2.5).
  @override
  Future<SkillDraft> createFromText(String text) async {
    // ParseError is intentionally not caught here — the caller (UI layer)
    // should display the readable error message to the user.
    final draft = await _parser.parse(text);

    // Requirement 8.2.5: always record source text character count here,
    // regardless of whether the parser implementation already set it.
    return SkillDraft(
      name: draft.name,
      description: draft.description,
      tags: draft.tags,
      promptChain: draft.promptChain,
      requiredComponents: draft.requiredComponents,
      isDraft: true,
      sourceTextLength: text.length,
    );
  }

  // ── createManually ─────────────────────────────────────────────────────────

  /// Requirement 7.1: open a manual editor (returns an empty draft).
  ///
  /// The UI layer renders an edit form pre-populated with this draft.
  @override
  Future<SkillDraft> createManually() async {
    return const SkillDraft(isDraft: true);
  }

  // ── publishDraft ───────────────────────────────────────────────────────────

  /// Converts a confirmed [draft] into a [Skill] and saves it to [SkillLibrary].
  ///
  /// Requirement 8.1.4 / 8.2: called after the user confirms the draft.
  /// Executes the same structural validation as Requirement 1.
  Future<Skill> publishDraft(
    SkillDraft draft, {
    required String createdByUserId,
    SkillSource source = SkillSource.userCreated,
  }) async {
    final skill = Skill(
      id: _uuid.v4(),
      name: draft.name ?? '',
      description: draft.description ?? '',
      tags: draft.tags,
      promptChain: draft.promptChain,
      requiredComponents: draft.requiredComponents,
      version: '1.0.0',
      createdAt: DateTime.now(),
      type: SkillType.custom,
      createdBy: createdByUserId,
      source: source,
    );

    // SkillLibrary.save() performs structural validation (Requirement 1.2, 1.3).
    await _library.save(skill);
    return skill;
  }
}
