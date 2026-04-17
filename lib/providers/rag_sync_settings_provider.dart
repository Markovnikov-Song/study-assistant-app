import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

// ── Key constants ─────────────────────────────────────────────────────────────

String _lectureKey(int subjectId) => 'rag_sync_lecture_$subjectId';

// ── Notifier ──────────────────────────────────────────────────────────────────

class RagSyncSettings {
  final bool autoSyncLecture;

  const RagSyncSettings({
    this.autoSyncLecture = false,
  });

  RagSyncSettings copyWith({bool? autoSyncLecture}) =>
      RagSyncSettings(
        autoSyncLecture: autoSyncLecture ?? this.autoSyncLecture,
      );
}

class RagSyncSettingsNotifier
    extends FamilyNotifier<RagSyncSettings, int> {
  late SharedPreferences _prefs;

  @override
  RagSyncSettings build(int subjectId) {
    _prefs = ref.watch(sharedPreferencesProvider);
    return RagSyncSettings(
      autoSyncLecture: _prefs.getBool(_lectureKey(subjectId)) ?? false,
    );
  }

  Future<void> setAutoSyncLecture(bool value) async {
    await _prefs.setBool(_lectureKey(arg), value);
    state = state.copyWith(autoSyncLecture: value);
  }
}

final ragSyncSettingsProvider = NotifierProviderFamily<
    RagSyncSettingsNotifier, RagSyncSettings, int>(
  RagSyncSettingsNotifier.new,
);
