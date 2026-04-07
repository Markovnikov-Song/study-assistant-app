class ApiConstants {
  ApiConstants._();

  // 开发时指向本地，生产时改为部署地址
  static const String baseUrl = 'http://192.168.137.1:8000';

  // Auth
  static const String login    = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout   = '/api/auth/logout';

  // Subjects
  static const String subjects = '/api/subjects';

  // Sessions
  static const String sessions = '/api/sessions';

  // Chat
  static const String chatQuery  = '/api/chat/query';
  static const String chatMindmap = '/api/chat/mindmap';

  // Documents
  static const String documents = '/api/documents';

  // Past Exams
  static const String pastExams = '/api/past-exams';

  // Exam Generation
  static const String examPredicted = '/api/exam/predicted';
  static const String examCustom    = '/api/exam/custom';

  // OCR
  static const String ocrImage = '/api/ocr/image';
}
