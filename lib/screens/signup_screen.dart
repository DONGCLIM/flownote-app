import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이용약관에 동의해주세요.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('회원가입'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeText(),
                const SizedBox(height: 32),
                _buildNameField(),
                const SizedBox(height: 16),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildConfirmPasswordField(),
                const SizedBox(height: 20),
                _buildFreeScanBanner(),
                const SizedBox(height: 20),
                _buildTermsCheckbox(),
                const SizedBox(height: 28),
                _buildSignUpButton(),
                const SizedBox(height: 16),
                _buildErrorWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '환영합니다! 🌺',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '지금 가입하고 30회 무료 스캔을\n시작해보세요',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      decoration: const InputDecoration(
        labelText: '이름',
        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textHint),
      ),
      validator: (v) => (v == null || v.isEmpty) ? '이름을 입력하세요' : null,
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: '이메일',
        prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.textHint),
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
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textHint,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
        if (v.length < 6) return '비밀번호는 6자 이상이어야 합니다';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmCtrl,
      obscureText: _obscureConfirm,
      decoration: InputDecoration(
        labelText: '비밀번호 확인',
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textHint,
          ),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
      validator: (v) {
        if (v != _passwordCtrl.text) return '비밀번호가 일치하지 않습니다';
        return null;
      },
    );
  }

  Widget _buildFreeScanBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🎁', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '30회 무료 스캔 제공!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '가입 즉시 30회의 OCR 스캔 기능을\n무료로 이용하실 수 있습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                TextSpan(text: '이용약관 및 '),
                TextSpan(
                  text: '개인정보처리방침',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: '에 동의합니다'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _signUp,
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('무료로 시작하기'),
          ),
        );
      },
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
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  auth.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
