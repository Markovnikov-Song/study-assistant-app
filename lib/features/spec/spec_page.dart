import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/study_plan_models.dart';
import 'providers/study_planner_providers.dart';
import 'widgets/phase_chat_view.dart';
import 'widgets/phase_progress_view.dart';
import 'widgets/phase_plan_view.dart';
import '../../services/level2_monitor.dart';

/// Spec 规划页：三阶段视图
///   Phase.chat     → 对话收集目标
///   Phase.progress → 规划进度（后台生成中）
///   Phase.plan     → 计划表
class SpecPage extends ConsumerStatefulWidget {
  final List<int> prefilledSubjectIds;
  final String? prefilledContext;

  const SpecPage({
    super.key,
    this.prefilledSubjectIds = const [],
    this.prefilledContext,
  });

  @override
  ConsumerState<SpecPage> createState() => _SpecPageState();
}

class _SpecPageState extends ConsumerState<SpecPage> {
  int? _generatingPlanId;
  StudyPlan? _activePlan;
  bool _initialized = false;

  Level2Monitor? _level2Monitor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
      // 启动 Level 2 监控
      _level2Monitor = Level2Monitor(ref, () => context);
      _level2Monitor!.start();
    });
  }

  @override
  void dispose() {
    _level2Monitor?.stop();
    super.dispose();
  }

  Future<void> _init() async {
    // 检查是否已有 active 计划
    final plan = await ref.read(studyPlannerApiServiceProvider).getActivePlan();
    if (!mounted) return;
    if (plan != null && plan.isActive) {
      setState(() {
        _activePlan = plan;
        _initialized = true;
      });
      ref.read(specPhaseProvider.notifier).state = SpecPhase.plan;
    } else {
      setState(() => _initialized = true);
      ref.read(specPhaseProvider.notifier).state = SpecPhase.chat;
    }
  }

  Future<void> _onChatConfirmed() async {
    final collection = ref.read(planCollectionProvider);
    if (!collection.isComplete) return;

    try {
      final result = await ref.read(studyPlannerApiServiceProvider).createPlan(
            subjectIds: collection.subjectIds,
            deadline: collection.deadline!,
            dailyMinutes: collection.dailyMinutes,
          );
      final planId = result['plan_id'] as int?;
      if (planId == null) throw Exception('未获取到 plan_id');

      setState(() => _generatingPlanId = planId);
      ref.read(specPhaseProvider.notifier).state = SpecPhase.progress;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建计划失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onProgressComplete() async {
    // 规划完成，加载计划数据
    final plan = await ref.read(studyPlannerApiServiceProvider).getActivePlan();
    if (!mounted) return;
    if (plan != null) {
      setState(() => _activePlan = plan);
      ref.invalidate(activePlanProvider);
      ref.invalidate(todayPlanItemsProvider);
    }
    ref.read(specPhaseProvider.notifier).state = SpecPhase.plan;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phase = ref.watch(specPhaseProvider);
    final collection = ref.watch(planCollectionProvider);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('学习规划')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_appBarTitle(phase)),
        centerTitle: false,
        actions: [
          if (phase == SpecPhase.plan && _activePlan != null)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: '刷新计划',
              onPressed: () async {
                final plan = await ref.read(studyPlannerApiServiceProvider).getActivePlan();
                if (plan != null && mounted) setState(() => _activePlan = plan);
              },
            ),
        ],
      ),
      body: _buildBody(phase, collection),
    );
  }

  String _appBarTitle(SpecPhase phase) => switch (phase) {
        SpecPhase.chat => '制定学习计划',
        SpecPhase.progress => '正在生成计划…',
        SpecPhase.plan => '我的学习计划',
      };

  Widget _buildBody(SpecPhase phase, PlanCollectionState collection) {
    switch (phase) {
      case SpecPhase.chat:
        return PhaseChatView(
          prefilledSubjectIds: widget.prefilledSubjectIds,
          onConfirmed: _onChatConfirmed,
        );
      case SpecPhase.progress:
        if (_generatingPlanId == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return PhaseProgressView(
          planId: _generatingPlanId!,
          subjectNames: collection.subjectNames,
          onComplete: _onProgressComplete,
        );
      case SpecPhase.plan:
        if (_activePlan == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return PhasePlanView(plan: _activePlan!);
    }
  }
}
