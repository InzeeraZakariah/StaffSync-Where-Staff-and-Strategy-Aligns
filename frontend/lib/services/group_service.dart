import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/group_model.dart';
import '../models/staff_model.dart';
import 'api_client.dart';

class GroupService {
  final _client = ApiClient();

  Future<List<GroupModel>> getMyGroups() async {
    try {
      final response = await _client.dio.get(ApiConstants.groups);
      return (response.data as List)
          .map((g) => GroupModel.fromJson(g))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<GroupModel?> getGroupDetail(int groupId) async {
    try {
      final response = await _client.dio.get('${ApiConstants.groups}/$groupId');
      return GroupModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<MessageModel>> getMessages(int groupId, {int page = 1}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.groupMessages(groupId),
        queryParameters: {'page': page, 'page_size': 50},
      );
      final data = response.data['messages'] as List;
      return data.map((m) => MessageModel.fromJson(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
    String? department,
    List<int> memberIds = const [],
  }) async {
    try {
      final response = await _client.dio.post(
        '${ApiConstants.groups}/',
        data: {
          'name': name,
          if (description != null) 'description': description,
          if (department != null) 'department': department,
          'member_ids': memberIds,
        },
      );
      return {'success': true, 'data': GroupModel.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to create group.',
      };
    }
  }

  Future<bool> deleteMessage(int groupId, int messageId) async {
    try {
      await _client.dio.delete(
        '${ApiConstants.groups}/$groupId/messages/$messageId',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Add Members ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addMembers({
    required int groupId,
    required List<int> memberIds,
  }) async {
    try {
      final response = await _client.dio.post(
        '${ApiConstants.groups}/$groupId/members',
        data: {'member_ids': memberIds},
      );
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to add members.',
      };
    }
  }

  // ── Get All Staff ──────────────────────────────────────────────────────────

  Future<List<StaffModel>> getAllStaff() async {
    try {
      final response = await _client.dio.get('/staff/');
      return (response.data as List)
          .map((s) => StaffModel.fromJson(s))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── NEW: Share resource / meeting / reminder / urgent to a group ───────────

  Future<Map<String, dynamic>> shareToGroup({
    required int groupId,
    required String shareType, // "resource" | "meeting" | "reminder" | "urgent"
    required String title,
    String? description,
    String? link, required bool isUrgent,
  }) async {
    try {
      final response = await _client.dio.post(
        '${ApiConstants.groups}/$groupId/share/$shareType',
        data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (link != null && link.isNotEmpty)
            'link': link,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to share to group.',
      };
    }
  }
}