import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:staffsync/models/resource_model.dart';
import '../../theme/app_theme.dart';
import '../../services/resource_service.dart';
import '../../widgets/common_widgets.dart';

class ShareResourceScreen extends StatefulWidget {
  const ShareResourceScreen({super.key});

  @override
  State<ShareResourceScreen> createState() => _ShareResourceScreenState();
}

class _ShareResourceScreenState extends State<ShareResourceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = ResourceService();

  // Link fields
  final _linkTitleCtrl = TextEditingController();
  final _linkUrlCtrl   = TextEditingController();
  final _linkDescCtrl  = TextEditingController();

  // File fields
  final _fileTitleCtrl = TextEditingController();
  final _fileDescCtrl  = TextEditingController();
  PlatformFile? _pickedFile;
  String? _detectedType;

  // Sharing targets
  String _visibility = 'department';
  List<int> _selectedStaffIds  = [];
  List<int> _selectedGroupIds  = [];

  // Picker data — loaded from API
  List<Map<String, dynamic>> _allStaff  = [];
  List<Map<String, dynamic>> _allGroups = [];
  bool _loadingPeople = false;

  bool _isSubmitting = false;

  // File extension → resource_type mapping (must match backend enum)
  static const _extToType = {
    'pdf': 'pdf',
    'ppt': 'ppt', 'pptx': 'ppt',
    'png': 'image', 'jpg': 'image', 'jpeg': 'image',
    'gif': 'image', 'webp': 'image',
    'mp4': 'video', 'mov': 'video', 'webm': 'video',
    'doc': 'document', 'docx': 'document', 'txt': 'document',
  };

  final _visibilityOptions = [
    {'key': 'department', 'label': 'Department', 'icon': Icons.group_rounded},
    {'key': 'all_staff',  'label': 'All Staff',  'icon': Icons.public_rounded},
    {'key': 'private',    'label': 'Private',    'icon': Icons.lock_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPeople();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _linkTitleCtrl.dispose(); _linkUrlCtrl.dispose(); _linkDescCtrl.dispose();
    _fileTitleCtrl.dispose(); _fileDescCtrl.dispose();
    super.dispose();
  }

  // ── Load staff & groups from real API ─────────────────────────────────────

  Future<void> _loadPeople() async {
    setState(() => _loadingPeople = true);
    final results = await Future.wait([
      _service.getAllStaff(),
      _service.getMyGroups(),
    ]);
    if (mounted) {
      setState(() {
        _allStaff  = results[0];
        _allGroups = results[1];
        _loadingPeople = false;
      });
    }
  }

  // ── File picker ───────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extToType.keys.toList(),
      withData: true
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final ext  = file.name.split('.').last.toLowerCase();
      setState(() {
        _pickedFile   = file;
        _detectedType = _extToType[ext] ?? 'document';
        if (_fileTitleCtrl.text.isEmpty) {
          _fileTitleCtrl.text =
              file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
    }
  }

  // ── Share after upload / link save ────────────────────────────────────────

  Future<void> _shareToTargets(int resourceId) async {
    if (_selectedStaffIds.isNotEmpty) {
      await _service.shareToStaff(
          resourceId: resourceId, staffIds: _selectedStaffIds);
    }
    if (_selectedGroupIds.isNotEmpty) {
      await _service.shareToGroups(
          resourceId: resourceId, groupIds: _selectedGroupIds);
    }
  }

  Future<void> _submitLink() async {
    final title = _linkTitleCtrl.text.trim();
    final url   = _linkUrlCtrl.text.trim();

    if (title.isEmpty) { _showError('Please enter a title'); return; }
    if (url.isEmpty || !url.contains('://')) {
      _showError('Please enter a valid URL (must include https://)');
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await _service.shareLink(
      title: title,
      url: url,
      description: _linkDescCtrl.text.trim().isEmpty
          ? null : _linkDescCtrl.text.trim(),
      visibility: _visibility,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      final resource = result['data'] as ResourceModel;
      await _shareToTargets(resource.id);
      setState(() => _isSubmitting = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link shared successfully!')));
      }
    } else {
      setState(() => _isSubmitting = false);
      _showError(result['message'] ?? 'Failed to share link');
    }
  }

  Future<void> _submitFile() async {
    if (_pickedFile == null) { _showError('Please select a file'); return; }
    final title = _fileTitleCtrl.text.trim();
    if (title.isEmpty) { _showError('Please enter a title'); return; }
    if (_pickedFile!.bytes == null) {
      _showError('Could not read file path. Try again.'); return;
    }

    setState(() => _isSubmitting = true);
    final result = await _service.uploadFile(
      fileBytes: _pickedFile!.bytes!,
      fileName: _pickedFile!.name,
      title: title,
      resourceType: _detectedType ?? 'document',
      description: _fileDescCtrl.text.trim().isEmpty
          ? null : _fileDescCtrl.text.trim(),
      visibility: _visibility, filePath: '',
    );

    if (!mounted) return;
    if (result['success'] == true) {
      final resource = result['data'] as ResourceModel;
      await _shareToTargets(resource.id);
      setState(() => _isSubmitting = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully!')));
      }
    } else {
      setState(() => _isSubmitting = false);
      _showError(result['message'] ?? 'Failed to upload file');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Share Resource'),
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle:
              GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.link_rounded, size: 18),         text: 'Share Link'),
            Tab(icon: Icon(Icons.upload_file_rounded, size: 18),  text: 'Upload File'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLinkTab(), _buildFileTab()],
      ),
    );
  }


  // ── Link tab ──────────────────────────────────────────────────────────────

  Widget _buildLinkTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppTextField(
            label: 'Title', hint: 'e.g. Python Tutorial',
            controller: _linkTitleCtrl,
            prefixIcon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'URL', hint: 'https://...',
            controller: _linkUrlCtrl,
            prefixIcon: Icons.link_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Description (Optional)',
            hint: 'What is this link about?',
            controller: _linkDescCtrl,
            prefixIcon: Icons.description_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          _VisibilityPicker(
            selected: _visibility,
            options: _visibilityOptions,
            onChanged: (v) => setState(() => _visibility = v),
          ),
          const SizedBox(height: 24),
          _ShareTargetSection(
            allStaff: _allStaff, allGroups: _allGroups,
            selectedStaffIds: _selectedStaffIds,
            selectedGroupIds: _selectedGroupIds,
            isLoading: _loadingPeople,
            onStaffChanged:  (ids) => setState(() => _selectedStaffIds  = ids),
            onGroupsChanged: (ids) => setState(() => _selectedGroupIds = ids),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Share Link', icon: Icons.share_rounded,
            onPressed: _submitLink, isLoading: _isSubmitting,
          ),
        ]),
      );

  // ── File tab ──────────────────────────────────────────────────────────────

  Widget _buildFileTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // File picker box
          GestureDetector(
            onTap: _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: _pickedFile != null
                    ? AppColors.primaryLighter : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _pickedFile != null
                      ? AppColors.primary : AppColors.border,
                  width: _pickedFile != null ? 1.5 : 1,
                ),
              ),
              child: Column(children: [
                Icon(
                  _pickedFile != null
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  size: 40,
                  color: _pickedFile != null
                      ? AppColors.primary : AppColors.textHint,
                ),
                const SizedBox(height: 10),
                Text(
                  _pickedFile != null ? _pickedFile!.name : 'Tap to pick a file',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: _pickedFile != null
                        ? FontWeight.w600 : FontWeight.w400,
                    color: _pickedFile != null
                        ? AppColors.primary : AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text('PDF, PPT, Image, Video, Doc',
                    style: GoogleFonts.sora(
                        fontSize: 12, color: AppColors.textHint)),
                if (_detectedType != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Detected: ${_detectedType!.toUpperCase()}',
                      style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Title', hint: 'Display name for this file',
            controller: _fileTitleCtrl, prefixIcon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Description (Optional)',
            hint: 'What is this file about?',
            controller: _fileDescCtrl,
            prefixIcon: Icons.description_outlined, maxLines: 2,
          ),
          const SizedBox(height: 24),
          _VisibilityPicker(
            selected: _visibility, options: _visibilityOptions,
            onChanged: (v) => setState(() => _visibility = v),
          ),
          const SizedBox(height: 24),
          _ShareTargetSection(
            allStaff: _allStaff, allGroups: _allGroups,
            selectedStaffIds: _selectedStaffIds,
            selectedGroupIds: _selectedGroupIds,
            isLoading: _loadingPeople,
            onStaffChanged:  (ids) => setState(() => _selectedStaffIds  = ids),
            onGroupsChanged: (ids) => setState(() => _selectedGroupIds = ids),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Upload File', icon: Icons.upload_rounded,
            onPressed: _submitFile, isLoading: _isSubmitting,
          ),
        ]),
      );
}

