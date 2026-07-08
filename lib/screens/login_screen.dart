import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  /// 테스트 계정으로 즉시 시작 (회원가입 불필요)
  Future<void> _loginAsGuest() async {
    final auth = context.read<AuthProvider>();
    await auth.signInAsGuest();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 36),

                  // ── 테스트 계정 카드 (가장 눈에 띄게 상단 배치) ──
                  _buildGuestCard(),
                  const SizedBox(height: 28),

                  _buildDivider('이메일로 로그인'),
                  const SizedBox(height: 24),

                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 8),
                  _buildForgotPassword(),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 24),
                  _buildSignUpRow(),
                  const SizedBox(height: 20),
                  _buildErrorWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text('🌸', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'FlowNote',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '꽃 영수증을 스마트하게 관리하세요',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// 테스트 계정 카드 - 회원가입 없이 바로 시작
  Widget _buildGuestCard() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return GestureDetector(
          onTap: auth.isLoading ? null : _loginAsGuest,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 16),
                // 텍스트
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '테스트 계정으로 시작하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '회원가입 없이 모든 기능 체험\n무제한 스캔 · 데이터 임시 저장',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // 화살표
                auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: '이메일',
        prefixIcon:
            Icon(Icons.mail_outline_rounded, color: AppColors.textHint),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return '이메일을 입력하세요';
        if (!v.contains('@')) return '올바른 이메일 형식이 아닙니다';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '비밀번호',
        prefixIcon:
            const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textHint,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
        if (v.length < 6) return '비밀번호는 6자 이상이어야 합니다';
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: const Text(
          '비밀번호를 잊으셨나요?',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _login,
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('로그인'),
          ),
        );
      },
    );
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '계정이 없으신가요? ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              );
            },
            child: const Text(
              '회원가입',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.error == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  auth.error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
