import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Uploads a Mobile Money screenshot so the secretary can look at it
/// directly and decide, instead of relying on OCR text extraction --
/// which turned out too unreliable on real compressed screenshots (small
/// fonts, mixed English/French, inconsistent receipt layouts across MTN/
/// Orange Money). This is a deliberate, honest simplification: the amount
/// is still typed by the member, but the secretary can now actually see
/// the proof before approving, which is what verification means anyway.
///
/// Uses ImgBB's free image-hosting API (https://api.imgbb.com) since
/// Firebase Storage needs the paid Blaze plan. Get a free key at
/// https://api.imgbb.com/ (no card) and paste it in [apiKey] below.
class ScreenshotService {
  static const apiKey = '89cb2b92d34607eb407fd8fe0e9995a3'; // <- replace this
  static const _endpoint = 'https://api.imgbb.com/1/upload';

  final _picker = ImagePicker();

  Future<File?> pickScreenshot() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Uploads the image and returns a real, publicly viewable URL. Throws
  /// a clear error (never a fake URL) if the key isn't set or the upload
  /// fails.
  Future<String> uploadScreenshot(File file) async {
    if (apiKey == 'YOUR_IMGBB_API_KEY') {
      throw Exception(
        'No image host API key set yet. Get a free one at api.imgbb.com and '
        'paste it into lib/services/screenshot_service.dart (replace YOUR_IMGBB_API_KEY).',
      );
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('$_endpoint?key=$apiKey'),
      body: {'image': base64Image},
    );

    if (response.statusCode != 200) {
      throw Exception('Upload failed (${response.statusCode}). Check your internet connection.');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error']?['message']?.toString() ?? 'Upload failed. Check your API key.');
    }

    return data['data']['url'] as String;
  }
}