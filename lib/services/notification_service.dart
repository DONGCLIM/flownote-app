import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

/// 로컬 푸시 알림 서비스
/// - 다중 스캔 진행 중 상태 알림 (Notification Panel에 진행률 표시)
/// - 스캔 완료 알림 (탭 시 앱으로 복귀)
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _progressId = 1001;  // 진행 중 알림 ID
  static const int _doneId    = 1002;   // 완료 알림 ID

  // 채널 1: 진행 중 (낮은 우선순위, 소리 없음)
  static const String _progressChannelId   = 'flow_note_progress';
  static const String _progressChannelName = 'FlowNote 스캔 진행';

  // 채널 2: 완료 (높은 우선순위, 소리 있음)
  static const String _doneChannelId   = 'flow_note_done';
  static const String _doneChannelName = 'FlowNote 스캔 완료';

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) { _initialized = true; return; }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // 알림 탭 시 앱이 포그라운드로 복귀하도록 콜백 등록
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // payload 'scan_complete' → 앱이 포그라운드로 올라옴
        // 추가 라우팅이 필요하면 여기서 처리
        if (kDebugMode) {
          debugPrint('[Notification] tapped: ${response.payload}');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Android 알림 채널 명시적 생성 (진행 채널)
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _progressChannelId,
        _progressChannelName,
        description: '영수증 스캔 진행 상황을 실시간으로 알려드립니다',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    // Android 알림 채널 명시적 생성 (완료 채널)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _doneChannelId,
        _doneChannelName,
        description: '영수증 스캔 완료 시 알려드립니다',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    _initialized = true;
  }

  /// Android 13+ 알림 권한 요청
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// ─────────────────────────────────────────
  /// 진행 중 알림 - Notification Panel에 "2/5번째 처리 중" 표시
  /// ongoing: true → 스와이프로 지울 수 없음 (처리 완료 전까지 유지)
  /// ─────────────────────────────────────────
  Future<void> showProgress(int current, int total) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _progressChannelId,
      _progressChannelName,
      channelDescription: '영수증 스캔 진행 상황',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,        // 완료 전까지 패널에 고정
      autoCancel: false,    // 탭해도 사라지지 않음 (진행 중)
      showProgress: true,
      maxProgress: total,
      progress: current,
      onlyAlertOnce: true,  // 업데이트 시 소리/진동 없음
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF4CAF50),
      styleInformation: BigTextStyleInformation(
        '$current / $total 번째 영수증을 분석하고 있습니다.\n잠시 기다려주세요...',
        contentTitle: '🌸 FlowNote - 영수증 스캔 중',
        summaryText: '백그라운드에서 계속 진행됩니다',
      ),
    );

    await _plugin.show(
      _progressId,
      '🌸 FlowNote - 스캔 진행 중',
      '$current / $total 번째 처리 중...',
      NotificationDetails(android: androidDetails),
      payload: 'scan_progress',
    );
  }

  /// ─────────────────────────────────────────
  /// 완료 알림 - 탭하면 앱으로 복귀
  /// ─────────────────────────────────────────
  Future<void> showComplete(int total, int success, int failed) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    // 진행 중 알림 제거
    await _plugin.cancel(_progressId);

    final title = failed == 0
        ? '✅ 영수증 스캔 완료!'
        : '⚠️ 스캔 완료 (일부 실패)';

    final body = failed == 0
        ? '$success장 모두 완료됐어요! 탭하여 앱으로 돌아가세요.'
        : '$success장 완료, $failed장 인식 실패.\n탭하여 앱으로 돌아가세요.';

    final androidDetails = AndroidNotificationDetails(
      _doneChannelId,
      _doneChannelName,
      channelDescription: '영수증 스캔 완료',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF4CAF50),
      playSound: true,
      enableVibration: true,
      autoCancel: true,     // 탭 시 자동 제거
      fullScreenIntent: false,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'FlowNote',
      ),
    );

    await _plugin.show(
      _doneId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'scan_complete',  // 탭 시 콜백으로 전달
    );
  }

  /// 모든 알림 취소
  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }
}

/// 백그라운드 알림 탭 핸들러 (top-level function 필수)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    debugPrint('[Notification BG] tapped: ${notificationResponse.payload}');
  }
}
