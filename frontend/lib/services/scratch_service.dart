import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/scratch/scratch_result_model.dart';

class ScratchPlayResponse {
  final ScratchResultModel result;
  final int? newWinCount;
  final Map<String, dynamic>? reward;
  final Map<String, dynamic>? recovery;
  final int? newBalance;
  final int? winAmount;
  final bool freeSpinUsed;
  final int? freeSpins;
  final int totalPlayers;
  final int totalWinners;
  final int totalLosers;

  ScratchPlayResponse({
    required this.result,
    this.newWinCount,
    this.reward,
    this.recovery,
    this.newBalance,
    this.winAmount,
    this.freeSpinUsed = false,
    this.freeSpins,
    this.totalPlayers = 0,
    this.totalWinners = 0,
    this.totalLosers = 0,
  });
}

class ScratchService {
  static final ScratchService _instance = ScratchService._internal();
  factory ScratchService() => _instance;
  ScratchService._internal();

  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://game.iwebgenics.com'
        : 'http://10.0.2.2:4017',
  );

  /// Play a scratch card via REST API
  /// Now accepts [multiplier] to scale the bet and rewards
  Future<ScratchPlayResponse?> play(String userId, String username, {bool useFreeSpins = false, int multiplier = 1}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/scratch/play'),
        headers: {'Content-Type': 'application/json'},
        // Send the multiplier to the backend API
        body: jsonEncode({
          'userId': userId, 
          'username': username, 
          'useFreeSpins': useFreeSpins,
          'multiplier': multiplier
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final result = ScratchResultModel.fromJson(body['data']);
          final newWinCount = (body['newWinCount'] as num?)?.toInt();
          final reward = body['reward'] as Map<String, dynamic>?;
          final recovery = body['recovery'] as Map<String, dynamic>?;
          final newBalance = (body['newBalance'] as num?)?.toInt();
          final winAmount = (body['winAmount'] as num?)?.toInt();
          final freeSpinUsed = body['freeSpinUsed'] == true;
          final freeSpins = (body['freeSpins'] as num?)?.toInt();
          final totalPlayers = (body['totalPlayers'] as num?)?.toInt() ?? 0;
          final totalWinners = (body['totalWinners'] as num?)?.toInt() ?? 0;
          final totalLosers = (body['totalLosers'] as num?)?.toInt() ?? 0;
          
          return ScratchPlayResponse(
            result: result, 
            newWinCount: newWinCount, 
            reward: reward, 
            recovery: recovery, 
            newBalance: newBalance, 
            winAmount: winAmount, 
            freeSpinUsed: freeSpinUsed, 
            freeSpins: freeSpins, 
            totalPlayers: totalPlayers, 
            totalWinners: totalWinners, 
            totalLosers: totalLosers
          );
        }
      }
      return null;
    } catch (e) {
      print('[ScratchService] play error: $e');
      return null;
    }
  }

  /// Get user scratch history
  Future<List<ScratchResultModel>> getUserHistory(String userId, {int limit = 20}) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/scratch/history/$userId?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => ScratchResultModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[ScratchService] history error: $e');
      return [];
    }
  }
}