import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_session.dart';

class JackpotModel {
  final String name;
  final int amount;
  final int targetAmount;
  final String displayAmount;
  final String message;
  final String icon;

  JackpotModel({
    required this.name,
    required this.amount,
    required this.targetAmount,
    required this.displayAmount,
    required this.message,
    required this.icon,
  });

  double get progress =>
      targetAmount > 0 ? (amount / targetAmount).clamp(0.0, 1.0) : 0.0;

  String get targetDisplay {
    if (targetAmount >= 100000) {
      return '₹${(targetAmount / 100000).toStringAsFixed(targetAmount % 100000 == 0 ? 0 : 2)} Lakh';
    }
    return '₹${_formatIndian(targetAmount)}';
  }

  static String _formatIndian(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '$buf,$last3';
  }

  factory JackpotModel.fromJson(Map<String, dynamic> json) {
    return JackpotModel(
      name: json['name'] ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      targetAmount: (json['targetAmount'] as num?)?.toInt() ?? 0,
      displayAmount: json['displayAmount'] ?? '',
      message: json['message'] ?? '',
      icon: json['icon'] ?? 'trophy',
    );
  }
}

class EngagementService {
  static final EngagementService _instance = EngagementService._internal();
  factory EngagementService() => _instance;
  EngagementService._internal();

static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4017',
);

  Future<List<JackpotModel>> getJackpots() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/engagement/jackpots'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List)
              .map((e) => JackpotModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Check if welcome bonus is already claimed
  Future<Map<String, dynamic>?> getWelcomeBonusStatus() async {
    try {
      final token = UserSession.instance.token;
      if (token == null || token.isEmpty) return null;

      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/engagement/welcome-bonus'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Claim welcome bonus — returns new balance or null on failure
  Future<Map<String, dynamic>?> claimWelcomeBonus() async {
    try {
      final token = UserSession.instance.token;
      if (token == null || token.isEmpty) return null;

      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/engagement/welcome-bonus/claim'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch recent winners for social proof ticker
  Future<List<Map<String, dynamic>>> getRecentWinners() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/engagement/recent-winners'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
