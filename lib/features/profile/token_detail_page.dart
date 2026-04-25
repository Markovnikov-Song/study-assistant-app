import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/background_style_provider.dart';
import '../../services/token_service.dart';

/// Token使用详细页面（带日历热力图）
class TokenDetailPage extends ConsumerStatefulWidget {
  const TokenDetailPage({super.key});

  @override
  ConsumerState<TokenDetailPage> createState() => _TokenDetailPageState();
}

class _TokenDetailPageState extends ConsumerState<TokenDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  UsageHistory? _history;
  bool _isLoading = true;
  String? _error;

  // 时间筛选
  int _days = 90; // 默认显示90天

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _days = 7;
            break;
          case 1:
            _days = 30;
            break;
          case 2:
            _days = 90;
            break;
        }
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = TokenService();
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: _days));
      final history = await service.getUsageHistory(
        startDate: DateFormat('yyyy-MM-dd').format(startDate),
        endDate: DateFormat('yyyy-MM-dd').format(endDate),
      );
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    // 动态 accent 颜色（来自 BackgroundStyle）
    final accentCs = ref.watch(accentColorSchemeProvider(context));

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF1E293B),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '使用记录',
          style: TextStyle(
            color: isDark
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab切换（使用动态 accent 颜色）
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentCs.primary,
                    Color.lerp(accentCs.primary, Colors.white, 0.3)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: '本周'),
                Tab(text: '本月'),
                Tab(text: '近三月'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 日历视图
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: accentCs.primary,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: cs.error,
                            ),
                            const SizedBox(height: 16),
                            Text('加载失败'),
                            TextButton(onPressed: _loadData, child: Text('重试')),
                          ],
                        ),
                      )
                    : _buildContent(context, isDark, accentCs),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, ColorScheme accentCs) {
    final history = _history!;

    // 计算最大使用量用于热力图颜色映射
    int maxUsage = 1;
    for (var d in history.data) {
      if (d.totalTokens > maxUsage) maxUsage = d.totalTokens;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 统计卡片
        _buildStatsCard(isDark, history),
        const SizedBox(height: 16),

        // 日历热力图（使用动态 accent 颜色）
        _buildCalendarSection(context, isDark, history, maxUsage, accentCs),
        const SizedBox(height: 16),

        // 图例
        _buildLegend(isDark, accentCs),
        const SizedBox(height: 24),

        // 日历选择器（类似微信查找聊天记录）
        _buildDateSelector(isDark),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildStatsCard(bool isDark, UsageHistory history) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                isDark,
                label: '总使用量',
                value: _formatNumber(history.totalTokens),
                unit: 'tokens',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            Expanded(
              child: _buildStatItem(
                isDark,
                label: '活跃天数',
                value: '${history.data.length}',
                unit: '天',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            Expanded(
              child: _buildStatItem(
                isDark,
                label: '总请求数',
                value: _formatNumber(history.totalRequests),
                unit: '次',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    bool isDark, {
    required String label,
    required String value,
    required String unit,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarSection(
    BuildContext context,
    bool isDark,
    UsageHistory history,
    int maxUsage,
    ColorScheme accentCs,
  ) {
    // 获取当前显示月份的数据
    final usageMap = history.usageMap;
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0=周日

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // 月份选择器
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E293B),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                    });
                  },
                ),
                GestureDetector(
                  onTap: () => _showMonthPicker(context, isDark, accentCs),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('yyyy年MM月').format(_selectedMonth),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _selectedMonth.year >= DateTime.now().year &&
                            _selectedMonth.month >= DateTime.now().month
                        ? (isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8))
                        : (isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF1E293B)),
                  ),
                  onPressed: _selectedMonth.year >= DateTime.now().year &&
                          _selectedMonth.month >= DateTime.now().month
                      ? null
                      : () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          });
                        },
                ),
              ],
            ),
          ),

          // 星期标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),

          // 日历网格
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 42, // 6 weeks
              itemBuilder: (context, index) {
                final dayOffset = index - firstWeekday;
                final date = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  dayOffset + 1,
                );
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final usage = usageMap[dateStr];
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                final isFuture = date.isAfter(DateTime.now());
                final isCurrentMonth = dayOffset >= 0 && dayOffset < daysInMonth;

                if (!isCurrentMonth) {
                  return SizedBox();
                }

                return _buildDayCell(
                  isDark,
                  accentCs,
                  day: date.day,
                  tokens: usage?.totalTokens ?? 0,
                  maxUsage: maxUsage,
                  isToday: isToday,
                  isFuture: isFuture,
                  isSelected: _selectedDate != null &&
                      _selectedDate!.year == date.year &&
                      _selectedDate!.month == date.month &&
                      _selectedDate!.day == date.day,
                  onTap: isFuture
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    bool isDark,
    ColorScheme accentCs, {
    required int day,
    required int tokens,
    required int maxUsage,
    required bool isToday,
    required bool isFuture,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    // 计算颜色强度
    final intensity = maxUsage > 0 ? (tokens / maxUsage) : 0.0;
    Color bgColor;
    Color textColor;

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = isDark
          ? const Color(0xFF64748B)
          : const Color(0xFF94A3B8);
    } else if (tokens == 0) {
      bgColor = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.5)
          : const Color(0xFFF1F5F9);
      textColor = isDark
          ? const Color(0xFFF1F5F9)
          : const Color(0xFF1E293B);
    } else {
      // 从浅到深的 accent 颜色热力图（使用动态 accent）
      bgColor = Color.lerp(
        accentCs.primary.withValues(alpha: 0.15),
        accentCs.primary,
        intensity,
      )!;
      textColor = intensity > 0.5
          ? Colors.white
          : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B));
    }

    if (isSelected) {
      bgColor = accentCs.primary;
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(
                  color: isSelected ? Colors.white : accentCs.primary,
                  width: 2,
                )
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDark, ColorScheme accentCs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '低',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          final intensity = index / 4;
          // 使用动态 accent 颜色
          final color = Color.lerp(
            accentCs.primary.withValues(alpha: 0.15),
            accentCs.primary,
            intensity,
          )!;
          return Container(
            width: 20,
            height: 12,
            margin: EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          '高',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDateRangePicker(context, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.date_range_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '日期范围筛选',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedDate != null
                            ? DateFormat('yyyy年MM月dd日').format(_selectedDate!)
                            : '点击选择日期查看详细记录',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, bool isDark, ColorScheme accentCs) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: accentCs.primary,
                    surface: const Color(0xFF1E293B),
                  )
                : ColorScheme.light(
                    primary: accentCs.primary,
                    surface: const Color(0xFFFFFFFF),
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showDateRangePicker(BuildContext context, bool isDark) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _selectedDate != null
          ? DateTimeRange(
              start: _selectedDate!,
              end: _selectedDate!,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: const Color(0xFF818CF8),
                    surface: const Color(0xFF1E293B),
                  )
                : ColorScheme.light(
                    primary: const Color(0xFF6366F1),
                    surface: const Color(0xFFFFFFFF),
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.start;
      });
    }
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
