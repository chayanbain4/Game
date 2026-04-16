import 'package:flutter/material.dart';

/// Shows "X players · Y won · Z lost" stats bar after game results.
/// Used in all games except Ludo.
class GameResultStats extends StatelessWidget {
  final int totalPlayers;
  final int totalWinners;
  final int totalLosers;
  final bool userWon;

  const GameResultStats({
    super.key,
    required this.totalPlayers,
    required this.totalWinners,
    required this.totalLosers,
    required this.userWon,
  });

  @override
  Widget build(BuildContext context) {
    final winPct = totalPlayers > 0
        ? (totalWinners / totalPlayers * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2548),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: userWon
              ? const Color(0xFF00D2A0).withAlpha(40)
              : const Color(0xFFE8534A).withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('👥 ', style: TextStyle(fontSize: 14)),
              Text(
                '$totalPlayers players this round',
                style: const TextStyle(
                  color: Color(0xFFF0F0FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Win/Loss bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: totalWinners.clamp(1, totalPlayers),
                    child: Container(color: const Color(0xFF00D2A0)),
                  ),
                  Expanded(
                    flex: totalLosers.clamp(1, totalPlayers),
                    child: Container(color: const Color(0xFFE8534A)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statChip('🏆 $totalWinners won', const Color(0xFF00D2A0)),
              _statChip('💔 $totalLosers lost', const Color(0xFFE8534A)),
              _statChip('$winPct% win rate', const Color(0xFFA29BFE)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
