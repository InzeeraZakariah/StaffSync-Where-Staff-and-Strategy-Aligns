import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/reminder_model.dart';
import 'api_client.dart';

class ReminderService {
  final _client = ApiClient();

  Future<List<ReminderModel>> getMyReminders({bool unreadOnly = false}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.reminders,
        queryParameters: {'unread_only': unreadOnly},
      );
      return (response.data as List)
          .map((r) => ReminderModel.fromJson(r))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createReminder({
    required String title,
    required String remindAt,
    String? message,
    int? meetingId, required String reminderType,
  }) async {
    try {
      final response = await _client.dio.post(
        '${ApiConstants.reminders}/',
        data: {
          'title': title,
          'remind_at': remindAt,
          if (message != null) 'body': message,
          if (meetingId != null) 'meeting_id': meetingId,
        },
      );
      return {'success': true, 'data': ReminderModel.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to create reminder.',
      };
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      await _client.dio.patch(ApiConstants.markReminderRead(id));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteReminder(int id) async {
    try {
      await _client.dio.delete('${ApiConstants.reminders}/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> sendUrgentNotify(String message, {String? title}) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.urgentNotify,
        data: {
          'title': title ?? 'Urgent Alert',
          'message': message,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to send urgent notification.',
      };
    }
  }

  Future<bool> shareReminderToGroup(int reminderId, int groupId) async {
    try {
      await _client.dio.post(
        ApiConstants.shareReminderToGroup(reminderId),
        queryParameters: {'group_id': groupId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}