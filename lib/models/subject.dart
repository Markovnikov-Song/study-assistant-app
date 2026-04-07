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

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String?,
        description: json['description'] as String?,
        isPinned: (json['is_pinned'] ?? 0) == 1,
        isArchived: (json['is_archived'] ?? 0) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
