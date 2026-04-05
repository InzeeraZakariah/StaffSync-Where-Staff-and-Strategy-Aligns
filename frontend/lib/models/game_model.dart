import 'package:flutter/material.dart';

class GameModel {
  final int id;
  final String gameType;
  final String difficulty;
  final String category;
  final String title;
  final String? description;
  final bool isDaily;
  final int playCount;
  final int basePoints;
  final Map<String, dynamic> payload;

  const GameModel({
    required this.id,
    required this.gameType,
    required this.difficulty,
    required this.category,
    required this.title,
    this.description,
    required this.isDaily,
    required this.playCount,
    required this.basePoints,
    required this.payload,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) => GameModel(
        id:          json['id'],
        gameType:    json['game_type'],
        difficulty:  json['difficulty'],
        category:    json['category'],
        title:       json['title'],
        description: json['description'],
        isDaily:     json['is_daily'] ?? false,
        playCount:   json['play_count'] ?? 0,
        basePoints:  json['base_points'] ?? 10,
        payload:     Map<String, dynamic>.from(json['payload'] ?? {}),
      );

  Color get difficultyColor {
    switch (difficulty) {
      case 'easy':   return const Color(0xFF10B981);
      case 'medium': return const Color(0xFFF59E0B);
      case 'hard':   return const Color(0xFFEF4444);
      default:       return const Color(0xFF6B7280);
    }
  }

  IconData get typeIcon {
    switch (gameType) {
      case 'quiz':          return Icons.quiz_rounded;
      case 'word_scramble': return Icons.shuffle_rounded;
      case 'hangman':       return Icons.abc_rounded;
      case 'word_search':   return Icons.search_rounded;
      case 'true_false':    return Icons.thumbs_up_down_rounded;
      default:              return Icons.games_rounded;
    }
  }

  String get typeLabel {
    switch (gameType) {
      case 'quiz':          return 'Quiz';
      case 'word_scramble': return 'Word Scramble';
      case 'hangman':       return 'Hangman';
      case 'word_search':   return 'Word Search';
      case 'true_false':    return 'True / False';
      default:              return gameType;
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy':   return 'Easy';
      case 'medium': return 'Medium';
      case 'hard':   return 'Hard';
      default:       return difficulty;
    }
  }
}

class GameSessionModel {
  final int sessionId;
  final int gameId;
  final String gameType;
  final String title;
  final String difficulty;
  final String category;
  final Map<String, dynamic> payload;
  final int basePoints;
  final String? startedAt;

  const GameSessionModel({
    required this.sessionId,
    required this.gameId,
    required this.gameType,
    required this.title,
    required this.difficulty,
    required this.category,
    required this.payload,
    required this.basePoints,
    this.startedAt,
  });

  factory GameSessionModel.fromJson(Map<String, dynamic> json) =>
      GameSessionModel(
        sessionId:  json['session_id'],
        gameId:     json['game_id'],
        gameType:   json['game_type'],
        title:      json['title'],
        difficulty: json['difficulty'],
        category:   json['category'],
        payload:    Map<String, dynamic>.from(json['payload'] ?? {}),
        basePoints: json['base_points'] ?? 10,
        startedAt:  json['started_at'],
      );
}

class AnswerResult {
  final bool isCorrect;
  final int score;
  final dynamic correctAnswer;
  final String? explanation;
  final int sessionId;
  final int totalScore;

  const AnswerResult({
    required this.isCorrect,
    required this.score,
    this.correctAnswer,
    this.explanation,
    required this.sessionId,
    required this.totalScore,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
        isCorrect:     json['is_correct'],
        score:         json['score'],
        correctAnswer: json['correct_answer'],
        explanation:   json['explanation'],
        sessionId:     json['session_id'],
        totalScore:    json['total_score'],
      );
}

class LeaderboardEntry {
  final int rank;
  final int staffId;
  final String fullName;
  final String department;
  final String? avatarUrl;
  final int totalScore;
  final int gamesPlayed;
  final int gamesWon;
  final int currentStreak;
  final int bestStreak;

  const LeaderboardEntry({
    required this.rank,
    required this.staffId,
    required this.fullName,
    required this.department,
    this.avatarUrl,
    required this.totalScore,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank:          json['rank'],
        staffId:       json['staff_id'],
        fullName:      json['full_name'],
        department:    json['department'],
        avatarUrl:     json['avatar_url'],
        totalScore:    json['total_score'],
        gamesPlayed:   json['games_played'],
        gamesWon:      json['games_won'],
        currentStreak: json['current_streak'],
        bestStreak:    json['best_streak'],
      );

  String get initials {
    final p = fullName.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : fullName.substring(0, 2).toUpperCase();
  }
}