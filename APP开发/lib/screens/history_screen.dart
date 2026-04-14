import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// 历史记录页面 (重新设计)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  RiskLevel? _selectedRiskFilter;
  DateTimeRange? _selectedDateRange;
  SortOption _sortOption = SortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<HistoryProvider>();
      if (provider.history.isEmpty && !provider.isLoading) {
        provider.initialize();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HistoryProvider>().loadMoreHistory();
    }
  }

  Future<void> _refreshHistory() async {
    await context.read<HistoryProvider>().refreshHistory();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilter();
    });
  }

  void _applyFilter() {
    final filter = FilterCriteria(
      riskLevel: _selectedRiskFilter,
      dateRange: _selectedDateRange,
      searchQuery:
          _searchController.text.isNotEmpty ? _searchController.text : null,
    );
    context.read<HistoryProvider>().setFilter(filter);
  }

  List<DetectionResult> _getSortedResults(List<DetectionResult> results) {
    final sortedResults = List<DetectionResult>.from(results);
    switch (_sortOption) {
      case SortOption.dateDesc:
        sortedResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortOption.dateAsc:
        sortedResults.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortOption.nameAsc:
        sortedResults.sort((a, b) => a.sampleName.compareTo(b.sampleName));
        break;
      case SortOption.riskDesc:
        sortedResults
            .sort((a, b) => b.riskLevel.index.compareTo(a.riskLevel.index));
        break;
    }
    return sortedResults;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '检测历史',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, size: 22),
            onPressed: _showFilterBottomSheet,
            tooltip: '筛选',
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, size: 22),
            onSelected: (option) {
              setState(() => _sortOption = option);
            },
            itemBuilder: (context) => [
              _buildSortMenuItem(SortOption.dateDesc, '时间降序'),
              _buildSortMenuItem(SortOption.dateAsc, '时间升序'),
              _buildSortMenuItem(SortOption.nameAsc, '名称排序'),
              _buildSortMenuItem(SortOption.riskDesc, '风险等级'),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                size: 22, color: Color(0xFF999999)),
            onPressed: _confirmClearHistory,
            tooltip: '清空历史',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildResultList()),
        ],
      ),
    );
  }

  PopupMenuItem<SortOption> _buildSortMenuItem(
      SortOption option, String label) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          if (_sortOption == option)
            const Icon(Icons.check, size: 18, color: AppConstants.primaryColor)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: '搜索样品名称...',
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: Color(0xFFBBBBBB)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      size: 18, color: Color(0xFF999999)),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {});
          _onSearchChanged(value);
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasFilters =
        _selectedRiskFilter != null || _selectedDateRange != null;
    if (!hasFilters) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (_selectedRiskFilter != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    Helpers.getRiskLevelDescription(_selectedRiskFilter!),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () {
                    setState(() => _selectedRiskFilter = null);
                    _applyFilter();
                  },
                  backgroundColor:
                      Helpers.getRiskLevelColor(_selectedRiskFilter!)
                          .withValues(alpha: 0.15),
                  deleteIconColor: const Color(0xFF999999),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (_selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    '${Helpers.formatDate(_selectedDateRange!.start)} - ${Helpers.formatDate(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () {
                    setState(() => _selectedDateRange = null);
                    _applyFilter();
                  },
                  deleteIconColor: const Color(0xFF999999),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (hasFilters)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedRiskFilter = null;
                    _selectedDateRange = null;
                  });
                  _applyFilter();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('清除', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultList() {
    final historyProvider = context.watch<HistoryProvider>();
    final filteredResults = historyProvider.filteredHistory;
    final sortedResults = _getSortedResults(filteredResults);

    if (historyProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('加载中...',
                style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
          ],
        ),
      );
    }

    if (sortedResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              historyProvider.history.isEmpty ? '暂无检测记录' : '没有找到匹配的记录',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              historyProvider.history.isEmpty ? '完成一次检测后，记录将显示在这里' : '尝试调整筛选条件',
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    final itemCount = sortedResults.length + (historyProvider.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      color: AppConstants.primaryColor,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= sortedResults.length) {
            return _buildLoadingMoreIndicator(historyProvider);
          }
          final result = sortedResults[index];
          return _HistoryItemCard(
            result: result,
            onTap: () => _showResultDetail(result),
            onDelete: () => _deleteResult(result),
          );
        },
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(HistoryProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton(
          onPressed: () => provider.loadMoreHistory(),
          child: const Text('加载更多',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        selectedRiskFilter: _selectedRiskFilter,
        selectedDateRange: _selectedDateRange,
        onApply: (risk, dateRange) {
          setState(() {
            _selectedRiskFilter = risk;
            _selectedDateRange = dateRange;
          });
          _applyFilter();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showResultDetail(DetectionResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailScreen(result: result),
      ),
    );
  }

  /// 长按删除单条记录
  Future<void> _deleteResult(DetectionResult result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${result.sampleName}」的检测记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<HistoryProvider>().deleteResult(result.id);
      if (!mounted) return;
      await context.read<AppProvider>().refreshStatistics();
      Helpers.showSnackBar(context, '已删除');
    }
  }

  /// 清空全部历史
  Future<void> _confirmClearHistory() async {
    final historyProvider = context.read<HistoryProvider>();
    if (historyProvider.history.isEmpty) {
      Helpers.showSnackBar(context, '暂无历史记录');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部历史'),
        content: Text(
            '确定要清空全部 ${historyProvider.totalCount} 条检测记录吗？\n\n此操作不可撤销，所有历史数据将永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空全部'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await historyProvider.clearHistory();
      if (!mounted) return;
      await context.read<AppProvider>().refreshStatistics();
      Helpers.showSnackBar(context, '历史记录已清空');
    }
  }
}

/// 历史记录卡片 (白色背景，长按2秒删除)
class _HistoryItemCard extends StatefulWidget {
  final DetectionResult result;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryItemCard({
    required this.result,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_HistoryItemCard> createState() => _HistoryItemCardState();
}

class _HistoryItemCardState extends State<_HistoryItemCard>
    with SingleTickerProviderStateMixin {
  Timer? _longPressTimer;
  late AnimationController _progressController;
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cancelLongPress();
        widget.onDelete();
      }
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startLongPress() {
    setState(() => _isLongPressing = true);
    _progressController.forward(from: 0);
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_isLongPressing) {
      setState(() => _isLongPressing = false);
      _progressController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = Helpers.getRiskLevelColor(widget.result.riskLevel);
    final riskText = Helpers.getRiskLevelDescription(widget.result.riskLevel);
    final hasPesticides = widget.result.hasPesticides;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _startLongPress(),
      onLongPressEnd: (_) => _cancelLongPress(),
      onLongPressCancel: _cancelLongPress,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isLongPressing
                    ? Colors.red.withValues(alpha: 0.5)
                    : const Color(0xFFEEEEEE),
                width: _isLongPressing ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 长按进度条
                if (_isLongPressing)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                    child: LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.red),
                      minHeight: 3,
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧风险指示
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Helpers.getRiskLevelIcon(widget.result.riskLevel),
                          color: riskColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 中间内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 样品名称
                            Text(
                              widget.result.sampleName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // 检测结果
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: riskColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    riskText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: riskColor,
                                    ),
                                  ),
                                ),
                                if (hasPesticides) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '毒死蜱 ${Helpers.formatConcentration(widget.result.detectedPesticides.first.concentration)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),

                            // 时间和类别
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 12, color: Color(0xFFBBBBBB)),
                                const SizedBox(width: 3),
                                Text(
                                  Helpers.formatDateTime(
                                      widget.result.timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFBBBBBB),
                                  ),
                                ),
                                if (widget.result.sampleCategory != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.result.sampleCategory!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFBBBBBB),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 右侧置信度
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Helpers.formatPercentage(widget.result.confidence),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),
                          const Text(
                            '置信度',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFFBBBBBB)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 长按删除提示
                if (_isLongPressing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(11)),
                    ),
                    child: const Text(
                      '松开取消，继续按住以删除',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 筛选底部弹窗
class _FilterBottomSheet extends StatefulWidget {
  final RiskLevel? selectedRiskFilter;
  final DateTimeRange? selectedDateRange;
  final Function(RiskLevel?, DateTimeRange?) onApply;

  const _FilterBottomSheet({
    this.selectedRiskFilter,
    this.selectedDateRange,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  RiskLevel? _tempRiskFilter;
  DateTimeRange? _tempDateRange;

  @override
  void initState() {
    super.initState();
    _tempRiskFilter = widget.selectedRiskFilter;
    _tempDateRange = widget.selectedDateRange;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '筛选条件',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text('风险等级', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('全部'),
                selected: _tempRiskFilter == null,
                onSelected: (_) => setState(() => _tempRiskFilter = null),
              ),
              ...RiskLevel.values.map((level) => FilterChip(
                    label: Text(Helpers.getRiskLevelDescription(level)),
                    selected: _tempRiskFilter == level,
                    onSelected: (_) => setState(() => _tempRiskFilter = level),
                    backgroundColor:
                        Helpers.getRiskLevelColor(level).withValues(alpha: 0.1),
                  )),
            ],
          ),
          const SizedBox(height: 20),
          const Text('时间范围', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _tempDateRange,
              );
              if (range != null) {
                setState(() => _tempDateRange = range);
              }
            },
            icon: const Icon(Icons.date_range),
            label: Text(
              _tempDateRange != null
                  ? '${Helpers.formatDate(_tempDateRange!.start)} - ${Helpers.formatDate(_tempDateRange!.end)}'
                  : '选择日期范围',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _tempRiskFilter = null;
                      _tempDateRange = null;
                    });
                  },
                  child: const Text('重置'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      widget.onApply(_tempRiskFilter, _tempDateRange),
                  child: const Text('应用'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 详情页面
class _DetailScreen extends StatefulWidget {
  final DetectionResult result;

  const _DetailScreen({required this.result});

  @override
  State<_DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<_DetailScreen> {
  late Future<SpectralData?> _spectralDataFuture;

  @override
  void initState() {
    super.initState();
    if (widget.result.spectralDataId != null &&
        widget.result.spectralDataId!.isNotEmpty) {
      _spectralDataFuture =
          StorageService().getSpectralData(widget.result.spectralDataId!);
    } else {
      _spectralDataFuture = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('检测详情'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDetailResult(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildRiskInfo(),
            const SizedBox(height: 16),
            _buildSpectralArchiveSection(),
            if ((widget.result.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildExecutionInfo(),
            ],
            if (widget.result.hasPesticides) ...[
              const SizedBox(height: 16),
              _buildPesticideDetails(),
            ],
            const SizedBox(height: 16),
            _buildAdvice(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.result.sampleName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (widget.result.sampleCategory != null)
              Chip(label: Text(widget.result.sampleCategory!)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  Helpers.formatDateTime(widget.result.timestamp),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskInfo() {
    final color = Helpers.getRiskLevelColor(widget.result.riskLevel);
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Helpers.getRiskLevelIcon(widget.result.riskLevel),
              size: 48,
              color: color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.result.riskLevelDescription,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '置信度: ${Helpers.formatPercentage(widget.result.confidence)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPesticideDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '毒死蜱检出详情',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.result.detectedPesticides
                .map((p) => _buildPesticideRow(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildPesticideRow(DetectedPesticide pesticide) {
    final isOverLimit = pesticide.isOverLimit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pesticide.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isOverLimit ? AppConstants.errorColor : null,
                  ),
                ),
                Text(
                  _getPesticideTypeName(pesticide.type),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.formatConcentration(pesticide.concentration),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isOverLimit ? AppConstants.errorColor : null,
                  ),
                ),
                Text(
                  '限量: ${Helpers.formatConcentration(pesticide.maxResidueLimit)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isOverLimit
              ? const Icon(Icons.warning,
                  color: AppConstants.errorColor, size: 20)
              : const Icon(Icons.check_circle,
                  color: AppConstants.successColor, size: 20),
        ],
      ),
    );
  }

  String _getPesticideTypeName(PesticideType type) {
    switch (type) {
      case PesticideType.organophosphate:
        return '有机磷类';
      default:
        return '未知类型';
    }
  }

  Widget _buildSpectralArchiveSection() {
    if (widget.result.spectralDataId == null ||
        widget.result.spectralDataId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<SpectralData?>(
      future: _spectralDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在加载光谱数据...'),
                ],
              ),
            ),
          );
        }

        final spectralData = snapshot.data;
        if (spectralData == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '光谱存档数据',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('光谱数据ID: ${widget.result.spectralDataId}'),
                  const SizedBox(height: 4),
                  const Text(
                    '该光谱文件在此设备上已不可用。',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '光谱存档数据',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '数据ID: ${spectralData.id} - ${spectralData.dataPointCount} 个数据点 - '
                  '${spectralData.wavelengths.first.toStringAsFixed(0)}-'
                  '${spectralData.wavelengths.last.toStringAsFixed(0)} nm',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: SpectralChart(spectralData: spectralData),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExecutionInfo() {
    final lines = (widget.result.notes ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '执行信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppConstants.warningColor),
                SizedBox(width: 8),
                Text(
                  '食用建议',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(Helpers.getRiskLevelAdvice(widget.result.riskLevel)),
          ],
        ),
      ),
    );
  }

  Future<void> _shareDetailResult(BuildContext context) async {
    final exportService = ExportService();
    try {
      final reportResult =
          await exportService.generateTextReport(widget.result);
      if (!context.mounted) return;
      if (reportResult.isSuccess && reportResult.filePath != null) {
        await exportService.shareFile(reportResult.filePath!);
      } else {
        Helpers.showSnackBar(context, '生成报告失败', isError: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      Helpers.showSnackBar(context, '分享失败: $e', isError: true);
    }
  }
}

/// 排序选项
enum SortOption {
  dateDesc,
  dateAsc,
  nameAsc,
  riskDesc,
}
