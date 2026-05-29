import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Android 模拟器访问宿主机可用 http://10.0.2.2:8000。
  static const String _devUrl = 'http://localhost:8000';

  // 原生端默认生产入口。Web 端优先使用当前页面 origin，避免 HTTPS 页面请求 HTTP API。
  static const String _prodUrl = 'https://www.study-assistant.cn';

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return Uri.base.origin;
    if (!kDebugMode) return _prodUrl;
    return _devUrl;
  }

  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';

  // Subjects
  static const String subjects = '/api/subjects';

  // Sessions
  static const String sessions = '/api/sessions';
  static const String sessionsSearch = '/api/sessions/search';

  // Chat
  static const String chatQuery = '/api/chat/query';
  static const String chatQueryStream = '/api/chat/query/stream';
  static const String chatMindmap = '/api/chat/mindmap';
  static const String chatMindmapCustom = '/api/chat/mindmap/custom';

  // Notebooks
  static const String notebooks = '/api/notebooks';
  static const String notes = '/api/notes';

  // Users (profile edit)
  static const String userMe = '/api/users/me';
  static const String userMeUsername = '/api/users/me/username';
  static const String userMePassword = '/api/users/me/password';
  static const String userMeAvatar = '/api/users/me/avatar';

  // Documents
  static const String documents = '/api/documents';

  // Past Exams
  static const String pastExams = '/api/past-exams';

  // Exam Generation
  static const String examPredicted = '/api/exam/predicted';
  static const String examCustom = '/api/exam/custom';

  // OCR
  static const String ocrImage = '/api/ocr/image';

  // Hints
  static const String hints = '/api/hints';

  // Review & Mistake Book
  static const String reviewMistakes = '/api/review/mistakes';
  static const String reviewMistakeFromPractice =
      '/api/review/mistakes/from-practice';
  static const String reviewSubmit = '/api/review/review/submit';
  static const String reviewQueue = '/api/review/review/queue';
  static const String reviewSubjects = '/api/review/review/subjects';
  static const String reviewCardRate = '/api/review/review/card';
  static const String progressSummary = '/api/review/progress/summary';

  // Token
  static const String tokenQuota = '/api/token/quota';
  static const String tokenUsage = '/api/token/usage';
  static const String tokenUsageToday = '/api/token/usage/today';
  static const String tokenUsageHistory = '/api/token/usage/history';
  static const String tokenTiers = '/api/token/tiers';

  // App Update
  static const String appVersion = '/api/app/version';
}
