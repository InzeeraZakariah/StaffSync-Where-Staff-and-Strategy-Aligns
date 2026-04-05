// lib/screens/students/student_summary_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';

class StudentSummaryScreen extends StatefulWidget {
  final int listId;
  final String listName;
  const StudentSummaryScreen(
      {super.key, required this.listId, required this.listName});

  @override
  State<StudentSummaryScreen> createState() => _StudentSummaryScreenState();
}

class _StudentSummaryScreenState extends State<StudentSummaryScreen> {
  final _service = StudentService();
  StudentSummaryModel? _summary;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final s = await _service.getSummary(widget.listId);
      if (mounted) setState(() => _summary = s);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to load summary"),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PDF EXPORT ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    if (_summary == null) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildPdf(_summary!);
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/student_summary_${widget.listId}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Student Summary — ${widget.listName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List> _buildPdf(StudentSummaryModel s) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Text(s.listName,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text("Student Summary Report",
              style: const pw.TextStyle(
                  fontSize: 14, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(
              "Generated: ${s.generatedAt.length >= 10 ? s.generatedAt.substring(0, 10) : s.generatedAt}",
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey500)),
          pw.Divider(height: 24),

          // Stats
          pw.Row(children: [
            _pdfStatBox("Total Students", s.totalStudents.toString()),
            pw.SizedBox(width: 12),
            _pdfStatBox("Submitted", s.submitted.toString()),
            pw.SizedBox(width: 12),
            _pdfStatBox("Alerts", s.alertStudents.toString()),
          ]),
          pw.SizedBox(height: 24),

          // Top achievers (top_activity from backend)
          pw.Text("Top 3 Achievers",
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (s.topAchievers.isEmpty)
            pw.Text("No data yet.",
                style: const pw.TextStyle(color: PdfColors.grey600))
          else
            ...s.topAchievers.asMap().entries.map((e) =>
                _pdfStudentRow(e.key + 1, e.value, showScore: true)),
          pw.SizedBox(height: 24),

          // Top CGPA
          pw.Text("Top 3 by CGPA",
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (s.topCgpa.isEmpty)
            pw.Text("No data yet.",
                style: const pw.TextStyle(color: PdfColors.grey600))
          else
            ...s.topCgpa.asMap().entries.map((e) =>
                _pdfStudentRow(e.key + 1, e.value, showScore: false)),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfStatBox(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600)),
            ],
          ),
        ),
      );

  pw.Widget _pdfStudentRow(int rank, TopStudentModel s,
          {required bool showScore}) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: rank == 1 ? PdfColors.amber50 : PdfColors.grey50,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(children: [
          pw.Text("#$rank  ",
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: rank == 1
                      ? PdfColors.amber700
                      : PdfColors.grey700)),
          pw.Expanded(
            child: pw.Text(
                "${s.studentName}${s.registerNumber != null ? ' (${s.registerNumber})' : ''}"),
          ),
          pw.Text(showScore
              ? "Score: ${s.achievementScore.toStringAsFixed(1)}"
              : "CGPA: ${s.overallCgpa?.toStringAsFixed(2) ?? '—'}"),
          pw.SizedBox(width: 10),
          pw.Text(
              "Patents: ${s.patentCount}  Papers: ${s.paperCount}",
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
        ]),
      );

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Summary — ${widget.listName}",
            style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          if (!_isLoading && _summary != null)
            _isExporting
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white)))
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: "Export PDF",
                    onPressed: _exportPdf,
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? const Center(child: Text("Failed to load summary"))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _summary!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row — now shows submitted count too
          Row(
            children: [
              Expanded(
                  child: _statCard("Total\nStudents",
                      s.totalStudents.toString(), AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      "Submitted", s.submitted.toString(), AppColors.info)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard("Alerts",
                      s.alertStudents.toString(), AppColors.warning)),
            ],
          ),
          const SizedBox(height: 28),

          // Top achievers (backend: top_activity → Flutter: topAchievers)
          _sectionTitle(context, "Top 3 Achievers"),
          const Text(
            "Ranked by composite score: CGPA · Sem GPA · Patents · Papers · Conferences",
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (s.topAchievers.isEmpty)
            _noData()
          else
            ...s.topAchievers.asMap().entries.map((e) =>
                _topCard(context, e.key + 1, e.value, showScore: true)),

          const SizedBox(height: 28),

          // Top CGPA
          _sectionTitle(context, "Top 3 by CGPA"),
          const SizedBox(height: 12),
          if (s.topCgpa.isEmpty)
            _noData()
          else
            ...s.topCgpa.asMap().entries.map((e) =>
                _topCard(context, e.key + 1, e.value, showScore: false)),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: const Icon(Icons.download_outlined, size: 20),
              label: const Text("Download PDF Report"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
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
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _topCard(BuildContext ctx, int rank, TopStudentModel s,
      {required bool showScore}) {
    final isFirst = rank == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFirst ? const Color(0xFFFFF8E1) : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFirst ? AppColors.warning : AppColors.border,
          width: isFirst ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor:
              isFirst ? AppColors.warning : AppColors.primaryLighter,
          child: Text(
            "#$rank",
            style: GoogleFonts.sora(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isFirst
                    ? const Color(0xFF4A2902)
                    : AppColors.primaryDark),
          ),
        ),
        title: Text(s.studentName,
            style: Theme.of(ctx).textTheme.titleMedium),
        subtitle: Text(
          [
            if (s.registerNumber != null) s.registerNumber!,
            "CGPA: ${s.overallCgpa?.toStringAsFixed(2) ?? '—'}",
            if (showScore)
              "Score: ${s.achievementScore.toStringAsFixed(1)}",
          ].join('  ·  '),
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
                "${s.patentCount} patent${s.patentCount != 1 ? 's' : ''}",
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text(
                "${s.paperCount} paper${s.paperCount != 1 ? 's' : ''}",
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Text(title, style: Theme.of(ctx).textTheme.headlineMedium),
      );

  Widget _noData() => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text("No data yet.",
            style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary)),
      );
}