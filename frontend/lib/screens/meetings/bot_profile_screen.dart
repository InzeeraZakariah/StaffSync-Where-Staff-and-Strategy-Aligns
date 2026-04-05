// bot profile screen

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class BotProfileScreen extends StatefulWidget {
  const BotProfileScreen({super.key});

  @override
  State<BotProfileScreen> createState() => _BotProfileScreenState();
}

class _BotProfileScreenState extends State<BotProfileScreen> {
  final _nameController = TextEditingController(text: 'My AI Assistant');
  final _personaController = TextEditingController();
  bool _autoJoin = true;
  bool _notifyAfterSummary = true;

  @override
  void dispose() {
    _nameController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('AI Bot Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot avatar preview
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            AppTextField(
              label: 'Bot Name',
              hint: 'e.g. Prof. Priya\'s Assistant',
              controller: _nameController,
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Bot Persona (Optional)',
              hint: 'Describe how the bot should represent you...',
              controller: _personaController,
              prefixIcon: Icons.psychology_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            Text(
              'Bot Behaviour',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _ToggleRow(
              icon: Icons.login_rounded,
              title: 'Auto Join',
              subtitle: 'Bot joins automatically when you\'re unavailable',
              value: _autoJoin,
              onChanged: (v) => setState(() => _autoJoin = v),
            ),
            const SizedBox(height: 10),
            _ToggleRow(
              icon: Icons.notifications_outlined,
              title: 'Notify After Summary',
              subtitle: 'Get notified when AI summary is ready',
              value: _notifyAfterSummary,
              onChanged: (v) => setState(() => _notifyAfterSummary = v),
            ),
            const SizedBox(height: 32),

            PrimaryButton(
              label: 'Save Bot Profile',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bot profile saved!')),
                );
              },
              icon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
