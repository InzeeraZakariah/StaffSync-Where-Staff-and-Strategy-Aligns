import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/staff_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  StaffModel? _staff;
  bool _isLoading = true;
  bool _isSyncing = false;

  // ── DEPARTMENT / DESIGNATION OPTIONS ─────────────────────────────────────
  static const _departments = [
    'CSE', 'IT', 'ECE', 'EEE', 'MECH', 'CIVIL', 'MBA', 'MCA', 'ADMIN', 'OTHER'
  ];
  static const _designations = [
    'Professor', 'Associate Professor', 'Assistant Professor',
    'Head of Department', 'Principal', 'Lab Instructor', 'Admin Staff', 'Other'
  ];
  static const _proficiencyLevels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final staff = await _authService.getProfile();
    if (mounted) {
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    }
  }

  // ── SYNC HELPER ───────────────────────────────────────────────────────────
  // Sends the full updated list for one section to the backend, then updates
  // local state if successful. Pops the bottom sheet and shows a snackbar.
  Future<void> _performSync({
    required String sectionName,
    required String apiKey,
    required List<dynamic> updatedList,
    required StaffModel newStaffObject,
  }) async {
    setState(() => _isSyncing = true);
    try {
      await _authService.updateProfile({
        apiKey: updatedList.map((e) => e.toJson()).toList(),
      });
      if (mounted) {
        setState(() => _staff = newStaffObject);
        _pop("$sectionName updated");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to update $sectionName"),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── ACCOUNT SETTING TOGGLE ────────────────────────────────────────────────
  // Optimistic update: flips the local state immediately, reverts on failure.
  Future<void> _updateSetting(String key, bool value) async {
    final originalStaff = _staff!;
    setState(() {
      _staff = _staff!.copyWith(
        pushNotificationsEnabled:
            key == 'push_notifications_enabled' ? value : _staff!.pushNotificationsEnabled,
        emailNotificationsEnabled:
            key == 'email_notifications_enabled' ? value : _staff!.emailNotificationsEnabled,
        showAvailabilityToOthers:
            key == 'show_availability_to_others' ? value : _staff!.showAvailabilityToOthers,
      );
    });
    try {
      await _authService.updateProfile({key: value});
    } catch (_) {
      if (mounted) {
        setState(() => _staff = originalStaff);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Update failed")));
      }
    }
  }

  // ── REMOVE ITEM FROM A SECTION ────────────────────────────────────────────
  void _removeItem(String key, int index) {
    late List<dynamic> newList;
    late StaffModel newStaff;

    switch (key) {
      case 'achievements':
        newList = [..._staff!.achievements]..removeAt(index);
        newStaff = _staff!.copyWith(achievements: newList.cast<AchievementModel>());
        break;
      case 'patents':
        newList = [..._staff!.patents]..removeAt(index);
        newStaff = _staff!.copyWith(patents: newList.cast<PatentModel>());
        break;
      case 'journals':
        newList = [..._staff!.journals]..removeAt(index);
        newStaff = _staff!.copyWith(journals: newList.cast<JournalModel>());
        break;
      case 'expertises':
        newList = [..._staff!.expertises]..removeAt(index);
        newStaff = _staff!.copyWith(expertises: newList.cast<ExpertiseModel>());
        break;
      default:
        return;
    }

    _performSync(
      sectionName: key,
      apiKey: key,
      updatedList: newList,
      newStaffObject: newStaff,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_staff == null) {
      return const Scaffold(body: Center(child: Text("Failed to load profile")));
    }

    final s = _staff!;

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
                      Text(
                        "Profile",
                        style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      if (_isSyncing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your professional details and preferences",
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      color: AppColors.primaryLighter.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AVATAR / IDENTITY ──────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.white),
                    child: StaffAvatar(
                        avatarUrl: s.avatarUrl, initials: s.initials, size: 90),
                  ),
                  const SizedBox(height: 16),
                  Text(s.fullName,
                      style: Theme.of(context).textTheme.headlineLarge),
                  Text(s.designation,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.primary)),
                  Text(s.department,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── PERSONAL INFO ──────────────────────────────────────────────
            _sectionTitle("Personal Info"),
            _infoTile("Email", s.email, Icons.email_outlined),
            if (s.phone != null && s.phone!.isNotEmpty)
              _infoTile("Phone", s.phone!, Icons.phone_outlined),
            if (s.bio != null && s.bio!.isNotEmpty)
              _infoTile("Bio", s.bio!, Icons.info_outline),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // ── ACHIEVEMENTS ───────────────────────────────────────────────
            _sectionHeader("Achievements", onAdd: _showAddAchievementSheet),
            if (s.achievements.isEmpty)
              _emptyHint("No achievements registered yet.")
            else
              ...s.achievements.asMap().entries.map((e) => _itemCard(
                    title: e.value.title,
                    sub: e.value.description,
                    // FIX: use formattedDate instead of raw date string
                    date: e.value.formattedDate,
                    icon: Icons.emoji_events_outlined,
                    iconColor: AppColors.warning,
                    onDelete: () => _removeItem('achievements', e.key),
                  )),

            const SizedBox(height: 24),

            // ── PATENTS ────────────────────────────────────────────────────
            _sectionHeader("Patents", onAdd: _showAddPatentSheet),
            if (s.patents.isEmpty)
              _emptyHint("No patents registered yet.")
            else
              ...s.patents.asMap().entries.map((e) => _itemCard(
                    title: e.value.title,
                    sub: e.value.patentNumber != null
                        ? "Patent No: ${e.value.patentNumber}"
                        : null,
                    date: e.value.formattedIssueDate,
                    icon: Icons.workspace_premium_outlined,
                    iconColor: AppColors.info,
                    onDelete: () => _removeItem('patents', e.key),
                  )),

            const SizedBox(height: 24),

            // ── JOURNALS ──────────────────────────────────────────────────
            // FIX: this section was completely missing from the original UI
            _sectionHeader("Journals", onAdd: _showAddJournalSheet),
            if (s.journals.isEmpty)
              _emptyHint("No journals registered yet.")
            else
              ...s.journals.asMap().entries.map((e) => _itemCard(
                    title: e.value.title,
                    sub: e.value.journalName != null
                        ? "${e.value.journalName}"
                              "${e.value.publisher != null ? ' · ${e.value.publisher}' : ''}"
                        : e.value.publisher,
                    date: e.value.formattedPublicationDate,
                    icon: Icons.article_outlined,
                    iconColor: AppColors.success,
                    onDelete: () => _removeItem('journals', e.key),
                  )),

            const SizedBox(height: 24),

            // ── SUBJECT EXPERTISE ──────────────────────────────────────────
            _sectionHeader("Subject Expertise", onAdd: _showAddExpertiseSheet),
            if (s.expertises.isEmpty)
              _emptyHint("No expertise registered yet.")
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: s.expertises.asMap().entries.map((e) => Chip(
                  backgroundColor: AppColors.primaryLighter,
                  side: BorderSide.none,
                  avatar: CircleAvatar(
                    backgroundColor: _levelColor(e.value.proficiencyLevel),
                    radius: 6,
                  ),
                  label: Text(
                    "${e.value.subject}"
                    "${e.value.experienceText.isNotEmpty ? '  ${e.value.experienceText}' : ''}",
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onDeleted: () => _removeItem('expertises', e.key),
                  deleteIcon: const Icon(Icons.cancel,
                      size: 18, color: AppColors.primaryLight),
                )).toList(),
              ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // ── ACCOUNT SETTINGS ───────────────────────────────────────────
            _sectionTitle("Account Settings"),
            _settingSwitch(
              icon: Icons.notifications_active_outlined,
              title: "Push Notifications",
              value: s.pushNotificationsEnabled,
              onChanged: (v) => _updateSetting('push_notifications_enabled', v),
            ),
            _settingSwitch(
              icon: Icons.email_outlined,
              title: "Email Notifications",
              value: s.emailNotificationsEnabled,
              onChanged: (v) => _updateSetting('email_notifications_enabled', v),
            ),
            _settingSwitch(
              icon: Icons.visibility_outlined,
              title: "Show Availability",
              value: s.showAvailabilityToOthers,
              onChanged: (v) => _updateSetting('show_availability_to_others', v),
            ),

            const SizedBox(height: 48),

            // ── ACTIONS ────────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _showEditSheet,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text("Edit Profile"),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text("Logout"),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── UI COMPONENT HELPERS ──────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      );

  Widget _sectionHeader(String title, {required VoidCallback onAdd}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _sectionTitle(title),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
          ),
        ],
      );

  Widget _itemCard({
    required String title,
    String? sub,
    // FIX: date is now a pre-formatted string from model helpers
    String? date,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onDelete,
  }) {
    // Build subtitle safely — skip empty segments
    final subtitleParts = [
      if (sub != null && sub.isNotEmpty) sub,
      if (date != null && date.isNotEmpty) date,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        subtitle: subtitleParts.isNotEmpty
            ? Text(subtitleParts.join('\n'),
                style: Theme.of(context).textTheme.bodyMedium)
            : null,
        trailing: IconButton(
          icon:
              const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
          onPressed: onDelete,
        ),
      ),
    );
  }

  // FIX: wrap value in Flexible so long bio/email never overflows
  Widget _infoTile(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.primaryLight),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary, fontSize: 12)),
                  Text(value,
                      style: Theme.of(context).textTheme.bodyLarge,
                      softWrap: true),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _settingSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          secondary: Icon(icon, color: AppColors.primary),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          value: value,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      );

  Widget _emptyHint(String m) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(m,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic)),
      );

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return AppColors.info;
      case 'expert':
        return AppColors.primary;
      case 'advanced':
        return AppColors.success;
      default:
        return AppColors.primaryLight;
    }
  }

  // ── BOTTOM SHEETS ─────────────────────────────────────────────────────────

  void _openSheet({required String title, required Widget child}) {
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
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
          {int maxLines = 1, TextInputType? keyboardType}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      );

  // ── ADD ACHIEVEMENT ───────────────────────────────────────────────────────
  void _showAddAchievementSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dateCtrl = TextEditingController(); // "YYYY-MM-DD"

    _openSheet(
      title: "Add Achievement",
      child: Column(children: [
        _field(titleCtrl, "Title *"),
        const SizedBox(height: 12),
        _field(descCtrl, "Description", maxLines: 3),
        const SizedBox(height: 12),
        _field(dateCtrl, "Date (YYYY-MM-DD)",
            keyboardType: TextInputType.datetime),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final entry = AchievementModel(
                id: DateTime.now().millisecondsSinceEpoch,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
                date: dateCtrl.text.trim().isEmpty
                    ? null
                    : dateCtrl.text.trim(),
              );
              final list = [..._staff!.achievements, entry];
              _performSync(
                sectionName: "Achievement",
                apiKey: "achievements",
                updatedList: list,
                newStaffObject: _staff!.copyWith(achievements: list),
              );
            },
            child: const Text("Save Achievement"),
          ),
        ),
      ]),
    );
  }

  // ── ADD PATENT ────────────────────────────────────────────────────────────
  void _showAddPatentSheet() {
    final titleCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    _openSheet(
      title: "Add Patent",
      child: Column(children: [
        _field(titleCtrl, "Patent Title *"),
        const SizedBox(height: 12),
        _field(numberCtrl, "Patent Number"),
        const SizedBox(height: 12),
        _field(dateCtrl, "Issue Date (YYYY-MM-DD)",
            keyboardType: TextInputType.datetime),
        const SizedBox(height: 12),
        _field(descCtrl, "Description", maxLines: 3),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final entry = PatentModel(
                id: DateTime.now().millisecondsSinceEpoch,
                title: titleCtrl.text.trim(),
                patentNumber: numberCtrl.text.trim().isEmpty
                    ? null
                    : numberCtrl.text.trim(),
                issueDate: dateCtrl.text.trim().isEmpty
                    ? null
                    : dateCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
              );
              final list = [..._staff!.patents, entry];
              _performSync(
                sectionName: "Patent",
                apiKey: "patents",
                updatedList: list,
                newStaffObject: _staff!.copyWith(patents: list),
              );
            },
            child: const Text("Save Patent"),
          ),
        ),
      ]),
    );
  }

  // ── ADD JOURNAL ───────────────────────────────────────────────────────────
  void _showAddJournalSheet() {
    final titleCtrl = TextEditingController();
    final journalCtrl = TextEditingController();
    final publisherCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final doiCtrl = TextEditingController();

    _openSheet(
      title: "Add Journal",
      child: Column(children: [
        _field(titleCtrl, "Article Title *"),
        const SizedBox(height: 12),
        _field(journalCtrl, "Journal Name"),
        const SizedBox(height: 12),
        _field(publisherCtrl, "Publisher"),
        const SizedBox(height: 12),
        _field(dateCtrl, "Publication Date (YYYY-MM-DD)",
            keyboardType: TextInputType.datetime),
        const SizedBox(height: 12),
        _field(doiCtrl, "DOI (e.g. 10.1000/xyz123)"),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final entry = JournalModel(
                id: DateTime.now().millisecondsSinceEpoch,
                title: titleCtrl.text.trim(),
                journalName: journalCtrl.text.trim().isEmpty
                    ? null
                    : journalCtrl.text.trim(),
                publisher: publisherCtrl.text.trim().isEmpty
                    ? null
                    : publisherCtrl.text.trim(),
                publicationDate: dateCtrl.text.trim().isEmpty
                    ? null
                    : dateCtrl.text.trim(),
                doi: doiCtrl.text.trim().isEmpty
                    ? null
                    : doiCtrl.text.trim(),
              );
              final list = [..._staff!.journals, entry];
              _performSync(
                sectionName: "Journal",
                apiKey: "journals",
                updatedList: list,
                newStaffObject: _staff!.copyWith(journals: list),
              );
            },
            child: const Text("Save Journal"),
          ),
        ),
      ]),
    );
  }

  // ── ADD EXPERTISE ─────────────────────────────────────────────────────────
  void _showAddExpertiseSheet() {
    final subjectCtrl = TextEditingController();
    String selectedLevel = 'Intermediate';
    int yearsExp = 0;

    _openSheet(
      title: "Add Expertise",
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(children: [
          _field(subjectCtrl, "Subject *"),
          const SizedBox(height: 16),

          // Proficiency level selector
          DropdownButtonFormField<String>(
            value: selectedLevel,
            decoration: const InputDecoration(labelText: "Proficiency Level"),
            items: _proficiencyLevels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setLocal(() => selectedLevel = v!),
          ),
          const SizedBox(height: 16),

          // Years experience stepper
          Row(
            children: [
              Text("Years of experience: $yearsExp",
                  style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: yearsExp > 0
                    ? () => setLocal(() => yearsExp--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setLocal(() => yearsExp++),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (subjectCtrl.text.trim().isEmpty) return;
                final entry = ExpertiseModel(
                  id: DateTime.now().millisecondsSinceEpoch,
                  subject: subjectCtrl.text.trim(),
                  proficiencyLevel: selectedLevel,
                  yearsExperience: yearsExp,
                );
                final list = [..._staff!.expertises, entry];
                _performSync(
                  sectionName: "Expertise",
                  apiKey: "expertises",
                  updatedList: list,
                  newStaffObject: _staff!.copyWith(expertises: list),
                );
              },
              child: const Text("Save Expertise"),
            ),
          ),
        ]),
      ),
    );
  }

  // ── EDIT PROFILE ──────────────────────────────────────────────────────────
  void _showEditSheet() {
    final nameCtrl = TextEditingController(text: _staff!.fullName);
    final phoneCtrl = TextEditingController(text: _staff!.phone ?? '');
    final bioCtrl = TextEditingController(text: _staff!.bio ?? '');
    String selectedDept = _staff!.department;
    String selectedDesig = _staff!.designation;

    _openSheet(
      title: "Edit Profile",
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(children: [
          _field(nameCtrl, "Full Name *"),
          const SizedBox(height: 12),
          _field(phoneCtrl, "Phone",
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _field(bioCtrl, "Bio", maxLines: 3),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _departments.contains(selectedDept) ? selectedDept : null,
            decoration: const InputDecoration(labelText: "Department"),
            items: _departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setLocal(() => selectedDept = v!),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _designations.contains(selectedDesig) ? selectedDesig : null,
            decoration: const InputDecoration(labelText: "Designation"),
            items: _designations
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setLocal(() => selectedDesig = v!),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() => _isSyncing = true);
                try {
                  await _authService.updateProfile({
                    'full_name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    'bio': bioCtrl.text.trim().isEmpty
                        ? null
                        : bioCtrl.text.trim(),
                    'department': selectedDept,
                    'designation': selectedDesig,
                  });
                  // Reload fresh profile from server
                  final updated = await _authService.getProfile();
                  if (mounted) {
                    setState(() => _staff = updated);
                    _pop("Profile updated");
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Failed to update profile")));
                  }
                } finally {
                  if (mounted) setState(() => _isSyncing = false);
                }
              },
              child: const Text("Save Changes"),
            ),
          ),
        ]),
      ),
    );
  }

  // ── UTILITY ───────────────────────────────────────────────────────────────

  void _pop(String message) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }
}