// Learning OS — 学习模式全局状态
// 四种模式：纯手动 / DIY / Skill 驱动 / Multi-Agent
// 需求 4.1：模式切换入口叠加在现有导航之上，不替换底部导航。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/skill/skill_model.dart';

/// 当前学习模式，全局共享。
/// 默认为纯手动模式（永远可用，不依赖 AI）。
final learningModeProvider = StateProvider<LearningMode>(
  (ref) => LearningMode.manual,
);
