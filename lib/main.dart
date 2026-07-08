import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models/receipt_model.dart';
import 'providers/auth_provider.dart';
import 'providers/receipt_provider.dart';
import 'services/notification_service.dart';
import 'services/training_data_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Korean locale
  await initializeDateFormatting('ko', null);

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ReceiptModelAdapter());
  Hive.registerAdapter(FlowerItemAdapter());

  // Initialize Firebase (실패해도 앱은 계속 실행)
  try {
    await Firebase.initializeApp();
    await TrainingDataService().init();
    if (kDebugMode) debugPrint('[Firebase] 초기화 완료');
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] 초기화 실패 (계속 진행): $e');
  }

  // Initialize notification service
  await NotificationService().init();

  // Initialize auth provider
  final authProvider = AuthProvider();
  await authProvider.init();

  // Initialize receipt provider
  final receiptProvider = ReceiptProvider();
  await receiptProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: receiptProvider),
      ],
      child: const FlowNoteApp(),
    ),
  );
}

class FlowNoteApp extends StatelessWidget {
  const FlowNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const MainScreen() : const LoginScreen();
  }
}
