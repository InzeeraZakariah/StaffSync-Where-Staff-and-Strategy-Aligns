import 'package:dio/dio.dart';
import '../models/game_model.dart';
import 'api_client.dart';

class GameService {
  final _client = ApiClient();

  // ─── Games List ───────────────────────────────────────────────────────────

  Future<List<GameModel>> getGames({
    String? gameType,
    String? difficulty,
    String? category,
  }) async {
    try {
      final response = await _client.dio.get(
        '/games/',
        queryParameters: {
          if (gameType != null)  'game_type':  gameType,
          if (difficulty != null) 'difficulty': difficulty,
          if (category != null)  'category':   category,
        },
      );
      return (response.data as List)
          .map((g) => GameModel.fromJson(g))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<GameModel?> getDailyChallenge() async {
    try {
      final response = await _client.dio.get('/games/daily');
      return GameModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<GameModel?> getGame(int id) async {
    try {
      final response = await _client.dio.get('/games/$id');
      return GameModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  // ─── Session ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startSession(int gameId) async {
    try {
      final response = await _client.dio.post('/games/$gameId/start');
      return {'success': true, 'data': GameSessionModel.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to start game.',
      };
    }
  }

  Future<Map<String, dynamic>> submitAnswer({
    required int sessionId,
    required dynamic answer,
    int? timeTakenSecs,
  }) async {
    try {
      final response = await _client.dio.post(
        '/games/sessions/$sessionId/submit',
        data: {
          'answer': answer,
          if (timeTakenSecs != null) 'time_taken_secs': timeTakenSecs,
        },
      );
      return {'success': true, 'data': AnswerResult.fromJson(response.data)};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to submit answer.',
      };
    }
  }

  Future<void> abandonSession(int sessionId) async {
    try {
      await _client.dio.post('/games/sessions/$sessionId/abandon');
    } catch (_) {}
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLeaderboard() async {
    try {
      final response = await _client.dio.get('/games/leaderboard/all');
      final entries = (response.data['leaderboard'] as List)
          .map((e) => LeaderboardEntry.fromJson(e))
          .toList();
      final myStats = response.data['my_stats'];
      return {'success': true, 'entries': entries, 'my_stats': myStats};
    } catch (_) {
      return {'success': false, 'entries': [], 'my_stats': null};
    }
  }

  // ─── Seed Sample Games ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> seedGames() async {
    try {
      final response = await _client.dio.post('/games/seed');
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to seed games.',
      };
    }
  }

  // ─── AI Generate ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> aiGenerateGames({
    String gameType  = 'quiz',
    String difficulty = 'medium',
    String category  = 'general',
    int count        = 3,
  }) async {
    try {
      final response = await _client.dio.post(
        '/games/ai-generate',
        data: {
          'game_type':  gameType,
          'difficulty': difficulty,
          'category':   category,
          'count':      count,
        },
      );
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'AI generation failed.',
      };
    }
  }
}