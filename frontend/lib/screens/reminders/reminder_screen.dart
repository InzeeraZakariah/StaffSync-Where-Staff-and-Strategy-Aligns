import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../widgets/common_widgets.dart';
import 'create_reminder_screen.dart';
import 'urgent_notify_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  final _service = ReminderService();
  late TabController _tabController;
  List<ReminderModel> _reminders = [];
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
    final reminders = await _service.getMyReminders();
    if (mounted) setState(() { _reminders = reminders; _isLoading = false; });
  }

  List<ReminderModel> get _upcoming => _reminders
      .where((r) => r.isUpcoming && !r.isRead)
      .toList()
    ..sort((a, b) => a.remindAt.compareTo(b.remindAt));

  List<ReminderModel> get _past => _reminders
      .where((r) => !r.isUpcoming || r.isRead)
      .toList()
    ..sort((a, b) => b.remindAt.compareTo(a.remindAt));

  int get _unreadCount => _reminders.where((r) => !r.isRead).length;

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
                  20, MediaQuery.of(context).padding.top + 16, 20, 0),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Reminders', style: GoogleFonts.sora(
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                        if (_unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(20)),
                            child: Text('$_unreadCount', style: GoogleFonts.sora(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                          ),
                        ],
                      ]),
                      Text('Your schedule alerts', style: GoogleFonts.sora(
                          fontSize: 13, color: Colors.white.withOpacity(0.8))),
                    ]),
                    Row(children: [
                      // Urgent notify button
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const UrgentNotifyScreen())),
                        child: Container(
                          width: 44, height: 44,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.campaign_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                      // Create reminder
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const CreateReminderScreen()));
                          _load();
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.add, color: Colors.white, size: 22),
                        ),
                      ),
                    ]),
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
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.sora(fontSize: 13),
                  tabs: [
                    Tab(text: 'Upcoming (${_upcoming.length})'),
                    Tab(text: 'Past (${_past.length})'),
                  ],
                ),
              ]),
            ),
          ),

          // ─── Tabs ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _ReminderList(
                        reminders: _upcoming,
                        onRefresh: _load,
                        service: _service,
                        emptyTitle: 'No upcoming reminders',
                        emptySubtitle: 'Tap + to set a reminder',
                        onChanged: _load,
                      ),
                      _ReminderList(
                        reminders: _past,
                        onRefresh: _load,
                        service: _service,
                        emptyTitle: 'No past reminders',
                        emptySubtitle: 'Completed reminders will appear here',
                        onChanged: _load,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── List ─────────────────────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  final List<ReminderModel> reminders;
  final Future<void> Function() onRefresh;
  final ReminderService service;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onChanged;

  const _ReminderList({
    required this.reminders,
    required this.onRefresh,
    required this.service,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return EmptyState(
        icon: Icons.notifications_off_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: reminders.length,
        itemBuilder: (context, i) => FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: i * 60),
          child: _ReminderCard(
            reminder: reminders[i],
            service: service,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final ReminderService service;
  final VoidCallback onChanged;

  const _ReminderCard({
    required this.reminder,
    required this.service,
    required this.onChanged,
  });

  Color get _typeColor {
    switch (reminder.reminderType) {
      case 'meeting': return AppColors.primary;
      case 'urgent': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  IconData get _typeIcon {
    switch (reminder.reminderType) {
      case 'meeting': return Icons.videocam_rounded;
      case 'urgent': return Icons.warning_amber_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(reminder.remindAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('dd MMM, h:mm a').format(dt) : '';
    final isRead = reminder.isRead;

    return Dismissible(
      key: Key('reminder_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) async {
        await service.deleteReminder(reminder.id);
        onChanged();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? AppColors.surfaceVariant : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? AppColors.divider : AppColors.border,
            width: isRead ? 1 : 1.5),
        ),
        child: InkWell(
          onTap: isRead ? null : () async {
            await service.markAsRead(reminder.id);
            onChanged();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Icon
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(isRead ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(14)),
                child: Icon(_typeIcon,
                    color: isRead
                        ? _typeColor.withOpacity(0.4)
                        : _typeColor,
                    size: 22),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(
                      reminder.title,
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                        color: isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (!isRead)
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: _typeColor, shape: BoxShape.circle)),
                  ]),
                  if (reminder.message != null &&
                      reminder.message!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      reminder.message!,
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: isRead
                            ? AppColors.textHint
                            : AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 12,
                        color: isRead
                            ? AppColors.textHint
                            : _typeColor),
                    const SizedBox(width: 4),
                    Text(dateStr, style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isRead ? AppColors.textHint : _typeColor,
                    )),
                    const SizedBox(width: 10),
                    StatusBadge(
                      label: reminder.typeLabel,
                      color: _typeColor,
                    ),
                  ]),
                ],
              )),

              // Mark read action
              if (!isRead)
                GestureDetector(
                  onTap: () async {
                    await service.markAsRead(reminder.id);
                    onChanged();
                  },
                  child: Container(
                    width: 34, height: 34,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.success, size: 18),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}