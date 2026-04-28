import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/chat_message.dart';

class HistorySessionItem extends ConversationSession {
  final int? subjectId;
  final String? subjectName;

  const HistorySessionItem({
    required super.id,
    required super.sessionType,
    super.title,
    required super.createdAt,
    this.subjectId,
    this.subjectName,
  });

  @override
  factory HistorySessionItem.fromJson(Map<String, dynamic> json) {
    final base = ConversationSession.fromJson(json);
    final rawSubjectId = json['subject_id'];
    int? subjectId;
    if (rawSubjectId is int) subjectId = rawSubjectId;
    else if (rawSubjectId is num) subjectId = rawSubjectId.toInt();
    else if (rawSubjectId is String) subjectId = int.tryParse(rawSubjectId);
    return HistorySessionItem(
      id: base.id,
      sessionType: base.sessionType,
      title: base.title,
      createdAt: base.createdAt,
      subjectId: subjectId,
      subjectName: json['subject_name'] as String?,
    );
  }
}

class MessageSearchResult {
  final int messageId;
  final int sessionId;
  final String? sessionTitle;
  final SessionType sessionType;
  final String typeLabel;
  final int? subjectId;
  final String? subjectName;
  final String role;
  final String snippet;
  final DateTime createdAt;

  const MessageSearchResult({
    required this.messageId,
    required this.sessionId,
    this.sessionTitle,
    required this.sessionType,
    required this.typeLabel,
    this.subjectId,
    this.subjectName,
    required this.role,
    required this.snippet,
    required this.createdAt,
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    final typeStr = json['session_type'] as String;
    final type = SessionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SessionType.qa,
    );

    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    int? _toIntOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return MessageSearchResult(
      messageId: _toInt(json['message_id']),
      sessionId: _toInt(json['session_id']),
      sessionTitle: json['session_title'] as String?,
      sessionType: type,
      typeLabel: json['type_label'] as String,
      subjectId: _toIntOrNull(json['subject_id']),
      subjectName: json['subject_name'] as String?,
      role: json['role'] as String,
      snippet: json['snippet'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class HistoryService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<HistorySessionItem>> getAllSessions() async {
    try {
      final res = await _dio.get(ApiConstants.sessions);
      return (res.data as List).map((e) => HistorySessionItem.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MessageSearchResult>> searchMessages(String q, {String? sessionType}) async {
    try {
      final res = await _dio.get(ApiConstants.sessionsSearch, queryParameters: {
        'q': q,
        'session_type': ?sessionType,
      });
      return (res.data as List).map((e) => MessageSearchResult.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
