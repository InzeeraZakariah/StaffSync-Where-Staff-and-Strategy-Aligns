import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../models/game_model.dart';
import '../../services/game_service.dart';
import '../../widgets/common_widgets.dart';
import 'play_game_screen.dart';
import 'leaderboard_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final _service = GameService();
  List<GameModel> _allGames = [];
  GameModel? _dailyChallenge;
  bool _isLoading = true;
  bool _isSeeding = false;
  String? _typeFilter;
  String? _diffFilter;

  final _types = [
    {'key': null, 'label': 'All'},
    {'key': 'quiz', 'label': 'Quiz'},
    {'key': 'true_false', 'label': 'True/False'},
    {'key': 'word_scramble', 'label': 'Scramble'},
    {'key': 'hangman', 'label': 'Hangman'},
  ];

  final _difficulties = [
    {'key': null, 'label': 'All'},
    {'key': 'easy', 'label': 'Easy'},
    {'key': 'medium', 'label': 'Medium'},
    {'key': 'hard', 'label': 'Hard'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getGames(gameType: _typeFilter, difficulty: _diffFilter),
      _service.getDailyChallenge(),
    ]);
    if (mounted) {
      setState(() {
        _allGames = results[0] as List<GameModel>;
        _dailyChallenge = results[1] as GameModel?;
        _isLoading = false;
      });
    }
  }

  Future<void> _seedGames() async {
    setState(() => _isSeeding = true);
    final result = await _service.seedGames();
    if (!mounted) return;
    setState(() => _isSeeding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Done'),
        backgroundColor: result['success'] == true
            ? AppColors.success
            : AppColors.error,
      ),
    );
    if (result['success'] == true) _load();
  }

  Future<void> _playGame(GameModel game) async {
    final result = await _service.startSession(game.id);
    if (!mounted) return;
    if (result['success']) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PlayGameScreen(session: result['data'] as GameSessionModel),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to start game'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Header ────────────────────────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 500),
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
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Games 🎮',
                            style: GoogleFonts.sora(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Play & climb the leaderboard',
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Leaderboard
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen(),
                              ),
                            ),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.leaderboard_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Seed games button
                          GestureDetector(
                            onTap: _isSeeding ? null : _seedGames,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: _isSeeding
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Stats row
                  if (!_isLoading) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statChip(
                          Icons.videogame_asset_rounded,
                          '${_allGames.length} Games',
                        ),
                        const SizedBox(width: 8),
                        if (_dailyChallenge != null)
                          _statChip(Icons.star_rounded, 'Daily Available'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ─── Filters ────────────────────────────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                // Type filter
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _types.length,
                    itemBuilder: (context, i) {
                      final t = _types[i];
                      final active = _typeFilter == t['key'];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _typeFilter = t['key']);
                          _load();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            t['label'] as String,
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Difficulty filter
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _difficulties.length,
                    itemBuilder: (context, i) {
                      final d = _difficulties[i];
                      final active = _diffFilter == d['key'];
                      final color = d['key'] == 'easy'
                          ? AppColors.success
                          : d['key'] == 'medium'
                          ? const Color(0xFFF59E0B)
                          : d['key'] == 'hard'
                          ? AppColors.error
                          : AppColors.primary;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _diffFilter = d['key']);
                          _load();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: active ? color : AppColors.border,
                            ),
                          ),
                          child: Text(
                            d['label'] as String,
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ─── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _allGames.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      children: [
                        // Daily challenge
                        if (_dailyChallenge != null) ...[
                          _buildDailyCard(),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          'All Games',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        ..._allGames.asMap().entries.map(
                          (e) => FadeInUp(
                            duration: const Duration(milliseconds: 400),
                            delay: Duration(milliseconds: e.key * 60),
                            child: _GameCard(
                              game: e.value,
                              onPlay: () => _playGame(e.value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCard() {
    final game = _dailyChallenge!;
    return GestureDetector(
      onTap: () => _playGame(game),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF9F67F8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '⭐ Daily Challenge',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    game.title,
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _badge(game.typeLabel),
                      const SizedBox(width: 8),
                      _badge('+${game.basePoints} pts'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(game.typeIcon, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: GoogleFonts.sora(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videogame_asset_off_rounded,
              size: 72,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No Games Yet',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the ⬇ button in the top right to load 20 sample games',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _isSeeding ? 'Loading...' : 'Load Sample Games',
              onPressed: _isSeeding ? () {} : _seedGames,
              isLoading: _isSeeding,
              icon: Icons.download_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback onPlay;

  const _GameCard({required this.game, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: game.difficultyColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(game.typeIcon, color: game.difficultyColor, size: 26),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _chip(game.typeLabel, AppColors.primary),
                    const SizedBox(width: 6),
                    _chip(game.difficultyLabel, game.difficultyColor),
                    const SizedBox(width: 6),
                    _chip('+${game.basePoints} pts', AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${game.playCount} plays',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Play button
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.sora(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
