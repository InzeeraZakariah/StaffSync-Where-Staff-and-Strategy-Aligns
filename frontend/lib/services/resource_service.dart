import 'package:flutter/foundation.dart';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/api_constants.dart';
import '../models/resource_model.dart';
import 'api_client.dart';

class ResourceService {
  final _client = ApiClient();

  // ═══════════════════════════════════════════════════════════════
  //   STAFF & GROUPS — for the share picker
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    try {
      final response = await _client.dio.get(ApiConstants.staff);
      return (response.data as List)
          .map((s) => {
                'id': s['id'],
                'full_name': s['full_name'] ?? '',
                'department': s['department'] ?? '',
                'avatar_url': s['avatar_url'],
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final response = await _client.dio.get(ApiConstants.groups);
      return (response.data as List)
          .map((g) => {
                'id': g['id'],
                'name': g['name'] ?? '',
                'avatar_url': g['avatar_url'],
                'member_count': g['member_count'] ?? 0,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //   RESOURCES — fetch
  // ═══════════════════════════════════════════════════════════════

  Future<List<ResourceModel>> getResources({
    String? resourceType,
    String? search,
    int page = 1,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.resources,
        queryParameters: {
          if (resourceType != null) 'resource_type': resourceType,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
        },
      );
      return (response.data as List)
          .map((r) => ResourceModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ResourceModel>> getSharedWithMe({
    String? resourceType,
    String? search,
    int page = 1,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.resourcesSharedWithMe,
        queryParameters: {
          if (resourceType != null) 'resource_type': resourceType,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
        },
      );
      return (response.data as List)
          .map((r) => ResourceModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //   RESOURCES — create
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> shareLink({
    required String title,
    required String url,
    String? description,
    String visibility = 'department',
    String? department,
    String? tags,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.resourceLink,
        data: {
          'title': title,
          'resource_type': 'link',
          'link_url': url,
          if (description != null && description.isNotEmpty)
            'description': description,
          'visibility': visibility,
          if (department != null) 'department': department,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      );
      return {
        'success': true,
        'data': ResourceModel.fromJson(response.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _parseError(e, 'Failed to share link.')
      };
    }
  }

  Future<Map<String, dynamic>> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String title,
    required String resourceType,
    String? description,
    String visibility = 'department',
    String? department,
    String? tags,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromBytes(fileBytes, filename: fileName),
        'title': title,
        'resource_type': resourceType,
        if (description != null && description.isNotEmpty)
          'description': description,
        'visibility': visibility,
        if (department != null) 'department': department,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      });

      final response = await _client.dio.post(
        ApiConstants.resourceUpload,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return {
        'success': true,
        'data': ResourceModel.fromJson(response.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _parseError(e, 'Failed to upload file.')
      };
    }
  }

  Future<bool> deleteResource(int id) async {
    try {
      await _client.dio.delete(ApiConstants.resourceById(id));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //   SHARING
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> shareToStaff({
    required int resourceId,
    required List<int> staffIds,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.resourceShareToStaff(resourceId),
        data: {'staff_ids': staffIds},
      );
      return {
        'success': true,
        'data': (response.data as List)
            .map((s) =>
                ResourceShareModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _parseError(e, 'Failed to share.')
      };
    }
  }

  Future<Map<String, dynamic>> shareToGroups({
    required int resourceId,
    required List<int> groupIds,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.resourceShareToGroups(resourceId),
        data: {'group_ids': groupIds},
      );
      return {
        'success': true,
        'data': (response.data as List)
            .map((s) =>
                ResourceShareModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _parseError(e, 'Failed to share.')
      };
    }
  }

  Future<bool> revokeShare(int shareId) async {
    try {
      await _client.dio.delete(ApiConstants.revokeShare(shareId));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //   DOWNLOAD  (web-compatible)
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> downloadAndOpenFile({
    required int resourceId,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      return _downloadForWeb(
          resourceId: resourceId,
          fileName: fileName,
          onProgress: onProgress);
    }
    return _downloadForMobile(
        resourceId: resourceId,
        fileName: fileName,
        onProgress: onProgress);
  }

  // ── Web: fetch bytes → Blob URL → programmatic <a> click ────────────────

  Future<Map<String, dynamic>> _downloadForWeb({
    required int resourceId,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // Fetch with responseType bytes so Dio gives us a Uint8List
      final response = await _client.dio.get<List<int>>(
        ApiConstants.resourceDownload(resourceId),
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onProgress,
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return {'success': false, 'message': 'Empty file received.'};
      }

      // Detect MIME from file extension
      final mime = _mimeFromFileName(fileName);

      // Create a Blob and a temporary object URL
      final blob = html.Blob([Uint8List.fromList(bytes)], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Programmatically click an anchor to trigger browser download
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body!.children.add(anchor);
      anchor.click();

      // Clean up
      Future.delayed(const Duration(seconds: 2), () {
        html.Url.revokeObjectUrl(url);
        anchor.remove();
      });

      return {'success': true};
    } on DioException catch (e) {
      return {'success': false, 'message': _parseError(e, 'Download failed.')};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Mobile: save to temp dir → OpenFilex ────────────────────────────────

  Future<Map<String, dynamic>> _downloadForMobile({
    required int resourceId,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$fileName';

      await _client.dio.download(
        ApiConstants.resourceDownload(resourceId),
        savePath,
        onReceiveProgress: onProgress,
      );

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        return {
          'success': false,
          'filePath': savePath,
          'message': 'Saved but could not open: ${result.message}',
        };
      }
      return {'success': true, 'filePath': savePath};
    } on DioException catch (e) {
      return {'success': false, 'message': _parseError(e, 'Download failed.')};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── MIME helper ─────────────────────────────────────────────────────────

  String _mimeFromFileName(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf':  'application/pdf',
      'png':  'image/png',
      'jpg':  'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif':  'image/gif',
      'webp': 'image/webp',
      'mp4':  'video/mp4',
      'mov':  'video/quicktime',
      'ppt':  'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'doc':  'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls':  'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt':  'text/plain',
      'zip':  'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ═══════════════════════════════════════════════════════════════
  //   NOTES
  // ═══════════════════════════════════════════════════════════════

  Future<List<NoteModel>> getNotes({String? search}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.notes,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'pinned_first': true,
        },
      );
      return (response.data as List)
          .map((n) => NoteModel.fromJson(n as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createNote({
    required String title,
    required String content,
    required String department,
    bool isPinned = false,
    String? tags,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.notes,
        data: {
          'title': title,
          'content': content,
          'department': department,
          'is_pinned': isPinned,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      );
      return {
        'success': true,
        'data': NoteModel.fromJson(response.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _parseError(e, 'Failed to create note.')
      };
    }
  }

  Future<Map<String, dynamic>> updateNote({
    required int id,
    String? title,
    String? content,
    bool? isPinned,
    String? tags,
  }) async {
    try {
      final response = await _client.dio.patch(
        ApiConstants.noteById(id),
        data: {
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          if (isPinned != null) 'is_pinned': isPinned,
          if (tags != null) 'tags': tags,
        },
      );
      return {
        'success': true,
        'data': NoteModel.fromJson(response.data as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _parseError(e, 'Failed to update note.')
      };
    }
  }

  Future<bool> deleteNote(int id) async {
    try {
      await _client.dio.delete(ApiConstants.noteById(id));
      return true;
    } catch (_) {
      return false;
    }
  }

  String _parseError(DioException e, String fallback) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['detail']?.toString() ?? fallback;
      if (data is String) return data;
    } catch (_) {}
    return fallback;
  }
}