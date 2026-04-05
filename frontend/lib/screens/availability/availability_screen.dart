import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../models/availability_model.dart';
import '../../services/availability_service.dart';
import '../../widgets/common_widgets.dart';
import 'set_availability_screen.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen>
    with SingleTickerProviderStateMixin {
  final _service = AvailabilityService();
  late TabController _tabController;
  List<AvailabilityModel> _slots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    final slots = await _service.getMyAvailability();
    if (mounted) setState(() { _slots = slots; _isLoading = false; });
  }

  List<AvailabilityModel> _filtered(String type) =>
      _slots.where((s) => s.availabilityType == type).toList();

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
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 0),
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
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Availability', style: GoogleFonts.sora(
                          fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Manage your schedule', style: GoogleFonts.sora(
                          fontSize: 13, color: Colors.white.withOpacity(0.8))),
                      ]),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SetAvailabilityScreen()));
                          _loadAvailability();
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.add, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary cards
                  Row(children: [
                    _SummaryCard(
                      label: 'Time Slots',
                      count: _filtered('time_slot').length,
                      icon: Icons.access_time_rounded,
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      label: 'Full Days',
                      count: _filtered('full_day').length,
                      icon: Icons.today_rounded,
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      label: 'Multi-Day',
                      count: _filtered('multi_day').length,
                      icon: Icons.date_range_rounded,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    labelStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.sora(fontSize: 13),
                    tabs: const [
                      Tab(text: 'Time Slots'),
                      Tab(text: 'Full Day'),
                      Tab(text: 'Multi-Day'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Tab Content ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _SlotList(slots: _filtered('time_slot'), onDelete: _deleteSlot),
                      _SlotList(slots: _filtered('full_day'), onDelete: _deleteSlot),
                      _SlotList(slots: _filtered('multi_day'), onDelete: _deleteSlot),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSlot(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Slot', style: Theme.of(context).textTheme.headlineSmall),
        content: Text('Remove this availability entry?',
          style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteAvailability(id);
      _loadAvailability();
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _SummaryCard({required this.label, required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text('$count', style: GoogleFonts.sora(
            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: GoogleFonts.sora(
            fontSize: 10, color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    );
  }
}

class _SlotList extends StatelessWidget {
  final List<AvailabilityModel> slots;
  final Future<void> Function(int id) onDelete;

  const _SlotList({required this.slots, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_rounded,
        title: 'No entries',
        subtitle: 'Tap + to add your availability',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: slots.length,
      itemBuilder: (context, i) {
        final slot = slots[i];
        return FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: i * 60),
          child: _AvailabilityCard(slot: slot, onDelete: () => onDelete(slot.id)),
        );
      },
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final AvailabilityModel slot;
  final VoidCallback onDelete;

  const _AvailabilityCard({required this.slot, required this.onDelete});

  Color get _statusColor {
    switch (slot.status) {
      case 'unavailable': return AppColors.error;
      case 'busy': return AppColors.warning;
      case 'available': return AppColors.success;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14)),
            child: Icon(_typeIcon, color: _statusColor, size: 22),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusBadge(
                    label: slot.statusLabel,
                    color: _statusColor,
                  ),
                  const SizedBox(width: 8),
                  if (slot.isRecurring)
                    StatusBadge(
                      label: 'Recurring',
                      color: AppColors.primary,
                    ),
                ]),
                const SizedBox(height: 6),
                Text(slot.displayDate, style: Theme.of(context).textTheme.titleMedium),
                if (slot.displayTime.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                      size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(slot.displayTime, style: GoogleFonts.sora(
                      fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ],
                if (slot.reason != null && slot.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(slot.reason!, style: GoogleFonts.sora(
                    fontSize: 12, color: AppColors.textHint,
                    fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),

          // Delete button
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  IconData get _typeIcon {
    switch (slot.availabilityType) {
      case 'time_slot': return Icons.access_time_rounded;
      case 'full_day': return Icons.today_rounded;
      case 'multi_day': return Icons.date_range_rounded;
      default: return Icons.event_rounded;
    }
  }
}