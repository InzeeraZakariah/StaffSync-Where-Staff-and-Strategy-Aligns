import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../services/notification_service.dart';

/// A reusable bottom sheet that lets the user pick a group
/// and share content (resource / meeting / reminder / urgent) to it.
class ShareToGroupSheet extends StatefulWidget {
  final String title;
  final String? description;
  final String? link;
  final String shareType; // "resource" | "meeting" | "reminder" | "urgent"
  final bool isUrgent;

  const ShareToGroupSheet({
    super.key,
    required this.title,
    this.description,
    this.link,
    required this.shareType,
    this.isUrgent = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? description,
    String? link,
    required String shareType,
    bool isUrgent = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareToGroupSheet(
        title: title,
        description: description,
        link: link,
        shareType: shareType,
        isUrgent: isUrgent,
      ),
    );
    return result == true;
  }

  @override
  State<ShareToGroupSheet> createState() => _ShareToGroupSheetState();
}

class _ShareToGroupSheetState extends State<ShareToGroupSheet> {
  final _groupService = GroupService();
  List<GroupModel> _groups = [];
  Set<int> _selectedGroupIds = {};
  bool _isLoading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await _groupService.getMyGroups();
    if (mounted) {
      setState(() {
        _groups    = groups;
        _isLoading = false;
      });
    }
  }

  Future<void> _share() async {
    if (_selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one group')));
      return;
    }

    setState(() => _isSharing = true);

    int successCount = 0;
    for (final groupId in _selectedGroupIds) {
      final result = await _groupService.shareToGroup(
        groupId:     groupId,
        shareType:   widget.shareType,
        title:       widget.title,
        description: widget.description,
        link:        widget.link,
        isUrgent:    widget.isUrgent,
      );
      if (result['success'] == true) successCount++;
    }

    if (!mounted) return;
    setState(() => _isSharing = false);

    // Play notification sound locally
    if (widget.isUrgent) {
      await NotificationService().showUrgentNotification(
        title: '🚨 ${widget.title}',
        body: 'Shared to ${_selectedGroupIds.length} group(s)',
      );
    } else {
      await NotificationService().showChatMessage(
        groupName:  'Group',
        senderName: 'You',
        message:    'Shared ${widget.title}',
      );
    }

    Navigator.pop(context, successCount > 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(successCount > 0
          ? 'Shared to $successCount group(s) ✅'
          : 'Failed to share'),
      backgroundColor:
          successCount > 0 ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final typeIcons = {
      'resource': Icons.attach_file_rounded,
      'meeting':  Icons.video_camera_front_rounded,
      'reminder': Icons.notifications_rounded,
      'urgent':   Icons.campaign_rounded,
    };
    final typeColors = {
      'resource': AppColors.primary,
      'meeting':  const Color(0xFF3B82F6),
      'reminder': const Color(0xFFF59E0B),
      'urgent':   AppColors.error,
    };

    final icon  = typeIcons[widget.shareType] ?? Icons.share_rounded;
    final color = typeColors[widget.shareType] ?? AppColors.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        // Handle
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Share to Group',
                  style: GoogleFonts.sora(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(widget.title,
                  style: GoogleFonts.sora(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),

        if (widget.isUrgent) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.error.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.volume_up_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Emergency sound will play for all recipients',
                  style: GoogleFonts.sora(
                      fontSize: 12, color: AppColors.error),
                )),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Divider(height: 1),

        // Group list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group_off_rounded,
                              size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text('No groups found',
                              style: GoogleFonts.sora(
                                  fontSize: 14, color: AppColors.textSecondary)),
                          Text('Create a group first',
                              style: GoogleFonts.sora(
                                  fontSize: 12, color: AppColors.textHint)),
                        ],
                      ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _groups.length,
                      itemBuilder: (context, i) {
                        final group     = _groups[i];
                        final isSelected = _selectedGroupIds.contains(group.id);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? color
                                : AppColors.primaryLighter,
                            child: Text(
                              group.name.isNotEmpty
                                  ? group.name[0].toUpperCase()
                                  : 'G',
                              style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary)),
                          ),
                          title: Text(group.name,
                              style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${group.memberCount} members',
                              style: GoogleFonts.sora(
                                  fontSize: 11,
                                  color: AppColors.textHint)),
                          trailing: Checkbox(
                            value: isSelected,
                            activeColor: color,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            onChanged: (_) => setState(() {
                              if (isSelected) {
                                _selectedGroupIds.remove(group.id);
                              } else {
                                _selectedGroupIds.add(group.id);
                              }
                            }),
                          ),
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedGroupIds.remove(group.id);
                            } else {
                              _selectedGroupIds.add(group.id);
                            }
                          }),
                        );
                      },
                    ),
        ),

        // Share button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSharing || _selectedGroupIds.isEmpty
                  ? null : _share,
              icon: _isSharing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(widget.isUrgent
                      ? Icons.campaign_rounded
                      : Icons.send_rounded,
                      size: 18),
              label: Text(
                _isSharing
                    ? 'Sharing...'
                    : _selectedGroupIds.isEmpty
                        ? 'Select Groups'
                        : 'Share to ${_selectedGroupIds.length} Group(s)',
                style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isUrgent ? AppColors.error : color,
                disabledBackgroundColor:
                    (widget.isUrgent ? AppColors.error : color)
                        .withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            ),
          ),
        ),
      ]),
    );
  }
}