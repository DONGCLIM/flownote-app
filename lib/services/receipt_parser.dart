import '../models/receipt_model.dart';
import 'ocr_service.dart';

/// OCR 인식 텍스트에서 꽃 구매 정보를 파싱하는 엔진
class ReceiptParser {
  // ────────────────────────────────────────────────
  // 꽃 이름 사전 (한국어 + 영어 + 변형 표기 포함)
  // ────────────────────────────────────────────────
  static const Map<String, String> _flowerDict = {
    // 장미류
    '장미': '장미', '로즈': '장미', 'rose': '장미', 'roses': '장미',
    '빨간장미': '장미(레드)', '붉은장미': '장미(레드)',
    '핑크장미': '장미(핑크)', '흰장미': '장미(화이트)', '황장미': '장미(옐로우)',
    // 튤립
    '튤립': '튤립', 'tulip': '튤립', 'tulips': '튤립',
    // 국화
    '국화': '국화', '소국': '소국', '대국': '대국',
    'chrysanthemum': '국화', '스프레이국화': '스프레이국화',
    // 수국
    '수국': '수국', 'hydrangea': '수국',
    // 라넌큘러스
    '라넌큘러스': '라넌큘러스', '라난큘러스': '라넌큘러스', 'ranunculus': '라넌큘러스',
    // 작약
    '작약': '작약', '모란': '작약', 'peony': '작약', 'peonies': '작약',
    // 해바라기
    '해바라기': '해바라기', 'sunflower': '해바라기', 'sunflowers': '해바라기',
    // 거베라
    '거베라': '거베라', 'gerbera': '거베라',
    // 카네이션
    '카네이션': '카네이션', 'carnation': '카네이션', 'carnations': '카네이션',
    // 프리지아
    '프리지아': '프리지아', 'freesia': '프리지아',
    // 라일락
    '라일락': '라일락', 'lilac': '라일락',
    // 안개꽃
    '안개꽃': '안개꽃', '안개': '안개꽃', 'babysbreath': '안개꽃', "baby's breath": '안개꽃',
    // 리시안셔스 (유스토마)
    '리시안셔스': '리시안셔스', '유스토마': '리시안셔스', 'lisianthus': '리시안셔스',
    // 스타티스
    '스타티스': '스타티스', 'statice': '스타티스',
    // 아이리스
    '아이리스': '아이리스', 'iris': '아이리스',
    // 백합
    '백합': '백합', '릴리': '백합', 'lily': '백합', 'lilies': '백합',
    // 데이지
    '데이지': '데이지', 'daisy': '데이지', 'daisies': '데이지',
    // 물망초
    '물망초': '물망초', 'forgetmenot': '물망초',
    // 천일홍
    '천일홍': '천일홍', 'globe amaranth': '천일홍',
    // 팬지
    '팬지': '팬지', 'pansy': '팬지',
    // 봄맞이
    '봄맞이': '봄맞이',
    // 아네모네
    '아네모네': '아네모네', 'anemone': '아네모네',
    // 히아신스
    '히아신스': '히아신스', 'hyacinth': '히아신스',
    // 포인세티아
    '포인세티아': '포인세티아', 'poinsettia': '포인세티아',
    // 칼라
    '칼라': '칼라', 'calla': '칼라', 'calla lily': '칼라',
    // 글라디올러스
    '글라디올러스': '글라디올러스', 'gladiolus': '글라디올러스',
    // 기타
    '혼합꽃': '혼합꽃', '믹스': '혼합꽃', 'mix': '혼합꽃',
    '조화': '조화', '생화': '생화',
  };

  // 수량 단위 패턴
  static const List<String> _units = [
    '송이', '줄기', '다발', '묶음', '개', '본', '포기', '화분',
    'stems', 'bunches', 'bunch', 'pcs', 'pc',
  ];

  // 상점명 힌트 키워드
  static const List<String> _storeKeywords = [
    '꽃집', '플라워', '화원', '꽃방', '꽃가게', '플로리스트',
    'flower', 'florist', 'floral', 'bloom', '꽃',
  ];

  // 합계/금액 관련 키워드
  static const List<String> _totalKeywords = [
    '합계', '총합계', '총금액', '결제금액', '청구금액', '총액',
    '받을금액', '지불금액', '실결제', '합산',
    'total', 'subtotal', 'amount', 'sum',
  ];

  static const List<String> _discountKeywords = [
    '할인', '쿠폰', '포인트', '적립', 'discount', 'coupon',
  ];

