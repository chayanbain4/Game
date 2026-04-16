// lib/services/lottery_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lottery/lottery_draw_model.dart';
import '../models/lottery/lottery_ticket_model.dart';

class LotteryBuyResponse {
  final LotteryTicketModel ticket;
  final Map<String, dynamic>? reward;
  final Map<String, dynamic>? recovery;
  final int? newBalance;
  final bool freeSpinUsed;
  final int? freeSpins;
  
  LotteryBuyResponse({
    required this.ticket, 
    this.reward, 
    this.recovery, 
    this.newBalance, 
    this.freeSpinUsed = false, 
    this.freeSpins
  });
}

class LotteryService {
  static final LotteryService _instance = LotteryService._internal();
  factory LotteryService() => _instance;
  LotteryService._internal();

  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://game.iwebgenics.com'
        : 'http://10.0.2.2:4017',
  );

  /// ── START MANUAL DRAW ──────────────────────────────────────────────────
  Future<bool> startDraw() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/lottery/start'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      print('[LotteryService] startDraw error: $e');
      return false;
    }
  }

  /// ── BUY TICKET ─────────────────────────────────────────────────────────
  Future<LotteryBuyResponse?> buyTicket(
      String userId, String username, List<int> numbers, int drawNumber, 
      {bool useFreeSpins = false, int multiplier = 1}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/lottery/buy'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'username': username,
              'numbers': numbers,
              'drawNumber': drawNumber,
              'useFreeSpins': useFreeSpins,
              'multiplier': multiplier, // Sending multiplier to backend
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final ticket = LotteryTicketModel.fromJson(body['data']);
          final reward = body['reward'] as Map<String, dynamic>?;
          final recovery = body['recovery'] as Map<String, dynamic>?;
          final newBalance = (body['newBalance'] as num?)?.toInt();
          final freeSpinUsed = body['freeSpinUsed'] == true;
          final freeSpins = (body['freeSpins'] as num?)?.toInt();
          return LotteryBuyResponse(
            ticket: ticket, 
            reward: reward, 
            recovery: recovery, 
            newBalance: newBalance, 
            freeSpinUsed: freeSpinUsed, 
            freeSpins: freeSpins
          );
        }
      }
      return null;
    } catch (e) {
      print('[LotteryService] buyTicket error: $e');
      return null;
    }
  }

  /// ── QUICK PICK ─────────────────────────────────────────────────────────
  Future<LotteryBuyResponse?> quickPick(
      String userId, String username, int drawNumber, 
      {bool useFreeSpins = false, int multiplier = 1}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/lottery/quick-pick'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'username': username,
              'drawNumber': drawNumber,
              'useFreeSpins': useFreeSpins,
              'multiplier': multiplier, // Sending multiplier to backend
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final ticket = LotteryTicketModel.fromJson(body['data']);
          final reward = body['reward'] as Map<String, dynamic>?;
          final recovery = body['recovery'] as Map<String, dynamic>?;
          final newBalance = (body['newBalance'] as num?)?.toInt();
          final freeSpinUsed = body['freeSpinUsed'] == true;
          final freeSpins = (body['freeSpins'] as num?)?.toInt();
          return LotteryBuyResponse(
            ticket: ticket, 
            reward: reward, 
            recovery: recovery, 
            newBalance: newBalance, 
            freeSpinUsed: freeSpinUsed, 
            freeSpins: freeSpins
          );
        }
      }
      return null;
    } catch (e) {
      print('[LotteryService] quickPick error: $e');
      return null;
    }
  }

  /// ── GET CURRENT DRAW ───────────────────────────────────────────────────
  Future<LotteryDrawModel?> getCurrentDraw() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/lottery/current-draw'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return LotteryDrawModel.fromJson(body['data']);
        }
      }
      return null;
    } catch (e) {
      print('[LotteryService] getCurrentDraw error: $e');
      return null;
    }
  }

  /// ── GET SPECIFIC DRAW ──────────────────────────────────────────────────
  Future<LotteryDrawModel?> getDraw(int drawNumber) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/lottery/draw/$drawNumber'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return LotteryDrawModel.fromJson(body['data']);
        }
      }
      return null;
    } catch (e) {
      print('[LotteryService] getDraw error: $e');
      return null;
    }
  }

  /// ── GET RECENT DRAWS ───────────────────────────────────────────────────
  Future<List<LotteryDrawModel>> getRecentDraws({int limit = 10}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/lottery/recent-draws?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => LotteryDrawModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[LotteryService] getRecentDraws error: $e');
      return [];
    }
  }

  /// ── GET TICKETS FOR A DRAW ─────────────────────────────────────────────
  Future<List<LotteryTicketModel>> getUserTickets(
      String userId, int drawNumber) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/lottery/tickets/$userId/$drawNumber'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => LotteryTicketModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[LotteryService] getUserTickets error: $e');
      return [];
    }
  }

  /// ── GET TICKET HISTORY ─────────────────────────────────────────────────
  Future<List<LotteryTicketModel>> getUserHistory(String userId,
      {int limit = 20}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/lottery/history/$userId?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => LotteryTicketModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[LotteryService] getUserHistory error: $e');
      return [];
    }
  }

  /// ── FETCH AUTHORITATIVE USER STATS (balance, wins, freeSpins) ──────────
  /// Call this after every draw result so the local cache always reflects
  /// the exact server value — never compute balance locally.
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
        if (body['success'] == true) return body as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[LotteryService] fetchUserStats error: $e');
      return null;
    }
  }
}