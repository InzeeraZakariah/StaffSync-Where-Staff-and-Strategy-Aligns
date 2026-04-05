// lib/screens/students/student_form_screen.dart
//
// This is the canonical StudentFormScreen — roster-based (student selects
// their name from a dropdown) and matches the submitForm() signature in
// student_service.dart: token, registerNumber, overallCgpa, semesters,
// patents, journals, conferences.
//
// The older self-entry version (studentName / semesterGpa params) in
// student_summary_screen.dart has been removed; StudentSummaryScreen lives
// in its own file: student_summary_screen.dart.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/student_service.dart';

class StudentFormScreen extends StatefulWidget {
  final String token;
  const StudentFormScreen({super.key, required this.token});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _service = StudentService();
  final _formKey = GlobalKey<FormState>();

  // State
  String? _listName;
  List<Map<String, String>> _roster = []; // [{student_name, register_number}]
  String? _selectedRegNum;
  bool _isLoadingInfo = true;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  // Academic fields
  final _cgpaCtrl = TextEditingController();

  // Dynamic lists
  final List<_SemRow>     _semesters   = [];
  final List<_PatentRow>  _patents      = [];
  final List<_JournalRow> _journals    = [];
  final List<_ConfRow>    _conferences = [];

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await _service.getFormInfo(widget.token);
      if (mounted) {
        setState(() {
          _listName = info['list_name'] as String? ?? 'Student Form';
          _roster = (info['students'] as List?)
                  ?.map((e) => {
                        'student_name': e['student_name'].toString(),
                        'register_number': e['register_number'].toString(),
                      })
                  .toList() ??
              [];
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoadingInfo = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegNum == null) {
      _snack('Please select your name first', error: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _service.submitForm(
        token: widget.token,
        registerNumber: _selectedRegNum!,
        overallCgpa: double.tryParse(_cgpaCtrl.text),
        semesters: _semesters
            .map((s) => {
                  'semester_number': int.parse(s.semCtrl.text),
                  'gpa': double.parse(s.gpaCtrl.text),
                })
            .toList(),
        patents: _patents
            .map((p) => {
                  'title': p.titleCtrl.text.trim(),
                  'application_number': p.numCtrl.text.trim().isEmpty
                      ? null
                      : p.numCtrl.text.trim(),
                })
            .toList(),
        journals: _journals
            .map((j) => {
                  'title': j.titleCtrl.text.trim(),
                  'journal_name': j.nameCtrl.text.trim().isEmpty
                      ? null
                      : j.nameCtrl.text.trim(),
                  'publish_date': j.dateCtrl.text.trim().isEmpty
                      ? null
                      : j.dateCtrl.text.trim(),
                })
            .toList(),
        conferences: _conferences
            .map((c) => {
                  'conference_name': c.nameCtrl.text.trim(),
                  'paper_title': c.paperCtrl.text.trim().isEmpty
                      ? null
                      : c.paperCtrl.text.trim(),
                  'attended_date': c.dateCtrl.text.trim().isEmpty
                      ? null
                      : c.dateCtrl.text.trim(),
                  'location': c.locCtrl.text.trim().isEmpty
                      ? null
                      : c.locCtrl.text.trim(),
                })
            .toList(),
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInfo) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_off, size: 72, color: AppColors.error),
                const SizedBox(height: 20),
                Text('Form unavailable',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    if (_submitted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 88, color: AppColors.success),
                const SizedBox(height: 24),
                Text('Details submitted!',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'Your academic details have been saved.\n'
                  'You can tap the link again anytime to update them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_listName ?? 'Student Form',
                      style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white)),
                  const SizedBox(height: 4),
                  Text('Fill in your academic details below',
                      style: GoogleFonts.sora(
                          fontSize: 13,
                          color: AppColors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SELECT YOUR NAME ────────────────────────────────────────
              _sectionTitle('Who are you?'),
              DropdownButtonFormField<String>(
                value: _selectedRegNum,
                decoration: InputDecoration(
                  labelText: 'Select your name *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.white,
                ),
                items: _roster
                    .map((s) => DropdownMenuItem(
                          value: s['register_number'],
                          child: Text(
                              '${s['student_name']}  (${s['register_number']})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRegNum = v),
                validator: (v) =>
                    v == null ? 'Please select your name' : null,
              ),

              const SizedBox(height: 28),

              // ── CGPA ────────────────────────────────────────────────────
              _sectionTitle('Overall CGPA'),
              TextFormField(
                controller: _cgpaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecor('e.g. 8.75', 'Overall CGPA'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 10) return 'Enter 0.0 – 10.0';
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ── SEMESTER GPA ─────────────────────────────────────────────
              _sectionHeader('Semester GPA', onAdd: () {
                setState(() => _semesters.add(_SemRow()));
              }),
              if (_semesters.isEmpty)
                _emptyHint('Tap + to add semester GPA entries')
              else
                ..._semesters.asMap().entries.map(
                    (e) => _semesterCard(e.key, e.value)),

              const SizedBox(height: 28),

              // ── PATENTS ──────────────────────────────────────────────────
              _sectionHeader('Patents', onAdd: () {
                setState(() => _patents.add(_PatentRow()));
              }),
              if (_patents.isEmpty)
                _emptyHint('Tap + to add a patent')
              else
                ..._patents.asMap().entries.map(
                    (e) => _patentCard(e.key, e.value)),

              const SizedBox(height: 28),

              // ── JOURNALS ─────────────────────────────────────────────────
              _sectionHeader('Journals Published', onAdd: () {
                setState(() => _journals.add(_JournalRow()));
              }),
              if (_journals.isEmpty)
                _emptyHint('Tap + to add a journal paper')
              else
                ..._journals.asMap().entries.map(
                    (e) => _journalCard(e.key, e.value)),

              const SizedBox(height: 28),

              // ── CONFERENCES ──────────────────────────────────────────────
              _sectionHeader('Conferences Attended', onAdd: () {
                setState(() => _conferences.add(_ConfRow()));
              }),
              if (_conferences.isEmpty)
                _emptyHint('Tap + to add a conference')
              else
                ..._conferences.asMap().entries.map(
                    (e) => _conferenceCard(e.key, e.value)),

              const SizedBox(height: 40),

              // ── SUBMIT ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white))
                      : Text('Submit Details',
                          style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── ROW CARD BUILDERS ─────────────────────────────────────────────────────

  Widget _semesterCard(int i, _SemRow row) => _rowCard(
        index: i,
        label: 'Semester ${i + 1}',
        onRemove: () => setState(() => _semesters.removeAt(i)),
        children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.semCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDecor('e.g. 3', 'Semester No. *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 20) return '1–20';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: row.gpaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecor('e.g. 8.5', 'GPA *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 10) return '0–10';
                  return null;
                },
              ),
            ),
          ]),
        ],
      );

  Widget _patentCard(int i, _PatentRow row) => _rowCard(
        index: i,
        label: 'Patent ${i + 1}',
        onRemove: () => setState(() => _patents.removeAt(i)),
        children: [
          TextFormField(
            controller: row.titleCtrl,
            decoration: _inputDecor('Patent title', 'Title *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.numCtrl,
            decoration:
                _inputDecor('e.g. IN202341012345', 'Application Number'),
          ),
        ],
      );

  Widget _journalCard(int i, _JournalRow row) => _rowCard(
        index: i,
        label: 'Journal ${i + 1}',
        onRemove: () => setState(() => _journals.removeAt(i)),
        children: [
          TextFormField(
            controller: row.titleCtrl,
            decoration: _inputDecor('Paper title', 'Title *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.nameCtrl,
            decoration: _inputDecor('e.g. IEEE Access', 'Journal Name'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.dateCtrl,
            keyboardType: TextInputType.datetime,
            decoration: _inputDecor('YYYY-MM-DD', 'Publication Date'),
          ),
        ],
      );

  Widget _conferenceCard(int i, _ConfRow row) => _rowCard(
        index: i,
        label: 'Conference ${i + 1}',
        onRemove: () => setState(() => _conferences.removeAt(i)),
        children: [
          TextFormField(
            controller: row.nameCtrl,
            decoration:
                _inputDecor('Conference name', 'Conference Name *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.paperCtrl,
            decoration:
                _inputDecor('Paper title (optional)', 'Paper Title'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.dateCtrl,
                keyboardType: TextInputType.datetime,
                decoration: _inputDecor('YYYY-MM-DD', 'Date'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: row.locCtrl,
                decoration: _inputDecor('City / Online', 'Location'),
              ),
            ),
          ]),
        ],
      );

  // ── REUSABLE UI ───────────────────────────────────────────────────────────

  Widget _rowCard({
    required int index,
    required String label,
    required VoidCallback onRemove,
    required List<Widget> children,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label,
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark)),
              const Spacer(),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 22),
              ),
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark)),
      );

  Widget _sectionHeader(String title, {required VoidCallback onAdd}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Add',
                      style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ]),
              ),
            ),
          ],
        ),
      );

  Widget _emptyHint(String msg) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(msg,
            style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                fontSize: 13)),
      );

  InputDecoration _inputDecor(String hint, String label) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success));
  }

  @override
  void dispose() {
    _cgpaCtrl.dispose();
    for (final r in _semesters) r.dispose();
    for (final r in _patents) r.dispose();
    for (final r in _journals) r.dispose();
    for (final r in _conferences) r.dispose();
    super.dispose();
  }
}

// ── DATA HOLDER CLASSES ───────────────────────────────────────────────────────

class _SemRow {
  final semCtrl = TextEditingController();
  final gpaCtrl = TextEditingController();
  void dispose() {
    semCtrl.dispose();
    gpaCtrl.dispose();
  }
}

class _PatentRow {
  final titleCtrl = TextEditingController();
  final numCtrl = TextEditingController();
  void dispose() {
    titleCtrl.dispose();
    numCtrl.dispose();
  }
}

class _JournalRow {
  final titleCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  void dispose() {
    titleCtrl.dispose();
    nameCtrl.dispose();
    dateCtrl.dispose();
  }
}

class _ConfRow {
  final nameCtrl = TextEditingController();
  final paperCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final locCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    paperCtrl.dispose();
    dateCtrl.dispose();
    locCtrl.dispose();
  }
}