  // ────────────────────────────────────────────────
  // 메인 파싱 함수
  // ────────────────────────────────────────────────
  static ParsedReceipt parse(OcrResult ocr) {
    final lines = _splitLines(ocr.rawText);

    final storeName = _extractStoreName(lines);
    final date = _extractDate(lines);
    final items = _extractFlowerItems(lines);
    final total = _extractTotal(lines, items);

    return ParsedReceipt(
      storeName: storeName,
      date: date ?? DateTime.now(),
      items: items,
      totalAmount: total,
      rawText: ocr.rawText,
      confidence: _calcConfidence(items, total, storeName),
    );
  }

  // ────────────────────────────────────────────────
  // 텍스트 전처리
  // ────────────────────────────────────────────────
  static List<String> _splitLines(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  // ────────────────────────────────────────────────
  // 상점명 추출
  // ────────────────────────────────────────────────
  static String _extractStoreName(List<String> lines) {
    // 1) 첫 1~3줄 중 스토어 키워드가 포함된 줄 우선
    for (var i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      for (final kw in _storeKeywords) {
        if (line.toLowerCase().contains(kw.toLowerCase())) {
          return _cleanText(line);
        }
      }
    }
    // 2) 첫 줄이 숫자/날짜가 아니면 상점명으로 간주
    if (lines.isNotEmpty) {
      final first = lines[0];
      if (!RegExp(r'^\d').hasMatch(first) && first.length > 2) {
        return _cleanText(first);
      }
    }
    return '꽃집';
  }

  // ────────────────────────────────────────────────
  // 날짜 추출
  // ────────────────────────────────────────────────
  static DateTime? _extractDate(List<String> lines) {
    // 패턴 예: 2024-03-15 / 2024.03.15 / 24/03/15 / 2024년3월15일
    final patterns = [
      RegExp(r'(\d{4})[-./년](\d{1,2})[-./월](\d{1,2})'),
      RegExp(r'(\d{2})[-./](\d{1,2})[-./](\d{1,2})'),
    ];

    for (final line in lines) {
      for (final pattern in patterns) {
        final m = pattern.firstMatch(line);
        if (m != null) {
          try {
            int year = int.parse(m.group(1)!);
            final month = int.parse(m.group(2)!);
            final day = int.parse(m.group(3)!);
            if (year < 100) year += 2000;
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              return DateTime(year, month, day);
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // 꽃 품목 추출 (핵심 로직)
  // ────────────────────────────────────────────────
  static List<FlowerItem> _extractFlowerItems(List<String> lines) {
    final items = <FlowerItem>[];
    final usedLines = <int>{};

    for (var i = 0; i < lines.length; i++) {
      if (usedLines.contains(i)) continue;

      final line = lines[i].toLowerCase();

      // 꽃 이름 매칭
      String? matchedFlower;
      for (final entry in _flowerDict.entries) {
        if (line.contains(entry.key.toLowerCase())) {
          matchedFlower = entry.value;
          break;
        }
      }
      if (matchedFlower == null) continue;

      // 현재 줄 + 인접 줄에서 수량/가격 탐색
      final searchText = _getSearchWindow(lines, i);

      final quantity = _extractQuantity(searchText);
      final unitPrice = _extractPrice(searchText, isUnitPrice: true);
      final totalPrice = _extractPrice(searchText, isUnitPrice: false);

      // 단가/총가 추론
      double finalUnitPrice = 0;
      int finalQty = quantity ?? 1;

      if (unitPrice != null && totalPrice != null && unitPrice != totalPrice) {
        finalUnitPrice = unitPrice;
        // 수량 검증
        if (finalQty > 1 && (finalQty * unitPrice - totalPrice).abs() < 1) {
          // 일치 확인
        } else if (totalPrice > 0 && unitPrice > 0) {
          finalQty = (totalPrice / unitPrice).round();
          if (finalQty <= 0) finalQty = 1;
        }
      } else if (totalPrice != null) {
        finalUnitPrice = (finalQty > 0) ? totalPrice / finalQty : totalPrice;
        finalUnitPrice = (finalUnitPrice / 10).round() * 10; // 10원 단위 반올림
      } else if (unitPrice != null) {
        finalUnitPrice = unitPrice;
      } else {
        // 가격 정보 없으면 건너뜀
        continue;
      }

      final unit = _extractUnit(searchText);

      // 합계/할인 줄은 품목으로 추가하지 않음
      bool isTotal = false;
      for (final kw in _totalKeywords) {
        if (lines[i].contains(kw)) {
          isTotal = true;
          break;
        }
      }
      if (isTotal) continue;

      items.add(FlowerItem(
        name: matchedFlower,
        quantity: finalQty,
        unitPrice: finalUnitPrice,
        unit: unit,
      ));
      usedLines.add(i);
    }

    return items;
  }

  /// 현재 줄 ±2 범위의 텍스트를 합쳐서 검색 창 생성
  static String _getSearchWindow(List<String> lines, int index) {
    final start = (index - 1).clamp(0, lines.length - 1);
    final end = (index + 2).clamp(0, lines.length);
    return lines.sublist(start, end).join(' ');
  }

  // ────────────────────────────────────────────────
  // 수량 추출
  // ────────────────────────────────────────────────
  static int? _extractQuantity(String text) {
    // 패턴: "5송이", "10개", "x3", "×5", "3ea"
    final patterns = [
      RegExp(r'(\d+)\s*(?:송이|줄기|다발|묶음|개|본|포기|ea|pcs|stems?)'),
      RegExp(r'[x×*]\s*(\d+)'),
      RegExp(r'수량[:\s]*(\d+)'),
      RegExp(r'qty[:\s]*(\d+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final v = int.tryParse(m.group(1)!);
        if (v != null && v > 0 && v < 9999) return v;
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // 가격 추출
  // ────────────────────────────────────────────────
  static double? _extractPrice(String text, {required bool isUnitPrice}) {
    // 금액 패턴: ₩3,000 / 3000원 / 3,000 / W3000
    final priceRegex = RegExp(
      r'[₩W\\]?\s*(\d{1,3}(?:[,\s]\d{3})*|\d+)\s*원?',
      caseSensitive: false,
    );

    final allMatches = priceRegex
        .allMatches(text)
        .map((m) {
          final raw = m.group(1)!.replaceAll(RegExp(r'[,\s]'), '');
          return double.tryParse(raw);
        })
        .where((v) => v != null && v >= 100 && v < 10000000)
        .cast<double>()
        .toList();

    if (allMatches.isEmpty) return null;

    if (isUnitPrice) {
      // 단가: 보통 더 작은 값
      allMatches.sort();
      return allMatches.first;
    } else {
      // 총가: 보통 더 큰 값
      allMatches.sort((a, b) => b.compareTo(a));
      return allMatches.first;
    }
  }

  // ────────────────────────────────────────────────
  // 단위 추출
  // ────────────────────────────────────────────────
  static String _extractUnit(String text) {
    for (final unit in _units) {
      if (text.contains(unit)) return unit;
    }
    return '단(묶음)';
  }

  // ────────────────────────────────────────────────
  // 합계 금액 추출
  // ────────────────────────────────────────────────
  static double _extractTotal(List<String> lines, List<FlowerItem> items) {
    double? explicitTotal;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      bool isTotal = false;
      for (final kw in _totalKeywords) {
        if (line.contains(kw)) {
          isTotal = true;
          break;
        }
      }
      if (!isTotal) continue;

      // 같은 줄 또는 다음 줄에서 금액 추출
      final searchText = '$line ${i + 1 < lines.length ? lines[i + 1] : ''}';
      final total = _extractPrice(searchText, isUnitPrice: false);
      if (total != null && total > 0) {
        // 할인 관련 키워드가 없는 줄의 가장 큰 값 사용
        bool isDiscount = false;
        for (final kw in _discountKeywords) {
          if (line.contains(kw)) {
            isDiscount = true;
            break;
          }
        }
        if (!isDiscount) {
          explicitTotal = total;
          break;
        }
      }
    }

    if (explicitTotal != null && explicitTotal > 0) return explicitTotal;

    // 명시적 합계 없으면 품목 합산
    final itemTotal = items.fold(0.0, (s, i) => s + i.totalPrice);
    return itemTotal;
  }

  // ────────────────────────────────────────────────
  // 신뢰도 계산 (0.0 ~ 1.0)
  // ────────────────────────────────────────────────
  static double _calcConfidence(
    List<FlowerItem> items,
    double total,
    String storeName,
  ) {
    double score = 0.0;
    if (items.isNotEmpty) score += 0.5;
    if (items.length >= 2) score += 0.2;
    if (total > 0) score += 0.2;
    if (storeName != '꽃집') score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\sㄱ-힣]'), '')
        .trim();
  }
}

// ────────────────────────────────────────────────
// 파싱 결과 데이터 클래스
// ────────────────────────────────────────────────
class ParsedReceipt {
  final String storeName;
  final DateTime date;
  final List<FlowerItem> items;
  final double totalAmount;
  final String rawText;
  final double confidence; // 0.0 ~ 1.0

  ParsedReceipt({
    required this.storeName,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.rawText,
    required this.confidence,
  });

  bool get hasFlowerItems => items.isNotEmpty;
  bool get isHighConfidence => confidence >= 0.6;
}
