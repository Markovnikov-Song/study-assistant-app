import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/shared_preferences_provider.dart';
import '../../providers/subject_provider.dart';

const onboardingDemoSetupPendingKey = 'onboarding.demo_course.pending.v1';

const _demoSubjectName = '高等数学';
const _demoDocumentName = '高等数学入门讲义.txt';
const _demoDocumentContent = '''
# 高等数学入门讲义

这份示例资料用于帮助你快速体验伴学的课程空间、思维导图和讲义生成流程。

## 1. 函数、极限与连续

函数描述变量之间的依赖关系。学习函数时，先关注定义域、值域、单调性、奇偶性和图像特征。

极限刻画变量无限接近某个点或无穷远处时函数值的趋势。常见方法包括等价无穷小、泰勒展开、洛必达法则和夹逼定理。

连续表示函数在某点附近没有跳跃或断裂。判断连续性通常需要检查函数值、左极限、右极限是否一致。

## 2. 导数与微分

导数表示函数在某点的瞬时变化率，也可以理解为曲线切线斜率。

常见求导规则包括四则运算、复合函数链式法则、隐函数求导和参数方程求导。

导数可以用于研究单调性、极值、凹凸性、拐点和实际优化问题。

## 3. 不定积分与定积分

不定积分关注寻找原函数，常用方法包括换元积分法、分部积分法和有理函数分解。

定积分表示累积量，可用于面积、体积、路程、平均值等问题。

牛顿-莱布尼茨公式建立了导数与积分之间的联系，是微积分的核心桥梁。

## 4. 多元函数与二重积分

多元函数研究多个自变量共同影响结果的情况。偏导数衡量某个变量单独变化时的影响。

二重积分可以理解为在平面区域上对函数值进行累积，常用于面积、体积、质量等问题。

学习建议：先让 AI 根据这份资料生成思维导图，再从导图节点进入讲义和练习。遇到错题后，把它加入错题本，后续复盘会更有针对性。
''';

final onboardingDemoServiceProvider = Provider<OnboardingDemoService>(
  (ref) => OnboardingDemoService(ref),
);

class OnboardingDemoResult {
  final int? subjectId;
  final bool deferred;

  const OnboardingDemoResult.ready(this.subjectId) : deferred = false;
  const OnboardingDemoResult.deferred() : subjectId = null, deferred = true;
}

class OnboardingDemoService {
  final Ref _ref;

  OnboardingDemoService(this._ref);

  Future<OnboardingDemoResult> prepareDemoCourse({
    bool allowDefer = true,
  }) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final isAuthenticated = _ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated) {
      if (allowDefer) {
        await prefs.setBool(onboardingDemoSetupPendingKey, true);
        return const OnboardingDemoResult.deferred();
      }
      return const OnboardingDemoResult.deferred();
    }

    final subjectService = _ref.read(subjectServiceProvider);
    final documentService = _ref.read(documentServiceProvider);

    final subjects = await subjectService.getSubjects(includeArchived: true);
    Subject? subject;
    for (final item in subjects) {
      if (item.name == _demoSubjectName) {
        subject = item;
        break;
      }
    }

    subject ??= await subjectService.createSubject(
      _demoSubjectName,
      category: '数学',
      description: '用于快速体验资料、导图、讲义、练习和计划的示例课程。',
      colorIndex: 0,
    );

    final documents = await documentService.getDocuments(subject.id);
    final hasDemoDocument = documents.any(
      (d) => d.filename == _demoDocumentName,
    );
    if (!hasDemoDocument) {
      await documentService.uploadDocument(
        fileBytes: utf8.encode(_demoDocumentContent),
        filename: _demoDocumentName,
        subjectId: subject.id,
      );
    }

    _ref.read(currentSubjectProvider.notifier).state = subject;
    _ref.invalidate(subjectsProvider);
    _ref.invalidate(documentsProvider(subject.id));
    _ref.invalidate(subjectKnowledgeBaseProvider(subject.id));
    await prefs.setBool(onboardingDemoSetupPendingKey, false);

    return OnboardingDemoResult.ready(subject.id);
  }

  Future<OnboardingDemoResult?> runPendingDemoSetup() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final pending = prefs.getBool(onboardingDemoSetupPendingKey) ?? false;
    if (!pending || !_ref.read(authProvider).isAuthenticated) return null;
    return prepareDemoCourse(allowDefer: false);
  }
}
