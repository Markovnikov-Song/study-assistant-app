/// 图谱维度枚举 - 支持知识/能力/问题/素质/思政五维图谱
enum GraphDimension {
  /// 知识图谱 - 默认，展示知识点
  knowledge('知识', 'knowledge'),
  
  /// 能力图谱 - 展示能力维度
  capability('能力', 'capability'),
  
  /// 问题图谱 - 展示典型问题/题型
  problem('问题', 'problem'),
  
  /// 素质图谱 - 展示素养维度
  quality('素质', 'quality'),
  
  /// 思政图谱 - 展示思政元素
  ideological('思政', 'ideological');

  final String label;
  final String value;
  
  const GraphDimension(this.label, this.value);
  
  static GraphDimension fromValue(String value) {
    return GraphDimension.values.firstWhere(
      (d) => d.value == value,
      orElse: () => GraphDimension.knowledge,
    );
  }
}

/// 节点维度映射数据模型
class NodeDimensionMapping {
  final int? id;
  final String nodeId;
  final GraphDimension dimension;
  final String mappingValue;  // 能力名称/问题类型/素质标签等
  final String source;  // "manual" 手动配置 / "ai" AI生成
  
  const NodeDimensionMapping({
    this.id,
    required this.nodeId,
    required this.dimension,
    required this.mappingValue,
    this.source = "manual",
  });
  
  factory NodeDimensionMapping.fromJson(Map<String, dynamic> json) {
    return NodeDimensionMapping(
      id: json['id'] as int?,
      nodeId: json['node_id'] as String,
      dimension: GraphDimension.fromValue(json['dimension'] as String),
      mappingValue: json['mapping_value'] as String,
      source: json['source'] as String? ?? "manual",
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'dimension': dimension.value,
      'mapping_value': mappingValue,
      'source': source,
    };
  }
}