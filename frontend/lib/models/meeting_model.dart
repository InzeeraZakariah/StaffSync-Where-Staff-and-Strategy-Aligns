class MeetingModel {
  final int id;
  final String title;
  final String? description;
  final String platform;
  final String meetingLink;
  final String? meetingIdExternal;
  final String? passcode;
  final String scheduledAt;
  final int durationMinutes;
  final String status;
  final int? createdBy;
  final int? sharedToGroupId;
  final bool botEnabled;
  final bool botJoined;
  final String createdAt;
  final List<MeetingAttendee> attendees;
  final MeetingSummary? summary;
  final BotProfile? botProfile;

  const MeetingModel({
    required this.id,
    required this.title,
    this.description,
    required this.platform,
    required this.meetingLink,
    this.meetingIdExternal,
    this.passcode,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.createdBy,
    this.sharedToGroupId,
    required this.botEnabled,
    required this.botJoined,
    required this.createdAt,
    this.attendees = const [],
    this.summary,
    this.botProfile,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      platform: json['platform'],
      meetingLink: json['meeting_link'],
      meetingIdExternal: json['meeting_id_external'],
      passcode: json['passcode'],
      scheduledAt: json['scheduled_at'],
      durationMinutes: json['duration_minutes'] ?? 60,
      status: json['status'],
      createdBy: json['created_by'],
      sharedToGroupId: json['shared_to_group_id'],
      botEnabled: json['bot_enabled'] ?? true,
      botJoined: json['bot_joined'] ?? false,
      createdAt: json['created_at'],
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((a) => MeetingAttendee.fromJson(a))
              .toList() ??
          [],
      summary: json['summary'] != null
          ? MeetingSummary.fromJson(json['summary'])
          : null,
      botProfile: json['bot_profile'] != null
          ? BotProfile.fromJson(json['bot_profile'])
          : null,
    );
  }

  String get platformLabel {
    switch (platform) {
      case 'zoom':        return 'Zoom';
      case 'google_meet': return 'Google Meet';
      case 'ms_teams':    return 'MS Teams';
      default:            return 'Other';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'scheduled': return 'Scheduled';
      case 'ongoing':   return 'Ongoing';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default:          return status;
    }
  }

  bool get isUpcoming  => status == 'scheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}


class MeetingAttendee {
  final int id;
  final String fullName;
  final String department;
  final String? avatarUrl;

  const MeetingAttendee({
    required this.id,
    required this.fullName,
    required this.department,
    this.avatarUrl,
  });

  factory MeetingAttendee.fromJson(Map<String, dynamic> json) {
    return MeetingAttendee(
      id: json['id'],
      fullName: json['full_name'],
      department: json['department'],
      avatarUrl: json['avatar_url'],
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, 2).toUpperCase();
  }
}


class MeetingSummary {
  final int id;
  final int meetingId;
  final String summary;
  final List<String> keyPoints;
  final List<String> actionItems;
  final bool generatedByAi;
  final String createdAt;
  final String? transcript;   // ← added: full speaker-labelled transcript from Fireflies

  const MeetingSummary({
    required this.id,
    required this.meetingId,
    required this.summary,
    required this.keyPoints,
    required this.actionItems,
    required this.generatedByAi,
    required this.createdAt,
    this.transcript,
  });

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: json['id'],
      meetingId: json['meeting_id'],
      summary: json['summary'],
      keyPoints: List<String>.from(json['key_points'] ?? []),
      actionItems: List<String>.from(json['action_items'] ?? []),
      generatedByAi: json['generated_by_ai'] ?? true,
      createdAt: json['created_at'],
      transcript: json['transcript'],
    );
  }
}


class BotProfile {
  final int id;
  final int meetingId;
  final int staffId;
  final String botName;
  final String? botPersona;
  final bool autoJoin;
  final bool notifyAfterSummary;

  const BotProfile({
    required this.id,
    required this.meetingId,
    required this.staffId,
    required this.botName,
    this.botPersona,
    required this.autoJoin,
    required this.notifyAfterSummary,
  });

  factory BotProfile.fromJson(Map<String, dynamic> json) {
    return BotProfile(
      id: json['id'],
      meetingId: json['meeting_id'],
      staffId: json['staff_id'],
      botName: json['bot_name'],
      botPersona: json['bot_persona'],
      autoJoin: json['auto_join'] ?? true,
      notifyAfterSummary: json['notify_after_summary'] ?? true,
    );
  }
}