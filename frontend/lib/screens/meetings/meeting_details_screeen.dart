import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/meeting_model.dart';
import '../../services/meeting_service.dart';
import '../../widgets/common_widgets.dart';

class MeetingDetailScreen extends StatefulWidget {
  final int meetingId;
  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _service = MeetingService();
  final _transcriptController = TextEditingController();
  MeetingModel? _meeting;
  bool _isLoading = true;
  bool _isGeneratingSummary = false;
  bool _showTranscriptInput = false;
  bool _showFullTranscript = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final meeting = await _service.getMeetingDetail(widget.meetingId);
    if (mounted) {
      setState(() {
        _meeting = meeting;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateSummary() async {
    if (_transcriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a meeting transcript')),
      );
      return;
    }
    setState(() => _isGeneratingSummary = true);
    final result = await _service.generateSummary(
      meetingId: widget.meetingId,
      transcript: _transcriptController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isGeneratingSummary = false;
      _showTranscriptInput = false;
    });
    if (result['success']) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI summary generated!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to generate summary'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchLink() async {
    if (_meeting == null) return;
    final uri = Uri.tryParse(_meeting!.meetingLink);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_meeting == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.error_outline, title: 'Meeting not found'),
      );
    }

    final m = _meeting!;
    final dt = DateTime.tryParse(m.scheduledAt)?.toLocal();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── Hero App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: m.statusLabel,
                      color: m.isUpcoming ? Colors.white : Colors.white70,
                      textColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m.title,
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.platformLabel,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Time & Duration ───────────────────────────────
                  _Section(
                    title: 'Schedule',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Date',
                            value: dt != null
                                ? DateFormat('EEEE, dd MMM yyyy').format(dt)
                                : '-',
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Time',
                            value: dt != null ? DateFormat('h:mm a').format(dt) : '-',
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value: '${m.durationMinutes} minutes',
                          ),
                          if (m.passcode != null) ...[
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.password_rounded,
                              label: 'Passcode',
                              value: m.passcode!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Join Button ───────────────────────────────────
                  if (m.isUpcoming)
                    PrimaryButton(
                      label: 'Join Meeting',
                      onPressed: _launchLink,
                      icon: Icons.videocam_rounded,
                    ),
                  if (m.isUpcoming) const SizedBox(height: 8),
                  if (m.isUpcoming)
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: m.meetingLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ─── AI Bot Status ─────────────────────────────────
                  if (m.botEnabled) ...[
                    _Section(
                      title: 'AI Bot',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.softGradient,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLighter,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.smart_toy_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.botProfile?.botName ?? 'StaffSync AI Bot',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    m.botJoined
                                        ? 'Fireflies bot attended this meeting'
                                        : 'Bot will join for unavailable staff',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: m.botJoined ? 'Attended' : 'Ready',
                              color: m.botJoined ? AppColors.success : AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Attendees ─────────────────────────────────────
                  if (m.attendees.isNotEmpty) ...[
                    _Section(
                      title: 'Attendees (${m.attendees.length})',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: m.attendees.map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StaffAvatar(
                                avatarUrl: a.avatarUrl,
                                initials: a.initials,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.fullName,
                                    style: GoogleFonts.sora(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    a.department,
                                    style: GoogleFonts.sora(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── AI Summary ────────────────────────────────────
                  _Section(
                    title: 'AI Summary',
                    action: m.isCompleted && m.summary == null
                        ? GestureDetector(
                            onTap: () => setState(
                              () => _showTranscriptInput = !_showTranscriptInput,
                            ),
                            child: Text(
                              'Generate',
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                    child: m.summary != null
                        ? _SummaryCard(
                            summary: m.summary!,
                            showTranscript: _showFullTranscript,
                            onToggleTranscript: () => setState(
                              () => _showFullTranscript = !_showFullTranscript,
                            ),
                          )
                        : _showTranscriptInput
                            ? _TranscriptInput(
                                controller: _transcriptController,
                                isLoading: _isGeneratingSummary,
                                onSubmit: _generateSummary,
                              )
                            : _BotSummaryPlaceholder(
                                botJoined: m.botJoined,
                                isCompleted: m.isCompleted,
                              ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Cancel ────────────────────────────────────────
                  if (m.isUpcoming)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text('Cancel Meeting'),
                            content: const Text(
                              'Are you sure you want to cancel this meeting?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Cancel Meeting',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _service.cancelMeeting(widget.meetingId);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Meeting'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Bot Summary Placeholder ──────────────────────────────────────────────────

class _BotSummaryPlaceholder extends StatelessWidget {
  final bool botJoined;
  final bool isCompleted;

  const _BotSummaryPlaceholder({
    required this.botJoined,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // Bot attended but summary not yet ready — still processing
    if (botJoined && !isCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fireflies AI bot attended this meeting. Summary is being generated...',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No bot involved or meeting not yet complete
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 32),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? 'Tap "Generate" to create an AI summary from the transcript'
                : 'Summary will be available after the meeting.\nIf you\'re unavailable, Fireflies AI bot will attend and generate it automatically.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


// ─── Summary Card (updated to show transcript toggle) ─────────────────────────

class _SummaryCard extends StatelessWidget {
  final MeetingSummary summary;
  final bool showTranscript;
  final VoidCallback onToggleTranscript;

  const _SummaryCard({
    required this.summary,
    required this.showTranscript,
    required this.onToggleTranscript,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI badge
          if (summary.generatedByAi)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Generated by Fireflies AI + Groq',
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Overview
          Text('Overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(summary.summary, style: Theme.of(context).textTheme.bodyLarge),

          // Key Points
          if (summary.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Key Points', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...summary.keyPoints.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(p, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Action Items
          if (summary.actionItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Action Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...summary.actionItems.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(e.value, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Full Transcript toggle — only if transcript exists
          if (summary.transcript != null && summary.transcript!.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onToggleTranscript,
              child: Row(
                children: [
                  Icon(
                    showTranscript
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    showTranscript ? 'Hide Transcript' : 'View Full Transcript',
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (showTranscript) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  summary.transcript!,
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}


// ─── Reused widgets (unchanged from original) ─────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Section({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.sora(fontSize: 13, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _TranscriptInput({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          maxLines: 8,
          style: GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText:
                'Paste meeting transcript here...\n\nGroq AI will extract key points and action items.',
            hintStyle: GoogleFonts.sora(fontSize: 13, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Generate AI Summary',
          onPressed: onSubmit,
          isLoading: isLoading,
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }
}