// lib/screens/students/student_entries_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';

// ─── ENTRIES LIST SCREEN ─────────────────────────────────────────────────────

class StudentEntriesScreen extends StatefulWidget {
  final StudentListModel studentList;
  const StudentEntriesScreen({super.key, required this.studentList});

  @override
  State<StudentEntriesScreen> createState() => _StudentEntriesScreenState();
}

class _StudentEntriesScreenState extends State<StudentEntriesScreen> {
  final _service = StudentService();
  List<StudentEntryModel> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // ✅ FIXED: was _service.getEntries — now correctly calls getEntries()
      final entries = await _service.getEntries(widget.studentList.id);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      _snack("Failed to load entries", error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.studentList.name,
            style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _entries.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      itemBuilder: (_, i) => _entryCard(_entries[i]),
                    ),
            ),
    );
  }

  Widget _entryCard(StudentEntryModel e) {
    final isAlert = e.isAlert;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF3E0) : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? AppColors.warning : AppColors.border,
          width: isAlert ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StudentDetailScreen(entry: e)),
        ),
        leading: CircleAvatar(
          backgroundColor:
              isAlert ? AppColors.warning : AppColors.primaryLighter,
          child: Text(
            e.studentName.isNotEmpty
                ? e.studentName[0].toUpperCase()
                : '?',
            style: GoogleFonts.sora(
              fontWeight: FontWeight.bold,
              color:
                  isAlert ? const Color(0xFF4A2902) : AppColors.primaryDark,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(e.studentName,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (isAlert)
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.registerNumber != null)
              Text(e.registerNumber!,
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                _badge("CGPA ${e.cgpaDisplay}", AppColors.primaryLighter,
                    AppColors.primaryDark),
                const SizedBox(width: 6),
                _badge("SGPA ${e.sgpaDisplay}",
                    AppColors.surfaceVariant, AppColors.textSecondary),
                const SizedBox(width: 6),
                if (e.patents.isNotEmpty)
                  _badge(
                      "${e.patents.length} patent${e.patents.length > 1 ? 's' : ''}",
                      const Color(0xFFEDE7F6),
                      const Color(0xFF4527A0)),
                if (e.papers.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _badge(
                      "${e.papers.length} paper${e.papers.length > 1 ? 's' : ''}",
                      const Color(0xFFE8F5E9),
                      const Color(0xFF1B5E20)),
                ],
              ],
            ),
          ],
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.primaryLight),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _empty() => const Center(
        child: Text("No students have submitted yet.",
            style: TextStyle(color: AppColors.textSecondary)),
      );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success));
  }
}

// ─── STUDENT DETAIL SCREEN ────────────────────────────────────────────────────

class StudentDetailScreen extends StatelessWidget {
  final StudentEntryModel entry;
  const StudentDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(entry.studentName,
            style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert banner
            if (entry.isAlert)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "This student has not updated their form "
                        "${entry.missedUpdatesThisMonth}+ time(s) this month.",
                        style: GoogleFonts.sora(
                            fontSize: 13, color: const Color(0xFF4A2902)),
                      ),
                    ),
                  ],
                ),
              ),

            // Identity
            _section(context, "Student Info"),
            _row(context, "Name", entry.studentName),
            if (entry.registerNumber != null)
              _row(context, "Register No.", entry.registerNumber!),
            if (entry.email != null) _row(context, "Email", entry.email!),
            _row(context, "Submissions", entry.submissionCount.toString()),

            const SizedBox(height: 24),

            // Academic
            _section(context, "Academic Performance"),
            Row(
              children: [
                Expanded(
                  child: _scoreCard(
                      context, "CGPA", entry.cgpaDisplay, AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _scoreCard(context, "SGPA (Best Semester)",
                      entry.sgpaDisplay, AppColors.info),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Patents
            _section(context, "Patents (${entry.patents.length})"),
            if (entry.patents.isEmpty)
              _hint("No patents added.")
            else
              ...entry.patents.map((p) => _itemCard(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    iconColor: AppColors.info,
                    title: p.title,
                    sub: p.applicationNumber != null
                        ? "No: ${p.applicationNumber}"
                        : null,
                  )),

            const SizedBox(height: 24),

            // Papers (journals)
            _section(context, "Papers Published (${entry.papers.length})"),
            if (entry.papers.isEmpty)
              _hint("No papers added.")
            else
              ...entry.papers.map((p) => _itemCard(
                    context,
                    icon: Icons.article_outlined,
                    iconColor: AppColors.success,
                    title: p.title,
                    sub: [
                      if (p.journalName != null) p.journalName!,
                      if (p.formattedDate.isNotEmpty) p.formattedDate,
                    ].join(' · '),
                  )),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext ctx, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(ctx).textTheme.headlineMedium),
      );

  Widget _row(BuildContext ctx, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value, style: Theme.of(ctx).textTheme.bodyLarge),
            ),
          ],
        ),
      );

  Widget _scoreCard(
          BuildContext ctx, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _itemCard(BuildContext ctx,
          {required IconData icon,
          required Color iconColor,
          required String title,
          String? sub}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          subtitle: sub != null && sub.isNotEmpty
              ? Text(sub, style: Theme.of(ctx).textTheme.bodyMedium)
              : null,
        ),
      );

  Widget _hint(String msg) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(msg,
            style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary)),
      );
}