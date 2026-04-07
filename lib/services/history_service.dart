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
    return HistorySessionItem(
      id: base.id,
      sessionType: base.sessionType,
      title: base.title,
      createdAt: base.createdAt,
      subjectId: json['subject_id'] as int?,
      subjectName: json['subject_name'] as String?,
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
}
