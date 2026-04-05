// lib/screens/students/student_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
import 'student_entries_screen.dart';
import 'student_summary_screen.dart';

class StudentListsScreen extends StatefulWidget {
  const StudentListsScreen({super.key});

  @override
  State<StudentListsScreen> createState() => _StudentListsScreenState();
}

class _StudentListsScreenState extends State<StudentListsScreen> {
  final _service = StudentService();
  List<StudentListModel> _lists = [];
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _service.getLists();
      if (mounted) setState(() => _lists = lists);
    } catch (e) {
      _snack('Failed to load: ${e.toString().replaceAll("Exception: ", "")}',
          error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── CREATE LIST ────────────────────────────────────────────────────────────

  void _showCreateSheet() {
    final nameCtrl    = TextEditingController();
    final descCtrl    = TextEditingController();
    final formCtrl    = TextEditingController(); // Google Form URL
    final sheetCtrl   = TextEditingController(); // Google Sheet ID
    final tabCtrl     = TextEditingController(text: 'Form Responses 1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Student List',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),

              // Basic info
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'List Name *',
                      hintText: 'e.g. CSE 2024 Batch A')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)')),

              const SizedBox(height: 20),
              // Google Forms section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.assignment_outlined,
                          color: Color(0xFF388E3C), size: 18),
                      const SizedBox(width: 8),
                      Text('Google Form (optional — add later)',
                          style: GoogleFonts.sora(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: const Color(0xFF1B5E20))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(controller: formCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Google Form URL',
                            hintText: 'https://forms.gle/...',
                            isDense: true)),
                    const SizedBox(height: 10),
                    TextField(controller: sheetCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Google Sheet ID',
                            hintText: 'from the Sheet URL: /d/SHEET_ID/edit',
                            isDense: true)),
                    const SizedBox(height: 10),
                    TextField(controller: tabCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Sheet Tab Name',
                            hintText: 'Form Responses 1',
                            isDense: true)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    setState(() => _isBusy = true);
                    try {
                      final created = await _service.createList(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null : descCtrl.text.trim(),
                        googleFormUrl: formCtrl.text.trim().isEmpty
                            ? null : formCtrl.text.trim(),
                        googleSheetId: sheetCtrl.text.trim().isEmpty
                            ? null : sheetCtrl.text.trim(),
                        sheetTabName: tabCtrl.text.trim().isEmpty
                            ? 'Form Responses 1' : tabCtrl.text.trim(),
                      );
                      setState(() => _lists = [created, ..._lists]);
                      _snack('List created!');
                    } catch (e) {
                      _snack(e.toString().replaceAll('Exception: ', ''),
                          error: true);
                    } finally {
                      if (mounted) setState(() => _isBusy = false);
                    }
                  },
                  child: const Text('Create List'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SHARE GOOGLE FORM LINK ─────────────────────────────────────────────────

  void _shareFormLink(StudentListModel sl) {
    if (!sl.hasFormUrl) {
      // No form URL yet — let staff set it
      _showSetFormUrl(sl);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share Google Form',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Students open this Google Form link in any browser — '
                'no app needed.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // URL preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Text(sl.googleFormUrl!,
                    style: GoogleFonts.sora(
                        fontSize: 12, color: const Color(0xFF2E7D32)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 20),

              // Share via OS sheet
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: const Text('Share via WhatsApp / Messages…'),
                  onPressed: () {
                    Navigator.pop(context);
                    Share.share(
                      'Hi! Please fill in your academic details for "${sl.name}".\n\n'
                      'Open this link in your browser:\n${sl.googleFormUrl}',
                      subject: 'Student Details Form — ${sl.name}',
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Open in browser
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser_outlined, size: 20),
                  label: const Text('Open form in browser'),
                  onPressed: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse(sl.googleFormUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Copy link
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  label: const Text('Copy link'),
                  onPressed: () {
                    Navigator.pop(context);
                    Clipboard.setData(
                        ClipboardData(text: sl.googleFormUrl!));
                    _snack('Link copied!');
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── SET / EDIT GOOGLE FORM URL ─────────────────────────────────────────────

  void _showSetFormUrl(StudentListModel sl) {
    final formCtrl  = TextEditingController(text: sl.googleFormUrl ?? '');
    final sheetCtrl = TextEditingController(text: sl.googleSheetId ?? '');
    final tabCtrl   = TextEditingController(
        text: sl.sheetTabName ?? 'Form Responses 1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Link Google Form',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Create a Google Form with CGPA, semester GPA, patents, '
              'journals and conference questions. Then paste the links here.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(controller: formCtrl,
                decoration: const InputDecoration(
                    labelText: 'Google Form URL *',
                    hintText: 'https://forms.gle/...')),
            const SizedBox(height: 12),
            TextField(controller: sheetCtrl,
                decoration: const InputDecoration(
                    labelText: 'Google Sheet ID *',
                    hintText: 'From Sheet URL: /spreadsheets/d/SHEET_ID/edit')),
            const SizedBox(height: 12),
            TextField(controller: tabCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tab name in Sheet',
                    hintText: 'Form Responses 1')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (formCtrl.text.trim().isEmpty ||
                      sheetCtrl.text.trim().isEmpty) return;
                  Navigator.pop(context);
                  setState(() => _isBusy = true);
                  try {
                    final updated = await _service.updateList(sl.id,
                        googleFormUrl: formCtrl.text.trim(),
                        googleSheetId: sheetCtrl.text.trim(),
                        sheetTabName: tabCtrl.text.trim().isEmpty
                            ? 'Form Responses 1' : tabCtrl.text.trim());
                    setState(() {
                      final idx = _lists.indexWhere((l) => l.id == sl.id);
                      if (idx != -1) _lists[idx] = updated;
                    });
                    _snack('Google Form linked!');
                  } catch (e) {
                    _snack('Failed to save', error: true);
                  } finally {
                    if (mounted) setState(() => _isBusy = false);
                  }
                },
                child: const Text('Save Google Form Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SYNC FROM GOOGLE SHEET ─────────────────────────────────────────────────

  Future<void> _sync(StudentListModel sl) async {
    if (!sl.canSync) {
      _snack('Link a Google Sheet first (tap the form icon)', error: true);
      return;
    }
    setState(() => _isBusy = true);
    try {
      final result = await _service.syncFromSheet(sl.id);
      _snack(result['message'] ?? 'Sync complete!',
          error: (result['errors'] as List?)?.isNotEmpty == true);
      await _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  void _confirmDelete(StudentListModel sl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text(
            '"${sl.name}" and all ${sl.totalStudents} student entries will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isBusy = true);
              try {
                await _service.deleteList(sl.id);
                setState(() => _lists.removeWhere((l) => l.id == sl.id));
                _snack('Deleted');
              } catch (_) {
                _snack('Failed to delete', error: true);
              } finally {
                if (mounted) setState(() => _isBusy = false);
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Student Details',
                          style: GoogleFonts.sora(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white)),
                      if (_isBusy)
                        const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Create lists · share Google Form · sync responses',
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          color: AppColors.white.withOpacity(0.85))),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _lists.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _lists.length,
                      itemBuilder: (_, i) => _listCard(_lists[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text('New List',
            style: GoogleFonts.sora(
                color: AppColors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── LIST CARD ─────────────────────────────────────────────────────────────

  Widget _listCard(StudentListModel sl) {
    final isAlert = sl.hasAlerts;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF3E0) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isAlert ? AppColors.warning : AppColors.border,
            width: isAlert ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StudentEntriesScreen(studentList: sl)),
        ).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(children: [
                Expanded(child: Text(sl.name,
                    style: Theme.of(context).textTheme.titleLarge)),
                if (isAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        '${sl.alertCount} alert${sl.alertCount > 1 ? 's' : ''}',
                        style: GoogleFonts.sora(
                            fontSize: 12,
                            color: const Color(0xFF4A2902),
                            fontWeight: FontWeight.w600)),
                  ),
              ]),

              if (sl.description != null && sl.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(sl.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],

              const SizedBox(height: 10),

              // Stats
              Row(children: [
                _chip(Icons.people_outline,
                    '${sl.totalStudents} student${sl.totalStudents != 1 ? 's' : ''}'),
                const SizedBox(width: 10),
                _chip(Icons.calendar_today_outlined, sl.formattedDate),
                if (sl.hasFormUrl) ...[
                  const SizedBox(width: 10),
                  _chip(Icons.assignment_turned_in_outlined, 'Form linked',
                      color: const Color(0xFF2E7D32)),
                ],
              ]),

              const SizedBox(height: 14),

              // Action buttons
              Row(children: [
                // Share Google Form
                _actionBtn(
                  icon: sl.hasFormUrl
                      ? Icons.share_outlined
                      : Icons.add_link_outlined,
                  label: sl.hasFormUrl ? 'Share form' : 'Link form',
                  color: const Color(0xFF2E7D32),
                  onTap: () => _shareFormLink(sl),
                ),
                const SizedBox(width: 8),

                // Sync
                _actionBtn(
                  icon: Icons.sync_outlined,
                  label: 'Sync',
                  color: AppColors.primary,
                  onTap: () => _sync(sl),
                ),
                const SizedBox(width: 8),

                // Summary
                _actionBtn(
                  icon: Icons.bar_chart_outlined,
                  label: 'Summary',
                  color: AppColors.info,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => StudentSummaryScreen(
                            listId: sl.id, listName: sl.name)),
                  ),
                ),
                const Spacer(),

                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 22),
                  onPressed: () => _confirmDelete(sl),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13,
              color: color ?? AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color ?? AppColors.textSecondary,
                  fontSize: 12)),
        ],
      );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add_outlined,
                size: 80,
                color: AppColors.primaryLight.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No student lists yet',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
                'Tap + to create a list.\nThen link a Google Form and share it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success));
  }
}