import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/meeting_model.dart';
import '../../services/meeting_service.dart';
import '../../widgets/common_widgets.dart';
import 'create_meeting_screen.dart';
import '../meetings/meeting_details_screeen.dart';
import 'bot_profile_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = MeetingService();
  late TabController _tabController;
  List<MeetingModel> _allMeetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final meetings = await _service.getMyMeetings();
    if (mounted) {
      setState(() {
        _allMeetings = meetings;
        _isLoading = false;
      });
    }
  }

  List<MeetingModel> get _upcoming =>
      _allMeetings.where((m) => m.isUpcoming).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<MeetingModel> get _past =>
      _allMeetings.where((m) => !m.isUpcoming).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Header ───────────────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                0,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meetings',
                            style: GoogleFonts.sora(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'AI-powered scheduling',
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Bot profile button
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BotProfileScreen(),
                              ),
                            ),
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.smart_toy_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          // Create meeting button
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateMeetingScreen(),
                                ),
                              );
                              _load();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    labelStyle: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.sora(fontSize: 13),
                    tabs: [
                      Tab(text: 'Upcoming (${_upcoming.length})'),
                      Tab(text: 'Past (${_past.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Tab Content ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MeetingList(
                        meetings: _upcoming,
                        onRefresh: _load,
                        emptyTitle: 'No upcoming meetings',
                        emptySubtitle: 'Create a meeting to get started',
                      ),
                      _MeetingList(
                        meetings: _past,
                        onRefresh: _load,
                        emptyTitle: 'No past meetings',
                        emptySubtitle: 'Completed meetings will appear here',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MeetingList extends StatelessWidget {
  final List<MeetingModel> meetings;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptySubtitle;

  const _MeetingList({
    required this.meetings,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return EmptyState(
        icon: Icons.videocam_off_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: meetings.length,
        itemBuilder: (context, i) => FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: i * 60),
          child: _MeetingCard(meeting: meetings[i]),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;

  const _MeetingCard({required this.meeting});

  Color get _statusColor {
    switch (meeting.status) {
      case 'scheduled':
        return AppColors.primary;
      case 'ongoing':
        return AppColors.success;
      case 'completed':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData get _platformIcon {
    switch (meeting.platform) {
      case 'zoom':
        return Icons.video_camera_front_rounded;
      case 'google_meet':
        return Icons.videocam_rounded;
      default:
        return Icons.videocam_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(meeting.scheduledAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : '';
    final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingDetailScreen(meetingId: meeting.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with status color
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _platformIcon,
                          color: _statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meeting.title,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              meeting.platformLabel,
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: meeting.statusLabel,
                        color: _statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: dateStr,
                      ),
                      const SizedBox(width: 16),
                      _InfoChip(
                        icon: Icons.access_time_rounded,
                        label: timeStr,
                      ),
                      const SizedBox(width: 16),
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: '${meeting.durationMinutes}m',
                      ),
                    ],
                  ),
                  if (meeting.botEnabled) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.smart_toy_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            meeting.botJoined
                                ? 'AI Bot attended this meeting'
                                : 'AI Bot enabled',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Attendee avatars
                  if (meeting.attendees.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ...meeting.attendees
                            .take(5)
                            .map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: StaffAvatar(
                                  avatarUrl: a.avatarUrl,
                                  initials: a.initials,
                                  size: 28,
                                ),
                              ),
                            ),
                        if (meeting.attendees.length > 5)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+${meeting.attendees.length - 5}',
                                style: GoogleFonts.sora(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.sora(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
