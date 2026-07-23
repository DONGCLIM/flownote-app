import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/gemini_ocr_service.dart';
import '../services/notification_service.dart';
import '../services/receipt_parser.dart';
import '../services/training_data_service.dart';
import '../models/receipt_model.dart';
import 'receipt_edit_screen.dart';
import 'gemini_key_screen.dart';
import 'in_app_camera_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final GeminiOcrService _geminiService = GeminiOcrService();
  final NotificationService _notif = NotificationService();
  final TrainingDataService _training = TrainingDataService();

  bool _isProcessing = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _stepDuration = Duration(milliseconds: 120);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // 알림 권한 요청 (Android 13+)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notif.requestPermission();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // 권한 요청
  // ──────────────────────────────────────────
  Future<bool> _requestCameraPermission() async {
    // 바로 권한 요청 (status 체크 없이 — iOS notDetermined 이슈 방지)
    var status = await Permission.camera.request();

    if (status.isGranted) return true;

    // 영구 거부 → 설정으로 이동 다이얼로그
    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('카메라 권한 필요'),
          ],
        ),
        content: const Text(
          '영수증 촬영을 위해 카메라 접근 권한이 필요합니다.\n\n설정 > FlowNote > 카메라를 허용해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _requestGalleryPermission() async {
    await Permission.photos.request();
    await Permission.storage.request();
  }

  // ──────────────────────────────────────────
  // 스캔 가능 여부 확인
  // ──────────────────────────────────────────
  bool _checkScanAvailable() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.canScan) {
      _showUpgradeDialog();
      return false;
    }
    return true;
  }

  // ──────────────────────────────────────────
  // 카메라 (InAppCameraScreen 사용)
  // ──────────────────────────────────────────
  /// MainScreen에서 스캔 탭 재탭 시 호출 (public)
  Future<void> showCameraOptions() => _scanFromCamera();

  Future<void> _scanFromCamera() async {
    if (!_checkScanAvailable()) return;

    final granted = await _requestCameraPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('카메라 권한이 필요합니다. 설정에서 허용해 주세요.'),
          action: SnackBarAction(label: '설정', onPressed: openAppSettings),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // 한 장 / 여러 장 선택 다이얼로그
    if (!mounted) return;
    final mode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '촬영 방식 선택',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _SheetOptionTile(
              icon: Icons.photo_camera_outlined,
              iconColor: AppColors.primary,
              title: '한 장 촬영',
              subtitle: '영수증 1장을 바로 스캔합니다',
              onTap: () => Navigator.pop(ctx, 'single'),
            ),
            const SizedBox(height: 12),
            _SheetOptionTile(
              icon: Icons.burst_mode_outlined,
              iconColor: AppColors.secondary,
              title: '여러 장 연속 촬영',
              subtitle: '여러 장을 찍고 한 번에 스캔합니다',
              onTap: () => Navigator.pop(ctx, 'multi'),
            ),
          ],
        ),
      ),
    );

    if (mode == null || !mounted) return;

    // InAppCameraScreen 열기 → 결과는 List<XFile>
    final List<XFile>? images = await Navigator.push<List<XFile>>(
      context,
      MaterialPageRoute(
        builder: (_) => InAppCameraScreen(mode: mode),
      ),
    );

    if (!mounted || images == null || images.isEmpty) return;

    if (images.length == 1) {
      await _runGeminiOcr(images.first);
    } else {
      await _runMultipleOcr(images);
    }
  }

  // 갤러리 다중 + 카메라 연속 공통 OCR 처리
  Future<void> _runMultipleOcr(List<XFile> imageList) async {
    final total = imageList.length;
    final List<({ParsedReceipt parsed, String imagePath})> results = [];
    int failCount = 0;

    for (int i = 0; i < total; i++) {
      if (!mounted) break;
      final progress = (i / total) * 0.9;
      _setProcessing(true, '${i + 1}/$total번째 영수증 분석 중...', progress.clamp(0.05, 0.9));
      await _notif.showProgress(i + 1, total);
      try {
        final result = await _geminiService.recognizeReceipt(xFile: imageList[i]);
        if (!mounted) break;
        if (!result.success) { failCount++; continue; }
        final parsed = _geminiResultToParsed(result);
        results.add((parsed: parsed, imagePath: imageList[i].path));
      } catch (e) {
        failCount++;
      }
    }

    await _notif.showComplete(total, results.length, failCount);
    if (!mounted) return;
    _setProcessing(false, '', 1.0);

    if (results.isEmpty) {
      _showErrorDialog('모든 영수증 인식에 실패했습니다.\n이미지를 더 밝고 선명하게 다시 시도해주세요.');
      return;
    }

    await _showScanCompleteDialog(results.length, failCount);
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    int savedCount = 0;
    for (int i = 0; i < results.length; i++) {
      if (!mounted) break;
      if (i > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${i + 1}/${results.length}번째 영수증 확인 중...'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: AppColors.primary,
        ));
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (!mounted) break;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptEditScreen(
            parsed: results[i].parsed,
            imagePath: results[i].imagePath,
          ),
        ),
      );
      if (saved == true && mounted) {
        savedCount++;
        await authProvider.incrementScanCount();
      }
    }

    if (mounted && savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $savedCount건의 영수증이 저장되었습니다'),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ──────────────────────────────────────────
  // 갤러리 다중 선택
  // ──────────────────────────────────────────
  Future<void> _scanMultipleFromGallery() async {
    if (!_checkScanAvailable()) return;
    await _requestGalleryPermission();

    final pickedList = await _picker.pickMultiImage(imageQuality: 90);
    if (pickedList.isEmpty) return;

    // 1장이면 기존 플로우
    if (pickedList.length == 1) {
      await _runGeminiOcr(pickedList.first);
      return;
    }

    // 여러 장: 공통 OCR 처리 함수 사용
    await _runMultipleOcr(pickedList);
  }

  Future<void> _showScanCompleteDialog(int successCount, int failCount) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('✅', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('스캔 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$successCount장의 영수증 인식이 완료되었습니다.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (failCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$failCount장은 인식에 실패하여 건너뜁니다.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              '지금부터 각 영수증을 순서대로 확인하고 저장합니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인 및 편집 시작'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // 갤러리
  // ──────────────────────────────────────────
  // 진행 바 자동 증가 (실제 응답 전까지 천천히 증가)
  // ──────────────────────────────────────────
  void _startProgressSimulation() {
    // 0.1 → 0.8 사이를 천천히 증가 (AI 응답 기다리는 동안)
    _animateProgressTo(0.1, 0.08, '이미지 준비 중...');

    Future.delayed(const Duration(milliseconds: 600), () {
      if (_isProcessing && mounted) {
        _animateProgressTo(0.3, 0.03, '영수증 분석 중...');
      }
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (_isProcessing && mounted) {
        _animateProgressTo(0.7, 0.015, '텍스트 인식 중...');
      }
    });
  }

  void _animateProgressTo(double target, double speed, String status) {
    if (!mounted) return;
    setState(() {
      _processingStatus = status;
    });

    Future.doWhile(() async {
      await Future.delayed(_stepDuration);
      if (!mounted || !_isProcessing) return false;
      if (_processingProgress >= target) return false;
      setState(() {
        _processingProgress =
            (_processingProgress + speed).clamp(0.0, target);
      });
      return true;
    });
  }

  // ──────────────────────────────────────────
  // Gemini OCR 파이프라인
  // ──────────────────────────────────────────
  Future<void> _runGeminiOcr(XFile xFile) async {
    _setProcessing(true, '이미지 준비 중...', 0.05);
    _startProgressSimulation();

    try {
      final result = await _geminiService.recognizeReceipt(
        xFile: xFile,
      );

      if (!mounted) return;

      _setProcessing(true, '영수증 데이터 정리 중...', 0.92);
      await Future.delayed(const Duration(milliseconds: 150));
      _setProcessing(false, '', 1.0);

      if (!mounted) return;

      if (!result.success) {
        _showErrorDialog(result.errorMessage ?? '알 수 없는 오류');
        return;
      }

      // Gemini 결과 → ParsedReceipt 변환
      final parsed = _geminiResultToParsed(result);

      // 학습 데이터 STEP1: 이미지 + AI결과 저장 (백그라운드)
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id ?? 'unknown';
      final trainingDocId = await _training.saveInitialScan(
        imagePath: xFile.path,
        aiResult: result,
        userId: userId,
      );

      // 편집 화면으로 이동
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptEditScreen(
            parsed: parsed,
            imagePath: xFile.path,
            trainingDocId: trainingDocId, // 학습 데이터 docId 전달
          ),
        ),
      );

      if (saved == true && mounted) {
        await authProvider.incrementScanCount();
      }
    } catch (e) {
      _setProcessing(false, '', 0);
      if (mounted) {
        _showErrorDialog('처리 중 오류: $e');
      }
    }
  }

  ParsedReceipt _geminiResultToParsed(GeminiOcrResult result) {
    final items = result.items.map((gi) {
      double unitPrice = gi.unitPrice;
      if (unitPrice <= 0 && gi.quantity > 0) {
        unitPrice = gi.totalPrice / gi.quantity;
      }
      return FlowerItem(
        name: gi.name,
        quantity: gi.quantity,
        unitPrice: unitPrice,
        unit: gi.unit,
      );
    }).toList();

    return ParsedReceipt(
      storeName: result.storeName,
      date: result.date,
      items: items,
      totalAmount: result.totalAmount,
      rawText: result.rawText,
      confidence: result.confidence,
    );
  }

  void _setProcessing(bool active, String status, double progress) {
    if (!mounted) return;
    setState(() {
      _isProcessing = active;
      _processingStatus = status;
      _processingProgress = progress;
    });
  }

  // ──────────────────────────────────────────
  // 수동 입력
  // ──────────────────────────────────────────
  void _openManualEntry() {
    final empty = ParsedReceipt(
      storeName: '',
      date: DateTime.now(),
      items: [],
      totalAmount: 0,
      rawText: '',
      confidence: 0,
    );
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptEditScreen(
          parsed: empty,
          imagePath: null,
          isManual: true,
        ),
      ),
    ).then((saved) async {
      if (saved == true && mounted) {
        await context.read<AuthProvider>().incrementScanCount();
      }
    });
  }

  // ──────────────────────────────────────────
  // 다이얼로그
  // ──────────────────────────────────────────
  void _showErrorDialog(String message) {
    // API 키 오류인지 감지
    final isApiKeyError = message.contains('API 키') ||
        message.contains('403') ||
        message.contains('callers without') ||
        message.contains('API key') ||
        message.contains('설정 화면');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(isApiKeyError ? '🔑' : '⚠️',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(isApiKeyError ? 'API 키 필요' : '스캔 실패'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          if (isApiKeyError)
            ElevatedButton.icon(
              icon: const Icon(Icons.key_outlined, size: 16),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GeminiKeyScreen(),
                  ),
                );
              },
              label: const Text('API 키 설정'),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openManualEntry();
              },
              child: const Text('수동 입력'),
            ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌟', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                '무료 스캔 소진',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '30회 무료 스캔을 모두 사용했어요.\n무제한으로 업그레이드하여 계속 사용하세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildPricingCard(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await context.read<AuthProvider>().unlockUnlimited();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 무제한 스캔이 활성화되었습니다!'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                  },
                  child: const Text('무제한으로 업그레이드'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('나중에'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '무제한 플랜',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '영수증 무제한 스캔',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          Text(
            '₩9,900',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canScan = user?.canScan ?? false;
    final remaining = user?.remainingScans ?? 0;
    final isUnlimited = user?.isUnlimited ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isProcessing
            ? _buildProcessingView()
            : _buildScanView(canScan, remaining, isUnlimited),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 처리 중 화면
  // ──────────────────────────────────────────
  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnim.value, child: child),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.secondary.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text('🌸', style: TextStyle(fontSize: 48)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '영수증 스캔 중',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI가 영수증을 분석하고 있어요',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _processingStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _processingProgress,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(_processingProgress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 메인 스캔 UI
  // ──────────────────────────────────────────
  Widget _buildScanView(bool canScan, int remaining, bool isUnlimited) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildHeader(),
          const SizedBox(height: 28),
          _buildActionButtons(canScan),
          const SizedBox(height: 12),
          _buildManualEntryButton(),
          const SizedBox(height: 20),
          _buildScanCountWidget(remaining, isUnlimited),
          const SizedBox(height: 20),
          _buildAiInfoCard(),
          const SizedBox(height: 20),
          _buildTipsCard(),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          '영수증 스캔',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            children: [
              TextSpan(text: 'AI를 통해 영수증을 '),
              TextSpan(
                text: '자동 분석',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: '합니다'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool canScan) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.camera_alt_outlined,
            label: '카메라 촬영',
            sublabel: '즉시 스캔',
            color: AppColors.primary,
            isEnabled: canScan,
            onTap: _scanFromCamera,
            isWide: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.photo_library_outlined,
            label: '갤러리 선택',
            sublabel: '여러 장 가능',
            color: AppColors.secondary,
            isEnabled: canScan,
            onTap: _scanMultipleFromGallery,
            isWide: false,
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openManualEntry,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('직접 수동 입력'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildScanCountWidget(int remaining, bool isUnlimited) {
    if (isUnlimited) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.all_inclusive_rounded,
                color: AppColors.accent, size: 20),
            SizedBox(width: 8),
            Text(
              '무제한 스캔 이용 중입니다',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Color barColor = remaining > 10
        ? AppColors.accent
        : remaining > 0
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '남은 무료 스캔: $remaining / 30회',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: remaining / 30,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(barColor),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showUpgradeDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '업그레이드',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🌿', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 영수증 분석',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'AI를 통해 영수증을 자동 분석합니다\n별도 설정 없이 바로 사용 가능합니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = [
      ('💡', '밝은 환경에서 찍을수록 AI 인식률이 높아요'),
      ('📄', '영수증 전체가 화면에 들어오게 촬영하세요'),
      ('✏️', '인식 후 편집 화면에서 수정 가능합니다'),
      ('🌐', '스캔 시 인터넷 연결이 필요합니다'),
    ];

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
          const Text(
            '스캔 팁',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tip.$1, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
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
}

// ──────────────────────────────────────────
// 액션 버튼 위젯 (정사각형 병렬 스타일)
// ──────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;
  final bool isWide; // 하위 호환용 (무시)

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isEnabled,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AspectRatio(
        aspectRatio: 1.0, // 정사각형
        child: Container(
          decoration: BoxDecoration(
            color: isEnabled
                ? color.withValues(alpha: 0.07)
                : AppColors.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled
                  ? color.withValues(alpha: 0.25)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withValues(alpha: 0.12)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : AppColors.textHint,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? color : AppColors.textHint,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled
                      ? color.withValues(alpha: 0.65)
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 촬영 방식 선택 바텀시트 옵션 타일 ──
class _SheetOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

