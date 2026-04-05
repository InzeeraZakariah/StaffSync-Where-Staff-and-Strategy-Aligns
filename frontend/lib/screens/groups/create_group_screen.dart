import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/group_service.dart';
import '../../widgets/common_widgets.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _groupService = GroupService();
  String? _selectedDept;
  bool _isLoading = false;

  final List<String> _departments = [
    'AI&DS',
    'CSE',
    'IT',
    'ECE',
    'EEE',
    'MECH',
    'CIVIL',
    'MBA',
    'MCA',
    'ADMIN',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final result = await _groupService.createGroup(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      department: _selectedDept,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to create group'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Group'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group avatar preview
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: _nameController,
                    builder: (_, __, ___) {
                      final name = _nameController.text.trim();
                      final initials = name.isEmpty
                          ? '?'
                          : (name.split(' ').length >= 2
                                    ? '${name.split(' ')[0][0]}${name.split(' ')[1][0]}'
                                    : name.substring(
                                        0,
                                        name.length >= 2 ? 2 : 1,
                                      ))
                                .toUpperCase();
                      return Text(
                        initials,
                        style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            AppTextField(
              label: 'Group Name',
              hint: 'e.g. CSE Department, HODs Group',
              controller: _nameController,
              prefixIcon: Icons.group_outlined,
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Description (Optional)',
              hint: 'What is this group for?',
              controller: _descController,
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedDept,
              onChanged: (v) => setState(() => _selectedDept = v),
              decoration: InputDecoration(
                labelText: 'Department (Optional)',
                hintText: 'Select department',
                prefixIcon: const Icon(
                  Icons.school_outlined,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              style: GoogleFonts.sora(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              dropdownColor: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    'None',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ),
                ..._departments.map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d, style: GoogleFonts.sora(fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            PrimaryButton(
              label: 'Create Group',
              onPressed: _create,
              isLoading: _isLoading,
              icon: Icons.group_add_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
