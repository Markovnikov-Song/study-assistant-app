import 'package:shared_preferences/shared_preferences.dart';

/// 成就类型
enum AchievementType {
  // 节点点亮成就
  beginner,        // 初学者 - 点亮 5 节点
  intermediate,    // 进阶学习者 - 点亮 20 节点  
  advanced,        // 熟练掌握 - 点亮 50 节点
  expert,          // 知识达人 - 点亮 100 节点
  master,          // 知识大师 - 点亮 200 节点
  
  // 学习 streak 成就
  streak3,         // 连续学习 3 天
  streak7,         // 连续学习 7 天
  streak30,        // 连续学习 30 天
  
  // 技能成就
  firstMindMap,    // 完成第一张思维导图
  quizMaster,      // 答题正确率 100% (10题)
  feynmanLearner,  // 完成费曼学习法
}

/// 成就定义
class Achievement {
  final AchievementType type;
  final String name;
  final String description;
  final String icon;
  final int requirement;
  
  const Achievement({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.requirement,
  });
  
  static const List<Achievement> all = [
    Achievement(type: AchievementType.beginner, name: '初学者', description: '点亮 5 个知识点', icon: '🌱', requirement: 5),
    Achievement(type: AchievementType.intermediate, name: '进阶学习者', description: '点亮 20 个知识点', icon: '🌿', requirement: 20),
    Achievement(type: AchievementType.advanced, name: '熟练掌握', description: '点亮 50 个知识点', icon: '🌳', requirement: 50),
    Achievement(type: AchievementType.expert, name: '知识达人', description: '点亮 100 个知识点', icon: '🎓', requirement: 100),
    Achievement(type: AchievementType.master, name: '知识大师', description: '点亮 200 个知识点', icon: '👑', requirement: 200),
    Achievement(type: AchievementType.streak3, name: '坚持不懈', description: '连续学习 3 天', icon: '🔥', requirement: 3),
    Achievement(type: AchievementType.streak7, name: '一周之星', description: '连续学习 7 天', icon: '⭐', requirement: 7),
    Achievement(type: AchievementType.streak30, name: '学习达人', description: '连续学习 30 天', icon: '💎', requirement: 30),
    Achievement(type: AchievementType.firstMindMap, name: '思维启航', description: '完成第一张思维导图', icon: '🗺️', requirement: 1),
    Achievement(type: AchievementType.quizMaster, name: '答题高手', description: '答题正确率 100%（10题）', icon: '🏆', requirement: 10),
    Achievement(type: AchievementType.feynmanLearner, name: '费曼学员', description: '完成费曼学习法', icon: '📢', requirement: 1),
  ];
}

/// 成就服务
class AchievementService {
  static const String _achievementsKey = 'user_achievements';
  static const String _masteredNodesKey = 'mastered_nodes_count';
  static const String _streakDaysKey = 'streak_days';
  
  /// 检查并返回新成就
  Future<List<Achievement>> checkAchievements({
    required int masteredNodesCount,
    required int streakDays,
    bool quizPerfect = false,
    bool mindMapCompleted = false,
    bool feynmanCompleted = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedJson = prefs.getStringList(_achievementsKey) ?? [];
    final unlocked = unlockedJson.map((e) => AchievementType.values.byName(e)).toSet();
    
    final newAchievements = <Achievement>[];
    
    for (final achievement in Achievement.all) {
      if (unlocked.contains(achievement.type)) continue;
      
      bool unlockedNow = false;
      
      switch (achievement.type) {
        case AchievementType.beginner:
        case AchievementType.intermediate:
        case AchievementType.advanced:
        case AchievementType.expert:
        case AchievementType.master:
          unlockedNow = masteredNodesCount >= achievement.requirement;
          break;
        case AchievementType.streak3:
        case AchievementType.streak7:
        case AchievementType.streak30:
          unlockedNow = streakDays >= achievement.requirement;
          break;
        case AchievementType.quizMaster:
          unlockedNow = quizPerfect;
          break;
        case AchievementType.firstMindMap:
          unlockedNow = mindMapCompleted;
          break;
        case AchievementType.feynmanLearner:
          unlockedNow = feynmanCompleted;
          break;
      }
      
      if (unlockedNow) {
        unlocked.add(achievement.type);
        newAchievements.add(achievement);
      }
    }
    
    // 保存解锁的成就
    await prefs.setStringList(
      _achievementsKey,
      unlocked.map((e) => e.name).toList(),
    );
    
    return newAchievements;
  }
  
  /// 获取已解锁成就列表
  Future<List<Achievement>> getUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedJson = prefs.getStringList(_achievementsKey) ?? [];
    final unlocked = unlockedJson.map((e) => AchievementType.values.byName(e)).toSet();
    
    return Achievement.all.where((a) => unlocked.contains(a.type)).toList();
  }
  
  /// 获取学习统计
  Future<Map<String, int>> getLearningStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'masteredNodes': prefs.getInt(_masteredNodesKey) ?? 0,
      'streakDays': prefs.getInt(_streakDaysKey) ?? 0,
    };
  }
  
  /// 更新节点掌握数
  Future<void> updateMasteredNodesCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_masteredNodesKey, count);
  }
  
  /// 更新连续学习天数
  Future<void> updateStreakDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakDaysKey, days);
  }
}