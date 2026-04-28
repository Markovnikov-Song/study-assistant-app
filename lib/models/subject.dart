class Subject {
  final int id;
  final String name;
  final String? category;
  final String? description;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;

  const Subject({
    required this.id,
    required this.name,
    this.category,
    this.description,
    this.isPinned = false,
    this.isArchived = false,
    required this.createdAt,
  });

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: _toInt(json['id']),
        name: (json['name'] as String?) ?? '',
        category: json['category'] as String?,
        description: json['description'] as String?,
        isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
        isArchived: json['is_archived'] == true || json['is_archived'] == 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}
