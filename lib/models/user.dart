class User {
  final String id;
  final String username;
  final String? avatarBase64;

  const User({
    required this.id,
    required this.username,
    this.avatarBase64,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'].toString(),
      username: json['username'] as String,
      avatarBase64: json['avatar_base64'] as String?,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? avatarBase64,
    bool clearAvatar = false,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarBase64: clearAvatar ? null : (avatarBase64 ?? this.avatarBase64),
    );
  }
}
