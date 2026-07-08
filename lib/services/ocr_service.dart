/// OCR 서비스 - Gemini Vision API로 대체됨
/// 이 파일은 하위 호환성을 위해 유지됩니다.
/// 실제 OCR은 gemini_ocr_service.dart를 사용합니다.
class OcrService {
  /// Gemini OCR로 대체됨 - gemini_ocr_service.dart 사용
  Future<OcrResult> recognizeFromPath(String imagePath) async {
    return OcrResult(
      rawText: '',
      blocks: [],
      success: false,
      errorMessage: 'Gemini OCR를 사용해주세요.',
    );
  }

  void dispose() {}
}

class OcrResult {
  final String rawText;
  final List<OcrBlock> blocks;
  final bool success;
  final String? errorMessage;

  OcrResult({
    required this.rawText,
    required this.blocks,
    required this.success,
    this.errorMessage,
  });
}

class OcrBlock {
  final String text;
  final List<String> lines;

  OcrBlock({required this.text, required this.lines});
}
