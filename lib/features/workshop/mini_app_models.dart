class MiniAppValidation {
  final bool ok;
  final List<String> errors;
  final List<String> warnings;

  const MiniAppValidation({
    required this.ok,
    required this.errors,
    required this.warnings,
  });

  factory MiniAppValidation.fromJson(Map<String, dynamic> json) {
    return MiniAppValidation(
      ok: json['ok'] as bool? ?? false,
      errors: ((json['errors'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class WorkshopBlockCategory {
  final String id;
  final String name;
  final String color;

  const WorkshopBlockCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  factory WorkshopBlockCategory.fromJson(Map<String, dynamic> json) {
    return WorkshopBlockCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#64748B',
    );
  }
}

class WorkshopBlockParam {
  final String name;
  final String slot;
  final bool required;
  final dynamic defaultValue;
  final List<String> options;
  final List<String> accepts;

  const WorkshopBlockParam({
    required this.name,
    required this.slot,
    required this.required,
    this.defaultValue,
    required this.options,
    required this.accepts,
  });

  factory WorkshopBlockParam.fromJson(Map<String, dynamic> json) {
    return WorkshopBlockParam(
      name: json['name'] as String? ?? '',
      slot: json['slot'] as String? ?? '',
      required: json['required'] == true,
      defaultValue: json['default'],
      options: ((json['options'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      accepts: ((json['accepts'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class WorkshopBlockDefinition {
  final String id;
  final String category;
  final String shape;
  final String label;
  final String? returns;
  final List<WorkshopBlockParam> params;
  final List<WorkshopBlockOutput> outputs;
  final List<String> sideEffects;
  final bool failurePolicyRequired;
  final bool requiresRunContext;
  final bool requiresIdempotencyKey;

  const WorkshopBlockDefinition({
    required this.id,
    required this.category,
    required this.shape,
    required this.label,
    this.returns,
    required this.params,
    required this.outputs,
    required this.sideEffects,
    required this.failurePolicyRequired,
    required this.requiresRunContext,
    required this.requiresIdempotencyKey,
  });

  factory WorkshopBlockDefinition.fromJson(Map<String, dynamic> json) {
    return WorkshopBlockDefinition(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      shape: json['shape'] as String? ?? '',
      label: json['label'] as String? ?? '',
      returns: json['returns'] as String?,
      params: ((json['params'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => WorkshopBlockParam.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      outputs: ((json['outputs'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                WorkshopBlockOutput.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      sideEffects: ((json['side_effects'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      failurePolicyRequired: json['failure_policy_required'] == true,
      requiresRunContext: json['requires_run_context'] == true,
      requiresIdempotencyKey: json['requires_idempotency_key'] == true,
    );
  }
}

class WorkshopBlockOutput {
  final String name;
  final String type;

  const WorkshopBlockOutput({required this.name, required this.type});

  factory WorkshopBlockOutput.fromJson(Map<String, dynamic> json) {
    return WorkshopBlockOutput(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}

class WorkshopResourceActorType {
  final String id;
  final String name;
  final String sourceFeature;
  final bool read;
  final bool write;

  const WorkshopResourceActorType({
    required this.id,
    required this.name,
    required this.sourceFeature,
    required this.read,
    required this.write,
  });

  factory WorkshopResourceActorType.fromJson(Map<String, dynamic> json) {
    return WorkshopResourceActorType(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sourceFeature: json['source_feature'] as String? ?? '',
      read: json['read'] == true,
      write: json['write'] == true,
    );
  }
}

class WorkshopWorkflowRegistry {
  final String schemaVersion;
  final String runtimeSchemaVersion;
  final List<WorkshopBlockCategory> categories;
  final List<WorkshopBlockDefinition> blocks;
  final List<WorkshopResourceActorType> resourceActorTypes;
  final Map<String, dynamic> exampleWorkflow;

  const WorkshopWorkflowRegistry({
    required this.schemaVersion,
    required this.runtimeSchemaVersion,
    required this.categories,
    required this.blocks,
    required this.resourceActorTypes,
    required this.exampleWorkflow,
  });

  factory WorkshopWorkflowRegistry.fromJson(Map<String, dynamic> json) {
    return WorkshopWorkflowRegistry(
      schemaVersion: json['schema_version'] as String? ?? '',
      runtimeSchemaVersion:
          json['runtime_schema_version'] as String? ?? 'workshop.workflow.v1',
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                WorkshopBlockCategory.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      blocks: ((json['blocks'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                WorkshopBlockDefinition.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      resourceActorTypes: ((json['resource_actor_types'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => WorkshopResourceActorType.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      exampleWorkflow:
          (json['example_workflow'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
  }

  List<WorkshopBlockDefinition> blocksForCategory(String categoryId) {
    return blocks.where((block) => block.category == categoryId).toList();
  }
}

class WorkshopWorkflowValidationResult {
  final MiniAppValidation validation;
  final Map<String, dynamic> normalized;

  const WorkshopWorkflowValidationResult({
    required this.validation,
    required this.normalized,
  });

  factory WorkshopWorkflowValidationResult.fromJson(Map<String, dynamic> json) {
    return WorkshopWorkflowValidationResult(
      validation: MiniAppValidation.fromJson(
        (json['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      normalized:
          (json['normalized'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class WorkshopWorkflowPatchResult {
  final List<Map<String, dynamic>> patch;
  final Map<String, dynamic> workflow;
  final MiniAppValidation validation;
  final List<String> changed;

  const WorkshopWorkflowPatchResult({
    required this.patch,
    required this.workflow,
    required this.validation,
    required this.changed,
  });

  factory WorkshopWorkflowPatchResult.fromJson(Map<String, dynamic> json) {
    return WorkshopWorkflowPatchResult(
      patch: ((json['patch'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(),
      workflow: (json['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
      validation: MiniAppValidation.fromJson(
        (json['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      changed: ((json['changed'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class MiniAppSummary {
  final String id;
  final String title;
  final String appType;
  final int? subjectId;
  final String status;
  final String? currentVersionId;
  final String description;
  final String updatedAt;
  final MiniAppValidation validation;

  const MiniAppSummary({
    required this.id,
    required this.title,
    required this.appType,
    required this.subjectId,
    required this.status,
    this.currentVersionId,
    required this.description,
    required this.updatedAt,
    required this.validation,
  });

  factory MiniAppSummary.fromJson(Map<String, dynamic> json) {
    return MiniAppSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      appType: json['app_type'] as String? ?? 'memory',
      subjectId: json['subject_id'] as int?,
      status: json['status'] as String? ?? 'draft',
      currentVersionId: json['current_version_id'] as String?,
      description: json['description'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      validation: MiniAppValidation.fromJson(
        (json['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class MiniAppRecord {
  final String id;
  final String title;
  final String appType;
  final int? subjectId;
  final String status;
  final String? currentVersionId;
  final Map<String, String> documents;
  final Map<String, dynamic> spec;
  final Map<String, dynamic> graph;
  final MiniAppValidation validation;
  final String updatedAt;

  const MiniAppRecord({
    required this.id,
    required this.title,
    required this.appType,
    required this.subjectId,
    required this.status,
    this.currentVersionId,
    required this.documents,
    required this.spec,
    required this.graph,
    required this.validation,
    required this.updatedAt,
  });

  factory MiniAppRecord.fromJson(Map<String, dynamic> json) {
    final rawDocs =
        (json['documents'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MiniAppRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      appType: json['app_type'] as String? ?? 'memory',
      subjectId: json['subject_id'] as int?,
      status: json['status'] as String? ?? 'draft',
      currentVersionId: json['current_version_id'] as String?,
      documents: rawDocs.map((key, value) => MapEntry(key, value.toString())),
      spec: (json['spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      graph: (json['graph'] as Map?)?.cast<String, dynamic>() ?? const {},
      validation: MiniAppValidation.fromJson(
        (json['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class MiniAppVersion {
  final String id;
  final String appId;
  final String userId;
  final int sequence;
  final String? parentVersionId;
  final String source;
  final String? instruction;
  final List<String> changed;
  final String summary;
  final Map<String, dynamic> snapshot;
  final String createdAt;

  const MiniAppVersion({
    required this.id,
    required this.appId,
    required this.userId,
    required this.sequence,
    this.parentVersionId,
    required this.source,
    this.instruction,
    required this.changed,
    required this.summary,
    required this.snapshot,
    required this.createdAt,
  });

  factory MiniAppVersion.fromJson(Map<String, dynamic> json) {
    return MiniAppVersion(
      id: json['id'] as String? ?? '',
      appId: json['app_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      parentVersionId: json['parent_version_id'] as String?,
      source: json['source'] as String? ?? '',
      instruction: json['instruction'] as String?,
      changed: ((json['changed'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      summary: json['summary'] as String? ?? '',
      snapshot: (json['snapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MiniAppVersionListResult {
  final String appId;
  final String? currentVersionId;
  final List<MiniAppVersion> versions;
  final int total;

  const MiniAppVersionListResult({
    required this.appId,
    this.currentVersionId,
    required this.versions,
    required this.total,
  });

  factory MiniAppVersionListResult.fromJson(Map<String, dynamic> json) {
    return MiniAppVersionListResult(
      appId: json['app_id'] as String? ?? '',
      currentVersionId: json['current_version_id'] as String?,
      versions: ((json['versions'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MiniAppVersion.fromJson(item.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class MiniAppVersionDiffItem {
  final String path;
  final String changeType;
  final dynamic before;
  final dynamic after;

  const MiniAppVersionDiffItem({
    required this.path,
    required this.changeType,
    this.before,
    this.after,
  });

  factory MiniAppVersionDiffItem.fromJson(Map<String, dynamic> json) {
    return MiniAppVersionDiffItem(
      path: json['path'] as String? ?? '',
      changeType: json['change_type'] as String? ?? 'changed',
      before: json['before'],
      after: json['after'],
    );
  }
}

class MiniAppVersionDiffResult {
  final String appId;
  final String? baseVersionId;
  final String targetVersionId;
  final List<MiniAppVersionDiffItem> items;
  final List<String> changed;
  final int total;

  const MiniAppVersionDiffResult({
    required this.appId,
    this.baseVersionId,
    required this.targetVersionId,
    required this.items,
    required this.changed,
    required this.total,
  });

  factory MiniAppVersionDiffResult.fromJson(Map<String, dynamic> json) {
    return MiniAppVersionDiffResult(
      appId: json['app_id'] as String? ?? '',
      baseVersionId: json['base_version_id'] as String?,
      targetVersionId: json['target_version_id'] as String? ?? '',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MiniAppVersionDiffItem.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      changed: ((json['changed'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class MiniAppRollbackResult {
  final MiniAppRecord app;
  final MiniAppVersion version;
  final MiniAppVersionDiffResult diff;

  const MiniAppRollbackResult({
    required this.app,
    required this.version,
    required this.diff,
  });

  factory MiniAppRollbackResult.fromJson(Map<String, dynamic> json) {
    return MiniAppRollbackResult(
      app: MiniAppRecord.fromJson((json['app'] as Map).cast<String, dynamic>()),
      version: MiniAppVersion.fromJson(
        (json['version'] as Map).cast<String, dynamic>(),
      ),
      diff: MiniAppVersionDiffResult.fromJson(
        (json['diff'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class GenerateCardsResult {
  final MiniAppRecord app;
  final int targetCardCount;
  final int actualCardCount;

  const GenerateCardsResult({
    required this.app,
    required this.targetCardCount,
    required this.actualCardCount,
  });

  factory GenerateCardsResult.fromJson(Map<String, dynamic> json) {
    return GenerateCardsResult(
      app: MiniAppRecord.fromJson((json['app'] as Map).cast<String, dynamic>()),
      targetCardCount: (json['target_card_count'] as num?)?.toInt() ?? 0,
      actualCardCount: (json['actual_card_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MiniAppInterviewTurn {
  final String sessionId;
  final String status;
  final String? question;
  final Map<String, String> collected;
  final MiniAppRecord? draft;
  final MiniAppValidation? validation;

  const MiniAppInterviewTurn({
    required this.sessionId,
    required this.status,
    this.question,
    required this.collected,
    this.draft,
    this.validation,
  });

  bool get isReady => status == 'ready' && draft != null;

  factory MiniAppInterviewTurn.fromJson(Map<String, dynamic> json) {
    final rawCollected =
        (json['collected'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MiniAppInterviewTurn(
      sessionId: json['session_id'] as String? ?? '',
      status: json['status'] as String? ?? 'collecting',
      question: json['question'] as String?,
      collected: rawCollected.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      draft: json['draft'] is Map
          ? MiniAppRecord.fromJson(
              (json['draft'] as Map).cast<String, dynamic>(),
            )
          : null,
      validation: json['validation'] is Map
          ? MiniAppValidation.fromJson(
              (json['validation'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}
