import 'package:intl/intl.dart';

class StaffModel {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String department;
  final String designation;
  final String? employeeId;
  final String? bio;
  final String? avatarUrl;
  final bool isAdmin;
  final bool pushNotificationsEnabled;
  final bool emailNotificationsEnabled;
  final bool showAvailabilityToOthers;
  final String createdAt;
  final String? lastLoginAt;

  final List<AchievementModel> achievements;
  final List<PatentModel> patents;
  final List<JournalModel> journals;
  final List<ExpertiseModel> expertises;

  const StaffModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.department,
    required this.designation,
    this.employeeId,
    this.bio,
    this.avatarUrl,
    required this.isAdmin,
    required this.pushNotificationsEnabled,
    required this.emailNotificationsEnabled,
    required this.showAvailabilityToOthers,
    required this.createdAt,
    this.lastLoginAt,
    this.achievements = const [],
    this.patents = const [],
    this.journals = const [],
    this.expertises = const [],
  });
  

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      department: json['department'] ?? '',
      designation: json['designation'] ?? '',
      employeeId: json['employee_id'],
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
      isAdmin: json['is_admin'] ?? false,
      pushNotificationsEnabled: json['push_notifications_enabled'] ?? true,
      emailNotificationsEnabled: json['email_notifications_enabled'] ?? true,
      showAvailabilityToOthers:
          json['show_availability_to_others'] ?? true,
      createdAt: json['created_at'] ?? '',
      lastLoginAt: json['last_login_at'],

      achievements: (json['achievements'] as List?)
              ?.map((e) =>
                  AchievementModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],

      patents: (json['patents'] as List?)
              ?.map((e) =>
                  PatentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],

      journals: (json['journals'] as List?)
              ?.map((e) =>
                  JournalModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],

      expertises:
          ((json['expertises'] ?? json['expertise']) as List?)
                  ?.map((e) =>
                      ExpertiseModel.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
    );
  }
  StaffModel copyWith({
  int? id,
  String? fullName,
  String? email,
  String? phone,
  String? department,
  String? designation,
  String? employeeId,
  String? bio,
  String? avatarUrl,
  bool? isAdmin,
  bool? pushNotificationsEnabled,
  bool? emailNotificationsEnabled,
  bool? showAvailabilityToOthers,
  String? createdAt,
  String? lastLoginAt,
  List<AchievementModel>? achievements,
  List<PatentModel>? patents,
  List<JournalModel>? journals,
  List<ExpertiseModel>? expertises,
}) 

{
  return StaffModel(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    department: department ?? this.department,
    designation: designation ?? this.designation,
    employeeId: employeeId ?? this.employeeId,
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isAdmin: isAdmin ?? this.isAdmin,
    pushNotificationsEnabled:
        pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    emailNotificationsEnabled:
        emailNotificationsEnabled ?? this.emailNotificationsEnabled,
    showAvailabilityToOthers:
        showAvailabilityToOthers ?? this.showAvailabilityToOthers,
    createdAt: createdAt ?? this.createdAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    achievements: achievements ?? this.achievements,
    patents: patents ?? this.patents,
    journals: journals ?? this.journals,
    expertises: expertises ?? this.expertises,
  );
}

  Map<String, dynamic> extrasToJson() {
    return {
      "achievements": achievements.map((e) => e.toJson()).toList(),
      "patents": patents.map((e) => e.toJson()).toList(),
      "journals": journals.map((e) => e.toJson()).toList(),
      "expertises": expertises.map((e) => e.toJson()).toList(),
    };
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty
        ? fullName.substring(0, 2).toUpperCase()
        : '??';
  }
}

// ─── ACHIEVEMENT ───────────────────────────────────
class AchievementModel {
  final int id;
  final String title;
  final String? description;
  final String? date;

  const AchievementModel({
    required this.id,
    required this.title,
    this.description,
    this.date,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      date: json['date'],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "description": description,
        "date": date,
      };

  String get formattedDate {
    if (date == null) return '';
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(date!));
    } catch (_) {
      return '';
    }
  }
}

// ─── PATENT ────────────────────────────────────────
class PatentModel {
  final int id;
  final String title;
  final String? patentNumber;
  final String? issueDate;
  final String? description;

  const PatentModel({
    required this.id,
    required this.title,
    this.patentNumber,
    this.issueDate,
    this.description,
  });

  factory PatentModel.fromJson(Map<String, dynamic> json) {
    return PatentModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      patentNumber: json['patent_number'],
      issueDate: json['issue_date'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "patent_number": patentNumber,
        "issue_date": issueDate,
        "description": description,
      };

  String get formattedIssueDate {
    if (issueDate == null) return '';
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(issueDate!));
    } catch (_) {
      return '';
    }
  }
}

// ─── JOURNAL ───────────────────────────────────────
class JournalModel {
  final int id;
  final String title;
  final String? journalName;
  final String? publisher;
  final String? publicationDate;
  final String? doi;

  const JournalModel({
    required this.id,
    required this.title,
    this.journalName,
    this.publisher,
    this.publicationDate,
    this.doi,
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    return JournalModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      journalName: json['journal_name'],
      publisher: json['publisher'],
      publicationDate: json['publication_date'],
      doi: json['doi'],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "journal_name": journalName,
        "publisher": publisher,
        "publication_date": publicationDate,
        "doi": doi,
      };

  String get formattedPublicationDate {
    if (publicationDate == null) return '';
    try {
      return DateFormat('MMM yyyy')
          .format(DateTime.parse(publicationDate!));
    } catch (_) {
      return '';
    }
  }

  String get doiLink {
    if (doi == null || doi!.isEmpty) return '';
    return 'https://doi.org/$doi';
  }
}

// ─── EXPERTISE ─────────────────────────────────────
class ExpertiseModel {
  final int id;
  final String subject;
  final String proficiencyLevel;
  final int yearsExperience;

  const ExpertiseModel({
    required this.id,
    required this.subject,
    required this.proficiencyLevel,
    required this.yearsExperience,
  });

  factory ExpertiseModel.fromJson(Map<String, dynamic> json) {
    return ExpertiseModel(
      id: json['id'] ?? 0,
      subject: json['subject'] ?? '',
      proficiencyLevel:
          json['proficiency_level'] ?? 'Intermediate',
      yearsExperience: json['years_experience'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "subject": subject,
        "proficiency_level": proficiencyLevel,
        "years_experience": yearsExperience,
      };

  String get displayProficiency =>
      proficiencyLevel.toUpperCase();

  String get experienceText {
    if (yearsExperience == 0) return '';
    return yearsExperience == 1
        ? '1 yr'
        : '$yearsExperience yrs';
  }
}
