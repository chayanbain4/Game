import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/andarbahar/andarbahar_game_model.dart';

class AndarBaharPlayResponse {
  final AndarBaharGameModel game;
  final int? newWinCount;
  final Map<String, dynamic>? reward;
  final Map<String, dynamic>? recovery;
  final int? newBalance;
  final int? winAmount;
  final String winType;
  final bool freeSpinUsed;
  final int? freeSpins;
  final String popularChoice;
  final int popularPercent;
  final int totalPlayers;
  final int totalWinners;
  final int totalLosers;
  AndarBaharPlayResponse({required this.game, this.newWinCount, this.reward, this.recovery, this.newBalance, this.winAmount, this.winType = 'normal', this.freeSpinUsed = false, this.freeSpins, this.popularChoice = 'ANDAR', this.popularPercent = 50, this.totalPlayers = 0, this.totalWinners = 0, this.totalLosers = 0});
}

class AndarBaharService {
  static final AndarBaharService _instance = AndarBaharService._internal();
  factory AndarBaharService() => _instance;
  AndarBaharService._internal();

static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4017',
);

  /// Play a round — choice must be "ANDAR" or "BAHAR"
  Future<AndarBaharPlayResponse?> play(
      String userId, String username, String choice, {bool useFreeSpins = false}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/andarbahar/play'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'username': username,
              'choice': choice,
              'useFreeSpins': useFreeSpins,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final game = AndarBaharGameModel.fromJson(body['data']);
          final newWinCount = (body['newWinCount'] as num?)?.toInt();
          final reward = body['reward'] as Map<String, dynamic>?;
          final recovery = body['recovery'] as Map<String, dynamic>?;
          final newBalance = (body['newBalance'] as num?)?.toInt();
          final winAmount = (body['winAmount'] as num?)?.toInt();
          final winType = (body['winType'] as String?) ?? 'normal';
          final freeSpinUsed = body['freeSpinUsed'] == true;
          final freeSpins = (body['freeSpins'] as num?)?.toInt();
          final popularChoice = (body['popularChoice'] as String?) ?? 'ANDAR';
          final popularPercent = (body['popularPercent'] as num?)?.toInt() ?? 50;
          final totalPlayers = (body['totalPlayers'] as num?)?.toInt() ?? 0;
          final totalWinners = (body['totalWinners'] as num?)?.toInt() ?? 0;
          final totalLosers = (body['totalLosers'] as num?)?.toInt() ?? 0;
          return AndarBaharPlayResponse(
              game: game, newWinCount: newWinCount, reward: reward, recovery: recovery, newBalance: newBalance, winAmount: winAmount, winType: winType, freeSpinUsed: freeSpinUsed, freeSpins: freeSpins, popularChoice: popularChoice, popularPercent: popularPercent, totalPlayers: totalPlayers, totalWinners: totalWinners, totalLosers: totalLosers);
        }
      }
      return null;
    } catch (e) {
      print('[AndarBaharService] play error: $e');
      return null;
    }
  }

  /// Get user game history
  Future<List<AndarBaharGameModel>> getUserHistory(String userId,
      {int limit = 20}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/andarbahar/history/$userId?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => AndarBaharGameModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[AndarBaharService] getUserHistory error: $e');
      return [];
    }
  }

  /// Get user stats (total, wins, losses, winRate)
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/andarbahar/stats/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('[AndarBaharService] getUserStats error: $e');
      return null;
    }
  }
}
