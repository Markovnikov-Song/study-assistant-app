class CapabilitySummary {
  final String id;
  final String kind;
  final String title;
  final String description;
  final String category;
  final String version;
  final String icon;
  final List<String> color;
  final String? actionId;
  final String? miniAppRoute;
  final bool standalone;
  final bool orchestratable;
  final bool schedulable;
  final List<String> nodeTypes;
  final List<String> patternRefs;
  final List<String> adapterRefs;
  final List<String> providerRefs;
  final List<String> fallbackRefs;
  final List<String> tags;

  const CapabilitySummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.category,
    required this.version,
    required this.icon,
    required this.color,
    this.actionId,
    this.miniAppRoute,
    required this.standalone,
    required this.orchestratable,
    required this.schedulable,
    required this.nodeTypes,
    required this.patternRefs,
    required this.adapterRefs,
    required this.providerRefs,
    required this.fallbackRefs,
    required this.tags,
  });

  factory CapabilitySummary.fromJson(Map<String, dynamic> json) {
    return CapabilitySummary(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'capability_app',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      version: json['version'] as String? ?? '1.0.0',
      icon: json['icon'] as String? ?? 'auto_awesome',
      color: ((json['color'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      actionId: json['action_id'] as String?,
      miniAppRoute: json['mini_app_route'] as String?,
      standalone: json['standalone'] as bool? ?? false,
      orchestratable: json['orchestratable'] as bool? ?? false,
      schedulable: json['schedulable'] as bool? ?? false,
      nodeTypes: ((json['node_types'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      patternRefs: ((json['pattern_refs'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      adapterRefs: ((json['adapter_refs'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      providerRefs: ((json['provider_refs'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      fallbackRefs: ((json['fallback_refs'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      tags: ((json['tags'] as List?) ?? const []).whereType<String>().toList(),
    );
  }
}
