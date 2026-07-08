import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final GlobalKey<ScanScreenState> _scanKey = GlobalKey<ScanScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onTabSwitch: (idx) => setState(() => _currentIndex = idx)),
      const HistoryScreen(),
      ScanScreen(key: _scanKey),
      const CalendarScreen(),
      const ProfileScreen(),
    ];
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('앱 종료'),
        content: const Text('앱을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          // 앱 완전 종료 (Android 시스템 종료)
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: '홈',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: '내역',
                isActive: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _ScanNavItem(
                onTap: () {
                  if (_currentIndex == 2) {
                    // 이미 스캔 탭 → 촬영 방식 선택 바로 표시
                    _scanKey.currentState?.showCameraOptions();
                  } else {
                    setState(() => _currentIndex = 2);
                  }
                },
                isActive: _currentIndex == 2,
              ),
              _NavItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month_rounded,
                label: '캘린더',
                isActive: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: '프로필',
                isActive: _currentIndex == 4,
                onTap: () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textHint,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : AppColors.textHint,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanNavItem extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _ScanNavItem({required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [AppColors.primaryDark, AppColors.primary]
                    : [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '스캔',
            style: TextStyle(
              fontSize: 11,
              color: isActive ? AppColors.primary : AppColors.textHint,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
