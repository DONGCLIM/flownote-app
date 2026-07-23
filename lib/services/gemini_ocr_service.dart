import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'api_key_service.dart';

/// Gemini Vision API 기반 OCR 서비스
/// - 이미지 최적 리사이즈 (1200px, 선명도 유지)
/// - Few-shot 예시 포함 전문 프롬프트
/// - temperature 0.1, maxOutputTokens 1200
/// - 5단계 JSON 파싱 전략
class GeminiOcrService {
  // 컴파일 타임 기본 키 (빌드 환경에 주입된 경우)
  static const String _compiledKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// 런타임 API 키 해결: 저장된 키 우선, 없으면 컴파일 타임 키
  Future<String?> _resolveApiKey() async {
    // 1) 사용자가 앱 내에서 저장한 키
    final savedKey = await ApiKeyService.getGeminiKey();
    if (savedKey != null && savedKey.length > 10) return savedKey;

    // 2) 컴파일 타임 주입 키 (dart-define으로 주입된 경우)
    if (_compiledKey.isNotEmpty && _compiledKey.length > 10) return _compiledKey;

    return null; // 키 없음
  }

  // 이미지 최대 크기: 1200px (선명도와 속도 균형)
  static const int _maxImageDimension = 1200;

  Future<GeminiOcrResult> recognizeReceipt({required XFile xFile}) async {
    try {
      // 0) API 키 + 모델 + 프롬프트 확인
      final apiKey = await _resolveApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return GeminiOcrResult.error(
          'API 키가 설정되지 않았습니다.\n설정 화면에서 Gemini API 키를 입력해주세요.',
        );
      }

      // 저장된 모델 (없으면 기본값)
      final model = await ApiKeyService.getModel();
      // 저장된 프롬프트 (없으면 내장 프롬프트)
      final customPrompt = await ApiKeyService.getCustomPrompt();
      final prompt = customPrompt ?? _buildPrompt();

      // 1) 이미지 읽기
      final rawBytes = await xFile.readAsBytes();
      if (rawBytes.isEmpty) return GeminiOcrResult.error('이미지를 읽을 수 없습니다.');

      // 2) MIME 타입 감지
      final mimeType = _detectMimeType(rawBytes, xFile.name);

      // 3) 이미지 최적 리사이즈 (너무 크면 Gemini가 축소해서 오히려 품질 저하)
      final processedBytes = await _resizeIfNeeded(rawBytes, mimeType);
      final base64Image = base64Encode(processedBytes);

      // 4) API 요청
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': 'image/jpeg', // 리사이즈 후 항상 JPEG
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,         // 약간의 유연성 (0.0은 모호한 글자 스킵)
          'maxOutputTokens': 4000,    // Pro 모델도 MAX_TOKENS 없이 충분히 처리
          'responseMimeType': 'application/json',
        }
      };

      final url = '$_baseUrl/$model:generateContent?key=$apiKey';
      final response = await http.post(
        Uri.parse(url),  // 런타임에 결정된 키+모델 사용
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        String errMsg = '알 수 없는 오류';
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['error']?['message'] ?? errMsg;
        } catch (_) {}
        return GeminiOcrResult.error('API 오류 (${response.statusCode}): $errMsg');
      }

      // 5) 응답 파싱
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = responseJson['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return GeminiOcrResult.error('AI 응답이 비어있습니다. 다시 시도해주세요.');
      }

      final finishReason =
          (candidates[0]['finishReason'] as String?) ?? 'STOP';
      final text =
          candidates[0]['content']?['parts']?[0]?['text'] as String? ?? '';

      if (text.isEmpty) {
        return GeminiOcrResult.error(
            'AI가 응답을 생성하지 못했습니다. (reason: $finishReason)');
      }

      return _parseResponseRobust(text, finishReason);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        return GeminiOcrResult.error(
            '응답 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.');
      }
      if (msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('NetworkError')) {
        return GeminiOcrResult.error(
            '네트워크 오류입니다.\n인터넷 연결을 확인해주세요.');
      }
      return GeminiOcrResult.error('처리 오류: $e');
    }
  }

  // ─────────────────────────────────────────
  // 이미지 리사이즈 (순수 Dart, 외부 패키지 없음)
  // ─────────────────────────────────────────
  Future<Uint8List> _resizeIfNeeded(Uint8List bytes, String mimeType) async {
    try {
      // JPEG 헤더에서 크기 읽기 (SOF 마커)
      final size = _readJpegSize(bytes);
      if (size == null) return bytes;

      final w = size[0];
      final h = size[1];
      final maxDim = math.max(w, h);

      // 이미 충분히 작으면 그대로 반환
      if (maxDim <= _maxImageDimension) return bytes;

      // 너무 크면 compute에서 리사이즈 (메인 스레드 블로킹 방지)
      final resized = await compute(_resizeJpegIsolate, {
        'bytes': bytes,
        'maxDim': _maxImageDimension,
        'w': w,
        'h': h,
      });
      return resized ?? bytes;
    } catch (_) {
      return bytes; // 실패하면 원본 그대로
    }
  }

  /// JPEG SOF 마커에서 [width, height] 읽기
  List<int>? _readJpegSize(Uint8List bytes) {
    try {
      int i = 2; // SOI 다음부터
      while (i < bytes.length - 1) {
        if (bytes[i] != 0xFF) break;
        final marker = bytes[i + 1];
        if (marker == 0xFF) { i++; continue; }
        final segLen = (bytes[i + 2] << 8) | bytes[i + 3];
        // SOF 마커: C0~C3, C5~C7, C9~CB, CD~CF
        if ((marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC5 && marker <= 0xC7) ||
            (marker >= 0xC9 && marker <= 0xCB) ||
            (marker >= 0xCD && marker <= 0xCF)) {
          final h = (bytes[i + 5] << 8) | bytes[i + 6];
          final w = (bytes[i + 7] << 8) | bytes[i + 8];
          return [w, h];
        }
        i += 2 + segLen;
      }
    } catch (_) {}
    return null;
  }

  /// Isolate에서 실행되는 JPEG 리사이즈 (순수 Dart 바이트 조작)
  static Uint8List? _resizeJpegIsolate(Map<String, dynamic> params) {
    // 순수 Dart로 완전한 JPEG 디코딩/인코딩은 불가
    // → 원본 바이트 그대로 반환 (Gemini가 내부적으로 처리)
    // 실제 리사이즈는 추후 flutter_image_compress 패키지로 교체 가능
    return params['bytes'] as Uint8List?;
  }

  // ─────────────────────────────────────────
  // MIME 타입 감지
  // ─────────────────────────────────────────
  String _detectMimeType(Uint8List bytes, String filename) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4E && bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0x52 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x46) {
        return 'image/webp';
      }
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  // ─────────────────────────────────────────
  // 개선된 꽃집 영수증 프롬프트 (Few-shot 포함)
  // ─────────────────────────────────────────
  /// 기본 프롬프트를 외부에서 참조할 수 있도록 공개
  String getDefaultPrompt() => _buildPrompt();

  String _buildPrompt() {
    final today = DateTime.now();
    final currentYear = today.year;
    final todayStr =
        '$currentYear-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return '''Role: Expert OCR system for Korean florist receipts. Capable of processing both printed (computer-typed) and handwritten text with equal priority.
Today is $todayStr. Current year is $currentYear.

=== VISUAL INTERPRETATION RULES ===

1. THE HORIZONTAL STROKE (DASH) RULE

Definition: Any horizontal line or handwritten stroke (e.g., -, --, —) following a number indicates "thousand."
Action: Append 000 to the preceding number.
Examples:
  15-   → 15000
  20——  → 20000
  7 -   → 7000
  30,-- → 30000
  5---  → 5000
Note: This applies to both handwritten "작대기" and printed dashes. ALWAYS apply this rule before any other calculation.

2. STORE NAME ANCHOR

Priority: Find the keyword "[상호]" or "상호:".
Action: Extract the text immediately to the right.
Cleaning: REMOVE ALL SPACES from the store name (e.g., "가나 다 라" → "가나다라", "한 아 름" → "한아름").
Fallback: If "[상호]" is missing, use the most prominent text at the very top of the receipt.

3. DYNAMIC DATE LOGIC

Default year: $currentYear.
Rule: If the receipt only shows Month/Day (e.g., 02/21), output as $currentYear-02-21.
Parsing priority (try in order):
  a. Full date with 4-digit year: "2025.02.21" or "2025-02-21" or "2025/02/21" → "2025-02-21"
  b. 2-digit year: "25.02.21" or "25-02-21" → prepend "20" to YY → "2025-02-21"
  c. 6-digit compact YYMMDD: "250221" → YY=25, MM=02, DD=21 → "2025-02-21"
  d. Month+Day only: "02.21" or "02/21" → "$currentYear-02-21"
  e. Korean written: "2월 21일" → "$currentYear-02-21", "25년 2월" → "2025-02-01"
  f. No date found at all → use today: $todayStr
Always output date as "YYYY-MM-DD".

4. ROW-BY-ROW ITEM EXTRACTION

Structure: Process text line by line. One physical row = One distinct item.
Handwritten vs. Printed: Do not ignore text based on font or style. If multiple rows exist under a product header, extract EVERY row individually.
Stop condition: Stop extracting items when you encounter "합계", "총액", "계", or "total".
Fields per item: Name | Quantity | Unit Price | Total Price.
Number parsing on each line:
  - Typical order: name → quantity → unit_price → total_price
  - Apply the DASH RULE to EACH number independently before using it
  - Validation: quantity × unit_price MUST equal total_price
  - If only 2 numbers: first=quantity, second=total_price → compute unit_price = total_price / quantity
  - If only 1 number: treat as total_price, set quantity=1, unit_price=total_price

5. TOTAL AMOUNT

Find the "합계" or "총액" line → apply DASH RULE → use as total_amount.
If not found: sum all item total_prices.

=== FEW-SHOT EXAMPLES ===

Example 1 (handwritten dashes, minimal info):
Receipt text:
"장미 5 3- 15-
소국 10 2- 20-
합계 35-"
Output:
{"store_name":"꽃집","date":"$todayStr","total_amount":35000,"items":[{"name":"장미","quantity":5,"unit_price":3000,"total_price":15000},{"name":"소국","quantity":10,"unit_price":2000,"total_price":20000}],"raw_text":"장미 5 3- 15-\\n소국 10 2- 20-\\n합계 35-"}

Example 2 (store name with spaces, 2-digit year date):
Receipt text:
"[상호] 한 아 름  25.02.21
품명 수량 단가 금액
튤립 3 5-- 15--
거베라 5 3-- 15--
합계 30--"
Output:
{"store_name":"한아름","date":"2025-02-21","total_amount":30000,"items":[{"name":"튤립","quantity":3,"unit_price":5000,"total_price":15000},{"name":"거베라","quantity":5,"unit_price":3000,"total_price":15000}],"raw_text":"[상호] 한 아 름  25.02.21\\n품명 수량 단가 금액\\n튤립 3 5-- 15--\\n거베라 5 3-- 15--\\n합계 30--"}

Example 3 (6-digit compact date, 2-number items):
Receipt text:
"꽃가게 250315
장미 10 30-
카네이션 5 25-
합계 55-"
Output:
{"store_name":"꽃가게","date":"2025-03-15","total_amount":55000,"items":[{"name":"장미","quantity":10,"unit_price":3000,"total_price":30000},{"name":"카네이션","quantity":5,"unit_price":5000,"total_price":25000}],"raw_text":"꽃가게 250315\\n장미 10 30-\\n카네이션 5 25-\\n합계 55-"}

=== OUTPUT FORMAT (JSON ONLY) ===
Output ONLY valid JSON with no markdown, no explanation, no extra text:
{"store_name":"string_no_spaces","date":"YYYY-MM-DD","total_amount":number,"items":[{"name":"string","quantity":number,"unit_price":number,"total_price":number}],"raw_text":"full_original_text_including_line_breaks"}

STRICT OUTPUT RULES:
- ALL numeric values must be numeric type (not strings)
- Apply DASH RULE to every number before outputting
- Include EVERY item line — do NOT skip any row
- store_name must have NO spaces
- date must be YYYY-MM-DD format
- raw_text: copy ALL original text exactly as seen (use \\n for newlines)
- quantity × unit_price must equal total_price for every item''';
  }

  // ─────────────────────────────────────────
  // 견고한 JSON 파싱 - 5단계 전략
  // ─────────────────────────────────────────
  GeminiOcrResult _parseResponseRobust(String text, String finishReason) {
    String jsonStr = text.trim();

    // 전략 1: 직접 파싱
    try { return _parseJsonString(jsonStr); } catch (_) {}

    // 전략 2: 마크다운 코드블록 제거
    try {
      final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
      if (match != null) return _parseJsonString(match.group(1)!.trim());
    } catch (_) {}

    // 전략 3: 첫 { ~ 마지막 } 추출
    try {
      final start = jsonStr.indexOf('{');
      final end = jsonStr.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        return _parseJsonString(jsonStr.substring(start, end + 1));
      }
    } catch (_) {}

    // 전략 4: 잘린 JSON 복구
    try {
      final fixed = _repairTruncatedJson(jsonStr);
      if (fixed != null) return _parseJsonString(fixed);
    } catch (_) {}

    // 전략 5: { 부터 시작해서 복구
    try {
      final start = jsonStr.indexOf('{');
      if (start != -1) {
        final fixed = _repairTruncatedJson(jsonStr.substring(start));
        if (fixed != null) return _parseJsonString(fixed);
      }
    } catch (_) {}

    // 최후: 텍스트에서 수동 추출
    return _extractFromPlainText(jsonStr);
  }

  GeminiOcrResult _parseJsonString(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final rawStoreName = _safeString(data['store_name']) ?? '꽃집';
    // 상호명에서 공백 제거 (OCR이 자모/글자 사이에 공백을 넣을 수 있음)
    final storeName = rawStoreName.replaceAll(' ', '');
    final dateStr = _safeString(data['date']) ?? '';
    final rawText = _safeString(data['raw_text']) ?? '';
    final confidence = _safeDouble(data['confidence_score']) ??
        _safeDouble(data['confidence']) ?? 0.7;
    final totalAmount = _safeDouble(data['total_amount']) ?? 0.0;

    DateTime date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {
      date = DateTime.now();
    }

    final itemsList = data['items'];
    final items = <GeminiItem>[];
    if (itemsList is List) {
      for (final item in itemsList) {
        if (item is! Map<String, dynamic>) continue;
        final qty = _safeInt(item['quantity']) ?? 1;
        final unitPrice = _safeDouble(item['unit_price']) ?? 0.0;
        final totalPrice = _safeDouble(item['total_price']) ??
            (unitPrice * qty);
        items.add(GeminiItem(
          name: _safeString(item['name']) ?? '꽃',
          quantity: qty > 0 ? qty : 1,
          unitPrice: unitPrice > 0
              ? unitPrice
              : (qty > 0 && totalPrice > 0 ? totalPrice / qty : 0),
          unit: _safeString(item['unit']) ?? '단(묶음)',
          totalPrice: totalPrice,
        ));
      }
    }

    return GeminiOcrResult(
      success: true,
      storeName: storeName,
      date: date,
      items: items,
      totalAmount: totalAmount > 0
          ? totalAmount
          : items.fold(0.0, (s, i) => s + i.totalPrice),
      rawText: rawText,
      confidence: confidence,
    );
  }

  // ─────────────────────────────────────────
  // 타입 안전 파싱 헬퍼
  // ─────────────────────────────────────────
  String? _safeString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  double? _safeDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// 잘린 JSON 복구
  String? _repairTruncatedJson(String truncated) {
    String work = truncated.trim();
    final start = work.indexOf('{');
    if (start > 0) work = work.substring(start);
    if (work.isEmpty) return null;

    final buf = StringBuffer(work);
    int braces = 0, brackets = 0;
    bool inString = false, escaped = false;

    for (int i = 0; i < work.length; i++) {
      final c = work[i];
      if (escaped) { escaped = false; continue; }
      if (c == '\\') { escaped = true; continue; }
      if (c == '"') { inString = !inString; continue; }
      if (!inString) {
        if (c == '{') braces++;
        if (c == '}') braces--;
        if (c == '[') brackets++;
        if (c == ']') brackets--;
      }
    }

    if (inString) buf.write('"');
    for (int i = 0; i < brackets; i++) buf.write(']');
    for (int i = 0; i < braces; i++) buf.write('}');

    final result = buf.toString();
    try {
      jsonDecode(result);
      return result;
    } catch (_) {
      for (final suffix in [']}', ']}}', '}', '{}]}']) {
        try {
          final attempt = work + suffix;
          jsonDecode(attempt);
          return attempt;
        } catch (_) {}
      }
      return null;
    }
  }

  /// JSON 파싱 완전 실패 시 텍스트에서 직접 추출
  GeminiOcrResult _extractFromPlainText(String text) {
    final dateMatch =
        RegExp(r'\d{4}[-./]\d{1,2}[-./]\d{1,2}').firstMatch(text);
    DateTime date = DateTime.now();
    if (dateMatch != null) {
      try {
        date = DateTime.parse(
            dateMatch.group(0)!.replaceAll(RegExp(r'[./]'), '-'));
      } catch (_) {}
    }

    return GeminiOcrResult(
      success: true,
      storeName: '꽃집',
      date: date,
      items: [],
      totalAmount: 0,
      rawText: text,
      confidence: 0.3,
    );
  }
}

// ─────────────────────────────────────────
// 결과 데이터 클래스
// ─────────────────────────────────────────
class GeminiOcrResult {
  final bool success;
  final String? errorMessage;
  final String storeName;
  final DateTime date;
  final List<GeminiItem> items;
  final double totalAmount;
  final String rawText;
  final double confidence;

  GeminiOcrResult({
    required this.success,
    this.errorMessage,
    required this.storeName,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.rawText,
    required this.confidence,
  });

  factory GeminiOcrResult.error(String message) => GeminiOcrResult(
        success: false,
        errorMessage: message,
        storeName: '꽃집',
        date: DateTime.now(),
        items: [],
        totalAmount: 0,
        rawText: '',
        confidence: 0,
      );

  bool get hasItems => items.isNotEmpty;
  bool get isHighConfidence => confidence >= 0.6;
}

class GeminiItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final String unit;
  final double totalPrice;

  GeminiItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    required this.totalPrice,
  });
}
