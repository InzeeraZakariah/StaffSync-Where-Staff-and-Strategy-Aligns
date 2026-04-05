// lib/services/student_service.dart

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import '../models/student_model.dart';
import 'api_client.dart';

class StudentService {
  final ApiClient _client = ApiClient();

  // ── LISTS ────────────────────────────────────────────────────────────────

  Future<List<StudentListModel>> getLists() async {
    final r = await _client.dio.get('/students/lists');
    _checkDio(r, 200);
    final data = r.data as List;
    return data.map((e) => StudentListModel.fromJson(e)).toList();
  }

  Future<StudentListModel> createList({
    required String name,
    String? description, String? googleFormUrl, String? googleSheetId, required String sheetTabName,
  }) async {
    final r = await _client.dio.post(
      '/students/lists',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    _checkDio(r, 201);
    return StudentListModel.fromJson(r.data);
  }

  Future<StudentListModel> updateList(int listId, {
    String? name,
    String? description,
    bool? isActive,
    String? googleFormUrl,
    String? googleSheetId,
    String? sheetTabName,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (isActive != null) body['is_active'] = isActive;
    if (googleFormUrl != null) body['google_form_url'] = googleFormUrl;
    if (googleSheetId != null) body['google_sheet_id'] = googleSheetId;
    if (sheetTabName != null) body['sheet_tab_name'] = sheetTabName;

    final r = await _client.dio.patch(
      '/students/lists/$listId',
      data: body,
    );
    _checkDio(r, 200);
    return StudentListModel.fromJson(r.data);
  }

  Future<void> deleteList(int listId) async {
    final r = await _client.dio.delete('/students/lists/$listId');
    _checkDio(r, 204);
  }

  // ── STUDENTS ─────────────────────────────────────────────────────────────

  /// Fetch all students with their full profile (flattened).
  /// Named `getEntries` to match StudentEntriesScreen usage.
  /// GET /students/lists/{id}/students → List<StudentResponse> → List<StudentEntryModel>
  Future<List<StudentEntryModel>> getEntries(int listId) async {
    final r = await _client.dio.get('/students/lists/$listId/students');
    _checkDio(r, 200);
    final data = r.data as List;
    return data.map((e) => StudentEntryModel.fromJson(e)).toList();
  }

  Future<StudentEntryModel> addStudent(
    int listId, {
    required String studentName,
    required String registerNumber,
    String? email,
  }) async {
    final r = await _client.dio.post(
      '/students/lists/$listId/students',
      data: {
        'student_name': studentName,
        'register_number': registerNumber,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    _checkDio(r, 201);
    return StudentEntryModel.fromJson(r.data);
  }

  Future<void> removeStudent(int listId, int studentId) async {
    final r = await _client.dio.delete(
      '/students/lists/$listId/students/$studentId',
    );
    _checkDio(r, 204);
  }
    /// Tells backend to read the linked Google Sheet and update student profiles.
  Future<Map<String, dynamic>> syncFromSheet(int listId) async {
    final r = await _client.dio.post('/students/lists/$listId/sync');
    _checkDio(r, 200);
    return jsonDecode(r.data) as Map<String, dynamic>;
  }
  // ── SUMMARY ──────────────────────────────────────────────────────────────

  Future<StudentSummaryModel> getSummary(int listId) async {
    final r = await _client.dio.get('/students/lists/$listId/summary');
    _checkDio(r, 200);
    return StudentSummaryModel.fromJson(r.data);
  }

  // ── PUBLIC FORM (NO AUTH) ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFormInfo(String token) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/students/form/$token');
    final r = await http.get(uri);

    if (r.statusCode == 404) {
      throw Exception('This form link is no longer active.');
    }
    if (r.statusCode != 200) {
      throw Exception('Could not load form.');
    }

    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Student identifies by register_number (from roster dropdown).
  /// No studentName param — the name is already stored in the DB.
  Future<void> submitForm({
    required String token,
    required String registerNumber,
    double? overallCgpa,
    required List<Map<String, dynamic>> semesters,
    required List<Map<String, dynamic>> patents,
    required List<Map<String, dynamic>> journals,
    required List<Map<String, dynamic>> conferences,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/students/form/$token');

    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'register_number': registerNumber,
        if (overallCgpa != null) 'overall_cgpa': overallCgpa,
        'semesters': semesters,
        'patents': patents,
        'journals': journals,
        'conferences': conferences,
      }),
    );

    if (r.statusCode == 404) {
      throw Exception(jsonDecode(r.body)['detail'] ?? 'Not found');
    }
    if (r.statusCode != 201) {
      throw Exception('Submission failed.');
    }
  }


  // ── LINK HELPERS ─────────────────────────────────────────────────────────

  String buildFormUrl(String token) => 'staffsync://form/$token';

  String buildShareMessage(String listName, String token) =>
      'Hi! Please fill in your academic details for "$listName".\n\n'
      'Tap the link below to open the StaffSync app:\n'
      '${buildFormUrl(token)}\n\n'
      '(You must have the StaffSync app installed)';

  // ── INTERNAL ─────────────────────────────────────────────────────────────

  void _checkDio(Response r, int expected) {
    if (r.statusCode != expected) {
      String detail = 'Error ${r.statusCode}';
      try {
        final d = r.data;
        if (d is Map && d.containsKey('detail')) {
          detail = d['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
  }
}