import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../models/group_model.dart';
import '../../models/staff_model.dart';
import '../../services/group_service.dart';

class AddMembersScreen extends StatefulWidget {
  final GroupModel group;

  const AddMembersScreen({super.key, required this.group});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final _groupService = GroupService();
  final _searchController = TextEditingController();

  List<StaffModel> _allStaff = [];
  List<StaffModel> _filtered = [];
  Set<int> _selectedIds = {};
  Set<int> _existingMemberIds = {};
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate existing member ids so we can grey them out
    _existingMemberIds = widget.group.members
        .map((m) => m.id)
        .toSet();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final staff = await _groupService.getAllStaff();
    if (mounted) {
      setState(() {
        _allStaff = staff;
        _filtered = staff;
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _allStaff
          : _allStaff.where((s) {
              return s.fullName.toLowerCase().contains(q) ||
                  s.department.toLowerCase().contains(q) ||
                  s.designation.toLowerCase().contains(q);
            }).toList();
    });
  }

  void _toggleSelect(int id) {
    if (_existingMemberIds.contains(id)) return; // already a member
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _addMembers() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isAdding = true);

    final result = await _groupService.addMembers(
      groupId: widget.group.id,
      memberIds: _selectedIds.toList(),
    );

    if (!mounted) return;
    setState(() => _isAdding = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${_selectedIds.length} member(s) successfully!',
            style: GoogleFonts.sora(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true); // return true = refresh needed
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Failed to add members.',
            style: GoogleFonts.sora(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Color _deptColor(String dept) {
    const colors = {
      'AI&DS': Color.fromARGB(255, 180, 200, 0),
      'CSE': Color(0xFF7C3AED),
      'IT': Color(0xFF2563EB),
      'ECE': Color(0xFF059669),
      'HOD': Color(0xFFDC2626),
      'ADMIN': Color(0xFFD97706),
    };
    return colors[dept.toUpperCase()] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Members',
                              style: GoogleFonts.sora(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.group.name,
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedIds.isNotEmpty)
                        FadeIn(
                          child: GestureDetector(
                            onTap: _isAdding ? null : _addMembers,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: _isAdding
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Text(
                                      'Add (${_selectedIds.length})',
                                      style: GoogleFonts.sora(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, dept or role...',
                        hintStyle: GoogleFonts.sora(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Selected chips ────────────────────────────────────────────────
          if (_selectedIds.isNotEmpty)
            FadeInDown(
              duration: const Duration(milliseconds: 300),
              child: Container(
                height: 54,
                margin: const EdgeInsets.only(top: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _selectedIds.map((id) {
                    final staff = _allStaff.firstWhere((s) => s.id == id);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            staff.fullName.split(' ').first,
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _toggleSelect(id),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ── Staff list ────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? _buildShimmer()
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 56,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No staff found',
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final s = _filtered[i];
                          final isExisting = _existingMemberIds.contains(s.id);
                          final isSelected = _selectedIds.contains(s.id);
                          final color = _deptColor(s.department);

                          return FadeInUp(
                            duration: const Duration(milliseconds: 350),
                            delay: Duration(milliseconds: i * 40),
                            child: GestureDetector(
                              onTap: () => _toggleSelect(s.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.07)
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.4)
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isExisting
                                              ? [Colors.grey.shade300, Colors.grey.shade200]
                                              : [color, color.withOpacity(0.7)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          s.initials,
                                          style: GoogleFonts.sora(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isExisting
                                                ? Colors.grey
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.fullName,
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isExisting
                                                  ? AppColors.textHint
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isExisting
                                                      ? Colors.grey.withOpacity(0.1)
                                                      : color.withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  s.department,
                                                  style: GoogleFonts.sora(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: isExisting
                                                        ? Colors.grey
                                                        : color,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  s.designation,
                                                  style: GoogleFonts.sora(
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Checkbox / already member badge
                                    if (isExisting)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Added',
                                          style: GoogleFonts.sora(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    else
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.border,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // ── Bottom Add button ─────────────────────────────────────────────────
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _isAdding ? null : _addMembers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isAdding
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Add ${_selectedIds.length} Member${_selectedIds.length > 1 ? 's' : ''}',
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: 130,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}