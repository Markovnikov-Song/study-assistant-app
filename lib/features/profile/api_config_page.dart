import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_config_service.dart';
import '../../services/token_service.dart';
import '../../routes/app_router.dart';

final apiConfigServiceProvider = Provider((ref) => ApiConfigService());

class ApiConfigPage extends ConsumerStatefulWidget {
  const ApiConfigPage({super.key});

  @override
  ConsumerState<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends ConsumerState<ApiConfigPage> {
  bool _sharedConfigVerified = false;
  bool _loading = true;

  final _passphraseCtrl = TextEditingController();
  final _llmBaseUrlCtrl = TextEditingController();
  final _llmKeyCtrl = TextEditingController();
  final _llmModelCtrl = TextEditingController();
  final _visionBaseUrlCtrl = TextEditingController();
  final _visionKeyCtrl = TextEditingController();
  final _visionModelCtrl = TextEditingController();
  final _embeddingBaseUrlCtrl = TextEditingController();
  final _embeddingKeyCtrl = TextEditingController();
  final _embeddingModelCtrl = TextEditingController();
  final _rerankerBaseUrlCtrl = TextEditingController();
  final _rerankerKeyCtrl = TextEditingController();
  final _rerankerModelCtrl = TextEditingController();

  // Token 统计数据
  TokenQuota? _quota;
  UsageSummary? _todayUsage;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadTokenStats();
  }

