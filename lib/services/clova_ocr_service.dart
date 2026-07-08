import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// CLOVA OCR 서비스
/// - 네이버 CLOVA OCR API 연동
/// - 원본 이미지 그대로 전송 (압축 없음)
/// - 한글 특화, 손글씨 인식 우수
class ClovaOcrService {
  static const String _apiUrl =
      'http://clovaocr-api-kr.ncloud.com/external/v1/50396/0ad62ffb286b5659893edd04df3f47891ed3882f813c6d9402057bbcbf068d41';
  static const String _secretKey =
      'TEJGa1pIWWtNSWJWQ0hUWkVpTlFacVVObGZFc3RPVU0=';

  Future<ClovaOcrResult> recognizeReceipt({required XFile xFile}) async {
    try {
      // 1) 이미지 읽기 (원본 그대로)
      final rawBytes = await xFile.readAsBytes();
      if (rawBytes.isEmpty) return ClovaOcrResult.error('이미지를 읽을 수 없습니다.');

      // 2) MIME 타입 감지
      final mimeType = _detectMimeType(rawBytes, xFile.name);
      final format = _mimeToFormat(mimeType); // jpeg, png, pdf 등
      final base64Image = base64Encode(rawBytes);

      // 3) CLOVA OCR 요청 바디 구성
      final requestBody = {
        'version': 'V2',
        'requestId': const Uuid().v4(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'lang': 'ko',
        'images': [
          {
            'format': format,
            'name': 'receipt',
            'data': base64Image,
          }
        ],
        'enableTableDetection': false,
      };

      // 4) API 호출
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'X-OCR-SECRET': _secretKey,
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        String errMsg = '알 수 없는 오류';
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['message'] ?? errMsg;
        } catch (_) {}
        return ClovaOcrResult.error('CLOVA OCR 오류 (${response.statusCode}): $errMsg');
      }

      // 5) 응답 파싱
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(responseJson);

    } catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        return ClovaOcrResult.error('응답 시간이 초과되었습니다.\n이미지를 더 작게 찍거나 잠시 후 다시 시도해주세요.');
      }
      if (msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('NetworkError')) {
        return ClovaOcrResult.error('네트워크 오류입니다.\n인터넷 연결을 확인해주세요.');
      }
      return ClovaOcrResult.error('처리 오류: $e');
    }
  }

  // ─────────────────────────────────────────
  // CLOVA OCR 응답 파싱
  // ─────────────────────────────────────────
  ClovaOcrResult _parseResponse(Map<String, dynamic> json) {
    try {
      final images = json['images'] as List?;
      if (images == null || images.isEmpty) {
        return ClovaOcrResult.error('OCR 결과가 없습니다.');
      }

      final image = images[0] as Map<String, dynamic>;
      final inferResult = image['inferResult'] as String? ?? '';

      if (inferResult == 'ERROR') {
        final errMsg = image['message'] as String? ?? 'OCR 처리 실패';
        return ClovaOcrResult.error(errMsg);
      }

      // 모든 텍스트 블록 추출
      final fields = image['fields'] as List? ?? [];
      final lines = <String>[];
      final rawTextBuf = StringBuffer();

      for (final field in fields) {
        final text = field['inferText'] as String? ?? '';
        if (text.trim().isEmpty) continue;
        lines.add(text.trim());
        rawTextBuf.write('$text ');
      }

      final rawText = rawTextBuf.toString().trim();

      if (rawText.isEmpty) {
        return ClovaOcrResult.error('텍스트를 인식하지 못했습니다.\n영수증이 잘 보이도록 다시 촬영해주세요.');
      }

      // 텍스트에서 영수증 정보 파싱
      return _parseReceiptFromText(lines, rawText);

    } catch (e) {
      return ClovaOcrResult.error('응답 파싱 오류: $e');
    }
  }

  // ─────────────────────────────────────────
  // 텍스트 라인에서 영수증 정보 추출
  // ─────────────────────────────────────────
  ClovaOcrResult _parseReceiptFromText(List<String> lines, String rawText) {
    String storeName = '꽃집';
    DateTime date = DateTime.now();
    double totalAmount = 0;
    final items = <ClovaItem>[];

    // ── 상호명 추출 ──
    // [상호] 레이블 오른쪽 텍스트
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('[상호]') || line.contains('상호:') || line.contains('상호 :')) {
        final extracted = line
            .replaceAll('[상호]', '')
            .replaceAll('상호:', '')
            .replaceAll('상호 :', '')
            .trim();
        if (extracted.isNotEmpty) {
          storeName = extracted;
        } else if (i + 1 < lines.length) {
          storeName = lines[i + 1].trim();
        }
        break;
      }
    }

    // 상호 못 찾으면 첫 줄 사용
    if (storeName == '꽃집' && lines.isNotEmpty) {
      final firstLine = lines[0].trim();
      if (firstLine.isNotEmpty && !_isNumber(firstLine)) {
        storeName = firstLine;
      }
    }

    // ── 날짜 추출 ──
    final dateRegexFull = RegExp(r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})');
    final dateRegexShort = RegExp(r'(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})');

    for (final line in lines) {
      final matchFull = dateRegexFull.firstMatch(line);
      if (matchFull != null) {
        try {
          date = DateTime(
            int.parse(matchFull.group(1)!),
            int.parse(matchFull.group(2)!),
            int.parse(matchFull.group(3)!),
          );
          break;
        } catch (_) {}
      }
      final matchShort = dateRegexShort.firstMatch(line);
      if (matchShort != null) {
        try {
          final year = int.parse(matchShort.group(1)!);
          date = DateTime(
            year < 100 ? 2000 + year : year,
            int.parse(matchShort.group(2)!),
            int.parse(matchShort.group(3)!),
          );
          break;
        } catch (_) {}
      }
    }

    // ── 합계 추출 ──
    final totalKeywords = ['합계', '총액', '총 금액', '합산', '계', 'total', 'TOTAL'];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final kw in totalKeywords) {
        if (line.contains(kw)) {
          // 같은 줄 또는 다음 줄에서 금액 추출
          final amount = _extractAmount(line) ?? 
              (i + 1 < lines.length ? _extractAmount(lines[i + 1]) : null);
          if (amount != null && amount > 0) {
            totalAmount = amount;
            break;
          }
        }
      }
      if (totalAmount > 0) break;
    }

    // ── 품목 추출 ──
    // 품명 헤더 이후부터 파싱
    bool inItemSection = false;
    final flowerKeywords = [
      '장미', '소국', '튤립', '거베라', '카네이션', '리시안서스', '수국',
      '안개꽃', '백합', '국화', '해바라기', '아이리스', '프리지아', '라넌큘러스',
      '작약', '목화', '유칼립투스', '레몬', '스타티스', '천일홍', '케일',
      '부바르디아', '알스트로메리아', '델피니움', '스냅', '금어초', '맨드라미',
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // 품명 섹션 시작 감지
      if (line.contains('품명') || line.contains('품  명') || line.contains('상품명')) {
        inItemSection = true;
        continue;
      }

      // 합계 줄 도달 시 종료
      for (final kw in totalKeywords) {
        if (line.contains(kw)) {
          inItemSection = false;
          break;
        }
      }

      if (!inItemSection) continue;

      // 꽃 이름 포함된 줄인지 확인
      bool isFlowerLine = flowerKeywords.any((kw) => line.contains(kw));

      // 꽃 이름 없어도 숫자 패턴이 있으면 품목으로 간주
      if (!isFlowerLine && _extractAmount(line) == null) continue;

      // 같은 줄 또는 인접 줄에서 수량, 단가, 금액 추출
      final parsed = _parseItemLine(lines, i);
      if (parsed != null) {
        items.add(parsed);
      }
    }

    // 품목 못 찾으면 전체 텍스트에서 꽃 이름 기반으로 추출
    if (items.isEmpty) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        final isFlower = flowerKeywords.any((kw) => line.contains(kw));
        if (!isFlower) continue;
        final parsed = _parseItemLine(lines, i);
        if (parsed != null) items.add(parsed);
      }
    }

    // 합계 없으면 품목 합산
    if (totalAmount <= 0 && items.isNotEmpty) {
      totalAmount = items.fold(0.0, (s, item) => s + item.totalPrice);
    }

    // 신뢰도 계산
    double confidence = 0.5;
    if (storeName != '꽃집') confidence += 0.15;
    if (items.isNotEmpty) confidence += 0.2;
    if (totalAmount > 0) confidence += 0.15;
    confidence = confidence.clamp(0.0, 1.0);

    return ClovaOcrResult(
      success: true,
      storeName: storeName,
      date: date,
      items: items,
      totalAmount: totalAmount,
      rawText: rawText,
      confidence: confidence,
    );
  }

  // ─────────────────────────────────────────
  // 품목 라인 파싱 (수량, 단가, 합계)
  // ─────────────────────────────────────────
  ClovaItem? _parseItemLine(List<String> lines, int index) {
    final line = lines[index].trim();

    // 꽃 이름 추출
    String name = line;
    // 숫자 부분 제거하여 이름만 남기기
    name = name.replaceAll(RegExp(r'[\d,\.\-]+'), '').trim();
    if (name.isEmpty) name = line.split(RegExp(r'\s+'))[0];

    // 인접 줄 포함하여 숫자들 수집
    final allNumbers = <double>[];
    for (int j = index; j < lines.length && j <= index + 2; j++) {
      final nums = _extractAllNumbers(lines[j]);
      allNumbers.addAll(nums);
    }

    // 대시룰 적용된 숫자 재추출
    final dashApplied = <double>[];
    for (int j = index; j < lines.length && j <= index + 2; j++) {
      final nums = _extractNumbersWithDashRule(lines[j]);
      dashApplied.addAll(nums);
    }

    final numbers = dashApplied.isNotEmpty ? dashApplied : allNumbers;

    if (numbers.isEmpty) return null;

    // 수량, 단가, 합계 추론
    int qty = 1;
    double unitPrice = 0;
    double totalPrice = 0;

    if (numbers.length >= 3) {
      qty = numbers[0].toInt();
      unitPrice = numbers[1];
      totalPrice = numbers[2];
    } else if (numbers.length == 2) {
      // qty × price 또는 단가, 합계
      if (numbers[0] < 100 && numbers[1] > 100) {
        qty = numbers[0].toInt();
        totalPrice = numbers[1];
        unitPrice = qty > 0 ? totalPrice / qty : totalPrice;
      } else {
        unitPrice = numbers[0];
        totalPrice = numbers[1];
      }
    } else if (numbers.length == 1) {
      totalPrice = numbers[0];
      unitPrice = totalPrice;
    }

    if (totalPrice <= 0 && unitPrice > 0) {
      totalPrice = unitPrice * qty;
    }

    if (name.isEmpty || totalPrice <= 0) return null;

    return ClovaItem(
      name: name.length > 20 ? name.substring(0, 20) : name,
      quantity: qty > 0 ? qty : 1,
      unitPrice: unitPrice,
      unit: '단(묶음)',
      totalPrice: totalPrice,
    );
  }

  // ─────────────────────────────────────────
  // 헬퍼 메서드들
  // ─────────────────────────────────────────

  /// 대시룰 적용: 15-- → 15000
  double? _extractAmount(String text) {
    // 대시룰 먼저 적용
    final dashApplied = _applyDashRule(text);
    final match = RegExp(r'[\d,]+').firstMatch(dashApplied.replaceAll(' ', ''));
    if (match == null) return null;
    final numStr = match.group(0)!.replaceAll(',', '');
    return double.tryParse(numStr);
  }

  List<double> _extractAllNumbers(String text) {
    final results = <double>[];
    final matches = RegExp(r'[\d,]+').allMatches(text);
    for (final m in matches) {
      final val = double.tryParse(m.group(0)!.replaceAll(',', ''));
      if (val != null) results.add(val);
    }
    return results;
  }

  List<double> _extractNumbersWithDashRule(String text) {
    final applied = _applyDashRule(text);
    return _extractAllNumbers(applied);
  }

  /// 대시룰: 숫자 뒤 대시 1개 이상 = × 1000
  String _applyDashRule(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\d+)[-─—]+'),
      (m) => '${int.parse(m.group(1)!) * 1000}',
    );
  }

  bool _isNumber(String text) {
    return RegExp(r'^[\d\s,.\-]+$').hasMatch(text);
  }

  String _detectMimeType(Uint8List bytes, String filename) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
      if (bytes[0] == 0x25 && bytes[1] == 0x50) return 'application/pdf';
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  String _mimeToFormat(String mime) {
    switch (mime) {
      case 'image/png': return 'png';
      case 'application/pdf': return 'pdf';
      default: return 'jpeg';
    }
  }
}

// ─────────────────────────────────────────
// 결과 데이터 클래스
// ─────────────────────────────────────────
class ClovaOcrResult {
  final bool success;
  final String? errorMessage;
  final String storeName;
  final DateTime date;
  final List<ClovaItem> items;
  final double totalAmount;
  final String rawText;
  final double confidence;

  ClovaOcrResult({
    required this.success,
    this.errorMessage,
    required this.storeName,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.rawText,
    required this.confidence,
  });

  factory ClovaOcrResult.error(String message) => ClovaOcrResult(
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

class ClovaItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final String unit;
  final double totalPrice;

  ClovaItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    required this.totalPrice,
  });
}
