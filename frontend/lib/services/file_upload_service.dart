import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// FileUploadService
/// Handles uploading images and files to your backend server.
/// The server then stores them (e.g., in local storage, AWS S3, or Firebase Storage)
/// and returns a public URL.
///
/// Replace _baseUrl with your actual backend URL.

class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  factory FileUploadService() => _instance;
  FileUploadService._internal();

  // ─── Config ────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://your-backend.com/api'; // 🔁 Replace with your API URL
  static const int _timeoutSeconds = 60;

  // ─── Auth Token ─────────────────────────────────────────────────────
  // Replace this with your actual token retrieval logic
  // e.g., from SharedPreferences or a Provider/Riverpod auth state
  String get _authToken => 'YOUR_AUTH_TOKEN'; // 🔁 Replace with real token

  // ─── Upload Image ────────────────────────────────────────────────────

  /// Uploads an image file to the server.
  /// [file]    - The image File from image_picker
  /// [groupId] - The group this image belongs to
  /// Returns the public URL of the uploaded image, or null on failure.
  Future<String?> uploadImage(File file, int groupId) async {
    try {
      final uri = Uri.parse('$_baseUrl/groups/$groupId/upload/image');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_authToken'
        ..fields['group_id'] = groupId.toString()
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          // Detect content type from extension
        ));

      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: _timeoutSeconds));

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Expected response: { "url": "https://..." }
        return data['url'] as String?;
      } else {
        print('Image upload failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  // ─── Upload File ─────────────────────────────────────────────────────

  /// Uploads any file (PDF, DOC, XLS, etc.) to the server.
  /// [file]     - The File from file_picker
  /// [fileName] - Original file name (e.g., "report.pdf")
  /// [groupId]  - The group this file belongs to
  /// Returns the public URL of the uploaded file, or null on failure.
  Future<String?> uploadFile(File file, String fileName, int groupId) async {
    try {
      final uri = Uri.parse('$_baseUrl/groups/$groupId/upload/file');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_authToken'
        ..fields['group_id'] = groupId.toString()
        ..fields['file_name'] = fileName
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
        ));

      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: _timeoutSeconds));

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Expected response: { "url": "https://...", "file_name": "report.pdf", "size": 12345 }
        return data['url'] as String?;
      } else {
        print('File upload failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('File upload error: $e');
      return null;
    }
  }

  // ─── Upload Profile Avatar ────────────────────────────────────────────

  /// Uploads a staff profile picture.
  /// Returns the public URL or null.
  Future<String?> uploadAvatar(File file, int staffId) async {
    try {
      final uri = Uri.parse('$_baseUrl/staff/$staffId/avatar');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_authToken'
        ..files.add(await http.MultipartFile.fromPath(
          'avatar',
          file.path,
        ));

      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: _timeoutSeconds));

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      } else {
        print('Avatar upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Avatar upload error: $e');
      return null;
    }
  }

  // ─── Delete File ──────────────────────────────────────────────────────

  /// Deletes an uploaded file from the server by its URL or file ID.
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload/delete');
      final response = await http
          .delete(
            uri,
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'url': fileUrl}),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('File delete error: $e');
      return false;
    }
  }

  // ─── Get File Size Label ──────────────────────────────────────────────

  /// Returns a human-readable file size string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)}MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)}GB';
  }

  // ─── Validate File Before Upload ─────────────────────────────────────

  /// Returns an error message if the file is invalid, or null if OK.
  static String? validateFile(File file, {bool isImage = false}) {
    final sizeInMB = file.lengthSync() / 1048576;

    if (isImage) {
      if (sizeInMB > 10) return 'Image must be under 10MB';
      final ext = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        return 'Only JPG, PNG, GIF, WEBP images allowed';
      }
    } else {
      if (sizeInMB > 50) return 'File must be under 50MB';
      final ext = file.path.split('.').last.toLowerCase();
      if (!['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip']
          .contains(ext)) {
        return 'File type not supported';
      }
    }

    return null; // Valid
  }
}