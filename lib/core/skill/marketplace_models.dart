// lib/core/skill/marketplace_models.dart
// Skill 生态扩展层 Dart 数据模型
// 任务 22：Flutter 端 Skill 生态数据模型

import 'skill_model.dart';

// ─── 扩展来源枚举 ─────────────────────────────────────────────────────────────

enum SkillSourceExtended {
  builtin,
  userCreated,
  thirdPartyApi,
  experienceImport,
  marketplaceDownload,
  marketplaceFork,
}

extension SkillSourceExtendedX on SkillSourceExtended {
  String get value {
    switch (this) {
      case SkillSourceExtended.builtin:
        return 'builtin';
      case SkillSourceExtended.userCreated:
        return 'user_created';
      case SkillSourceExtended.thirdPartyApi:
        return 'third_party_api';
      case SkillSourceExtended.experienceImport:
        return 'experience_import';
      case SkillSourceExtended.marketplaceDownload:
        return 'marketplace_download';
      case SkillSourceExtended.marketplaceFork:
        return 'marketplace_fork';
    }
  }

  String get displayName {
    switch (this) {
      case SkillSourceExtended.builtin:
        return '内置';
      case SkillSourceExtended.userCreated:
        return '用户创建';
      case SkillSourceExtended.thirdPartyApi:
        return '第三方';
      case SkillSourceExtended.experienceImport:
        return '经验导入';
      case SkillSourceExtended.marketplaceDownload:
        return '市场下载';
      case SkillSourceExtended.marketplaceFork:
        return '市场分叉';
    }
  }

  static SkillSourceExtended fromString(String value) {
    switch (value) {
      case 'builtin':
        return SkillSourceExtended.builtin;
      case 'user_created':
        return SkillSourceExtended.userCreated;
      case 'third_party_api':
        return SkillSourceExtended.thirdPartyApi;
      case 'experience_import':
        return SkillSourceExtended.experienceImport;
      case 'marketplace_download':
        return SkillSourceExtended.marketplaceDownload;
      case 'marketplace_fork':
        return SkillSourceExtended.marketplaceFork;
      default:
        return SkillSourceExtended.builtin;
    }
  }
}

// ─── MarketplaceSkill ─────────────────────────────────────────────────────────

/// Skill 市场中的 Skill，继承 Skill 并新增市场相关字段。
class MarketplaceSkill extends Skill {
  final int downloadCount;
  final String? submitterId;
  final DateTime? submittedAt;
  final String? originalMarketplaceId;
  final DateTime? downloadedAt;

  const MarketplaceSkill({
    required super.id,
    required super.name,
    required super.description,
    required super.tags,
    required super.promptChain,
    required super.requiredComponents,
    required super.version,
    required super.createdAt,
    required super.type,
    super.createdBy,
    super.source,
    this.downloadCount = 0,
    this.submitterId,
    this.submittedAt,
    this.originalMarketplaceId,
    this.downloadedAt,
  });

  factory MarketplaceSkill.fromJson(Map<String, dynamic> json) {
    final promptChainRaw = (json['prompt_chain'] as List?) ?? [];
    final promptChain = promptChainRaw.map((node) {
      final n = node as Map<String, dynamic>;
      return PromptNode(
        id: n['id'] as String? ?? '',
        prompt: n['prompt'] as String? ?? '',
        inputMapping: (n['input_mapping'] as Map?)
                ?.map((k, v) => MapEntry(k as String, v as String)) ??
            const {},
      );
    }).toList();

    return MarketplaceSkill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      tags: ((json['tags'] as List?) ?? []).map((t) => t as String).toList(),
      promptChain: promptChain,
      requiredComponents: ((json['required_components'] as List?) ?? [])
          .map((c) => c as String)
          .toList(),
      version: json['version'] as String? ?? '1.0.0',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: json['type'] == 'builtin' ? SkillType.builtin : SkillType.custom,
      createdBy: json['created_by'] as String?,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      submitterId: json['submitter_id'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      originalMarketplaceId: json['original_marketplace_id'] as String?,
      downloadedAt: json['downloaded_at'] != null
          ? DateTime.tryParse(json['downloaded_at'] as String)
          : null,
    );
  }
}

// ─── DialogTurn ───────────────────────────────────────────────────────────────

