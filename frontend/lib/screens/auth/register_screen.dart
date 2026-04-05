import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/main_nav_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Step 1 controllers
  final _nameController       = TextEditingController();
  final _emailController      = TextEditingController();
  final _passwordController   = TextEditingController();
  final _confirmController    = TextEditingController();

  // Step 2 controllers
  final _phoneController      = TextEditingController();
  final _employeeIdController = TextEditingController();

  final _authService = AuthService();
  int  _currentStep = 0;
  bool _isLoading   = false;

  String? _selectedDepartment;
  String? _selectedDesignation;

  final _departments = [
    'CSE','IT','ECE','EEE','MECH','CIVIL','MBA','MCA','ADMIN','OTHER'
  ];

  final _designations = [
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Head of Department',
    'Principal',
    'Lab Instructor',
    'Admin Staff',
    'Other',
  ];

  // Exact values the backend expects
  final _designationValues = {
    'Professor':            'Professor',
    'Associate Professor':  'Associate Professor',
    'Assistant Professor':  'Assistant Professor',
    'Head of Department':   'Head of Department',
    'Principal':            'Principal',
    'Lab Instructor':       'Lab Instructor',
    'Admin Staff':          'Admin Staff',
    'Other':                'Other',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  // ─── Step 1 Validation ────────────────────────────────────────────────────

  void _goToStep2() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.length < 2) {
      _showError('Please enter your full name'); return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email'); return;
    }
    if (pass.length < 8) {
      _showError('Password must be at least 8 characters'); return;
    }
    if (!pass.contains(RegExp(r'[A-Z]'))) {
      _showError('Password must contain at least 1 uppercase letter'); return;
    }
    if (!pass.contains(RegExp(r'[0-9]'))) {
      _showError('Password must contain at least 1 number'); return;
    }
    if (pass != confirm) {
      _showError('Passwords do not match'); return;
    }

    setState(() => _currentStep = 1);
  }

  // ─── Step 2 Submit ────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (_selectedDepartment == null) {
      _showError('Please select your department'); return;
    }
    if (_selectedDesignation == null) {
      _showError('Please select your designation'); return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      fullName:    _nameController.text.trim(),
      email:       _emailController.text.trim(),
      password:    _passwordController.text,
      department:  _selectedDepartment!,
      designation: _designationValues[_selectedDesignation!] ?? _selectedDesignation!,
      phone:       _phoneController.text.trim().isEmpty
                       ? null : _phoneController.text.trim(),
      employeeId:  _employeeIdController.text.trim().isEmpty
                       ? null : _employeeIdController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      // Auto-login after register
      final loginResult = await _authService.login(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (loginResult['success']) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
          (route) => false,
        );
      } else {
        // Login failed — go back to login screen
        Navigator.of(context).pop();
      }
    } else {
      _showError(result['message'] ?? 'Registration failed. Please try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [

          // Header
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => _currentStep == 1
                      ? setState(() => _currentStep = 0)
                      : Navigator.of(context).pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Create Account', style: GoogleFonts.sora(
                    fontSize: 26, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                const SizedBox(height: 4),
                Text('Step ${_currentStep + 1} of 2', style: GoogleFonts.sora(
                    fontSize: 13, color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 16),

                // Progress bar
                Row(children: List.generate(2, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _currentStep
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                  ),
                ))),
              ]),
            ),
          ),

          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
            ),
          ),

          // Bottom button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: _currentStep == 0
                ? PrimaryButton(
                    label: 'Continue',
                    onPressed: _goToStep2,
                    icon: Icons.arrow_forward_rounded,
                  )
                : Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        child: Text('Back', style: GoogleFonts.sora(
                            fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'Create Account',
                        onPressed: _handleRegister,
                        isLoading: _isLoading,
                      ),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }

  // ─── Step 1 — Personal Info ───────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Personal Info', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Tell us about yourself',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),

      AppTextField(
        label: 'Full Name',
        hint: 'Dr. Priya Nair',
        controller: _nameController,
        prefixIcon: Icons.person_outline_rounded,
      ),
      const SizedBox(height: 14),

      AppTextField(
        label: 'Email Address',
        hint: 'staff@college.edu',
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        prefixIcon: Icons.email_outlined,
      ),
      const SizedBox(height: 14),

      AppTextField(
        label: 'Password',
        hint: 'Min 8 chars, 1 uppercase, 1 number',
        controller: _passwordController,
        isPassword: true,
        prefixIcon: Icons.lock_outline_rounded,
      ),
      const SizedBox(height: 14),

      AppTextField(
        label: 'Confirm Password',
        hint: 'Re-enter your password',
        controller: _confirmController,
        isPassword: true,
        prefixIcon: Icons.lock_outline_rounded,
      ),
    ]);
  }

  // ─── Step 2 — College Info ────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('College Info', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Your role at the college',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),

      // Department
      _buildDropdown(
        label: 'Department *',
        hint: 'Select your department',
        value: _selectedDepartment,
        items: _departments,
        icon: Icons.school_outlined,
        onChanged: (v) => setState(() => _selectedDepartment = v),
      ),
      const SizedBox(height: 14),

      // Designation
      _buildDropdown(
        label: 'Designation *',
        hint: 'Select your designation',
        value: _selectedDesignation,
        items: _designations,
        icon: Icons.badge_outlined,
        onChanged: (v) => setState(() => _selectedDesignation = v),
      ),
      const SizedBox(height: 14),

      AppTextField(
        label: 'Phone Number (Optional)',
        hint: '+91 98765 43210',
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        prefixIcon: Icons.phone_outlined,
      ),
      const SizedBox(height: 14),

      AppTextField(
        label: 'Employee ID (Optional)',
        hint: 'e.g. CSE2024001',
        controller: _employeeIdController,
        prefixIcon: Icons.badge_outlined,
      ),
    ]);
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value != null ? AppColors.primary : AppColors.border,
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, color: AppColors.primaryLight, size: 18),
            const SizedBox(width: 10),
            Text(hint, style: GoogleFonts.sora(
                fontSize: 14, color: AppColors.textHint)),
          ]),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textHint),
          dropdownColor: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          style: GoogleFonts.sora(
              fontSize: 14, color: AppColors.textPrimary),
          onChanged: onChanged,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Row(children: [
              Icon(icon, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 10),
              Text(item, style: GoogleFonts.sora(fontSize: 14)),
            ]),
          )).toList(),
        ),
      ),
    );
  }
}