// ─── Visibility Picker ────────────────────────────────────────────────────────

class _VisibilityPicker extends StatelessWidget {
  final String selected;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String> onChanged;

  const _VisibilityPicker({
    required this.selected, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Visible to', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Row(
        children: options.map((o) {
          final isSelected = selected == o['key'];
          return Expanded(child: GestureDetector(
            onTap: () => onChanged(o['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                  right: o['key'] != options.last['key'] ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLighter : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(children: [
                Icon(o['icon'] as IconData,
                    color: isSelected
                        ? AppColors.primary : AppColors.textHint,
                    size: 20),
                const SizedBox(height: 4),
                Text(o['label'] as String,
                    style: GoogleFonts.sora(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary : AppColors.textSecondary,
                    )),
              ]),
            ),
          ));
        }).toList(),
      ),
    ]);
  }
}

// ─── Share Target Section ─────────────────────────────────────────────────────

class _ShareTargetSection extends StatelessWidget {
  final List<Map<String, dynamic>> allStaff, allGroups;
  final List<int> selectedStaffIds, selectedGroupIds;
  final bool isLoading;
  final ValueChanged<List<int>> onStaffChanged, onGroupsChanged;

  const _ShareTargetSection({
    required this.allStaff, required this.allGroups,
    required this.selectedStaffIds, required this.selectedGroupIds,
    required this.isLoading,
    required this.onStaffChanged, required this.onGroupsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Also share with (Optional)',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        'Share directly with specific people or groups, in addition to the visibility setting above.',
        style: GoogleFonts.sora(fontSize: 12, color: AppColors.textHint),
      ),
      const SizedBox(height: 14),

      _PickerTile(
        label: 'Staff members',
        icon: Icons.person_rounded,
        isLoading: isLoading,
        items: allStaff,
        selectedIds: selectedStaffIds,
        nameKey: 'full_name',
        onTap: allStaff.isEmpty ? null : () => _openSheet(
          context, title: 'Select Staff',
          items: allStaff, selectedIds: selectedStaffIds,
          nameKey: 'full_name', onChanged: onStaffChanged,
        ),
      ),
      const SizedBox(height: 10),

      _PickerTile(
        label: 'Groups',
        icon: Icons.group_rounded,
        isLoading: isLoading,
        items: allGroups,
        selectedIds: selectedGroupIds,
        nameKey: 'name',
        onTap: allGroups.isEmpty ? null : () => _openSheet(
          context, title: 'Select Groups',
          items: allGroups, selectedIds: selectedGroupIds,
          nameKey: 'name', onChanged: onGroupsChanged,
        ),
      ),
    ]);
  }

  void _openSheet(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> items,
    required List<int> selectedIds,
    required String nameKey,
    required ValueChanged<List<int>> onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MultiSelectSheet(
        title: title, items: items,
        selectedIds: selectedIds, nameKey: nameKey,
        onChanged: onChanged,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final List<Map<String, dynamic>> items;
  final List<int> selectedIds;
  final String nameKey;
  final VoidCallback? onTap;

  const _PickerTile({
    required this.label, required this.icon, required this.isLoading,
    required this.items, required this.selectedIds,
    required this.nameKey, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedNames = items
        .where((i) => selectedIds.contains(i['id'] as int))
        .map((i) => i[nameKey] as String)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedIds.isNotEmpty
                ? AppColors.primary : AppColors.border,
            width: selectedIds.isNotEmpty ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color: selectedIds.isNotEmpty
                  ? AppColors.primary : AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: isLoading
                ? Text('Loading...',
                    style: GoogleFonts.sora(
                        fontSize: 13, color: AppColors.textHint))
                : items.isEmpty
                    ? Text('No $label found',
                        style: GoogleFonts.sora(
                            fontSize: 13, color: AppColors.textHint))
                    : selectedIds.isEmpty
                        ? Text('Select $label',
                            style: GoogleFonts.sora(
                                fontSize: 13,
                                color: AppColors.textSecondary))
                        : Text(
                            selectedNames.join(', '),
                            style: GoogleFonts.sora(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
          ),
          if (selectedIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${selectedIds.length}',
                  style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

// ─── Multi-Select Bottom Sheet ────────────────────────────────────────────────

class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<int> selectedIds;
  final String nameKey;
  final ValueChanged<List<int>> onChanged;

  const _MultiSelectSheet({
    required this.title, required this.items,
    required this.selectedIds, required this.nameKey,
    required this.onChanged,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late List<int> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
  }

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? widget.items
      : widget.items.where((i) {
          final name = (i[widget.nameKey] as String? ?? '').toLowerCase();
          return name.contains(_search.toLowerCase());
        }).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(children: [
              Expanded(child: Text(widget.title,
                  style: Theme.of(context).textTheme.headlineSmall)),
              TextButton(
                onPressed: () {
                  widget.onChanged(List.from(_selected));
                  Navigator.pop(context);
                },
                child: Text('Done',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.sora(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.sora(
                    fontSize: 14, color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final id   = item['id'] as int;
                final name = item[widget.nameKey] as String? ?? '';
                final isSelected = _selected.contains(id);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        AppColors.primary.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.sora(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  title: Text(name,
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.textPrimary,
                      )),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  onTap: () => setState(() {
                    isSelected
                        ? _selected.remove(id)
                        : _selected.add(id);
                  }),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}