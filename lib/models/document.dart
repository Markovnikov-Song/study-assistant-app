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
  final String processingStage;
  final int progress;
  final String? parserBackend;
  final int chunkCount;
  final bool mindmapReady;
  final String? error;
  final DateTime createdAt;

  const StudyDocument({
    required this.id,
    required this.filename,
    required this.status,
    this.processingStage = 'queued',
    this.progress = 0,
    this.parserBackend,
    this.chunkCount = 0,
    this.mindmapReady = false,
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
      processingStage: json['processing_stage'] as String? ?? 'queued',
      progress: _toInt(json['progress']),
      parserBackend: json['parser_backend'] as String?,
      chunkCount: _toInt(json['chunk_count']),
      mindmapReady: json['mindmap_ready'] == true,
      error: json['error'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
}

class SubjectKnowledgeBase {
  final int subjectId;
  final String status;
  final int documentCount;
  final int chunkCount;
  final bool mindmapReady;
  final DateTime? updatedAt;

  const SubjectKnowledgeBase({
    required this.subjectId,
    required this.status,
    required this.documentCount,
    required this.chunkCount,
    required this.mindmapReady,
    this.updatedAt,
  });

  String get statusLabel {
    switch (status) {
      case 'ready':
        return '资料库已就绪';
      case 'processing':
        return '资料库处理中';
      case 'failed':
        return '资料库有失败任务';
      default:
        return '资料库为空';
    }
  }

  factory SubjectKnowledgeBase.fromJson(Map<String, dynamic> json) {
    return SubjectKnowledgeBase(
      subjectId: _toInt(json['subject_id']),
      status: json['status'] as String? ?? 'empty',
      documentCount: _toInt(json['document_count']),
      chunkCount: _toInt(json['chunk_count']),
      mindmapReady: json['mindmap_ready'] == true,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
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
