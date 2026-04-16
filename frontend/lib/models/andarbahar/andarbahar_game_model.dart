class CardModel {
  final String value;
  final String suit;

  CardModel({required this.value, required this.suit});

  String get display => '$value$suit';

  bool get isRed => suit == '♥' || suit == '♦';

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      value: json['value'] ?? '',
      suit: json['suit'] ?? '',
    );
  }
}

class AndarBaharGameModel {
  final String id;
  final String userId;
  final String username;
  final String playerChoice; // ANDAR or BAHAR
  final CardModel jokerCard;
  final List<CardModel> andarCards;
  final List<CardModel> baharCards;
  final CardModel? matchingCard;
  final String winningSide; // ANDAR or BAHAR
  final String result; // WIN or LOSE
  final int totalDealt;
  final DateTime createdAt;

  AndarBaharGameModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.playerChoice,
    required this.jokerCard,
    required this.andarCards,
    required this.baharCards,
    this.matchingCard,
    required this.winningSide,
    required this.result,
    required this.totalDealt,
    required this.createdAt,
  });

  bool get isWin => result == 'WIN';

  factory AndarBaharGameModel.fromJson(Map<String, dynamic> json) {
    return AndarBaharGameModel(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? 'Anonymous',
      playerChoice: json['playerChoice'] ?? '',
      jokerCard: CardModel.fromJson(json['jokerCard'] ?? {}),
      andarCards: (json['andarCards'] as List? ?? [])
          .map((e) => CardModel.fromJson(e))
          .toList(),
      baharCards: (json['baharCards'] as List? ?? [])
          .map((e) => CardModel.fromJson(e))
          .toList(),
      matchingCard: json['matchingCard'] != null
          ? CardModel.fromJson(json['matchingCard'])
          : null,
      winningSide: json['winningSide'] ?? '',
      result: json['result'] ?? 'LOSE',
      totalDealt: (json['totalDealt'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
