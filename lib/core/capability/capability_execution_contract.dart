class CapabilityExecutionContext {
  final String capabilityId;
  final String topic;
  final int? count;
  final String? contentType;
  final int? planId;
  final int? itemId;
  final Map<String, dynamic> params;

  const CapabilityExecutionContext({
    required this.capabilityId,
    this.topic = '',
    this.count,
    this.contentType,
    this.planId,
    this.itemId,
    this.params = const {},
  });

  factory CapabilityExecutionContext.fromQuery(
    Map<String, String> query, {
    required String capabilityId,
  }) =>
      CapabilityExecutionContext(
        capabilityId: capabilityId,
        topic: query['topic'] ?? '',
        count: int.tryParse(query['count'] ?? ''),
        contentType: query['content_type'],
        planId: int.tryParse(query['plan_id'] ?? ''),
        itemId: int.tryParse(query['item_id'] ?? ''),
        params: Map.of(query),
      );

  bool get isPlanBound => planId != null && itemId != null;

  Map<String, String> toQuery() {
    return {
      if (topic.isNotEmpty) 'topic': topic,
      if (count != null) 'count': '$count',
      if (contentType != null && contentType!.isNotEmpty)
        'content_type': contentType!,
      if (planId != null) 'plan_id': '$planId',
      if (itemId != null) 'item_id': '$itemId',
      if (params['source_mode'] != null)
        'source_mode': '${params['source_mode']}',
    };
  }
}

String appendCapabilityQuery(
  String route,
  CapabilityExecutionContext context,
) {
  final query = context.toQuery();
  if (query.isEmpty) return route;
  return '$route?${Uri(queryParameters: query).query}';
}
