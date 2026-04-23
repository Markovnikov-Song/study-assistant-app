class ApiConstants {
  ApiConstants._();

  // 开发时指向本地，生产时改为部署地址
  // 手机调试时用热点的 IP
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.137.1:8000',
  );

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
}
