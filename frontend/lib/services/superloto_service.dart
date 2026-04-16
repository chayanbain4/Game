// lib/services/superloto_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/superloto/superloto_draw_model.dart';
import '../models/superloto/superloto_ticket_model.dart';

class SuperLotoBuyResponse {
  final SuperLotoTicketModel ticket;
  final Map<String, dynamic>? reward;
  final Map<String, dynamic>? recovery;
  final int? newBalance;
  final bool freeSpinUsed;
  final int? freeSpins;
  final int? drawNumber;
  final int? remainingTime;
  final int multiplier;
  final int? fee;

  SuperLotoBuyResponse({
    required this.ticket,
    this.reward,
    this.recovery,
    this.newBalance,
    this.freeSpinUsed = false,
    this.freeSpins,
    this.drawNumber,
    this.remainingTime,
    this.multiplier = 1,
    this.fee,
  });
}

class SuperLotoService {
  static final SuperLotoService _instance = SuperLotoService._internal();
  factory SuperLotoService() => _instance;
  SuperLotoService._internal();

  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://game.iwebgenics.com'
        : 'http://10.0.2.2:4017',
  );

  // ── Buy ticket with manual numbers ──────────────────────────
  Future<SuperLotoBuyResponse?> buyTicket(
    String userId,
    String username,
    List<int> numbers, {
    bool useFreeSpins = false,
    int multiplier = 1,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/superloto/buy'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId':       userId,
              'username':     username,
              'numbers':      numbers,
              'useFreeSpins': useFreeSpins,
              'multiplier':   multiplier,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _parseBuyResponse(body);
        }
      }
      return null;
    } catch (e) {
      print('[SuperLotoService] buyTicket error: $e');
      return null;
    }
  }

  // ── Quick pick ───────────────────────────────────────────────
  Future<SuperLotoBuyResponse?> quickPick(
    String userId,
    String username, {
    bool useFreeSpins = false,
    int multiplier = 1,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/superloto/quick-pick'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId':       userId,
              'username':     username,
              'useFreeSpins': useFreeSpins,
              'multiplier':   multiplier,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _parseBuyResponse(body);
        }
      }
      return null;
    } catch (e) {
      print('[SuperLotoService] quickPick error: $e');
      return null;
    }
  }

  SuperLotoBuyResponse _parseBuyResponse(Map<String, dynamic> body) {
    return SuperLotoBuyResponse(
      ticket:        SuperLotoTicketModel.fromJson(body['data']),
      reward:        body['reward']       as Map<String, dynamic>?,
      recovery:      body['recovery']     as Map<String, dynamic>?,
      newBalance:    (body['newBalance']  as num?)?.toInt(),
      freeSpinUsed:  body['freeSpinUsed'] == true,
      freeSpins:     (body['freeSpins']   as num?)?.toInt(),
      drawNumber:    (body['drawNumber']  as num?)?.toInt(),
      remainingTime: (body['remainingTime'] as num?)?.toInt(),
      multiplier:    (body['multiplier']  as num?)?.toInt() ?? 1,
      fee:           (body['fee']         as num?)?.toInt(),
    );
  }

  // ── Engine status ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/superloto/status'),
              headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) return body['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Current draw ──────────────────────────────────────────────
  Future<SuperLotoDrawModel?> getCurrentDraw() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/superloto/current-draw'),
              headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return SuperLotoDrawModel.fromJson(body['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<SuperLotoDrawModel>> getRecentDraws({int limit = 10}) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/superloto/recent-draws?limit=$limit'),
              headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => SuperLotoDrawModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<SuperLotoTicketModel>> getUserTickets(
      String userId, int drawNumber) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/superloto/tickets/$userId/$drawNumber'),
              headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => SuperLotoTicketModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<SuperLotoTicketModel>> getUserHistory(String userId,
      {int limit = 20}) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/superloto/history/$userId?limit=$limit'),
              headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => SuperLotoTicketModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch the authoritative user stats (balance, wins, freeSpins) from the
  /// auth endpoint. Call this after every draw result so the local cache
  /// always reflects the exact server value — no local arithmetic needed.
  Future<Map<String, dynamic>?> fetchUserStats(String token) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/auth/stats'),
            headers: {
              'Content-Type':  'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          return body as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}