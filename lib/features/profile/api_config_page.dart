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
  final _visionBaseUrlCtrl = TextEditingController();
  final _visionKeyCtrl = TextEditingController();
  
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
    _visionBaseUrlCtrl.dispose();
    _visionKeyCtrl.dispose();
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
        _visionBaseUrlCtrl.text = await storage.read(key: 'vision_base_url') ?? '';
        _visionKeyCtrl.text = await storage.read(key: 'vision_api_key') ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载配置失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPassphrase() async {
    final passphrase = _passphraseCtrl.text.trim();
    if (passphrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入口令')),
      );
      return;
    }

    try {
      final result = await ref.read(apiConfigServiceProvider)
          .verifySharedConfig(passphrase);

      if (mounted) {
        if (result['verified'] == true) {
          setState(() {
            _sharedConfigVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '验证成功')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '验证失败')),
          );
        }
      }
    } catch (e, st) {
      debugPrint('_verifyPassphrase error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('验证失败：$e')),
        );
      }
    }
  }

  Future<void> _saveCustomConfig() async {
    final llmKey = _llmKeyCtrl.text.trim();
    if (llmKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少填写语言模型的 API Key')),
      );
      return;
    }

    try {
      // 保存到本地
      final storage = const FlutterSecureStorage();
      await storage.write(key: 'llm_base_url', value: _llmBaseUrlCtrl.text.trim());
      await storage.write(key: 'llm_api_key', value: llmKey);
      await storage.write(key: 'vision_base_url', value: _visionBaseUrlCtrl.text.trim());
      await storage.write(key: 'vision_api_key', value: _visionKeyCtrl.text.trim());

      // 同步到后端
      await ref.read(apiConfigServiceProvider).saveCustomConfig(
        llmBaseUrl: _llmBaseUrlCtrl.text.trim(),
        llmApiKey: llmKey,
        visionBaseUrl: _visionBaseUrlCtrl.text.trim(),
        visionApiKey: _visionKeyCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _sharedConfigVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
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
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试失败：$e')),
        );
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
          if (_quota != null && _todayUsage != null)
            _buildTokenStatsCard(cs),
          if (_quota != null && _todayUsage != null)
            const SizedBox(height: 16),
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
                      Text('使用说明', style: Theme.of(context).textTheme.titleMedium),
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
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
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
                  Text('语言模型', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _llmBaseUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.openai.com/v1',
                      helperText: '支持 OpenAI 兼容的 API',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _llmKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  Text('视觉模型（OCR）', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _visionBaseUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.openai.com/v1',
                      helperText: '支持 OpenAI 兼容的 API',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _visionKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
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
      color: cs.primaryContainer.withOpacity(0.3),
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
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.analytics_outlined, color: cs.primary, size: 20),
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
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
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
                    color: cs.outline.withOpacity(0.3),
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
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
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