  Future<void> _loadTokenStats() async {
    try {
      final service = TokenService();
      final quota = await service.getQuota();
      final todayUsage = await service.getTodayUsage();

      if (mounted) {
        setState(() {
          _quota = quota;
          _todayUsage = todayUsage;
        });
      }
    } on TypeError catch (e) {
      // 特别处理类型错误
      debugPrint('Token统计类型错误: $e');
      if (mounted) {
        setState(() {
          _quota = null;
          _todayUsage = null;
        });
      }
    } catch (e) {
      // 忽略错误，不影响主功能
      debugPrint('加载Token统计失败: $e');
      if (mounted) {
        setState(() {
          _quota = null;
          _todayUsage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _llmBaseUrlCtrl.dispose();
    _llmKeyCtrl.dispose();
    _llmModelCtrl.dispose();
    _visionBaseUrlCtrl.dispose();
    _visionKeyCtrl.dispose();
    _visionModelCtrl.dispose();
    _embeddingBaseUrlCtrl.dispose();
    _embeddingKeyCtrl.dispose();
    _embeddingModelCtrl.dispose();
    _rerankerBaseUrlCtrl.dispose();
    _rerankerKeyCtrl.dispose();
    _rerankerModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      // 从后端获取配置状态
      final status = await ref.read(apiConfigServiceProvider).getConfigStatus();

      // 添加类型检查，避免类型错误
      setState(() {
        _sharedConfigVerified = status['shared_config_verified'] is bool
            ? status['shared_config_verified'] as bool
            : false;
      });

      // 如果用户有自己的配置，从本地加载
      final hasCustomConfig = status['has_custom_config'] is bool
          ? status['has_custom_config'] as bool
          : false;

      if (hasCustomConfig) {
        final storage = const FlutterSecureStorage();
        _llmBaseUrlCtrl.text = await storage.read(key: 'llm_base_url') ?? '';
        _llmKeyCtrl.text = await storage.read(key: 'llm_api_key') ?? '';
        _llmModelCtrl.text = status['custom_llm_model'] as String? ?? '';
        _visionBaseUrlCtrl.text =
            await storage.read(key: 'vision_base_url') ?? '';
        _visionKeyCtrl.text = await storage.read(key: 'vision_api_key') ?? '';
        _visionModelCtrl.text = status['custom_vision_model'] as String? ?? '';
        _embeddingBaseUrlCtrl.text =
            status['custom_embedding_base_url'] as String? ?? '';
        _embeddingKeyCtrl.text =
            await storage.read(key: 'embedding_api_key') ?? '';
        _embeddingModelCtrl.text =
            status['custom_embedding_model'] as String? ?? '';
        _rerankerBaseUrlCtrl.text =
            status['custom_reranker_base_url'] as String? ?? '';
        _rerankerKeyCtrl.text =
            await storage.read(key: 'reranker_api_key') ?? '';
        _rerankerModelCtrl.text =
            status['custom_reranker_model'] as String? ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载配置失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPassphrase() async {
    final passphrase = _passphraseCtrl.text.trim();
    if (passphrase.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入口令')));
      return;
    }

    try {
      final result = await ref
          .read(apiConfigServiceProvider)
          .verifySharedConfig(passphrase);

      if (mounted) {
        if (result['verified'] == true) {
          setState(() {
            _sharedConfigVerified = true;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'] ?? '验证成功')));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'] ?? '验证失败')));
        }
      }
    } catch (e, st) {
      debugPrint('_verifyPassphrase error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('验证失败：$e')));
      }
    }
  }

  Future<void> _saveCustomConfig() async {
    final llmKey = _llmKeyCtrl.text.trim();
    if (llmKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少填写语言模型的 API Key')));
      return;
    }

    try {
      // 保存到本地（Key 敏感，存 SecureStorage；其余存后端）
      final storage = const FlutterSecureStorage();
      await storage.write(
        key: 'llm_base_url',
        value: _llmBaseUrlCtrl.text.trim(),
      );
      await storage.write(key: 'llm_api_key', value: llmKey);
      await storage.write(
        key: 'vision_base_url',
        value: _visionBaseUrlCtrl.text.trim(),
      );
      await storage.write(
        key: 'vision_api_key',
        value: _visionKeyCtrl.text.trim(),
      );
      await storage.write(
        key: 'embedding_api_key',
        value: _embeddingKeyCtrl.text.trim(),
      );
      await storage.write(
        key: 'reranker_api_key',
        value: _rerankerKeyCtrl.text.trim(),
      );

      // 同步到后端
      await ref
          .read(apiConfigServiceProvider)
          .saveCustomConfig(
            llmBaseUrl: _llmBaseUrlCtrl.text.trim(),
            llmApiKey: llmKey,
            llmModel: _llmModelCtrl.text.trim(),
            visionBaseUrl: _visionBaseUrlCtrl.text.trim(),
            visionApiKey: _visionKeyCtrl.text.trim(),
            visionModel: _visionModelCtrl.text.trim(),
            embeddingBaseUrl: _embeddingBaseUrlCtrl.text.trim(),
            embeddingApiKey: _embeddingKeyCtrl.text.trim(),
            embeddingModel: _embeddingModelCtrl.text.trim(),
            rerankerBaseUrl: _rerankerBaseUrlCtrl.text.trim(),
            rerankerApiKey: _rerankerKeyCtrl.text.trim(),
            rerankerModel: _rerankerModelCtrl.text.trim(),
          );

      if (mounted) {
        setState(() {
          _sharedConfigVerified = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  Future<void> _testConnection() async {
    try {
      final result = await ref.read(apiConfigServiceProvider).testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '测试完成'),
            backgroundColor: result['success'] == true
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('测试失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 模型配置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 模型配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_find),
            tooltip: '测试连接',
            onPressed: _testConnection,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Token 使用统计卡片
          if (_quota != null && _todayUsage != null) _buildTokenStatsCard(cs),
          if (_quota != null && _todayUsage != null) const SizedBox(height: 16),
          // 说明卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '使用说明',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本应用需要配置 OpenAI 兼容的 API 才能使用 AI 功能。\n\n'
                    '你可以：\n'
                    '• 使用自己的 API Key（推荐）\n'
                    '• 使用共享配置（需要口令）',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 模型用途说明卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        size: 20,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '模型用途说明',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ModelRoleItem(
                    icon: Icons.chat_outlined,
                    color: cs.primary,
                    title: '语言模型（LLM）',
                    subtitle: '主力对话模型',
                    description:
                        '负责问答、解题、讲义生成、思维导图等所有文字生成任务。推荐使用 DeepSeek-V3 或 GPT-4o。',
                  ),
                  const Divider(height: 20),
                  _ModelRoleItem(
                    icon: Icons.search_outlined,
                    color: Colors.orange,
                    title: '向量化模型（Embedding）',
                    subtitle: '语义检索引擎',
                    description:
                        '把课本文字转成向量存入数据库，用于语义检索。不生成文字，只做"理解"。推荐 BAAI/bge-m3（多语言，支持中文）。',
                  ),
                  const Divider(height: 20),
                  _ModelRoleItem(
                    icon: Icons.image_search_outlined,
                    color: Colors.teal,
                    title: '视觉模型（Vision / OCR）',
                    subtitle: '图片文字识别',
                    description:
                        '识别拍照题目中的文字和公式，用于图文解题功能。推荐 PaddleOCR-VL-1.5（专为中文数学公式优化）。',
                  ),
                  const Divider(height: 20),
                  _ModelRoleItem(
                    icon: Icons.sort_outlined,
                    color: Colors.purple,
                    title: '重排序模型（Reranker）',
                    subtitle: 'RAG 精准检索',
                    description:
                        '对课本检索召回的候选片段重新打分，筛出最相关的内容喂给 LLM。让"从课本找答案"更精准。推荐 BAAI/bge-reranker-v2-m3。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 共享配置区域
          Text('共享配置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            color: _sharedConfigVerified ? Colors.green.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_sharedConfigVerified) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已启用共享配置',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '你正在使用共享的 API 配置，无需自己配置',
                      style: TextStyle(fontSize: 13),
                    ),
                  ] else ...[
                    TextField(
                      controller: _passphraseCtrl,
                      decoration: InputDecoration(
                        labelText: '验证口令',
                        hintText: '输入口令以使用共享配置',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _verifyPassphrase,
                        ),
                      ),
                      obscureText: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 自定义配置区域
          Text('自定义配置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 语言模型 ──────────────────────────────────────────
                  _ModelConfigSection(
                    icon: Icons.chat_outlined,
                    color: cs.primary,
                    title: '语言模型（LLM）',
                    subtitle: '问答 / 解题 / 讲义生成',
                    children: [
                      _ConfigField(
                        ctrl: _llmBaseUrlCtrl,
                        label: 'Base URL',
                        hint: 'https://api.siliconflow.cn/v1',
                      ),
                      _ConfigField(
                        ctrl: _llmKeyCtrl,
                        label: 'API Key',
                        hint: 'sk-...',
                        obscure: true,
                      ),
                      _ConfigField(
                        ctrl: _llmModelCtrl,
                        label: '模型名称',
                        hint: 'deepseek-ai/DeepSeek-V3',
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  // ── 视觉模型 ──────────────────────────────────────────
                  _ModelConfigSection(
                    icon: Icons.image_search_outlined,
                    color: Colors.teal,
                    title: '视觉模型（OCR）',
                    subtitle: '图片文字识别',
                    children: [
                      _ConfigField(
                        ctrl: _visionBaseUrlCtrl,
                        label: 'Base URL',
                        hint: '留空则复用语言模型',
                      ),
                      _ConfigField(
                        ctrl: _visionKeyCtrl,
                        label: 'API Key',
                        hint: '留空则复用语言模型',
                        obscure: true,
                      ),
                      _ConfigField(
                        ctrl: _visionModelCtrl,
                        label: '模型名称',
                        hint: 'PaddlePaddle/PaddleOCR-VL-1.5',
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  // ── 向量化模型 ────────────────────────────────────────
                  _ModelConfigSection(
                    icon: Icons.search_outlined,
                    color: Colors.orange,
                    title: '向量化模型（Embedding）',
                    subtitle: '课本语义检索',
                    children: [
                      _ConfigField(
                        ctrl: _embeddingBaseUrlCtrl,
                        label: 'Base URL',
                        hint: '留空则复用语言模型',
                      ),
                      _ConfigField(
                        ctrl: _embeddingKeyCtrl,
                        label: 'API Key',
                        hint: '留空则复用语言模型',
                        obscure: true,
                      ),
                      _ConfigField(
                        ctrl: _embeddingModelCtrl,
                        label: '模型名称',
                        hint: 'BAAI/bge-m3',
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  // ── 重排序模型 ────────────────────────────────────────
                  _ModelConfigSection(
                    icon: Icons.sort_outlined,
                    color: Colors.purple,
                    title: '重排序模型（Reranker）',
                    subtitle: 'RAG 精准检索',
                    children: [
                      _ConfigField(
                        ctrl: _rerankerBaseUrlCtrl,
                        label: 'Base URL',
                        hint: '留空则复用语言模型',
                      ),
                      _ConfigField(
                        ctrl: _rerankerKeyCtrl,
                        label: 'API Key',
                        hint: '留空则复用语言模型',
                        obscure: true,
                      ),
                      _ConfigField(
                        ctrl: _rerankerModelCtrl,
                        label: '模型名称',
                        hint: 'BAAI/bge-reranker-v2-m3',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveCustomConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('保存配置'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenStatsCard(ColorScheme cs) {
    final todayTokens = _quota?.usedToday ?? 0;
    final todayRequests = _todayUsage?.totalRequests ?? 0;

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => context.push(R.profileTokenDetail),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '今日使用统计',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '词元消耗',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatNumber(todayTokens),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: cs.outline.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            '请求次数',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            '$todayRequests',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: cs.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '点击查看详细统计',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

// ── 模型用途说明条目 ──────────────────────────────────────────────────────────

class _ModelRoleItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;

  const _ModelRoleItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModelConfigSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _ModelConfigSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _ConfigField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool obscure;

  const _ConfigField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
