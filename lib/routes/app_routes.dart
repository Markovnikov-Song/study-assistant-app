import '../core/capability/capability_execution_contract.dart';

class R {
  R._();

  // Auth
  static const login = '/login';
  static const register = '/register';

  // Shell tabs
  static const chat = '/';
  static const courseSpace = '/course-space';
  static const toolkit = '/toolkit';
  static const profile = '/profile';

  // Chat
  static String chatSession(String chatId) => '/chat/$chatId';
  static String chatSubject(String chatId, int subjectId) =>
      '/chat/$chatId/subject/$subjectId';
  static String chatTask(String chatId, String taskId) =>
      '/chat/$chatId/task/$taskId';
  static const spec = '/spec';

  // Course space
  static String courseSpaceSubject(int subjectId) => '/course-space/$subjectId';
  static String mindmap(int subjectId, int sessionId) =>
      '/course-space/$subjectId/mindmap/$sessionId';
  static String lecture(int subjectId, int sessionId, String nodeId) =>
      '/course-space/$subjectId/mindmap/$sessionId/lecture?node_id=${Uri.encodeQueryComponent(nodeId)}';

  // Toolkit
  static const toolkitMistakeBook = '/toolkit/mistake-book';
  static const toolkitNotebooks = '/toolkit/notebooks';
  static String notebookDetail(int id) => '/toolkit/notebooks/$id';
  static String noteDetail(int nbId, int noteId) =>
      '/toolkit/notebooks/$nbId/notes/$noteId';
  static const toolkitSolve = '/toolkit/solve';
  static const toolkitQuiz = '/toolkit/quiz';
  static const toolkitMemoryDrill = '/toolkit/memory-drill';
  static const toolkitSettings = '/toolkit/settings';

  // Profile
  static const profileEdit = '/profile/edit';
  static const profileMemory = '/profile/memory';
  static const profileSubjects = '/profile/subjects';
  static const profileResources = '/profile/resources';
  static const profileHistory = '/profile/history';
  static const profileTokenUsage = '/profile/token-usage';
  static const profileTokenDetail = '/profile/token-usage/detail';
  static const profileNotifications = '/profile/notifications';
  static const profileApiConfig = '/profile/api-config';
  static const profileLogs = '/profile/logs';
  static const profileSettings = '/profile/settings';
  static String subjectDetail(int id) => '/profile/resources/$id';

  // Standalone pages
  static const skillMarketplace = '/skill-marketplace';
  static const skillDialogCreate = '/skill-create-dialog';
  static const workshop = '/workshop';
  static const workshopBuilder = '/workshop/builder';
  static String workshopApp(String id) => '/workshop/apps/$id';
  static const mindmapEntry = '/mindmap-entry';
  static String mindmapEntryForSubject(int subjectId) =>
      '/mindmap-entry?subject=$subjectId';

  // Calendar planner
  static const toolkitCalendar = '/toolkit/calendar';
  static String toolkitCalendarTask(String id) => '/toolkit/calendar/task/$id';
  static const toolkitCalendarCountdown = '/toolkit/calendar/countdown';
  static const toolkitCalendarStats = '/toolkit/calendar/stats';

  static String memoryDrillRun(CapabilityExecutionContext context) =>
      appendCapabilityQuery(toolkitMemoryDrill, context);

  // Backward-compatible aliases.
  static String legacyMindmap(int subjectId, int sessionId) =>
      '/course-space/$subjectId/mindmap/$sessionId';
  static String legacyLecture(int subjectId, int sessionId, String nodeId) =>
      lecture(subjectId, sessionId, nodeId);
  static String subjectDetailPath(int id) => subjectDetail(id);
  static String courseSpacePath(int id) => courseSpaceSubject(id);
  static String courseSpaceById(int id) => courseSpaceSubject(id);
  static String editableMindMap(int subjectId, int sessionId) =>
      mindmap(subjectId, sessionId);
  static String lecturePage(int subjectId, int sessionId, String nodeId) =>
      lecture(subjectId, sessionId, nodeId);
  static String notebookDetail_(int id) => notebookDetail(id);
  static String noteDetail_(int nbId, int noteId) => noteDetail(nbId, noteId);
}

typedef AppRoutes = R;
