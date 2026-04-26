import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  /// Android 模拟器访问宿主机用 10.0.2.2（如需切换，将 _devUrl 改为此值）
  // static const String _androidEmulatorUrl = 'http://10.0.2.2:8000';

  /// 真机调试：
  /// - USB 调试（推荐）：ADB 端口转发后可直接用 localhost
  /// - WiFi 调试：改成电脑局域网 IP，如 http://192.168.43.133:8000
  /// 也可以通过 --dart-define=API_BASE_URL=http://192.168.x.x:8000 覆盖
  static const String _devUrl = 'http://localhost:8000';

  /// 云服务器地址
  static const String _prodUrl = 'https://your-server.com';

  static String get baseUrl {
    // 优先使用编译时注入的地址（flutter run --dart-define=API_BASE_URL=xxx）
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kDebugMode) return _prodUrl;
    // Debug 模式：Web/iOS 模拟器用 localhost，Android 模拟器用 10.0.2.2，真机用局域网 IP
    return _devUrl;
  }

  // Auth
  static const String login    = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout   = '/api/auth/logout';

  // Subjects
  static const String subjects = '/api/subjects';

  // Sessions
  static const String sessions = '/api/sessions';
  static const String sessionsSearch = '/api/sessions/search';

  // Chat
  static const String chatQuery  = '/api/chat/query';
  static const String chatQueryStream = '/api/chat/query/stream';
  static const String chatMindmap = '/api/chat/mindmap';
  static const String chatMindmapCustom = '/api/chat/mindmap/custom';

  // Notebooks
  static const String notebooks = '/api/notebooks';
  static const String notes     = '/api/notes';

  // Users (profile edit)
  static const String userMe         = '/api/users/me';
  static const String userMeUsername = '/api/users/me/username';
  static const String userMePassword = '/api/users/me/password';
  static const String userMeAvatar   = '/api/users/me/avatar';

  // Documents
  static const String documents = '/api/documents';

  // Past Exams
  static const String pastExams = '/api/past-exams';

  // Exam Generation
  static const String examPredicted = '/api/exam/predicted';
  static const String examCustom    = '/api/exam/custom';

  // OCR
  static const String ocrImage = '/api/ocr/image';

  // Hints
  static const String hints = '/api/hints';

  // Review & Mistake Book
  static const String reviewMistakes      = '/api/review/mistakes';
  static const String reviewMistakeFromPractice = '/api/review/mistakes/from-practice';
  static const String reviewSubmit        = '/api/review/review/submit';
  static const String reviewQueue         = '/api/review/review/queue';
  static const String reviewSubjects      = '/api/review/review/subjects';
  static const String reviewCardRate      = '/api/review/review/card';
  static const String progressSummary     = '/api/review/review/progress/summary';

  // Token
  static const String tokenQuota    = '/api/token/quota';
  static const String tokenUsage    = '/api/token/usage';
  static const String tokenUsageToday = '/api/token/usage/today';
  static const String tokenUsageHistory = '/api/token/usage/history';
  static const String tokenTiers   = '/api/token/tiers';
}
