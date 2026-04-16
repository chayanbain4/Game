import 'dart:convert';
import 'package:http/http.dart' as http;

class HistoryEntry {
  final String game; // scratch, andarbahar, lottery, superloto
  final String result; // WIN, LOSE, PENDING
  final DateTime createdAt;
  final Map<String, dynamic> raw;

  HistoryEntry({
    required this.game,
    required this.result,
    required this.createdAt,
    required this.raw,
  });

  bool get isWin => result == 'WIN';
  bool get isPending => result == 'PENDING';
}

class GameHistoryData {
  final List<HistoryEntry> scratch;
  final List<HistoryEntry> andarbahar;
  final List<HistoryEntry> lottery;
  final List<HistoryEntry> superloto;
  final List<HistoryEntry> ludo;

  GameHistoryData({
    required this.scratch,
    required this.andarbahar,
    required this.lottery,
    required this.superloto,
    required this.ludo,
  });

  List<HistoryEntry> get all => [...scratch, ...andarbahar, ...lottery, ...superloto, ...ludo]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4017',
);

  Future<GameHistoryData?> getFullHistory(String userId, {int limit = 50}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/history/$userId?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;

          List<HistoryEntry> _parse(String game, List items) {
            return items.map((e) {
              final map = e as Map<String, dynamic>;
              return HistoryEntry(
                game: game,
                result: map['result'] ?? 'LOSE',
                createdAt: map['createdAt'] != null
                    ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
                    : DateTime.now(),
                raw: map,
              );
            }).toList();
          }

          return GameHistoryData(
            scratch: _parse('scratch', data['scratch'] ?? []),
            andarbahar: _parse('andarbahar', data['andarbahar'] ?? []),
            lottery: _parse('lottery', data['lottery'] ?? []),
            superloto: _parse('superloto', data['superloto'] ?? []),
            ludo: _parse('ludo', data['ludo'] ?? []),
          );
        }
      }
      return null;
    } catch (e) {
      print('[HistoryService] getFullHistory error: $e');
      return null;
    }
  }
}
