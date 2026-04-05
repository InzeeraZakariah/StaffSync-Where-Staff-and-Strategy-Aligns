class AvailabilityModel {
  final int id;
  final int staffId;
  final String availabilityType;
  final String status;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;
  final String? reason;
  final bool isRecurring;
  final String createdAt;
  final String updatedAt;

  const AvailabilityModel({
    required this.id,
    required this.staffId,
    required this.availabilityType,
    required this.status,
    this.date,
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.reason,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AvailabilityModel.fromJson(Map<String, dynamic> json) {
    return AvailabilityModel(
      id: json['id'],
      staffId: json['staff_id'],
      availabilityType: json['availability_type'],
      status: json['status'],
      date: json['date'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      reason: json['reason'],
      isRecurring: json['is_recurring'] ?? false,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  bool get isUnavailable => status == 'unavailable' || status == 'busy';

  String get typeLabel {
    switch (availabilityType) {
      case 'time_slot': return 'Time Slot';
      case 'full_day': return 'Full Day';
      case 'multi_day': return 'Multi-Day';
      default: return availabilityType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'unavailable': return 'Unavailable';
      case 'busy': return 'Busy';
      case 'available': return 'Available';
      default: return status;
    }
  }

  String get displayDate {
    if (availabilityType == 'multi_day') {
      return '$startDate → $endDate';
    }
    return date ?? '';
  }

  String get displayTime {
    if (availabilityType == 'time_slot') {
      return '$startTime – $endTime';
    }
    if (availabilityType == 'full_day') return 'All Day';
    return '';
  }
}