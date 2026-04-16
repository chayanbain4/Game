// lib/models/roulette/roulette_game_model.dart

class RouletteBetResult {
  final String betType;
  final dynamic betValue;
  final int amount;
  final bool won;
  final int winAmount;
  final int payout;

  RouletteBetResult({
    required this.betType,
    required this.betValue,
    required this.amount,
    required this.won,
    required this.winAmount,
    required this.payout,
  });

  factory RouletteBetResult.fromJson(Map<String, dynamic> json) {
    return RouletteBetResult(
      betType:   json['betType']   ?? '',
      betValue:  json['betValue'],
      amount:    (json['amount']    as num?)?.toInt() ?? 0,
      won:       json['won']       == true,
      winAmount: (json['winAmount'] as num?)?.toInt() ?? 0,
      payout:    (json['payout']   as num?)?.toInt() ?? 0,
    );
  }
}

class RouletteGameModel {
  final String id;
  final String userId;
  final String username;
  final List<RouletteBetResult> bets;
  final int    totalBet;
  final int    spinResult;    // 0–36
  final String resultColor;   // red | black | green
  final String resultParity;  // odd | even | zero
  final String resultHalf;    // low | high | zero
  final String resultDozen;   // 1st | 2nd | 3rd | zero
  final String resultColumn;  // col1 | col2 | col3 | zero
  final int    totalWin;
  final String result;        // WIN | LOSE
  final String winType;       // normal | rare | popular | jackpot
  final bool   freeSpinUsed;
  final DateTime createdAt;

  RouletteGameModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.bets,
    required this.totalBet,
    required this.spinResult,
    required this.resultColor,
    required this.resultParity,
    required this.resultHalf,
    required this.resultDozen,
    required this.resultColumn,
    required this.totalWin,
    required this.result,
    this.winType    = 'normal',
    this.freeSpinUsed = false,
    required this.createdAt,
  });

  bool get isWin => result == 'WIN';

  bool get isJackpot =>
      winType == 'jackpot' ||
      bets.any((b) => b.betType == 'number' && b.won);

  factory RouletteGameModel.fromJson(Map<String, dynamic> json) {
    return RouletteGameModel(
      id:           json['_id']          ?? '',
      userId:       json['userId']        ?? '',
      username:     json['username']      ?? 'Anonymous',
      bets:         (json['bets'] as List? ?? [])
                        .map((e) => RouletteBetResult.fromJson(e))
                        .toList(),
      totalBet:     (json['totalBet']     as num?)?.toInt() ?? 0,
      spinResult:   (json['spinResult']   as num?)?.toInt() ?? 0,
      resultColor:  json['resultColor']   ?? 'black',
      resultParity: json['resultParity']  ?? 'zero',
      resultHalf:   json['resultHalf']    ?? 'zero',
      resultDozen:  json['resultDozen']   ?? 'zero',
      resultColumn: json['resultColumn']  ?? 'zero',
      totalWin:     (json['totalWin']     as num?)?.toInt() ?? 0,
      result:       json['result']        ?? 'LOSE',
      winType:      json['winType']       ?? 'normal',
      freeSpinUsed: json['freeSpinUsed']  == true,
      createdAt:    json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}