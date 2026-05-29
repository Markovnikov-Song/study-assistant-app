import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Skill 启动器
class SkillLauncher {
  /// 根据 Skill ID 和节点启动对应页面
  static Future<void> launch({
    required BuildContext context,
    required String skillId,
    required String nodeId,
    int? subjectId,
  }) async {
    final route = _getRoute(skillId, subjectId);
    
    // 传递参数
    if (context.mounted) {
      context.push('$route?node=$nodeId');
    }
  }
  
  static String _getRoute(String skillId, int? subjectId) {
    switch (skillId) {
      case 'mindmap_learning':
      case 'mindmap':
        return '/mindmap-entry${subjectId != null ? '?subject=$subjectId' : ''}';
      case 'quiz':
      case 'comprehensive_test':
      case 'drill':
        return '/toolkit/quiz';
      case 'mistake_review':
        return '/toolkit/mistake-book';
      case 'feynman_technique':
        return '/feynman';
      case 'lecture':
        return subjectId != null 
            ? '/course-space/$subjectId/lecture' 
            : '/course-space';
      default:
        return '/toolkit';
    }
  }
}

/// Skill 推荐卡片组件
class SkillRecommendationCard extends StatelessWidget {
  final String skillId;
  final String skillName;
  final String reason;
  final VoidCallback onLaunch;
  
  const SkillRecommendationCard({
    super.key,
    required this.skillId,
    required this.skillName,
    required this.reason,
    required this.onLaunch,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: onLaunch,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSkillIcon(skillId),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skillName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getSkillIcon(String skillId) {
    switch (skillId) {
      case 'mindmap_learning':
      case 'mindmap':
        return Icons.account_tree;
      case 'quiz':
      case 'comprehensive_test':
      case 'drill':
        return Icons.quiz;
      case 'mistake_review':
        return Icons.error_outline;
      case 'feynman_technique':
        return Icons.record_voice_over;
      case 'lecture':
        return Icons.menu_book;
      default:
        return Icons.school;
    }
  }
}