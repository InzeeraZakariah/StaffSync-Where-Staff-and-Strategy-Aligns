import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../models/game_model.dart';
import '../../services/game_service.dart';
import '../../widgets/common_widgets.dart';

class PlayGameScreen extends StatefulWidget {
  final GameSessionModel session;
  const PlayGameScreen({super.key, required this.session});

  @override
  State<PlayGameScreen> createState() => _PlayGameScreenState();
}

class _PlayGameScreenState extends State<PlayGameScreen> {
  final _service = GameService();
  late Stopwatch _stopwatch;
  late Timer _timer;
  int _elapsedSecs = 0;
  bool _submitting = false;
  AnswerResult? _result;

  // For Quiz / True-False
  String? _selectedOption;

  // For Word Scramble / Hangman
  final _answerCtrl = TextEditingController();

  // For Hangman
  List<String> _wrongGuesses = [];
  Set<String> _guessedLetters = {};
  int _maxAttempts = 6;

  String get _gameType => widget.session.gameType;
  Map<String, dynamic> get _payload => widget.session.payload;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSecs++);
    });
    if (_gameType == 'hangman') {
      _maxAttempts = (_payload['max_attempts'] ?? 6) as int;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(dynamic answer) async {
    if (_submitting || _result != null) return;
    setState(() => _submitting = true);
    _timer.cancel();

    final result = await _service.submitAnswer(
      sessionId:     widget.session.sessionId,
      answer:        answer,
      timeTakenSecs: _elapsedSecs,
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result['success']) {
        _result = result['data'] as AnswerResult;
      }
    });
  }

  void _guessLetter(String letter) {
    if (_guessedLetters.contains(letter) || _result != null) return;
    setState(() => _guessedLetters.add(letter));

    final word = (_payload['word'] as String? ?? '').toUpperCase();
    // Check if word solved
    bool solved = word.split('').every((c) => _guessedLetters.contains(c));

    if (!word.contains(letter)) {
      setState(() => _wrongGuesses.add(letter));
      if (_wrongGuesses.length >= _maxAttempts) {
        _submit(word); // auto-fail
      }
    } else if (solved) {
      _submit(word);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.session.title,
            style: Theme.of(context).textTheme.headlineMedium,
            overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            if (_result == null) {
              await _service.abandonSession(widget.session.sessionId);
            }
            if (mounted) Navigator.pop(context);
          },
        ),
        actions: [
          // Timer
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _elapsedSecs > 60
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined,
                      size: 14,
                      color: _elapsedSecs > 60
                          ? AppColors.error
                          : AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${(_elapsedSecs ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSecs % 60).toString().padLeft(2, '0')}',
                    style: GoogleFonts.sora(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _elapsedSecs > 60 ? AppColors.error : AppColors.primary),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: _result != null
          ? _buildResultView()
          : _buildGameView(),
    );
  }

  // ─── Game View ─────────────────────────────────────────────────────────────

  Widget _buildGameView() {
    switch (_gameType) {
      case 'quiz':         return _buildQuizView();
      case 'true_false':   return _buildTrueFalseView();
      case 'word_scramble':return _buildWordScrambleView();
      case 'hangman':      return _buildHangmanView();
      default:             return _buildQuizView();
    }
  }

  // ─── QUIZ ──────────────────────────────────────────────────────────────────

  Widget _buildQuizView() {
    final question = _payload['question'] as String? ?? '';
    final options  = List<String>.from(_payload['options'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _difficultyBadge(),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
          child: Text(question, style: GoogleFonts.sora(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary, height: 1.5)),
        ),
        const SizedBox(height: 24),
        Text('Choose your answer',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...options.asMap().entries.map((e) {
          final isSelected = _selectedOption == e.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedOption = e.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLighter : AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1)),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                    shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      ['A','B','C','D'][e.key],
                      style: GoogleFonts.sora(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value.replaceFirst(RegExp(r'^[ABCD]\.\s*'), ''),
                    style: GoogleFonts.sora(fontSize: 14, color: AppColors.textPrimary))),
              ]),
            ),
          );
        }),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Submit Answer',
          onPressed: _selectedOption == null
              ? () {}
              : () => _submit(_selectedOption![0]),
          isLoading: _submitting,
          icon: Icons.check_rounded,
        ),
      ]),
    );
  }

  // ─── TRUE / FALSE ──────────────────────────────────────────────────────────

  Widget _buildTrueFalseView() {
    final statement = _payload['statement'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _difficultyBadge(),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
          child: Column(children: [
            const Icon(Icons.help_outline_rounded,
                size: 40, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(statement, style: GoogleFonts.sora(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary, height: 1.5),
                textAlign: TextAlign.center),
          ]),
        ),
        const Spacer(),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _submit(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEF4444))),
                child: Column(children: [
                  const Icon(Icons.close_rounded,
                      color: Color(0xFFEF4444), size: 36),
                  const SizedBox(height: 8),
                  Text('FALSE', style: GoogleFonts.sora(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444))),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => _submit(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981))),
                child: Column(children: [
                  const Icon(Icons.check_rounded,
                      color: Color(0xFF10B981), size: 36),
                  const SizedBox(height: 8),
                  Text('TRUE', style: GoogleFonts.sora(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981))),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 32),
      ]),
    );
  }

  // ─── WORD SCRAMBLE ─────────────────────────────────────────────────────────

  Widget _buildWordScrambleView() {
    final scrambled = _payload['scrambled'] as String? ?? '';
    final hint      = _payload['hint'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        _difficultyBadge(),
        const SizedBox(height: 24),
        Text('Unscramble this word!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        // Scrambled word display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(scrambled.split('').join(' '),
                style: GoogleFonts.sora(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 8)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
              child: Text('${scrambled.length} letters',
                  style: GoogleFonts.sora(
                      fontSize: 13, color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        if (hint.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A))),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(hint,
                  style: GoogleFonts.sora(fontSize: 13,
                      color: AppColors.textPrimary))),
            ]),
          ),
          const SizedBox(height: 20),
        ],
        AppTextField(
          label: 'Your Answer',
          hint: 'Type the unscrambled word...',
          controller: _answerCtrl,
          prefixIcon: Icons.abc_rounded,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Submit',
          onPressed: _answerCtrl.text.trim().isEmpty
              ? () {}
              : () => _submit(_answerCtrl.text.trim().toUpperCase()),
          isLoading: _submitting,
          icon: Icons.check_rounded,
        ),
      ]),
    );
  }

  // ─── HANGMAN ───────────────────────────────────────────────────────────────

  Widget _buildHangmanView() {
    final hint       = _payload['hint'] as String? ?? '';
    final wordLength = (_payload['word_length'] as int?) ?? 5;
    final remaining  = _maxAttempts - _wrongGuesses.length;
    final word       = (_payload['word'] as String? ?? '').toUpperCase();
    final display    = word.isNotEmpty
        ? word.split('').map((c) => _guessedLetters.contains(c) ? c : '_').join(' ')
        : List.generate(wordLength, (_) => '_').join(' ');

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _difficultyBadge(),
            const SizedBox(height: 16),
            // Attempts left
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ...List.generate(_maxAttempts, (i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  i < remaining ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: i < remaining ? AppColors.error : AppColors.border,
                  size: 22),
              )),
            ]),
            const SizedBox(height: 8),
            Text('$remaining attempts left',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: remaining <= 2 ? AppColors.error : AppColors.textHint)),
            const SizedBox(height: 24),
            // Word display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border)),
              child: Text(
                display,
                style: GoogleFonts.sora(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: 4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (hint.isNotEmpty) Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A))),
              child: Row(children: [
                const Text('💡 '),
                Expanded(child: Text(hint,
                    style: GoogleFonts.sora(fontSize: 12))),
              ]),
            ),
            if (_wrongGuesses.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Wrong guesses: ${_wrongGuesses.join(', ')}',
                  style: GoogleFonts.sora(
                      fontSize: 13, color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            // Keyboard
            _buildKeyboard(),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildKeyboard() {
    const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    return Column(children: rows.map((row) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.split('').map((letter) {
          final isWrong    = _wrongGuesses.contains(letter);
          final isCorrect  = _guessedLetters.contains(letter) && !isWrong;
          final isGuessed  = _guessedLetters.contains(letter);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: isGuessed ? null : () => _guessLetter(letter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 40,
                decoration: BoxDecoration(
                  color: isWrong
                      ? AppColors.error.withOpacity(0.15)
                      : isCorrect
                          ? AppColors.success.withOpacity(0.15)
                          : isGuessed
                              ? AppColors.surfaceVariant
                              : AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWrong
                        ? AppColors.error
                        : isCorrect
                            ? AppColors.success
                            : AppColors.border)),
                child: Center(
                  child: Text(letter,
                      style: GoogleFonts.sora(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isWrong
                            ? AppColors.error
                            : isCorrect
                                ? AppColors.success
                                : isGuessed
                                    ? AppColors.textHint
                                    : AppColors.textPrimary)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    )).toList());
  }

  // ─── Result View ───────────────────────────────────────────────────────────

  Widget _buildResultView() {
    final r = _result!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FadeInDown(
            duration: const Duration(milliseconds: 600),
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: r.isCorrect
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle),
              child: Icon(
                r.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: r.isCorrect ? AppColors.success : AppColors.error,
                size: 60),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 100),
            child: Text(
              r.isCorrect ? '🎉 Correct!' : '😞 Wrong Answer',
              style: GoogleFonts.sora(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: r.isCorrect ? AppColors.success : AppColors.error),
            ),
          ),
          const SizedBox(height: 16),

          // Score
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _scoreStat('Points Earned', '+${r.score}',
                      r.isCorrect ? AppColors.success : AppColors.textHint),
                  _scoreStat('Total Score', '${r.totalScore}', AppColors.primary),
                  _scoreStat('Time', '${_elapsedSecs}s', AppColors.textSecondary),
                ]),
              ]),
            ),
          ),

          // Correct answer
          if (!r.isCorrect && r.correctAnswer != null) ...[
            const SizedBox(height: 16),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 300),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withOpacity(0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Correct Answer',
                      style: GoogleFonts.sora(
                          fontSize: 12, color: AppColors.success,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${r.correctAnswer}',
                      style: GoogleFonts.sora(
                          fontSize: 15, color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],

          // Explanation
          if (r.explanation != null && r.explanation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 400),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('💡 ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(r.explanation!,
                      style: GoogleFonts.sora(
                          fontSize: 13, color: AppColors.textPrimary))),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 32),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 500),
            child: PrimaryButton(
              label: 'Back to Games',
              onPressed: () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _scoreStat(String label, String value, Color color) => Column(children: [
    Text(value, style: GoogleFonts.sora(
        fontSize: 22, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 4),
    Text(label, style: GoogleFonts.sora(
        fontSize: 11, color: AppColors.textHint)),
  ]);

  Widget _difficultyBadge() {
    final colors = {
      'easy':   AppColors.success,
      'medium': const Color(0xFFF59E0B),
      'hard':   AppColors.error,
    };
    final color = colors[widget.session.difficulty] ?? AppColors.primary;
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
        child: Text(
          widget.session.difficulty.toUpperCase(),
          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(12)),
        child: Text(
          '+${widget.session.basePoints} pts',
          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
      ),
    ]);
  }
}