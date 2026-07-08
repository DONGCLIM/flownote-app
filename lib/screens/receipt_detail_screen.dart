import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../models/receipt_model.dart';
import '../providers/receipt_provider.dart';
import '../theme/app_theme.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final ReceiptModel receipt;
  final bool isNew;

  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    this.isNew = false,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late TextEditingController _storeCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _monthCtrl;
  late TextEditingController _dayCtrl;
  late List<_ItemControllers> _itemCtrls;

  bool _isEditing = false;
  bool _isSaving = false;

  // 이미지 수동 회전 (0, 1, 2, 3 = 0°, 90°, 180°, 270°)
  int _imageRotation = 0;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.receipt);
  }

  void _initControllers(ReceiptModel r) {
    _storeCtrl = TextEditingController(text: r.storeName);
    _yearCtrl = TextEditingController(text: r.date.year.toString());
    _monthCtrl = TextEditingController(text: r.date.month.toString().padLeft(2, '0'));
    _dayCtrl = TextEditingController(text: r.date.day.toString().padLeft(2, '0'));
    _itemCtrls = r.items.map((item) => _ItemControllers.fromItem(item)).toList();
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _parsedDate {
    final y = int.tryParse(_yearCtrl.text) ?? DateTime.now().year;
    final m = int.tryParse(_monthCtrl.text) ?? 1;
    final d = int.tryParse(_dayCtrl.text) ?? 1;
    try {
      return DateTime(y, m.clamp(1, 12), d.clamp(1, 31));
    } catch (_) {
      return DateTime.now();
    }
  }

  double get _calcTotal => _itemCtrls.fold(0.0, (s, c) => s + c.calcTotal);

  Future<void> _saveEdits() async {
    setState(() => _isSaving = true);

    final updatedItems = _itemCtrls
        .where((c) => c.nameCtrl.text.isNotEmpty)
        .map((c) {
          final qty = int.tryParse(c.qtyCtrl.text) ?? 1;
          final price = double.tryParse(c.priceCtrl.text.replaceAll(',', '')) ?? 0;
          return FlowerItem(
            name: c.nameCtrl.text,
            quantity: qty,
            unitPrice: price,
            unit: c.unit,
          );
        })
        .toList();

    final updated = widget.receipt.copyWith(
      storeName: _storeCtrl.text.isNotEmpty ? _storeCtrl.text : '꽃집',
      date: _parsedDate,
      items: updatedItems,
      totalAmount: _calcTotal,
      isManuallyEdited: true,
    );

    await context.read<ReceiptProvider>().updateReceipt(updated);

    setState(() {
      _isSaving = false;
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 변경사항이 저장되었습니다'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final fmt = NumberFormat('#,###', 'ko');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('영수증 삭제'),
        content: Text(
          '${widget.receipt.storeName}\n'
          '₩${fmt.format(widget.receipt.totalAmount)}\n\n'
          '이 영수증을 삭제할까요?',
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
    if (confirmed == true && mounted) {
      await context.read<ReceiptProvider>().deleteReceipt(widget.receipt.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'ko');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isNew ? '새 영수증' : '영수증 상세'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isEditing && !widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: '삭제',
              onPressed: () => _confirmDelete(context),
            ),
          if (_isEditing)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _saveEdits,
                    child: const Text(
                      '저장',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          TextButton(
            onPressed: () {
              if (_isEditing) {
                for (final c in _itemCtrls) c.dispose();
                _storeCtrl.dispose();
                _yearCtrl.dispose();
                _monthCtrl.dispose();
                _dayCtrl.dispose();
                _initControllers(widget.receipt);
              }
              setState(() => _isEditing = !_isEditing);
            },
            child: Text(
              _isEditing ? '취소' : '편집',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(fmt),
    );
  }

  // ── 바디: 이미지가 있으면 상단 고정, 나머지는 스크롤 ──
  Widget _buildBody(NumberFormat fmt) {
    final hasImage = widget.receipt.imagePath != null &&
        widget.receipt.imagePath!.isNotEmpty;

    if (!hasImage) {
      // 이미지 없으면 단순 스크롤
      return SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isNew) _buildNewBadge(),
            _buildInfoCard(fmt),
            const SizedBox(height: 12),
            _buildItemsCard(fmt),
            const SizedBox(height: 12),
            _buildTotalCard(fmt),
            const SizedBox(height: 16),
            if (_isEditing) _buildAddItemButton(),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    // 이미지가 있으면: 이미지 상단 고정 + 나머지 스크롤
    return Column(
      children: [
        // 고정 이미지 영역
        _buildReceiptImage(),
        // 스크롤 영역
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 12,
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isNew) _buildNewBadge(),
                _buildInfoCard(fmt),
                const SizedBox(height: 12),
                _buildItemsCard(fmt),
                const SizedBox(height: 12),
                _buildTotalCard(fmt),
                const SizedBox(height: 16),
                if (_isEditing) _buildAddItemButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Text('✅', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'OCR 스캔 완료! 내용을 확인하고 필요시 수정하세요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 원본 영수증 이미지 ──
  Widget _buildReceiptImage() {
    final path = widget.receipt.imagePath!;
    final isNetwork = path.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(0),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Column(
          children: [
            // ── 회전 버튼 툴바 ──
            Container(
              color: AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  const Text(
                    '원본 영수증',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  // 반시계 회전
                  GestureDetector(
                    onTap: () =>
                        setState(() => _imageRotation = (_imageRotation - 1 + 4) % 4),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rotate_left,
                          size: 18, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 시계 회전
                  GestureDetector(
                    onTap: () =>
                        setState(() => _imageRotation = (_imageRotation + 1) % 4),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rotate_right,
                          size: 18, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 확대
                  GestureDetector(
                    onTap: () =>
                        _showFullImage(path, isNetwork, _imageRotation),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            // ── 이미지 본체 (핀치줌 가능) ──
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: GestureDetector(
                onTap: () => _showFullImage(path, isNetwork, _imageRotation),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  width: double.infinity,
                  color: AppColors.surfaceVariant,
                  child: RotatedBox(
                    quarterTurns: _imageRotation,
                    child: isNetwork
                        ? Image.network(
                            path,
                            fit: BoxFit.fitWidth,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : Image.file(
                            File(path),
                            fit: BoxFit.fitWidth,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 100,
      color: AppColors.border.withValues(alpha: 0.3),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: AppColors.textHint, size: 28),
      ),
    );
  }

  void _showFullImage(String path, bool isNetwork, int rotation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(
          path: path,
          isNetwork: isNetwork,
          initialRotation: rotation,
        ),
      ),
    );
  }

  // ── 상점명 + 날짜 카드 ──
  Widget _buildInfoCard(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상점명
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🌸', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isEditing
                    ? TextFormField(
                        controller: _storeCtrl,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '상점명',
                        ),
                      )
                    : Text(
                        _storeCtrl.text,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // 날짜
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              const Text(
                '날짜',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (_isEditing)
                _buildDateInputRow()
              else
                Text(
                  DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_parsedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInputRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _yearPickerChip(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('/', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ),
        _monthPickerChip(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('/', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ),
        _dayPickerChip(),
      ],
    );
  }

  // 연도 선택 칩 (탭 → 리스트 선택, 직접 입력 병행)
  Widget _yearPickerChip() {
    return GestureDetector(
      onTap: () => _showYearPicker(),
      child: _dateChipField(_yearCtrl, 4, 52, 'YYYY'),
    );
  }

  Widget _monthPickerChip() {
    return GestureDetector(
      onTap: () => _showMonthPicker(),
      child: _dateChipField(_monthCtrl, 2, 32, 'MM'),
    );
  }

  Widget _dayPickerChip() {
    return GestureDetector(
      onTap: () => _showDayPicker(),
      child: _dateChipField(_dayCtrl, 2, 32, 'DD'),
    );
  }

  Widget _dateChipField(
      TextEditingController ctrl, int maxLen, double width, String hint) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        maxLength: maxLen,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          hintStyle: const TextStyle(fontSize: 9, color: AppColors.textHint),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  void _showYearPicker() {
    final years = [2024, 2025, 2026, 2027];
    _showPickerDialog(
      title: '연도 선택',
      items: years.map((y) => y.toString()).toList(),
      current: _yearCtrl.text,
      onSelect: (v) {
        _yearCtrl.text = v;
        setState(() {});
      },
    );
  }

  void _showMonthPicker() {
    _showPickerDialog(
      title: '월 선택',
      items: List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')),
      current: _monthCtrl.text,
      onSelect: (v) {
        _monthCtrl.text = v;
        setState(() {});
      },
    );
  }

  void _showDayPicker() {
    final month = int.tryParse(_monthCtrl.text) ?? 1;
    final year = int.tryParse(_yearCtrl.text) ?? DateTime.now().year;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    _showPickerDialog(
      title: '일 선택',
      items: List.generate(daysInMonth, (i) => (i + 1).toString().padLeft(2, '0')),
      current: _dayCtrl.text,
      onSelect: (v) {
        _dayCtrl.text = v;
        setState(() {});
      },
    );
  }

  void _showPickerDialog({
    required String title,
    required List<String> items,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('닫기',
                        style: TextStyle(color: AppColors.textHint)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final val = items[i];
                  final isSelected = val == current;
                  return GestureDetector(
                    onTap: () {
                      onSelect(val);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        val,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ── 항목 카드 ──
  Widget _buildItemsCard(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '구매 항목',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_itemCtrls.length}종',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._itemCtrls.asMap().entries.map(
                (entry) => _buildItemRow(entry.key, entry.value, fmt),
              ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, _ItemControllers ctrl, NumberFormat fmt) {
    if (!_isEditing) {
      // ── 보기 모드 ──
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // 꽃 이름
                  Expanded(
                    child: Text(
                      ctrl.nameCtrl.text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // 합계
                  Text(
                    '₩${fmt.format(ctrl.calcTotal)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${ctrl.qtyCtrl.text}${ctrl.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    ' × ',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                  Text(
                    '₩${fmt.format(double.tryParse(ctrl.priceCtrl.text.replaceAll(',', '')) ?? 0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── 편집 모드 ──
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 꽃 이름 + 삭제
          Row(
            children: [
              const Text('🌸', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: ctrl.nameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '꽃 이름',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 18),
                onPressed: () => setState(() => _itemCtrls.removeAt(index)),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 수량 행
          Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  '수량',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: ctrl.qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              // 단위 드롭다운
              DropdownButton<String>(
                value: ctrl.unit,
                isDense: true,
                underline: const SizedBox(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                items: ['송이', '단(묶음)', '개']
                    .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(u),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => ctrl.unit = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 단가 행
          Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  '단가',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: ctrl.priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    prefixText: '₩ ',
                    prefixStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),

          // 소계
          if (ctrl.calcTotal > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '소계 ₩${fmt.format(ctrl.calcTotal)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalCard(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.secondary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 금액',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              SizedBox(height: 2),
              Text('항목 합산',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          Text(
            '₩${fmt.format(_calcTotal)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _itemCtrls.add(_ItemControllers.empty());
          });
        },
        icon: const Icon(Icons.add, size: 16),
        label: const Text('항목 추가'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────
// 전체화면 이미지 뷰어 (레터박스 없음, 수동 회전 지원)
// ─────────────────────────────────────
class _FullImageViewer extends StatefulWidget {
  final String path;
  final bool isNetwork;
  final int initialRotation;

  const _FullImageViewer({
    required this.path,
    required this.isNetwork,
    this.initialRotation = 0,
  });

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late int _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = widget.initialRotation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('원본 영수증',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          // 반시계 회전
          IconButton(
            icon: const Icon(Icons.rotate_left, color: Colors.white),
            onPressed: () =>
                setState(() => _rotation = (_rotation - 1 + 4) % 4),
          ),
          // 시계 회전
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            onPressed: () =>
                setState(() => _rotation = (_rotation + 1) % 4),
          ),
        ],
      ),
      // 레터박스 없이 화면 꽉 채우기
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isRotated90 = _rotation % 2 != 0;
          // 90/270° 회전 시 가로/세로 치환 → 올바른 크기로 SizedBox 지정
          final imgW = isRotated90 ? constraints.maxHeight : constraints.maxWidth;
          final imgH = isRotated90 ? constraints.maxWidth : constraints.maxHeight;

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 8.0,
            constrained: false,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _rotation,
                  child: SizedBox(
                    width: imgW,
                    height: imgH,
                    child: widget.isNetwork
                        ? Image.network(
                            widget.path,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64),
                          )
                        : Image.file(
                            File(widget.path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────
// 항목 컨트롤러 묶음
// ─────────────────────────────────────
class _ItemControllers {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  String unit;

  _ItemControllers({
    required this.nameCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.unit,
  });

  factory _ItemControllers.fromItem(FlowerItem item) => _ItemControllers(
        nameCtrl: TextEditingController(text: item.name),
        qtyCtrl: TextEditingController(text: item.quantity.toString()),
        priceCtrl: TextEditingController(text: item.unitPrice.toInt().toString()),
        unit: item.unit,
      );

  factory _ItemControllers.empty() => _ItemControllers(
        nameCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(),
        unit: '단(묶음)',
      );

  double get calcTotal {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0;
    return qty * price;
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
