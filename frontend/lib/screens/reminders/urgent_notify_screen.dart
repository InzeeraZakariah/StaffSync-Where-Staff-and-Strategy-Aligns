import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_widgets.dart';

class UrgentNotifyScreen extends StatefulWidget {
  const UrgentNotifyScreen({super.key});

  @override
  State<UrgentNotifyScreen> createState() => _UrgentNotifyScreenState();
}

class _UrgentNotifyScreenState extends State<UrgentNotifyScreen> {
  final _messageController = TextEditingController();
  final _service = ReminderService();
  bool _isSending = false;
  bool _sent = false;
  int _recipientCount = 0;

  final _templates = [
    '🚨 Emergency faculty meeting in 15 minutes. All staff please report to Conference Room 1.',
    '⚠️ Exam hall duty change — please check the updated timetable immediately.',
    '📢 Important announcement regarding tomorrow\'s schedule. Please check your emails.',
    '🔔 College management meeting postponed. New time will be notified shortly.',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')));
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded,
              color: AppColors.error, size: 30)),
          const SizedBox(height: 16),
          Text('Send Urgent Notification?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'This will alert ALL active staff with an emergency sound. Groq AI will enhance your message.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
              child: const Text('Send to All Staff'))),
          ]),
        ]),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    // Play emergency sound locally immediately
    await NotificationService().showUrgentNotification(
      title: 'Urgent Notification Sent',
      body: _messageController.text.trim(),
    );

    final result = await _service.sendUrgentNotify(_messageController.text.trim());

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success']) {
      setState(() {
        _sent = true;
        _recipientCount = result['data']?['total_recipients'] ?? 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Failed to send notification'),
        backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.campaign_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Text('Urgent Notify',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: AppColors.error)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context)),
      ),
      body: _sent ? _buildSuccessView() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        FadeInDown(
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text('Emergency Broadcast',
                  style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.error)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Sends an emergency alert sound + push notification to ALL active staff instantly. Groq AI enhances your message.',
                style: GoogleFonts.sora(fontSize: 12, color: AppColors.error)),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // AI badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter,
            borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text('Groq AI will enhance your message',
              style: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.primary)),
          ]),
        ),
        const SizedBox(height: 20),

        Text('Message', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          maxLines: 5,
          style: GoogleFonts.sora(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Type your urgent message here...',
            hintStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.error, width: 1.5)),
          ),
        ),
        const SizedBox(height: 24),

        Text('Quick Templates',
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._templates.asMap().entries.map((e) => FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: e.key * 60),
          child: GestureDetector(
            onTap: () => setState(
              () => _messageController.text = e.value),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
              child: Text(e.value, style: GoogleFonts.sora(
                fontSize: 13, color: AppColors.textPrimary)),
            ),
          ),
        )),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.campaign_rounded, size: 20),
            label: Text(
              _isSending ? 'Sending...' : '🚨 Send Emergency Alert',
              style: GoogleFonts.sora(
                fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: AppColors.error.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ]),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FadeInDown(
            duration: const Duration(milliseconds: 600),
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 56)),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: Text('Emergency Alert Sent!',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 300),
            child: Text(
              _recipientCount > 0
                ? 'Emergency sound triggered for $_recipientCount staff members. Groq AI enhanced your message.'
                : 'Emergency alert sent to all active staff.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          ),
          const SizedBox(height: 32),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 400),
            child: PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context)),
          ),
        ]),
      ),
    );
  }
}