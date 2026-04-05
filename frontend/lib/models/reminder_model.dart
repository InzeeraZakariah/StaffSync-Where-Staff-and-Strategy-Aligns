class ReminderModel {
  final int id;
  final int staffId;
  final int? meetingId;
  final String title;
  final String? message;
  final String reminderType;
  final String status;
  final String remindAt;
  final bool isRead;
  final bool isAiGenerated;
  final String createdAt;

  const ReminderModel({
    required this.id,
    required this.staffId,
    this.meetingId,
    required this.title,
    this.message,
    required this.reminderType,
    required this.status,
    required this.remindAt,
    required this.isRead,
    required this.isAiGenerated,
    required this.createdAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'],
      staffId: json['staff_id'],
      meetingId: json['meeting_id'],
      title: json['title'],
      message: json['body'],         // backend field is "body"
      reminderType: json['reminder_type'] ?? 'custom',
      status: json['status'] ?? 'pending',
      remindAt: json['remind_at'],
      isRead: json['is_read'] ?? false,
      isAiGenerated: json['is_ai_generated'] ?? false,
      createdAt: json['created_at'],
    );
  }

  bool get isUpcoming {
    final dt = DateTime.tryParse(remindAt)?.toLocal();
    return dt != null && dt.isAfter(DateTime.now());
  }

  String get typeLabel {
    switch (reminderType) {
      case 'meeting': return 'Meeting';
      case 'urgent':  return 'Urgent';
      default:        return 'Custom';
    }
  }
}