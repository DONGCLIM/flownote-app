import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../models/receipt_model.dart';
import 'receipt_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = '전체';
  final List<String> _filters = ['전체', '장미', '튤립', '국화', '수국', '기타'];

  // 다중 선택 모드
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<ReceiptModel> receipts) {
    setState(() {
      if (_selectedIds.length == receipts.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(receipts.map((r) => r.id));
      }
    });
  }

  Future<void> _deleteSelected(BuildContext context) async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('선택 삭제'),
        content: Text(
          '$count건의 구매 내역을 삭제할까요?\n삭제 후 복구할 수 없습니다.',
          style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context
          .read<ReceiptProvider>()
          .deleteReceipts(_selectedIds.toList());
      setState(() {
        _isSelecting = false;
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count건 삭제되었습니다'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              // 탭 바
              if (!_isSelecting)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle:
                        const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(3),
                    tabs: const [
                      Tab(text: '날짜순'),
                      Tab(text: '업체별'),
                    ],
                  ),
                ),
              if (!_isSelecting) _buildSearchBar(),
              if (!_isSelecting) _buildFilterChips(),
              Expanded(
                child: _isSelecting
                    ? _buildList(context)
                    : TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildList(context),
                          _VendorTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _isSelecting ? _buildSelectionBar(context) : null,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isSelecting) ...[
            GestureDetector(
              onTap: _toggleSelectMode,
              child: const Row(
                children: [
                  Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 6),
                  Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_selectedIds.length}건 선택됨',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ] else ...[
            const Text(
              '구매 내역',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Consumer<ReceiptProvider>(
                  builder: (context, provider, _) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '총 ${provider.allReceipts.length}건',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 선택 모드 진입 버튼
                GestureDetector(
                  onTap: _toggleSelectMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          '선택',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: '꽃 이름, 상점명으로 검색',
          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textHint),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedFilter = filter),
            labelStyle: TextStyle(
              fontSize: 13,
              color:
                  isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            checkmarkColor: AppColors.primary,
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    var receipts = provider.allReceipts;

    if (_searchQuery.isNotEmpty) {
      receipts = receipts.where((r) {
        return r.storeName.contains(_searchQuery) ||
            r.items.any((i) => i.name.contains(_searchQuery));
      }).toList();
    }

    if (_selectedFilter != '전체' && _selectedFilter != '기타') {
      receipts = receipts.where((r) {
        return r.items.any((i) => i.name.contains(_selectedFilter));
      }).toList();
    }

    if (receipts.isEmpty) return _buildEmptyState();

    // 선택 모드: 전체 선택 버튼 + 항목
    if (_isSelecting) {
      return Column(
        children: [
          // 전체 선택 바
          GestureDetector(
            onTap: () => _selectAll(receipts),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedIds.length == receipts.length
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: _selectedIds.length == receipts.length
                        ? AppColors.primary
                        : AppColors.textHint,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedIds.length == receipts.length
                        ? '전체 선택 해제'
                        : '전체 선택 (${receipts.length}건)',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: receipts.length,
              itemBuilder: (context, i) => _SelectableHistoryTile(
                receipt: receipts[i],
                isSelected: _selectedIds.contains(receipts[i].id),
                onToggle: () => _toggleSelect(receipts[i].id),
              ),
            ),
          ),
        ],
      );
    }

    // 일반 모드: 월별 그룹
    final grouped = <String, List<ReceiptModel>>{};
    for (final r in receipts) {
      final key = DateFormat('yyyy년 M월', 'ko').format(r.date);
      grouped.putIfAbsent(key, () => []).add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final month = grouped.keys.elementAt(i);
        final monthReceipts = grouped[month]!;
        final monthTotal =
            monthReceipts.fold(0.0, (s, r) => s + r.totalAmount);
        final fmt = NumberFormat('#,###', 'ko');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(month,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      )),
                  Text('₩${fmt.format(monthTotal)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            ...monthReceipts.map(
              (r) => _HistoryListTile(
                receipt: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiptDetailScreen(receipt: r),
                  ),
                ),
                onDelete: () => _confirmDelete(context, r),
                onLongPress: () {
                  // 롱프레스로 선택 모드 진입
                  setState(() {
                    _isSelecting = true;
                    _selectedIds.add(r.id);
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedIds.isEmpty
                    ? '항목을 선택하세요'
                    : '${_selectedIds.length}건 선택됨',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _selectedIds.isEmpty
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => _deleteSelected(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('삭제'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.border,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ReceiptModel receipt) {
    final fmt = NumberFormat('#,###', 'ko');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('내역 삭제'),
        content: Text(
          '${receipt.storeName}\n'
          '${DateFormat('yyyy.M.d', 'ko').format(receipt.date)} · '
          '₩${fmt.format(receipt.totalAmount)}\n\n'
          '이 구매 내역을 삭제할까요?',
          style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ReceiptProvider>().deleteReceipt(receipt.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('내역이 삭제되었습니다'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌺', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '구매 내역이 없습니다',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '영수증을 스캔하여 구매 내역을 추가해보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 선택 모드 타일
// ──────────────────────────────────────────
class _SelectableHistoryTile extends StatelessWidget {
  final ReceiptModel receipt;
  final bool isSelected;
  final VoidCallback onToggle;

  const _SelectableHistoryTile({
    required this.receipt,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'ko');
    final dateFmt = DateFormat('M/d (E)', 'ko');

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // 체크박스
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  isSelected ? AppColors.primary : AppColors.textHint,
              size: 22,
            ),
            const SizedBox(width: 12),
            // 꽃 이모지
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _flowerEmoji(receipt),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receipt.storeName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    receipt.items
                        .map((i) => '${i.name} ${i.quantity}${i.unit}')
                        .take(2)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₩${fmt.format(receipt.totalAmount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFmt.format(receipt.date),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _flowerEmoji(ReceiptModel r) {
    if (r.items.isEmpty) return '🌸';
    final n = r.items.first.name;
    if (n.contains('장미')) return '🌹';
    if (n.contains('튤립')) return '🌷';
    if (n.contains('해바라기')) return '🌻';
    if (n.contains('라일락') || n.contains('수국')) return '💜';
    return '🌸';
  }
}

// ──────────────────────────────────────────
// 일반 모드 타일
// ──────────────────────────────────────────
class _HistoryListTile extends StatelessWidget {
  final ReceiptModel receipt;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;

  const _HistoryListTile({
    required this.receipt,
    required this.onTap,
    required this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'ko');
    final dateFmt = DateFormat('M/d (E)', 'ko');

    return Dismissible(
      key: Key(receipt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('삭제',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _flowerColor(receipt).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _flowerEmoji(receipt),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.storeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      receipt.items
                          .map((i) => '${i.name} ${i.quantity}${i.unit}')
                          .take(2)
                          .join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₩${fmt.format(receipt.totalAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateFmt.format(receipt.date),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  String _flowerEmoji(ReceiptModel r) {
    if (r.items.isEmpty) return '🌸';
    final n = r.items.first.name;
    if (n.contains('장미')) return '🌹';
    if (n.contains('튤립')) return '🌷';
    if (n.contains('해바라기')) return '🌻';
    if (n.contains('라일락') || n.contains('수국')) return '💜';
    return '🌸';
  }

  Color _flowerColor(ReceiptModel r) {
    if (r.items.isEmpty) return AppColors.primary;
    final n = r.items.first.name;
    if (n.contains('장미')) return AppColors.error;
    if (n.contains('튤립')) return AppColors.primary;
    if (n.contains('해바라기')) return AppColors.warning;
    return AppColors.secondary;
  }
}

// ══════════════════════════════════════════════════════════
// 업체별 탭
// ══════════════════════════════════════════════════════════
class _VendorTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final vendors = provider.getVendorStats();
    final fmt = NumberFormat('#,###', 'ko');

    if (vendors.isEmpty) {
      return const Center(
        child: Text('구매 내역이 없습니다',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: 80 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: vendors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final v = vendors[index];
        return _VendorCard(vendor: v, fmt: fmt);
      },
    );
  }
}

// ── 업체 카드 ──
class _VendorCard extends StatefulWidget {
  final dynamic vendor;
  final NumberFormat fmt;
  const _VendorCard({required this.vendor, required this.fmt});

  @override
  State<_VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<_VendorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final fmt = widget.fmt;
    final provider = context.read<ReceiptProvider>();
    final monthly = provider.getMonthlyByVendor(v.name as String);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // 헤더
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🏭', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '총 ${v.receiptCount}건',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₩${fmt.format(v.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 내보내기 버튼
                          GestureDetector(
                            onTap: () => _showExportSheet(context, v, monthly, fmt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.ios_share_rounded,
                                      size: 12, color: AppColors.accent),
                                  SizedBox(width: 3),
                                  Text(
                                    '내보내기',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down,
                                size: 20, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 펼쳐지는 월별 내역
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '월별 구매 금액',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...monthly.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₩${fmt.format(e.value)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showExportSheet(
    BuildContext context,
    dynamic vendor,
    Map<String, double> monthly,
    NumberFormat fmt,
  ) {
    final user = context.read<AuthProvider>().currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExportSheet(
        vendor: vendor,
        monthly: monthly,
        fmt: fmt,
        user: user,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 내보내기 시트
// ══════════════════════════════════════════════════════════
class _ExportSheet extends StatefulWidget {
  final dynamic vendor;
  final Map<String, double> monthly;
  final NumberFormat fmt;
  final dynamic user;

  const _ExportSheet({
    required this.vendor,
    required this.monthly,
    required this.fmt,
    this.user,
  });

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _copied = false;

  @override
  void dispose() {
    super.dispose();
  }

  String _buildReportText() {
    final user = widget.user;
    final v = widget.vendor;
    final now = DateTime.now();
    final nowFmt = DateFormat('yyyy-MM-dd HH:mm', 'ko');

    final sb = StringBuffer();

    // 헤더
    if (user != null && user.businessName.isNotEmpty) {
      sb.writeln('# 구매처\t${user.businessName}\t${user.ownerName} 대표\t${user.businessNumber}');
    }
    sb.writeln('# 공급업체\t${v.name}');
    sb.writeln('# 발행일\t${nowFmt.format(now)}');
    sb.writeln('');

    // 월별 요약 (탭 구분 → 엑셀 붙여넣기용)
    sb.writeln('월\t구매건수\t구매금액(원)');

    final monthMap = <String, _MonthStat>{};
    for (final r in v.receipts) {
      final key = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}';
      monthMap.putIfAbsent(key, () => _MonthStat());
      monthMap[key]!.count++;
      monthMap[key]!.total += r.totalAmount;
    }
    final sortedMonths = monthMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final e in sortedMonths) {
      sb.writeln('${e.key}\t${e.value.count}\t${e.value.total.toStringAsFixed(0)}');
    }
    sb.writeln('합계\t${v.receiptCount}\t${v.totalAmount.toStringAsFixed(0)}');

    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final fmt = widget.fmt;
    final user = widget.user;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${v.name} 구매 내역 내보내기',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textHint),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 내 사업장 정보 요약
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: user != null && user.hasBusinessInfo
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: user != null && user.hasBusinessInfo
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: user != null && user.hasBusinessInfo
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.store_outlined,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '발신처 (내 사업장)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${user.businessName}  |  ${user.ownerName} 대표',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (user.businessNumber.isNotEmpty)
                                Text(
                                  '사업자번호: ${user.businessNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '프로필에서 내 사업장 정보를 먼저 등록해주세요',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  // 엑셀 테이블 미리보기
                  _buildExcelPreview(v, fmt),

                  const SizedBox(height: 20),

                  // 액션 버튼들
                  Row(
                    children: [
                      // 클립보드 복사
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final text = _buildReportText();
                            await _copyToClipboard(context, text);
                            setState(() => _copied = true);
                            await Future.delayed(
                                const Duration(seconds: 2));
                            if (mounted) setState(() => _copied = false);
                          },
                          icon: Icon(
                            _copied
                                ? Icons.check_circle_outline
                                : Icons.copy_outlined,
                            size: 16,
                            color: _copied
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                          label: Text(
                            _copied ? '복사됨! ✅' : '엑셀용 복사',
                            style: TextStyle(
                              color: _copied
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _copied
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 공유 버튼
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _shareReport(context),
                          icon: const Icon(Icons.share_outlined,
                              size: 16, color: Colors.white),
                          label: const Text(
                            '공유하기',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcelPreview(dynamic v, NumberFormat fmt) {
    // 월별 집계
    final monthMap = <String, _MonthStat>{};
    for (final r in v.receipts) {
      final key = '${r.date.year}년 ${r.date.month}월';
      monthMap.putIfAbsent(key, () => _MonthStat());
      monthMap[key]!.count++;
      monthMap[key]!.total += r.totalAmount;
    }
    final sortedMonths = monthMap.entries.toList()
      ..sort((a, b) {
        // "2026년 1월" 형식 파싱해서 날짜 비교
        final pa = a.key.replaceAll('년 ', '-').replaceAll('월', '').split('-');
        final pb = b.key.replaceAll('년 ', '-').replaceAll('월', '').split('-');
        final da = DateTime(int.parse(pa[0]), int.parse(pa[1]));
        final db = DateTime(int.parse(pb[0]), int.parse(pb[1]));
        return da.compareTo(db);
      });

    const headerColor = Color(0xFF4A7C59);   // 진한 초록 (엑셀 헤더 느낌)
    const headerText = Colors.white;
    const rowEven = Color(0xFFF5FAF6);
    const rowOdd = Colors.white;
    const totalRowColor = Color(0xFFE8F4EB);
    const borderColor = Color(0xFFCCDDD1);
    const colMonth = 110.0;
    const colCount = 80.0;
    const colAmount = 120.0;

    // 셀 빌더
    Widget cell(String text,
        {double width = colAmount,
        Color bg = Colors.white,
        Color textColor = const Color(0xFF2C2825),
        FontWeight fw = FontWeight.w400,
        Alignment align = Alignment.centerRight,
        bool isHeader = false}) {
      return Container(
        width: width,
        height: 36,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor, width: 0.7),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 12 : 13,
            fontWeight: fw,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타이틀 행
        Row(children: [
          const Icon(Icons.table_chart_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text('월별 구매 내역',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 8),

        // 테이블
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 헤더 행
              Row(children: [
                cell('월', width: colMonth, bg: headerColor, textColor: headerText,
                    fw: FontWeight.w700, align: Alignment.centerLeft, isHeader: true),
                cell('구매건수', width: colCount, bg: headerColor, textColor: headerText,
                    fw: FontWeight.w700, align: Alignment.center, isHeader: true),
                cell('구매금액', width: colAmount, bg: headerColor, textColor: headerText,
                    fw: FontWeight.w700, isHeader: true),
              ]),

              // 데이터 행
              ...sortedMonths.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                final bg = idx.isEven ? rowEven : rowOdd;
                return Row(children: [
                  cell(e.key, width: colMonth, bg: bg,
                      align: Alignment.centerLeft,
                      fw: FontWeight.w500,
                      textColor: const Color(0xFF2C2825)),
                  cell('${e.value.count}건', width: colCount, bg: bg,
                      align: Alignment.center),
                  cell('₩${fmt.format(e.value.total)}', width: colAmount, bg: bg,
                      fw: FontWeight.w600, textColor: AppColors.primary),
                ]);
              }),

              // 합계 행
              Row(children: [
                cell('합  계', width: colMonth, bg: totalRowColor,
                    align: Alignment.centerLeft,
                    fw: FontWeight.w800,
                    textColor: headerColor),
                cell('${v.receiptCount}건', width: colCount, bg: totalRowColor,
                    align: Alignment.center,
                    fw: FontWeight.w800,
                    textColor: headerColor),
                cell('₩${fmt.format(v.totalAmount)}', width: colAmount,
                    bg: totalRowColor,
                    fw: FontWeight.w800,
                    textColor: headerColor),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 복사 안내 텍스트
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                '"엑셀용 복사" 버튼 → 엑셀/구글시트에 붙여넣기',
                style: TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _statBox(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    // Flutter에서 클립보드에 텍스트 복사
    final data = ClipboardData(text: text);
    await Clipboard.setData(data);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 리포트가 클립보드에 복사되었습니다'),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareReport(BuildContext context) {
    final text = _buildReportText();
    // 공유: 텍스트를 클립보드에 복사하고 안내 메시지 표시
    // (share_plus 패키지 없이 기본 방식으로 구현)
    _copyToClipboard(context, text);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            '📊 엑셀 형식으로 복사됨! 엑셀/구글시트에 붙여넣기 하세요.'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// 월별 집계용 헬퍼
class _MonthStat {
  int count = 0;
  double total = 0;
}
