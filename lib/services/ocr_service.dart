import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Real image pick + real OCR call -- no Firebase Storage or Cloud
/// Functions, so this works entirely on the free Spark plan (no card
/// needed). Uses OCR.space's free API (https://ocr.space/ocrapi) called
/// directly from the client.
///
/// IMPORTANT: get your own free API key at https://ocr.space/ocrapi
/// (instant, no card) and put it in [apiKey] below.
///
/// Tradeoff of this approach: the API key ships inside the app, which is
/// fine for a student/demo project but not for production -- a real
/// production app should proxy this call through a backend so the key
/// isn't exposed. Worth mentioning if asked about it during your
/// presentation.
class OcrService {
  static const apiKey = 'K83292103888957'; // <- replace this
  static const _endpoint = 'https://api.ocr.space/parse/image';

  final _picker = ImagePicker();

  Future<File?> pickScreenshot() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Sends the image to OCR.space, gets back raw text, then extracts
  /// amount/date/sender/receiver/reference with pattern matching tuned
  /// for MTN/Orange Money receipt formats. This is real extraction, not
  /// fabricated data -- if OCR.space can't read the image, the fields
  /// come back null and the UI should tell the user to try again /
  /// enter the amount manually, never fake a value.
  ///
  /// MoMo receipts in Cameroon can be in English OR French, so this tries
  /// English first, and if nothing useful comes back (no amount found),
  /// retries the same image with French OCR before giving up. Costs one
  /// extra API call in the French-receipt case, but that's cheap and free
  /// tier covers it.
  Future<Map<String, dynamic>> extractReceiptData(File imageFile) async {
    if (apiKey == 'YOUR_OCRSPACE_API_KEY') {
      throw Exception(
        'No OCR API key set yet. Get a free one at ocr.space/ocrapi and '
        'paste it into lib/services/ocr_service.dart (replace YOUR_OCRSPACE_API_KEY).',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    var result = await _callOcr(base64Image, 'eng');
    if (result['amount'] == null) {
      final frenchResult = await _callOcr(base64Image, 'fre');
      if (frenchResult['amount'] != null || (frenchResult['rawText'] as String).length > (result['rawText'] as String).length) {
        result = frenchResult;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> _callOcr(String base64Image, String language) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'apikey': apiKey},
      body: {
        'base64Image': base64Image,
        'language': language,
        'isOverlayRequired': 'false',
        'OCREngine': '2',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('OCR request failed (${response.statusCode}). Check your internet connection.');
    }

    final data = jsonDecode(response.body);
    if (data['IsErroredOnProcessing'] == true) {
      final rawError = data['ErrorMessage'];
      final message = rawError is List ? rawError.join('; ') : rawError?.toString();
      throw Exception(message ?? 'OCR could not read this image. Check that your API key is correct.');
    }

    final results = data['ParsedResults'] as List?;
    final rawText = (results != null && results.isNotEmpty)
        ? (results[0]['ParsedText'] as String? ?? '')
        : '';

    if (rawText.trim().isEmpty) {
      throw Exception('No text detected in the screenshot. Try a clearer, uncropped photo.');
    }

    final lower = rawText.toLowerCase();

    return {
      'rawText': rawText,
      'amount': _extractAmount(rawText),
      'date': _extractDate(rawText),
      'reference': _extractReference(rawText),
      'sender': _extractSender(rawText),
      'status': (lower.contains('successful') ||
              lower.contains('success') ||
              lower.contains('rÃ©ussi') ||
              lower.contains('effectuÃ©'))
          ? 'success'
          : null,
    };
  }

  // Best-effort pattern matching against common MTN/Orange Money receipt
  // wording, in both English and French. These won't be perfect for every
  // screenshot layout -- that's expected with a free OCR API rather than a
  // purpose-built receipt parser, and it's why the amount field stays
  // editable before submit.

  String? _extractAmount(String text) {
    final match = RegExp(
      r'(?:amount|montant|xaf|fcfa)[:\s]*([\d,\.\s]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text.replaceAll('\n', ' '));
    return match?.group(1)?.replaceAll(RegExp(r'[,\s]'), '');
  }

  String? _extractDate(String text) {
    final match = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})').firstMatch(text);
    return match?.group(1);
  }

  String? _extractReference(String text) {
    final match = RegExp(
      r'(?:ref|reference|rÃ©fÃ©rence|transaction\s*id|trans\s*id|id\s*transaction)[:\s]*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  String? _extractSender(String text) {
    final match = RegExp(
      r'(?:from|sender|de|expÃ©diteur|envoyÃ©\s*par)[:\s]*([A-Za-zÃ€-Ã¿\s]{3,30})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }
}


