import 'package:shared_preferences/shared_preferences.dart';

/// Gemini API 키 / 모델 / 프롬프트 로컬 저장 관리
class ApiKeyService {
  static const String _keyGemini = 'gemini_api_key';
  static const String _keyModel = 'gemini_model';
  static const String _keyPrompt = 'gemini_prompt';

  // ── 기본 모델 ──
  static const String defaultModel = 'gemini-2.5-flash-lite';

  // ── API 키 ──
  static Future<void> saveGeminiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGemini, key.trim());
  }

  static Future<String?> getGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyGemini);
    if (key == null || key.isEmpty) return null;
    return key;
  }

  static Future<bool> hasGeminiKey() async {
    final key = await getGeminiKey();
    return key != null && key.length > 10;
  }

  static Future<void> clearGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGemini);
  }

  /// API 키 마스킹 표시용 (앞 8자 + ***)
  static String maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 8)}••••••••••••••••';
  }

  // ── 모델 ──
  static Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModel, model.trim());
  }

  static Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyModel) ?? defaultModel;
  }

  // ── 프롬프트 (null = 기본 프롬프트 사용) ──
  static Future<void> savePrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrompt, prompt);
  }

  static Future<String?> getCustomPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(_keyPrompt);
    if (p == null || p.isEmpty) return null;
    return p;
  }

  static Future<void> clearCustomPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrompt);
  }
}
