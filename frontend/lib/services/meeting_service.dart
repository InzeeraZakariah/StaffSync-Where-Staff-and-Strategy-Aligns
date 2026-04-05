import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/meeting_model.dart';
import 'api_client.dart';

class MeetingService {
  final _client = ApiClient();

  Future<List<MeetingModel>> getMyMeetings({bool upcomingOnly = false}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.meetings,
        queryParameters: {'upcoming_only': upcomingOnly},
      );
      return (response.data as List)
          .map((m) => MeetingModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<MeetingModel?> getMeetingDetail(int id) async {
    try {
      final response = await _client.dio.get(ApiConstants.meetingById(id));
      return MeetingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createMeeting({
    required String title,
    required String platform,
    required String meetingLink,
    required String scheduledAt,
    int durationMinutes = 60,
    String? description,
    String? passcode,
    List<int> attendeeIds = const [],
    int? sharedToGroupId,
    bool botEnabled = true,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.meetings,
        data: {
          'title': title,
          'platform': platform,
          'meeting_link': meetingLink,
          'scheduled_at': scheduledAt,
          'duration_minutes': durationMinutes,
          if (description != null && description.isNotEmpty) 'description': description,
          if (passcode != null && passcode.isNotEmpty) 'passcode': passcode,
          'attendee_ids': attendeeIds,
          if (sharedToGroupId != null) 'shared_to_group_id': sharedToGroupId,
          'bot_enabled': botEnabled,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to create meeting.',
      };
    }
  }

  // ─── Share to group (with notification on web) ────────────────────────────

  Future<Map<String, dynamic>> shareMeetingToGroup(
    int meetingId,
    int groupId,
  ) async {
    try {
      await _client.dio.post(
        ApiConstants.shareMeeting(meetingId),
        data: {'group_id': groupId},
      );
      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to share meeting.',
      };
    }
  }

  // ─── Share link to specific staff ────────────────────────────────────────

  Future<Map<String, dynamic>> shareMeetingToStaff(
    int meetingId,
    List<int> staffIds,
  ) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.shareMeetingToStaff(meetingId),
        data: {'staff_ids': staffIds},
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to share meeting.',
      };
    }
  }

  // ─── Get all staff (for the share picker) ────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    try {
      final response = await _client.dio.get(ApiConstants.staff);
      return (response.data as List)
          .map((s) => {
                'id': s['id'] as int,
                'full_name': s['full_name'] as String? ?? '',
                'department': s['department'] as String? ?? '',
                'avatar_url': s['avatar_url'] as String?,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Get all groups (for the share picker) ────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final response = await _client.dio.get(ApiConstants.groups);
      return (response.data as List)
          .map((g) => {
                'id': g['id'] as int,
                'name': g['name'] as String? ?? '',
                'member_count': g['member_count'] as int? ?? 0,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> rsvpMeeting(int meetingId, String status) async {
    try {
      await _client.dio.patch(
        ApiConstants.rsvpMeeting(meetingId),
        data: {'status': status},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelMeeting(int id) async {
    try {
      await _client.dio.delete(ApiConstants.meetingById(id));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> createBotProfile({
    required int meetingId,
    required String botName,
    String? botPersona,
    bool autoJoin = true,
    bool notifyAfterSummary = true,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.meetingBotProfile(meetingId),
        data: {
          'bot_name': botName,
          if (botPersona != null) 'bot_persona': botPersona,
          'auto_join': autoJoin,
          'notify_after_summary': notifyAfterSummary,
        },
      );
      return {'success': true, 'data': BotProfile.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to set up bot.',
      };
    }
  }

  Future<Map<String, dynamic>> generateSummary({
    required int meetingId,
    required String transcript,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.meetingSummary(meetingId),
        data: {'transcript': transcript},
      );
      return {'success': true, 'data': MeetingSummary.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to generate summary.',
      };
    }
  }
}