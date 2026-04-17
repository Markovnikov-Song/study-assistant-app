import 'package:uuid/uuid.dart';

/// Metadata for a single named mindmap belonging to a subject.
///
/// Requirement: 10.3
class MindmapMeta {
  final String id;
  final int subjectId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MindmapMeta({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new MindmapMeta with a generated UUID and current timestamps.
  factory MindmapMeta.create({
    required int subjectId,
    required String name,
  }) {
    final now = DateTime.now();
    return MindmapMeta(
      id: const Uuid().v4(),
      subjectId: subjectId,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  MindmapMeta copyWith({
    String? id,
    int? subjectId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MindmapMeta(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MindmapMeta.fromJson(Map<String, dynamic> json) {
    return MindmapMeta(
      id: json['id'] as String,
      subjectId: (json['subject_id'] as num).toInt(),
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindmapMeta &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MindmapMeta(id: $id, subjectId: $subjectId, name: $name)';
}
