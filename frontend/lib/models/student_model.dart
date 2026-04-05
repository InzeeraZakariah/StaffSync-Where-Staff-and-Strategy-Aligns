// lib/models/student_model.dart
import 'package:intl/intl.dart';

// ─── STUDENT LIST ─────────────────────────────────────────────────────────────
// Maps to backend: StudentListResponse

class StudentListModel {
  final int id;
  final String name;
  final String? description;
  final String token;
  final bool isActive;
  final String createdAt;
  final int totalStudents;
  final int alertCount;
  final String? googleFormUrl;
  final String? googleSheetId;
  final String? sheetTabName;

  const StudentListModel({
    required this.id,
    required this.name,
    this.description,
    required this.token,
    required this.isActive,
    required this.createdAt,
    required this.totalStudents,
    required this.alertCount,
    this.googleFormUrl,
    this.googleSheetId,
    this.sheetTabName,
  });

  factory StudentListModel.fromJson(Map<String, dynamic> json) {
    return StudentListModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      token: json['token'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      totalStudents: json['total_students'] ?? 0,
      alertCount: json['alert_count'] ?? 0,
      googleFormUrl: json['google_form_url'],
      googleSheetId: json['google_sheet_id'],
      sheetTabName: json['sheet_tab_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'token': token,
    'is_active': isActive,
    'created_at': createdAt,
    'total_students': totalStudents,
    'alert_count': alertCount,
  };

  bool get hasAlerts => alertCount > 0;
  bool get hasFormUrl => googleFormUrl != null && googleFormUrl!.isNotEmpty;
  bool get hasSheetId => googleFormUrl != null && googleSheetId!.isNotEmpty;
  bool get canSync => hasSheetId;

  String get formattedDate {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt));
    } catch (_) {
      return '';
    }
  }
}

// ─── PATENT ───────────────────────────────────────────────────────────────────
// Maps to backend: PatentItem

class StudentPatentModel {
  final int id;
  final String title;
  final String? applicationNumber;

  const StudentPatentModel({
    required this.id,
    required this.title,
    this.applicationNumber,
  });

  factory StudentPatentModel.fromJson(Map<String, dynamic> json) {
    return StudentPatentModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      applicationNumber: json['application_number'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'application_number': applicationNumber,
  };
}

// ─── PAPER ────────────────────────────────────────────────────────────────────
// Maps to backend: PaperItem (which is built from StudentJournal rows).
// journal_name  → journalName
// publish_date  → publishDate

class StudentPaperModel {
  final int id;
  final String title;
  final String? journalName;
  final String? publishDate;

  const StudentPaperModel({
    required this.id,
    required this.title,
    this.journalName,
    this.publishDate,
  });

  factory StudentPaperModel.fromJson(Map<String, dynamic> json) {
    return StudentPaperModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      journalName: json['journal_name'],
      publishDate: json['publish_date'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'journal_name': journalName,
    'publish_date': publishDate,
  };

  String get formattedDate {
    if (publishDate == null) return '';
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(publishDate!));
    } catch (_) {
      return publishDate!;
    }
  }
}

// ─── STUDENT ENTRY ────────────────────────────────────────────────────────────
// Maps to backend: StudentResponse (flattened Student + StudentProfile).
//
// semester_gpa          → semesterGpa   (highest GPA across all semesters)
// overall_cgpa          → overallCgpa
// missed_updates_this_month → missedUpdatesThisMonth
// submission_count      → submissionCount
// last_updated_at       → lastUpdatedAt
// patents               → patents  (PatentItem[])
// papers                → papers   (PaperItem[] built from journals)

class StudentEntryModel {
  final int id;
  final int listId;
  final String studentName;
  final String? registerNumber;
  final String? email;
  final double? semesterGpa;
  final double? overallCgpa;
  final int missedUpdatesThisMonth;
  final int submissionCount;
  final String? lastUpdatedAt;
  final String createdAt;
  final List<StudentPatentModel> patents;
  final List<StudentPaperModel> papers;

  const StudentEntryModel({
    required this.id,
    required this.listId,
    required this.studentName,
    this.registerNumber,
    this.email,
    this.semesterGpa,
    this.overallCgpa,
    required this.missedUpdatesThisMonth,
    required this.submissionCount,
    this.lastUpdatedAt,
    required this.createdAt,
    this.patents = const [],
    this.papers = const [],
  });

