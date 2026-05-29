class MiniAppValidation {
  final bool ok;
  final List<String> errors;
  final List<String> warnings;

  const MiniAppValidation({
    required this.ok,
    required this.errors,
    required this.warnings,
  });

  factory MiniAppValidation.fromJson(Map<String, dynamic> json) {
    return MiniAppValidation(
      ok: json['ok'] as bool? ?? false,
      errors: ((json['errors'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class MiniAppSummary {
  final String id;
  final String title;
  final String appType;
  final int? subjectId;
  final String status;
  final String description;
  final String updatedAt;
  final MiniAppValidation validation;

  const MiniAppSummary({
    required this.id,
    required this.title,
    required this.appType,
    required this.subjectId,
    required this.status,
    required this.description,
    required this.updatedAt,
    required this.validation,
  });

  factory MiniAppSummary.fromJson(Map<String, dynamic> json) {
    return MiniAppSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      appType: json['app_type'] as String? ?? 'memory',
      subjectId: json['subject_id'] as int?,
      status: json['status'] as String? ?? 'draft',
      description: json['description'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      validation: MiniAppValidation.fromJson(
        (json['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class MiniAppRecord {
  final String id;
  final String title;
  final String appType;
  final int? subjectId;
  final String status;
  final Map<String, String> documents;
  final Map<String, dynamic> spec;
  final Map<String, dynamic> graph;
  final MiniAppValidation validation;
  final String updatedAt;

  const MiniAppRecord({
    required this.id,
    required this.title,
    required this.appType,
    required this.subjectId,
    required this.status,
    required this.documents,
    required this.spec,
    required this.graph,
    required this.validation,
    required this.updatedAt,
  });

  factory MiniAppRecord.fromJson(Map<String, dynamic> json) {
    final rawDocs =
        (json['documents'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MiniAppRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      appType: json['app_type'] as String? ?? 'memory',
      subjectId: json['subject_id'] as int?,
      status: json['status'] as String? ?? 'draft',
      documents: rawDocs.map((key, value) => MapEntry(key, value.toString())),
      spec: (json['spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      graph: (json['graph'] as Map?)?.cast<String, dynamic>() ?? const {},
      validation: MiniAppValidation.fromJson(
        (json['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class GenerateCardsResult {
  final MiniAppRecord app;
  final int targetCardCount;
  final int actualCardCount;

  const GenerateCardsResult({
    required this.app,
    required this.targetCardCount,
    required this.actualCardCount,
  });

  factory GenerateCardsResult.fromJson(Map<String, dynamic> json) {
    return GenerateCardsResult(
      app: MiniAppRecord.fromJson(
        (json['app'] as Map).cast<String, dynamic>(),
      ),
      targetCardCount: (json['target_card_count'] as num?)?.toInt() ?? 0,
      actualCardCount: (json['actual_card_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MiniAppInterviewTurn {
  final String sessionId;
  final String status;
  final String? question;
  final Map<String, String> collected;
  final MiniAppRecord? draft;
  final MiniAppValidation? validation;

  const MiniAppInterviewTurn({
    required this.sessionId,
    required this.status,
    this.question,
    required this.collected,
    this.draft,
    this.validation,
  });

  bool get isReady => status == 'ready' && draft != null;

  factory MiniAppInterviewTurn.fromJson(Map<String, dynamic> json) {
    final rawCollected =
        (json['collected'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MiniAppInterviewTurn(
      sessionId: json['session_id'] as String? ?? '',
      status: json['status'] as String? ?? 'collecting',
      question: json['question'] as String?,
      collected: rawCollected.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      draft: json['draft'] is Map
          ? MiniAppRecord.fromJson(
              (json['draft'] as Map).cast<String, dynamic>(),
            )
          : null,
      validation: json['validation'] is Map
          ? MiniAppValidation.fromJson(
              (json['validation'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}
