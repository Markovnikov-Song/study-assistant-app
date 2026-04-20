import 'package:study_assistant_app/models/chat_message.dart';

class Notebook {
  final int id;
  final String name;
  final bool isSystem;
  final bool isPinned;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;

  const Notebook({
    required this.id,
    required this.name,
    required this.isSystem,
    required this.isPinned,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
  });

  factory Notebook.fromJson(Map<String, dynamic> json) => Notebook(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        isSystem: json['is_system'] as bool? ?? false,
        isPinned: json['is_pinned'] as bool? ?? false,
        isArchived: json['is_archived'] as bool? ?? false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_system': isSystem,
        'is_pinned': isPinned,
        'is_archived': isArchived,
        'sort_order': sortOrder,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class Note {
  final int id;
  final int notebookId;
  final int? subjectId;
  final int? sourceSessionId;
  final int? sourceMessageId;
  final String role; // 'user' | 'assistant'
  final String originalContent;
  final String? title;
  final List<String>? outline;
  final int? importedToDocId;
  final List<MessageSource>? sources;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String noteType; // 'general' | 'mistake'
  final String? mistakeStatus; // 'pending' | 'reviewed' (only when noteType == 'mistake')
  final Map<String, dynamic>? mistakeDetails;

  const Note({
    required this.id,
    required this.notebookId,
    this.subjectId,
    this.sourceSessionId,
    this.sourceMessageId,
    required this.role,
    required this.originalContent,
    this.title,
    this.outline,
    this.importedToDocId,
    this.sources,
    required this.createdAt,
    required this.updatedAt,
    this.noteType = 'general',
    this.mistakeStatus,
    this.mistakeDetails,
  });

  /// 显示标题：有 title 用 title，否则截取前 20 字符
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    return originalContent.length > 20
        ? originalContent.substring(0, 20)
        : originalContent;
  }

  bool get hasTitleSet => title != null && title!.isNotEmpty;

  bool get isImported => importedToDocId != null;

  bool get isMistake => noteType == 'mistake';

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: (json['id'] as num).toInt(),
        notebookId: (json['notebook_id'] as num).toInt(),
        subjectId: (json['subject_id'] as num?)?.toInt(),
        sourceSessionId: (json['source_session_id'] as num?)?.toInt(),
        sourceMessageId: (json['source_message_id'] as num?)?.toInt(),
        role: json['role'] as String,
        originalContent: json['original_content'] as String,
        title: json['title'] as String?,
        outline: (json['outline'] as List?)?.map((e) => e as String).toList(),
        importedToDocId: (json['imported_to_doc_id'] as num?)?.toInt(),
        sources: (json['sources'] as List?)
            ?.map((e) => MessageSource.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
        noteType: json['note_type'] as String? ?? 'general',
        mistakeStatus: json['mistake_status'] as String?,
        mistakeDetails: (json['mistake_details'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'notebook_id': notebookId,
        'subject_id': subjectId,
        'source_session_id': sourceSessionId,
        'source_message_id': sourceMessageId,
        'role': role,
        'original_content': originalContent,
        'title': title,
        'outline': outline,
        'imported_to_doc_id': importedToDocId,
        'sources': sources?.map((s) => {
              'filename': s.filename,
              'chunk_index': s.chunkIndex,
              'content': s.content,
              'score': s.score,
            }).toList(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'note_type': noteType,
        'mistake_status': mistakeStatus,
        'mistake_details': mistakeDetails,
      };
}