  factory StudentEntryModel.fromJson(Map<String, dynamic> json) {
    return StudentEntryModel(
      id: json['id'] ?? 0,
      listId: json['list_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      registerNumber: json['register_number'],
      email: json['email'],
      semesterGpa: (json['semester_gpa'] as num?)?.toDouble(),
      overallCgpa: (json['overall_cgpa'] as num?)?.toDouble(),
      missedUpdatesThisMonth: json['missed_updates_this_month'] ?? 0,
      submissionCount: json['submission_count'] ?? 0,
      lastUpdatedAt: json['last_updated_at'],
      createdAt: json['created_at'] ?? '',
      patents:
          (json['patents'] as List?)
              ?.map((e) => StudentPatentModel.fromJson(e))
              .toList() ??
          [],
      papers:
          (json['papers'] as List?)
              ?.map((e) => StudentPaperModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  bool get isAlert => missedUpdatesThisMonth >= 3;

  String get cgpaDisplay =>
      overallCgpa != null ? overallCgpa!.toStringAsFixed(2) : '—';

  String get sgpaDisplay =>
      semesterGpa != null ? semesterGpa!.toStringAsFixed(2) : '—';
}

// ─── SUMMARY ──────────────────────────────────────────────────────────────────
// Maps to backend: RankedStudent
//
// student_id       → id
// student_name     → studentName
// register_number  → registerNumber
// highest_sem_gpa  → semesterGpa
// overall_cgpa     → overallCgpa
// patent_count     → patentCount
// journal_count    → paperCount   (conferences tracked separately server-side)
// activity_score   → achievementScore

class TopStudentModel {
  final int id;
  final String studentName;
  final String? registerNumber;
  final double? semesterGpa;
  final double? overallCgpa;
  final int patentCount;
  final int paperCount;
  final double achievementScore;

  const TopStudentModel({
    required this.id,
    required this.studentName,
    this.registerNumber,
    this.semesterGpa,
    this.overallCgpa,
    required this.patentCount,
    required this.paperCount,
    required this.achievementScore,
  });

  factory TopStudentModel.fromJson(Map<String, dynamic> json) {
    return TopStudentModel(
      // Backend sends `student_id` — map it to `id`
      id: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      registerNumber: json['register_number'],
      // Backend sends `highest_sem_gpa` — map it to semesterGpa
      semesterGpa: (json['highest_sem_gpa'] as num?)?.toDouble(),
      overallCgpa: (json['overall_cgpa'] as num?)?.toDouble(),
      patentCount: json['patent_count'] ?? 0,
      // Backend sends `journal_count` — map it to paperCount
      paperCount: json['journal_count'] ?? 0,
      // Backend sends `activity_score` — map it to achievementScore
      achievementScore: (json['activity_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Maps to backend: StudentSummaryResponse
//
// top_activity  → topAchievers
// top_cgpa      → topCgpa
// submitted     → (not shown in UI, available if needed)

class StudentSummaryModel {
  final int listId;
  final String listName;
  final int totalStudents;
  final int submitted;
  final int alertStudents;
  final List<TopStudentModel> topAchievers; // ← top_activity
  final List<TopStudentModel> topCgpa;
  final String generatedAt;

  const StudentSummaryModel({
    required this.listId,
    required this.listName,
    required this.totalStudents,
    required this.submitted,
    required this.alertStudents,
    required this.topAchievers,
    required this.topCgpa,
    required this.generatedAt,
  });

  factory StudentSummaryModel.fromJson(Map<String, dynamic> json) {
    return StudentSummaryModel(
      listId: json['list_id'] ?? 0,
      listName: json['list_name'] ?? '',
      totalStudents: json['total_students'] ?? 0,
      submitted: json['submitted'] ?? 0,
      alertStudents: json['alert_students'] ?? 0,
      // Backend: top_activity → Flutter: topAchievers
      topAchievers:
          (json['top_activity'] as List?)
              ?.map((e) => TopStudentModel.fromJson(e))
              .toList() ??
          [],
      topCgpa:
          (json['top_cgpa'] as List?)
              ?.map((e) => TopStudentModel.fromJson(e))
              .toList() ??
          [],
      generatedAt: json['generated_at'] ?? '',
    );
  }
}
