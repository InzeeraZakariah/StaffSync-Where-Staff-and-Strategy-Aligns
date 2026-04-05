import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/availability_service.dart';
import '../../widgets/common_widgets.dart';

class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({super.key});

  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  final _service = AvailabilityService();
  final _reasonController = TextEditingController();

  String _selectedType = 'time_slot';
  String _selectedStatus = 'unavailable';
  bool _isRecurring = false;
  bool _isLoading = false;

  // Time slot
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Multi-day
  DateTime? _startDate;
  DateTime? _endDate;

  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _displayDateFormat = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate
    if (_selectedType == 'time_slot') {
      if (_selectedDate == null || _startTime == null || _endTime == null) {
        _showError('Please select date, start time and end time');
        return;
      }
    } else if (_selectedType == 'full_day') {
      if (_selectedDate == null) {
        _showError('Please select a date');
        return;
      }
    } else if (_selectedType == 'multi_day') {
      if (_startDate == null || _endDate == null) {
        _showError('Please select start and end dates');
        return;
      }
      if (_startDate!.isAfter(_endDate!)) {
        _showError('Start date must be before end date');
        return;
      }
    }

    setState(() => _isLoading = true);

    final result = await _service.setAvailability(
      type: _selectedType,
      status: _selectedStatus,
      date: _selectedDate != null ? _dateFormat.format(_selectedDate!) : null,
      startTime: _startTime != null ? _formatTime(_startTime!) : null,
      endTime: _endTime != null ? _formatTime(_endTime!) : null,
      startDate: _startDate != null ? _dateFormat.format(_startDate!) : null,
      endDate: _endDate != null ? _dateFormat.format(_endDate!) : null,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      isRecurring: _isRecurring,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability set successfully!')));
    } else {
      _showError(result['message'] ?? 'Failed to set availability');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate({bool isStart = false, bool isEnd = false}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) _startDate = picked;
      else if (isEnd) _endDate = picked;
      else _selectedDate = picked;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? const TimeOfDay(hour: 9, minute: 0)
          : const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isStart) _startTime = picked; else _endTime = picked; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Set Availability'),
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
            // ─── Status ────────────────────────────────────────────
            Text('Status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(children: [
              _StatusChip(
                label: 'Unavailable',
                color: AppColors.error,
                isSelected: _selectedStatus == 'unavailable',
                onTap: () => setState(() => _selectedStatus = 'unavailable'),
              ),
              const SizedBox(width: 10),
              _StatusChip(
                label: 'Busy',
                color: AppColors.warning,
                isSelected: _selectedStatus == 'busy',
                onTap: () => setState(() => _selectedStatus = 'busy'),
              ),
              const SizedBox(width: 10),
              _StatusChip(
                label: 'Available',
                color: AppColors.success,
                isSelected: _selectedStatus == 'available',
                onTap: () => setState(() => _selectedStatus = 'available'),
              ),
            ]),
            const SizedBox(height: 24),

            // ─── Type ──────────────────────────────────────────────
            Text('Type', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _TypeSelector(
              selected: _selectedType,
              onChanged: (v) => setState(() => _selectedType = v),
            ),
            const SizedBox(height: 24),

            // ─── Date/Time Fields ──────────────────────────────────
            if (_selectedType == 'time_slot') ...[
              Text('Date & Time', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _DatePickerField(
                label: 'Date',
                value: _selectedDate != null
                    ? _displayDateFormat.format(_selectedDate!) : null,
                onTap: () => _pickDate(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _TimePickerField(
                  label: 'Start Time',
                  value: _startTime?.format(context),
                  onTap: () => _pickTime(isStart: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _TimePickerField(
                  label: 'End Time',
                  value: _endTime?.format(context),
                  onTap: () => _pickTime(isStart: false),
                )),
              ]),
            ],

            if (_selectedType == 'full_day') ...[
              Text('Date', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _DatePickerField(
                label: 'Select Date',
                value: _selectedDate != null
                    ? _displayDateFormat.format(_selectedDate!) : null,
                onTap: () => _pickDate(),
              ),
            ],

            if (_selectedType == 'multi_day') ...[
              Text('Date Range', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DatePickerField(
                  label: 'Start Date',
                  value: _startDate != null
                      ? _displayDateFormat.format(_startDate!) : null,
                  onTap: () => _pickDate(isStart: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _DatePickerField(
                  label: 'End Date',
                  value: _endDate != null
                      ? _displayDateFormat.format(_endDate!) : null,
                  onTap: () => _pickDate(isEnd: true),
                )),
              ]),
            ],
            const SizedBox(height: 24),

            // ─── Reason ────────────────────────────────────────────
            Text('Reason (Optional)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Reason',
              hint: 'e.g. Medical leave, Conference, etc.',
              controller: _reasonController,
              prefixIcon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ─── Recurring ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.repeat_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Recurring Weekly', style: Theme.of(context).textTheme.titleMedium),
                  Text('Repeat this slot every week',
                    style: Theme.of(context).textTheme.bodyMedium),
                ])),
                Switch(
                  value: _isRecurring,
                  onChanged: (v) => setState(() => _isRecurring = v),
                  activeColor: AppColors.primary,
                ),
              ]),
            ),
            const SizedBox(height: 32),

            PrimaryButton(
              label: 'Save Availability',
              onPressed: _submit,
              isLoading: _isLoading,
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label, required this.color,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
        ),
        child: Text(label, style: GoogleFonts.sora(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : color)),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = [
      {'key': 'time_slot', 'label': 'Time Slot', 'icon': Icons.access_time_rounded,
       'desc': 'e.g. 12 PM – 3 PM'},
      {'key': 'full_day', 'label': 'Full Day', 'icon': Icons.today_rounded,
       'desc': 'Entire day off'},
      {'key': 'multi_day', 'label': 'Multi-Day', 'icon': Icons.date_range_rounded,
       'desc': 'Date range'},
    ];

    return Column(
      children: types.map((t) {
        final isSelected = selected == t['key'];
        return GestureDetector(
          onTap: () => onChanged(t['key'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLighter : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(t['icon'] as IconData,
                  color: isSelected ? Colors.white : AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['label'] as String, style: GoogleFonts.sora(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                Text(t['desc'] as String, style: GoogleFonts.sora(
                  fontSize: 12, color: AppColors.textSecondary)),
              ])),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DatePickerField({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.border,
            width: value != null ? 1.5 : 1)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
            color: value != null ? AppColors.primary : AppColors.textHint, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            value ?? label,
            style: GoogleFonts.sora(
              fontSize: 13,
              color: value != null ? AppColors.textPrimary : AppColors.textHint,
              fontWeight: value != null ? FontWeight.w500 : FontWeight.w400),
          )),
        ]),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _TimePickerField({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.border,
            width: value != null ? 1.5 : 1)),
        child: Row(children: [
          Icon(Icons.access_time_rounded,
            color: value != null ? AppColors.primary : AppColors.textHint, size: 18),
          const SizedBox(width: 8),
          Text(
            value ?? label,
            style: GoogleFonts.sora(
              fontSize: 13,
              color: value != null ? AppColors.textPrimary : AppColors.textHint,
              fontWeight: value != null ? FontWeight.w500 : FontWeight.w400),
          ),
        ]),
      ),
    );
  }
}