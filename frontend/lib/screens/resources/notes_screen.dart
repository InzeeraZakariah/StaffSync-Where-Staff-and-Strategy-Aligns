import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/resource_model.dart';
import '../../services/resource_service.dart';
import '../../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NotesTab — embedded inside ResourcesScreen TabView
// ─────────────────────────────────────────────────────────────────────────────

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final _service = ResourceService();
  List<NoteModel> _notes = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(microseconds: 300));
    final notes = await _service.getNotes(
      search: _search.isEmpty ? null : _search,
    );
    print('=== notes count: ${notes.length} ===');
    print('=== notes data: $notes ===');
    if (mounted) setState(() { _notes = notes; _isLoading = false; });
  }

  void _openEditor([NoteModel? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
    await _load();
  }

  Future<void> _deleteNote(NoteModel note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Note',
            style: Theme.of(context).textTheme.headlineSmall),
        content: Text('Are you sure you want to delete "${note.title}"?',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: GoogleFonts.sora(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _service.deleteNote(note.id);
      if (ok && mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        // ── Search bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) {
              _search = v;
              _load();
            },
            style: GoogleFonts.sora(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search notes...',
              hintStyle: GoogleFonts.sora(
                  fontSize: 14, color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.white,
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // ── Note list ───────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : _notes.isEmpty
                  ? EmptyState(
                      icon: Icons.note_outlined,
                      title: _search.isEmpty
                          ? 'No notes yet'
                          : 'No notes match "$_search"',
                      subtitle: _search.isEmpty
                          ? 'Tap + to create a shared department note'
                          : '',
                      actionLabel:
                          _search.isEmpty ? 'Create Note' : null,
                      onAction:
                          _search.isEmpty ? () async => _openEditor() : null,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _notes.length,
                        itemBuilder: (context, i) => FadeInUp(
                          duration: const Duration(milliseconds: 350),
                          delay: Duration(milliseconds: i * 50),
                          child: NoteCard(
                            note: _notes[i],
                            onTap: () => _openEditor(_notes[i]),
                            onDelete: () => _deleteNote(_notes[i]),
                          ),
                        ),
                      ),
                    ),
        ),
      ]),

      // ── FAB ─────────────────────────────────────────────────
      Positioned(
        bottom: 24,
        right: 24,
        child: GestureDetector(
          onTap: () => _openEditor(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.edit_note_rounded,
                color: Colors.white, size: 26),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NoteCard — reusable card widget
// ─────────────────────────────────────────────────────────────────────────────

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(note.updatedAt)?.toLocal();
    final dateStr =
        dt != null ? DateFormat('dd MMM, h:mm a').format(dt) : '';
    final tagList = note.tags != null
        ? note.tags!
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : <String>[];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                note.isPinned ? AppColors.primary : AppColors.border,
            width: note.isPinned ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(children: [
                if (note.isPinned) ...[
                  const Icon(Icons.push_pin_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    note.title,
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.error),
                  ),
                ),
              ]),
            ),

            // ── Content preview ──────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                note.content,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Tags ─────────────────────────────────────────
            if (tagList.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tagList
                      .take(4)
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

            // ── Footer: author + timestamp ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                // Author avatar
                if (note.author != null) ...[
                  CircleAvatar(
                    radius: 11,
                    backgroundColor:
                        AppColors.primary.withOpacity(0.12),
                    backgroundImage: note.author!.avatarUrl != null
                        ? NetworkImage(note.author!.avatarUrl!)
                        : null,
                    child: note.author!.avatarUrl == null
                        ? Text(
                            note.author!.initials,
                            style: GoogleFonts.sora(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.author!.fullName,
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                // Timestamp
                const Icon(Icons.access_time_rounded,
                    size: 11, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(
                  dateStr,
                  style: GoogleFonts.sora(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NoteEditorScreen — create & edit notes, saves to backend
// ─────────────────────────────────────────────────────────────────────────────

class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagsCtrl;
  final _service = ResourceService();

  bool _isPinned = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl =
        TextEditingController(text: widget.note?.content ?? '');
    _tagsCtrl =
        TextEditingController(text: widget.note?.tags ?? '');
    _isPinned = widget.note?.isPinned ?? false;

    // Mark dirty on any change
    for (final ctrl in [_titleCtrl, _contentCtrl, _tagsCtrl]) {
      ctrl.addListener(() {
        if (!_hasChanges && mounted) setState(() => _hasChanges = true);
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      _showSnack('Please enter a title', isError: true);
      return;
    }
    if (content.isEmpty) {
      _showSnack('Please write some content', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    Map<String, dynamic> result;

    if (_isEditing) {
      result = await _service.updateNote(
        id: widget.note!.id,
        title: title,
        content: content,
        isPinned: _isPinned,
        tags: _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim(),
      );
    } else {
      // For new notes: department comes from the logged-in user's profile.
      // Here we read it from SharedPreferences where your auth stores it.
      // If you store department differently, replace this logic.
      final prefs = await _getDepartment();
      print('=== department being sent: $prefs ===');  // ← add this
      print('=== title: $title, content: $content ===');  
      result = await _service.createNote(
        title: title,
        content: content,
        department: prefs,
        isPinned: _isPinned,
        tags: _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      _showSnack(
          _isEditing ? 'Note updated!' : 'Note created!');
      Navigator.pop(context);
    } else {
      _showSnack(result['message'] ?? 'Failed to save note.',
          isError: true);
    }
  }

  Future<String> _getDepartment() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final dept = prefs.getString('user_department');
    print('=== stored department: $dept ==='); // ← check what's stored
    return dept ?? 'general';
  } catch (_) {
    return 'general';
  }
}

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Note' : 'New Note',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          // Pin toggle
          IconButton(
            tooltip: _isPinned ? 'Unpin' : 'Pin note',
            icon: Icon(
              _isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: _isPinned
                  ? AppColors.primary
                  : AppColors.textHint,
            ),
            onPressed: () =>
                setState(() { _isPinned = !_isPinned; _hasChanges = true; }),
          ),
          // Save
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed:
                  (_hasChanges || !_isEditing) && !_isSaving
                      ? _save
                      : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Text(
                      'Save',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: (_hasChanges || !_isEditing)
                            ? AppColors.primary
                            : AppColors.textHint,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Title field
              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Note title...',
                  hintStyle: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 12),

              // Content field
              TextField(
                controller: _contentCtrl,
                style: GoogleFonts.sora(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.65,
                ),
                decoration: InputDecoration(
                  hintText: 'Start writing your note here...',
                  hintStyle: GoogleFonts.sora(
                    fontSize: 15,
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                minLines: 15,
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // Tags field
              Row(children: [
                const Icon(Icons.tag_rounded,
                    size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tagsCtrl,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Tags — comma separated (e.g. exams, semester2)',
                      hintStyle: GoogleFonts.sora(
                          fontSize: 13,
                          color: AppColors.textHint),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Add this import at the top of the file:
