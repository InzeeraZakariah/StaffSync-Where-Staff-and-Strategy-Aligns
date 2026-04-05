import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/staff_model.dart';
import 'api_client.dart';

class AuthService {
  final _client = ApiClient();

  // ─── LOGIN ─────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      await _client.saveTokens(data['access_token'], data['refresh_token']);
      final prefs = await SharedPreferences.getInstance();
      final dept = data['staff']?['department'] ?? data['department'] ?? 'general';
      await prefs.setString('user_department', dept);

      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message':
            e.response?.data?['detail'] ?? 'Login failed. Please try again.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Something went wrong.'};
    }
  }

  // ─── REGISTER ─────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String department,
    required String designation,
    String? phone,
    String? employeeId,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.register,
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'department': department,
          'designation': designation,
          if (phone != null) 'phone': phone,
          if (employeeId != null) 'employee_id': employeeId,
        },
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Registration failed.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Something went wrong.'};
    }
  }

  // ─── GET PROFILE ──────────────────────────────────────
  Future<StaffModel?> getProfile() async {
    try {
      final response = await _client.dio.get(ApiConstants.me);
      return StaffModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  // ─── UPDATE BASIC PROFILE ─────────────────────────────
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      await _client.dio.patch(ApiConstants.updateProfile, data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── UPDATE SETTINGS ──────────────────────────────────
  Future<bool> updateSettings(Map<String, dynamic> data) async {
    try {
      await _client.dio.patch(ApiConstants.updateSettings, data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── 🔥 NEW: UPDATE PROFILE EXTRAS ─────────────────────
  Future<bool> updateExtras(Map<String, dynamic> data) async {
    try {
      await _client.dio.put(
        '${ApiConstants.me}/extras', // IMPORTANT: /profile/extras endpoint
        data: data,
      );
      return true;
    } on DioException catch (e) {
      print('Extras update error: ${e.response?.data}');
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── CHANGE PASSWORD ─────────────────────────────────
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.dio.post(
        ApiConstants.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to change password.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Something went wrong.'};
    }
  }

  // ─── LOGOUT ──────────────────────────────────────────
  Future<void> logout() async {
    await _client.clearTokens();
  }

  // ─── CHECK LOGIN ─────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await _client.getAccessToken();
    return token != null;
  }
}
