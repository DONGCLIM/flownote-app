import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      try {
        _currentUser = UserModel.fromMap(jsonDecode(userData) as Map<String, dynamic>);
        // 사업장 정보가 비어있으면 테스트 정보 자동 입력
        if (_currentUser != null && !_currentUser!.hasBusinessInfo) {
          _currentUser = _currentUser!.copyWith(
            businessName: '플로라 꽃집',
            businessNumber: '2024-03-18101',
            ownerName: '이꽃님',
            businessAddress: '서울시 송파구 잠실로 123, 1층',
            phoneNumber: '02-9876-5432',
            isUnlimited: true,
          );
          await prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
        }
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<bool> signUp({
    required String email,
    required String name,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // Simulate unique email check
      final prefs = await SharedPreferences.getInstance();
      final existingUsers = prefs.getStringList('all_users') ?? [];
      if (existingUsers.contains(email)) {
        _error = '이미 등록된 이메일입니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = UserModel(
        id: const Uuid().v4(),
        email: email,
        name: name,
        createdAt: DateTime.now(),
        scanCount: 0,
        isUnlimited: false,
      );

      await prefs.setString('user_data', jsonEncode(user.toMap()));
      await prefs.setString('user_password_$email', password);
      existingUsers.add(email);
      await prefs.setStringList('all_users', existingUsers);

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '회원가입 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPassword = prefs.getString('user_password_$email');
      if (savedPassword == null || savedPassword != password) {
        _error = '이메일 또는 비밀번호가 올바르지 않습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userData = prefs.getString('user_data');
      if (userData != null) {
        _currentUser = UserModel.fromMap(jsonDecode(userData) as Map<String, dynamic>);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '로그인 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  /// 테스트 계정으로 즉시 시작 - 회원가입 없이 앱 사용
  /// SharedPreferences에 저장하지 않아서 앱 재시작 시 초기화됨
  Future<void> signInAsGuest() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _currentUser = UserModel(
      id: 'guest_user',
      email: 'test@flownote.app',
      name: '김꽃순',
      createdAt: DateTime.now(),
      scanCount: 0,
      isUnlimited: true,
      businessName: '꽃향기 플라워샵',
      businessNumber: '123-45-67890',
      ownerName: '김꽃순',
      businessAddress: '서울시 마포구 합정동 123-4 꽃향기빌딩 1층',
      phoneNumber: '02-1234-5678',
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> incrementScanCount() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      scanCount: _currentUser!.scanCount + 1,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
    notifyListeners();
  }

  Future<void> unlockUnlimited() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(isUnlimited: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 사업자 정보 저장
  Future<void> updateBusinessInfo({
    required String businessName,
    required String businessNumber,
    required String ownerName,
    required String businessAddress,
    String phoneNumber = '',
  }) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      businessName: businessName,
      businessNumber: businessNumber,
      ownerName: ownerName,
      businessAddress: businessAddress,
      phoneNumber: phoneNumber,
    );
    // guest 계정이 아닐 때만 저장
    if (_currentUser!.id != 'guest_user') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
    }
    notifyListeners();
  }
}
