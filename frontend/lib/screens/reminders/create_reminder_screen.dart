import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/reminder_service.dart';
import '../../widgets/common_widgets.dart';

class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  State<CreateReminderScreen> createState() => _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _service = ReminderService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _type = 'custom';
  bool _isLoading = false;

  final _types = [
    {'key': 'custom', 'label': 'Custom', 'icon': Icons.notifications_rounded,
     'color': AppColors.warning},
    {'key': 'meeting', 'label': 'Meeting', 'icon': Icons.videocam_rounded,
     'color': AppColors.primary},
  ];

  // Quick time presets
  final _presets = [
    {'label': 'In 15 min', 'minutes': 15},
    {'label': 'In 1 hour', 'minutes': 60},
    {'label': 'In 3 hours', 'minutes': 180},
    {'label': 'Tomorrow 9am', 'minutes': -1},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _applyPreset(int minutes) {
    DateTime dt;
    if (minutes == -1) {
      // Tomorrow 9am
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      dt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    } else {
      dt = DateTime.now().add(Duration(minutes: minutes));
    }
    setState(() {
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a title'); return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showError('Please select date and time'); return;
    }

    final dt = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );
    if (dt.isBefore(DateTime.now())) {
      _showError('Please select a future date and time'); return;
    }

    setState(() => _isLoading = true);
    final result = await _service.createReminder(
      title: _titleController.text.trim(),
      remindAt: dt.toUtc().toIso8601String(),
      message: _messageController.text.trim().isEmpty
          ? null : _messageController.text.trim(),
      reminderType: _type,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder set!')));
    } else {
      _showError(result['message'] ?? 'Failed to create reminder');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    final displayDateTime = (_selectedDate != null && _selectedTime != null)
        ? DateFormat('dd MMM yyyy, h:mm a').format(DateTime(
            _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
            _selectedTime!.hour, _selectedTime!.minute))
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Reminder'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Type selector
          Text('Type', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(children: _types.map((t) {
            final isSelected = _type == t['key'];
            final color = t['color'] as Color;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _type = t['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(
                    right: t['key'] == 'custom' ? 10 : 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 1.5 : 1)),
                child: Column(children: [
                  Icon(t['icon'] as IconData,
                    color: isSelected ? color : AppColors.textHint, size: 24),
                  const SizedBox(height: 6),
                  Text(t['label'] as String, style: GoogleFonts.sora(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppColors.textSecondary)),
                ]),
              ),
            ));
          }).toList()),
          const SizedBox(height: 24),

          // Title
          AppTextField(
            label: 'Reminder Title',
            hint: 'e.g. Submit semester results',
            controller: _titleController,
            prefixIcon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),

          AppTextField(
            label: 'Note (Optional)',
            hint: 'Additional details...',
            controller: _messageController,
            prefixIcon: Icons.notes_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Quick presets
          Text('Quick Set', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8,
            children: _presets.map((p) => GestureDetector(
              onTap: () => _applyPreset(p['minutes'] as int),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border)),
                child: Text(p['label'] as String, style: GoogleFonts.sora(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),

          // Date & time picker
          Text('Date & Time', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Combined display when both are set
          if (displayDateTime != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: AppColors.softGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.4))),
              child: Row(children: [
                const Icon(Icons.alarm_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  displayDateTime,
                  style: GoogleFonts.sora(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: AppColors.primary))),
              ]),
            ),

          Row(children: [
            Expanded(child: GestureDetector(
              onTap: _pickDate,
              child: _PickerBtn(
                icon: Icons.calendar_today_outlined,
                label: _selectedDate != null
                    ? DateFormat('dd MMM').format(_selectedDate!)
                    : 'Pick Date',
                isSet: _selectedDate != null,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _pickTime,
              child: _PickerBtn(
                icon: Icons.access_time_rounded,
                label: _selectedTime?.format(context) ?? 'Pick Time',
                isSet: _selectedTime != null,
              ),
            )),
          ]),
          const SizedBox(height: 32),

          PrimaryButton(
            label: 'Set Reminder',
            onPressed: _save,
            isLoading: _isLoading,
            icon: Icons.alarm_add_rounded,
          ),
        ]),
      ),
    );
  }
}

class _PickerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSet;
  const _PickerBtn({required this.icon, required this.label, required this.isSet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isSet ? AppColors.primaryLighter : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSet ? AppColors.primary : AppColors.border,
          width: isSet ? 1.5 : 1)),
      child: Row(children: [
        Icon(icon, color: isSet ? AppColors.primary : AppColors.textHint, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: GoogleFonts.sora(
          fontSize: 13,
          fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
          color: isSet ? AppColors.primary : AppColors.textHint))),
      ]),
    );
  }
}