import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/meeting_service.dart';
import '../../widgets/common_widgets.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  final _descController = TextEditingController();
  final _passcodeController = TextEditingController();
  final _service = MeetingService();

  String _platform = 'zoom';
  int _duration = 60;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _botEnabled = true;
  bool _isLoading = false;

  final _platforms = [
    {'key': 'zoom', 'label': 'Zoom', 'icon': Icons.video_camera_front_rounded},
    {
      'key': 'google_meet',
      'label': 'Google Meet',
      'icon': Icons.videocam_rounded,
    },
    {'key': 'ms_teams', 'label': 'MS Teams', 'icon': Icons.video_call_rounded},
    {'key': 'other', 'label': 'Other', 'icon': Icons.video_library_rounded},
  ];

  final _durations = [30, 45, 60, 90, 120];

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    _descController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a meeting title');
      return;
    }
    if (_linkController.text.trim().isEmpty) {
      _showError('Please enter a meeting link');
      return;
    }
    if (_scheduledDate == null || _scheduledTime == null) {
      _showError('Please select date and time');
      return;
    }

    final dt = DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );

    setState(() => _isLoading = true);
    final result = await _service.createMeeting(
      title: _titleController.text.trim(),
      platform: _platform,
      meetingLink: _linkController.text.trim(),
      scheduledAt: dt.toUtc().toIso8601String(),
      durationMinutes: _duration,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      passcode: _passcodeController.text.trim().isEmpty
          ? null
          : _passcodeController.text.trim(),
      botEnabled: _botEnabled,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting created! AI checked availability.'),
        ),
      );
    } else {
      _showError(result['message'] ?? 'Failed to create meeting');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.error),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Meeting'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI notice banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.softGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryLight.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI will check all attendees\' availability and assign a bot for unavailable staff.',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title
            AppTextField(
              label: 'Meeting Title',
              hint: 'e.g. CSE Department Review',
              controller: _titleController,
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: 16),

            // Platform picker
            Text('Platform', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _platforms.map((p) {
                final isSelected = _platform == p['key'];
                return GestureDetector(
                  onTap: () => setState(() => _platform = p['key'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLighter
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p['icon'] as IconData,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p['label'] as String,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Meeting link
            AppTextField(
              label: 'Meeting Link',
              hint: 'https://zoom.us/j/...',
              controller: _linkController,
              prefixIcon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Date & time
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: _PickerField(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _scheduledDate != null
                          ? DateFormat('dd MMM yyyy').format(_scheduledDate!)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: _PickerField(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: _scheduledTime?.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duration
            Text('Duration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _durations.map((d) {
                final isSelected = _duration == d;
                return GestureDetector(
                  onTap: () => setState(() => _duration = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${d}m',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Optional fields
            AppTextField(
              label: 'Description (Optional)',
              hint: 'Agenda or meeting notes...',
              controller: _descController,
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Passcode (Optional)',
              hint: 'Meeting passcode',
              controller: _passcodeController,
              prefixIcon: Icons.password_rounded,
            ),
            const SizedBox(height: 20),

            // AI bot toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable AI Bot',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Bot attends for unavailable staff',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _botEnabled,
                    onChanged: (v) => setState(() => _botEnabled = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            PrimaryButton(
              label: 'Create Meeting',
              onPressed: _create,
              isLoading: _isLoading,
              icon: Icons.videocam_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _PickerField({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value != null ? AppColors.primary : AppColors.border,
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value != null ? AppColors.primary : AppColors.textHint,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? label,
              style: GoogleFonts.sora(
                fontSize: 13,
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
