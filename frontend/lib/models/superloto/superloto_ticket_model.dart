class SuperLotoTicketModel {
  final String id;
  final String userId;
  final String username;
  final int drawNumber;
  final List<int> numbers;
  final bool isQuickPick;
  final int multiplier; // 1, 2, 5, or 10
  final List<int> matchedNumbers;
  final int matchCount;
  final String result; // PENDING, WIN, LOSE
  final String? tier;
  final String? tierLabel;
  final int winAmount;
  final DateTime createdAt;

  SuperLotoTicketModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.drawNumber,
    required this.numbers,
    required this.isQuickPick,
    this.multiplier = 1,
    required this.matchedNumbers,
    required this.matchCount,
    required this.result,
    this.tier,
    this.tierLabel,
    this.winAmount = 0,
    required this.createdAt,
  });

  bool get isPending => result == 'PENDING';
  bool get isWin     => result == 'WIN';

  factory SuperLotoTicketModel.fromJson(Map<String, dynamic> json) {
    return SuperLotoTicketModel(
      id:         json['_id']      ?? '',
      userId:     json['userId']   ?? '',
      username:   json['username'] ?? 'Anonymous',
      drawNumber: (json['drawNumber'] as num?)?.toInt() ?? 0,
      numbers: List<int>.from(
        (json['numbers'] ?? []).map((e) => (e as num).toInt()),
      ),
      isQuickPick: json['isQuickPick'] ?? false,
      multiplier:  (json['multiplier'] as num?)?.toInt() ?? 1,
      matchedNumbers: List<int>.from(
        (json['matchedNumbers'] ?? []).map((e) => (e as num).toInt()),
      ),
      matchCount: (json['matchCount'] as num?)?.toInt() ?? 0,
      result:     json['result']    ?? 'PENDING',
      tier:       json['tier'],
      tierLabel:  json['tierLabel'],
      winAmount:  (json['winAmount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}