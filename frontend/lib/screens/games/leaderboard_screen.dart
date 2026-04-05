import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../models/game_model.dart';
import '../../services/game_service.dart';
import '../../widgets/common_widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _service = GameService();
  List<LeaderboardEntry> _entries = [];
  Map<String, dynamic>? _myStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _service.getLeaderboard();
    if (mounted) {
      setState(() {
        _entries  = result['entries'] as List<LeaderboardEntry>;
        _myStats  = result['my_stats'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // Header
        FadeInDown(
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 4),
                Text('🏆 Leaderboard', style: GoogleFonts.sora(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ]),

              // My stats
              if (_myStats != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _myStat('My Score', '${_myStats!['total_score']}'),
                      _divider(),
                      _myStat('Played', '${_myStats!['games_played']}'),
                      _divider(),
                      _myStat('Won', '${_myStats!['games_won']}'),
                      _divider(),
                      _myStat('Streak 🔥', '${_myStats!['current_streak']}'),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ),

        // Top 3 podium
        if (!_isLoading && _entries.length >= 3) ...[
          const SizedBox(height: 20),
          _buildPodium(),
          const SizedBox(height: 16),
          const Divider(indent: 20, endIndent: 20),
        ],

        // Rest of leaderboard
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _entries.isEmpty
                  ? EmptyState(
                      icon: Icons.leaderboard_rounded,
                      title: 'No rankings yet',
                      subtitle: 'Play games to appear on the leaderboard!')
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: _entries.length > 3 ? _entries.length - 3 : 0,
                        itemBuilder: (context, i) {
                          final entry = _entries[i + 3];
                          return FadeInUp(
                            duration: const Duration(milliseconds: 400),
                            delay: Duration(milliseconds: i * 50),
                            child: _LeaderboardRow(entry: entry),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildPodium() {
    final top3   = _entries.take(3).toList();
    final first  = top3[0];
    final second = top3.length > 1 ? top3[1] : null;
    final third  = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2nd
          if (second != null) Expanded(child: _PodiumCard(
              entry: second, height: 80, emoji: '🥈')),
          const SizedBox(width: 8),
          // 1st
          Expanded(child: _PodiumCard(entry: first, height: 110, emoji: '🥇')),
          const SizedBox(width: 8),
          // 3rd
          if (third != null) Expanded(child: _PodiumCard(
              entry: third, height: 60, emoji: '🥉')),
        ],
      ),
    );
  }

  Widget _myStat(String label, String value) => Column(children: [
    Text(value, style: GoogleFonts.sora(
        fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
    Text(label, style: GoogleFonts.sora(
        fontSize: 10, color: Colors.white.withOpacity(0.8))),
  ]);

  Widget _divider() => Container(
        width: 1, height: 28,
        color: Colors.white.withOpacity(0.3));
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final String emoji;

  const _PodiumCard({
    required this.entry,
    required this.height,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      StaffAvatar(
        avatarUrl: entry.avatarUrl,
        initials: entry.initials,
        size: 44,
      ),
      const SizedBox(height: 6),
      Text(entry.fullName.split(' ').first,
          style: GoogleFonts.sora(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Text('${entry.totalScore} pts',
          style: GoogleFonts.sora(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.primary)),
      const SizedBox(height: 6),
      Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12))),
        child: Center(
          child: Text('#${entry.rank}',
              style: GoogleFonts.sora(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ),
      ),
    ]);
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : entry.rank == 3
                ? const Color(0xFFCD7F32)
                : AppColors.textHint;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Rank
        SizedBox(
          width: 36,
          child: Text('#${entry.rank}',
              style: GoogleFonts.sora(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: rankColor)),
        ),

        // Avatar
        StaffAvatar(
          avatarUrl: entry.avatarUrl,
          initials: entry.initials,
          size: 38,
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(entry.fullName,
              style: GoogleFonts.sora(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          Row(children: [
            Text(entry.department,
                style: GoogleFonts.sora(
                    fontSize: 11, color: AppColors.textHint)),
            if (entry.currentStreak > 0) ...[
              const SizedBox(width: 6),
              Text('🔥 ${entry.currentStreak}',
                  style: GoogleFonts.sora(
                      fontSize: 11, color: AppColors.error)),
            ],
          ]),
        ])),

        // Score
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${entry.totalScore}',
              style: GoogleFonts.sora(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          Text('pts',
              style: GoogleFonts.sora(
                  fontSize: 10, color: AppColors.textHint)),
        ]),
      ]),
    );
  }
}