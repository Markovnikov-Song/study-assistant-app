enum DocumentStatus { pending, processing, completed, failed }

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class StudyDocument {
  final int id;
  final String filename;
  final DocumentStatus status;
  final String? error;
  final DateTime createdAt;

  const StudyDocument({
    required this.id,
    required this.filename,
    required this.status,
    this.error,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case DocumentStatus.pending: return '等待';
      case DocumentStatus.processing: return '处理中';
      case DocumentStatus.completed: return '完成';
      case DocumentStatus.failed: return '失败';
    }
  }

  factory StudyDocument.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = DocumentStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => DocumentStatus.pending,
    );
    return StudyDocument(
      id: _toInt(json['id']),
      filename: json['filename'] as String? ?? '',
      status: status,
      error: json['error'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
}

class PastExamFile {
  final int id;
  final String filename;
  final DocumentStatus status;
  final int questionCount;
  final DateTime createdAt;

  const PastExamFile({
    required this.id,
    required this.filename,
    required this.status,
    required this.questionCount,
    required this.createdAt,
  });

  factory PastExamFile.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String;
    final status = DocumentStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => DocumentStatus.pending,
    );
    return PastExamFile(
      id: _toInt(json['id']),
      filename: json['filename'] as String? ?? '',
      status: status,
      questionCount: _toInt(json['question_count']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
}
