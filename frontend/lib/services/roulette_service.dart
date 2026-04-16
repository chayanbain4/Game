// lib/services/roulette_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/roulette/roulette_game_model.dart';

class RouletteBet {
  final String  betType;  // color | parity | half | dozen | column | number
  final dynamic betValue; // "red"/"black"/"green" | "odd"/"even" | "low"/"high" | "1st"/"2nd"/"3rd" | "col1"/"col2"/"col3" | 0-36
  final int     amount;

  RouletteBet({required this.betType, required this.betValue, required this.amount});

  Map<String, dynamic> toJson() => {
    'betType':  betType,
    'betValue': betValue,
    'amount':   amount,
  };
}

class RoulettePlayResponse {
  final RouletteGameModel game;
  final int?   newWinCount;
  final Map<String, dynamic>? reward;
  final Map<String, dynamic>? recovery;
  final int?   newBalance;
  final int    totalWin;
  final int    totalBet;
  final int    netChange;
  final String winType;
  final bool   freeSpinUsed;
  final int?   freeSpins;
  final int    spinResult;
  final String resultColor;
  final String resultParity;
  final String resultHalf;
  final String resultDozen;
  final String resultColumn;
  final List<RouletteBetResult> betResults;
  final int?   popularNumber;
  final int    popularPercent;
  final int    totalPlayers;
  final int    totalWinners;
  final int    totalLosers;

  RoulettePlayResponse({
    required this.game,
    this.newWinCount,
    this.reward,
    this.recovery,
    this.newBalance,
    this.totalWin    = 0,
    this.totalBet    = 0,
    this.netChange   = 0,
    this.winType     = 'normal',
    this.freeSpinUsed = false,
    this.freeSpins,
    this.spinResult  = 0,
    this.resultColor = 'black',
    this.resultParity = 'zero',
    this.resultHalf   = 'zero',
    this.resultDozen  = 'zero',
    this.resultColumn = 'zero',
    this.betResults  = const [],
    this.popularNumber,
    this.popularPercent = 0,
    this.totalPlayers   = 0,
    this.totalWinners   = 0,
    this.totalLosers    = 0,
  });
}

class RouletteService {
  static final RouletteService _instance = RouletteService._internal();
  factory RouletteService() => _instance;
  RouletteService._internal();

  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://game.iwebgenics.com'
        : 'http://10.0.2.2:4017',
  );

  /// Play a round — bets is a list of RouletteBet objects
  Future<RoulettePlayResponse?> play(
    String userId,
    String username,
    List<RouletteBet> bets, {
    bool useFreeSpins = false,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/roulette/play'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId':       userId,
              'username':     username,
              'bets':         bets.map((b) => b.toJson()).toList(),
              'useFreeSpins': useFreeSpins,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final game         = RouletteGameModel.fromJson(body['data']);
          final betResultsRaw = (body['betResults'] as List? ?? [])
              .map((e) => RouletteBetResult.fromJson(e))
              .toList();

          return RoulettePlayResponse(
            game:          game,
            newWinCount:   (body['newWinCount']   as num?)?.toInt(),
            reward:        body['reward']          as Map<String, dynamic>?,
            recovery:      body['recovery']        as Map<String, dynamic>?,
            newBalance:    (body['newBalance']     as num?)?.toInt(),
            totalWin:      (body['totalWin']       as num?)?.toInt() ?? 0,
            totalBet:      (body['totalBet']       as num?)?.toInt() ?? 0,
            netChange:     (body['netChange']      as num?)?.toInt() ?? 0,
            winType:       (body['winType']        as String?) ?? 'normal',
            freeSpinUsed:  body['freeSpinUsed']   == true,
            freeSpins:     (body['freeSpins']      as num?)?.toInt(),
            spinResult:    (body['spinResult']     as num?)?.toInt() ?? 0,
            resultColor:   (body['resultColor']    as String?) ?? 'black',
            resultParity:  (body['resultParity']   as String?) ?? 'zero',
            resultHalf:    (body['resultHalf']     as String?) ?? 'zero',
            resultDozen:   (body['resultDozen']    as String?) ?? 'zero',
            resultColumn:  (body['resultColumn']   as String?) ?? 'zero',
            betResults:    betResultsRaw,
            popularNumber: (body['popularNumber']  as num?)?.toInt(),
            popularPercent:(body['popularPercent'] as num?)?.toInt() ?? 0,
            totalPlayers:  (body['totalPlayers']   as num?)?.toInt() ?? 0,
            totalWinners:  (body['totalWinners']   as num?)?.toInt() ?? 0,
            totalLosers:   (body['totalLosers']    as num?)?.toInt() ?? 0,
          );
        }
      }
      return null;
    } catch (e) {
      print('[RouletteService] play error: $e');
      return null;
    }
  }

  /// Get user game history
  Future<List<RouletteGameModel>> getUserHistory(String userId, {int limit = 20}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/roulette/history/$userId?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => RouletteGameModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[RouletteService] getUserHistory error: $e');
      return [];
    }
  }

  /// Get user stats
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/roulette/stats/$userId'),
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
      print('[RouletteService] getUserStats error: $e');
      return null;
    }
  }
}