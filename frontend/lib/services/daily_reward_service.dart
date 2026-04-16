import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/user_session.dart';

class DailyRewardDay {
  final int day;
  final String type;
  final String label;
  final int amount;

  DailyRewardDay({
    required this.day,
    required this.type,
    required this.label,
    required this.amount,
  });

  factory DailyRewardDay.fromJson(Map<String, dynamic> json) {
    return DailyRewardDay(
      day: (json['day'] as num?)?.toInt() ?? 1,
      type: json['type'] ?? 'bonus',
      label: json['label'] ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyRewardStatus {
  final bool claimedToday;
  final int streak;
  final List<DailyRewardDay> rewardTable;
  final int currentDayIndex;
  final DailyRewardDay todayReward;

  DailyRewardStatus({
    required this.claimedToday,
    required this.streak,
    required this.rewardTable,
    required this.currentDayIndex,
    required this.todayReward,
  });

  factory DailyRewardStatus.fromJson(Map<String, dynamic> json) {
    final table = (json['rewardTable'] as List? ?? [])
        .map((e) => DailyRewardDay.fromJson(e as Map<String, dynamic>))
        .toList();
    return DailyRewardStatus(
      claimedToday: json['claimedToday'] == true,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      rewardTable: table,
      currentDayIndex: (json['currentDayIndex'] as num?)?.toInt() ?? 0,
      todayReward: DailyRewardDay.fromJson(
          json['todayReward'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class DailyRewardClaimResult {
  final bool success;
  final String? message;
  final bool alreadyClaimed;
  final int streak;
  final DailyRewardDay? reward;
  final int? newBalance;
  final int? freeSpins;

  DailyRewardClaimResult({
    required this.success,
    this.message,
    this.alreadyClaimed = false,
    this.streak = 0,
    this.reward,
    this.newBalance,
    this.freeSpins,
  });

  factory DailyRewardClaimResult.fromJson(Map<String, dynamic> json) {
    return DailyRewardClaimResult(
      success: json['success'] == true,
      message: json['message'],
      alreadyClaimed: json['alreadyClaimed'] == true,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      reward: json['reward'] != null
          ? DailyRewardDay.fromJson(json['reward'] as Map<String, dynamic>)
          : null,
      newBalance: (json['newBalance'] as num?)?.toInt(),
      freeSpins: (json['freeSpins'] as num?)?.toInt(),
    );
  }
}

class DailyRewardService {
  static final DailyRewardService _instance = DailyRewardService._();
  factory DailyRewardService() => _instance;
  DailyRewardService._();

static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4017',
);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${UserSession.instance.token ?? ''}',
      };

  Future<DailyRewardStatus?> getStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/engagement/daily-reward/status'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          return DailyRewardStatus.fromJson(body);
        }
      }
      return null;
    } catch (e) {
      print('[DailyRewardService] getStatus error: $e');
      return null;
    }
  }

  Future<DailyRewardClaimResult?> claim() async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/api/engagement/daily-reward/claim'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return DailyRewardClaimResult.fromJson(jsonDecode(res.body));
      }
      return null;
    } catch (e) {
      print('[DailyRewardService] claim error: $e');
      return null;
    }
  }
}
