import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/availability_model.dart';
import 'api_client.dart';

class AvailabilityService {
  final _client = ApiClient();

  Future<List<AvailabilityModel>> getMyAvailability({
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.myAvailability,
        queryParameters: {
          if (fromDate != null) 'from_date': fromDate,
          if (toDate != null) 'to_date': toDate,
        },
      );
      return (response.data as List)
          .map((a) => AvailabilityModel.fromJson(a))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> setAvailability({
    required String type,
    required String status,
    String? date,
    String? startTime,
    String? endTime,
    String? startDate,
    String? endDate,
    String? reason,
    bool isRecurring = false,
  }) async {
    try {
      final data = <String, dynamic>{
        'availability_type': type,
        'status': status,
        'is_recurring': isRecurring,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      };

      if (type == 'time_slot') {
        data['date'] = date;
        data['start_time'] = startTime;
        data['end_time'] = endTime;
      } else if (type == 'full_day') {
        data['date'] = date;
      } else if (type == 'multi_day') {
        data['start_date'] = startDate;
        data['end_date'] = endDate;
      }

      final response = await _client.dio.post(
        '${ApiConstants.availability}/',
        data: data,
      );
      return {'success': true, 'data': AvailabilityModel.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to set availability.',
      };
    }
  }

  Future<bool> deleteAvailability(int id) async {
    try {
      await _client.dio.delete('${ApiConstants.availability}/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> checkAvailability({
    required int staffId,
    required String checkDate,
    String? checkTime,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.checkAvailability,
        data: {
          'staff_id': staffId,
          'check_date': checkDate,
          if (checkTime != null) 'check_time': checkTime,
        },
      );
      return {'success': true, 'data': response.data};
    } catch (_) {
      return {'success': false};
    }
  }
}