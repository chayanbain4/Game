class LotteryDrawModel {
  final String id;
  final int drawNumber;
  final List<int> winningNumbers;
  final int totalTickets;
  final int totalWinners;
  final int totalLosers;
  final String status; // UPCOMING, OPEN, DRAWN
  final String winType; // normal, rare, popular
  final int? remainingTime;
  final DateTime? drawnAt;
  final DateTime createdAt;

  LotteryDrawModel({
    required this.id,
    required this.drawNumber,
    required this.winningNumbers,
    required this.totalTickets,
    required this.totalWinners,
    this.totalLosers = 0,
    required this.status,
    this.winType = 'normal',
    this.remainingTime,
    this.drawnAt,
    required this.createdAt,
  });

  bool get isOpen => status == 'OPEN';
  bool get isDrawn => status == 'DRAWN';

  factory LotteryDrawModel.fromJson(Map<String, dynamic> json) {
    return LotteryDrawModel(
      id: json['_id'] ?? '',
      drawNumber: (json['drawNumber'] as num?)?.toInt() ?? 0,
      winningNumbers: List<int>.from(
        (json['winningNumbers'] ?? []).map((e) => (e as num).toInt()),
      ),
      totalTickets: (json['totalTickets'] as num?)?.toInt() ?? 0,
      totalWinners: (json['totalWinners'] as num?)?.toInt() ?? 0,
      totalLosers: (json['totalLosers'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'UPCOMING',
      winType: json['winType'] ?? 'normal',
      remainingTime: (json['remainingTime'] as num?)?.toInt(),
      drawnAt: json['drawnAt'] != null
          ? DateTime.tryParse(json['drawnAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}