/// 对话式 Skill 创建的单轮对话。
class DialogTurn {
  final String sessionId;
  final String question;
  final SkillDraft? draftPreview;
  final bool isComplete;

  const DialogTurn({
    required this.sessionId,
    required this.question,
    this.draftPreview,
    this.isComplete = false,
  });

  factory DialogTurn.fromJson(Map<String, dynamic> json) {
    SkillDraft? draftPreview;
    final draftRaw = json['draft_preview'];
    if (draftRaw != null) {
      draftPreview = _parseDraft(draftRaw as Map<String, dynamic>);
    }

    return DialogTurn(
      sessionId: json['session_id'] as String,
      question: json['question'] as String,
      draftPreview: draftPreview,
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }
}

// ─── SkillImportResult ────────────────────────────────────────────────────────

/// Skill JSON 导入结果。
class SkillImportResult {
  final bool success;
  final Skill? skill;
  final List<String> missingComponents;
  final List<String> errors;

  const SkillImportResult({
    required this.success,
    this.skill,
    this.missingComponents = const [],
    this.errors = const [],
  });

  factory SkillImportResult.fromJson(Map<String, dynamic> json) {
    Skill? skill;
    final skillRaw = json['skill'];
    if (skillRaw != null) {
      skill = _parseSkill(skillRaw as Map<String, dynamic>);
    }

    return SkillImportResult(
      success: json['success'] as bool,
      skill: skill,
      missingComponents: ((json['missing_components'] as List?) ?? [])
          .map((c) => c as String)
          .toList(),
      errors: ((json['errors'] as List?) ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

// ─── PaginatedSkillList ───────────────────────────────────────────────────────

/// 分页 Skill 列表。
class PaginatedSkillList {
  final List<MarketplaceSkill> skills;
  final int total;
  final int page;
  final int pageSize;

  const PaginatedSkillList({
    required this.skills,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PaginatedSkillList.fromJson(Map<String, dynamic> json) {
    final skillsRaw = (json['skills'] as List?) ?? [];
    final skills = skillsRaw
        .map((s) => MarketplaceSkill.fromJson(s as Map<String, dynamic>))
        .toList();

    return PaginatedSkillList(
      skills: skills,
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    );
  }
}

// ─── 内部工具函数 ─────────────────────────────────────────────────────────────

SkillDraft _parseDraft(Map<String, dynamic> json) {
  final stepsRaw = (json['steps'] as List?) ?? [];
  final steps = stepsRaw.map((node) {
    final n = node as Map<String, dynamic>;
    return PromptNode(
      id: n['id'] as String? ?? '',
      prompt: n['prompt'] as String? ?? '',
      inputMapping: (n['input_mapping'] as Map?)
              ?.map((k, v) => MapEntry(k as String, v as String)) ??
          const {},
    );
  }).toList();

  return SkillDraft(
    name: json['name'] as String?,
    description: json['description'] as String?,
    tags: ((json['tags'] as List?) ?? []).map((t) => t as String).toList(),
    promptChain: steps,
    requiredComponents: ((json['required_components'] as List?) ?? [])
        .map((c) => c as String)
        .toList(),
    isDraft: json['is_draft'] as bool? ?? true,
    sourceTextLength: (json['source_text_length'] as num?)?.toInt(),
  );
}

Skill _parseSkill(Map<String, dynamic> json) {
  final promptChainRaw = (json['prompt_chain'] as List?) ?? [];
  final promptChain = promptChainRaw.map((node) {
    final n = node as Map<String, dynamic>;
    return PromptNode(
      id: n['id'] as String? ?? '',
      prompt: n['prompt'] as String? ?? '',
      inputMapping: (n['input_mapping'] as Map?)
              ?.map((k, v) => MapEntry(k as String, v as String)) ??
          const {},
    );
  }).toList();

  return Skill(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    tags: ((json['tags'] as List?) ?? []).map((t) => t as String).toList(),
    promptChain: promptChain,
    requiredComponents: ((json['required_components'] as List?) ?? [])
        .map((c) => c as String)
        .toList(),
    version: json['version'] as String? ?? '1.0.0',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
    type: json['type'] == 'builtin' ? SkillType.builtin : SkillType.custom,
    createdBy: json['created_by'] as String?,
  );
}
