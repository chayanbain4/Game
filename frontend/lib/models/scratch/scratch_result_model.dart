class ScratchResultModel {
  final String id;
  final String userId;
  final String username;
  final List<String> cells;
  final String result;
  final String? symbol;
  final int matchCount;
  final int multiplier;
  final DateTime createdAt;

  ScratchResultModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.cells,
    required this.result,
    this.symbol,
    required this.matchCount,
    required this.multiplier,
    required this.createdAt,
  });

  bool get isWin => result == 'WIN';

  factory ScratchResultModel.fromJson(Map<String, dynamic> json) {
    return ScratchResultModel(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? 'Anonymous',
      cells: List<String>.from(json['cells'] ?? []),
      result: json['result'] ?? 'LOSE',
      symbol: json['symbol'],
      matchCount: (json['matchCount'] as num?)?.toInt() ?? 0,
      multiplier: (json['multiplier'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
