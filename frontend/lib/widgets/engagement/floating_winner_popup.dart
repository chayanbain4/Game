import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/engagement_service.dart';

/// Inline double winner popup:
/// - top row slides from left
/// - bottom row slides from right
/// - both show together
/// - then hide together
/// - then next pair appears
class FloatingWinnerPopup extends StatefulWidget {
  const FloatingWinnerPopup({super.key});

  @override
  State<FloatingWinnerPopup> createState() => _FloatingWinnerPopupState();
}

class _FloatingWinnerPopupState extends State<FloatingWinnerPopup> {
  List<Map<String, dynamic>> _winners = [];

  int _topIndex = 0;
  int _bottomIndex = 1;

  bool _visible = false;

  Timer? _cycleTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadWinners();

    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadWinners();
    });
  }

  Future<void> _loadWinners() async {
    final winners = await EngagementService().getRecentWinners();
    if (!mounted || winners.isEmpty) return;

    setState(() {
      _winners = winners;
      _topIndex = 0;
      _bottomIndex = winners.length > 1 ? 1 : 0;
      _visible = true;
    });

    _startCycle();
  }

  void _startCycle() {
    _cycleTimer?.cancel();

    _cycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _winners.isEmpty) return;

      // First hide both
      setState(() => _visible = false);

      // After hide animation, move to next pair and show again
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _winners.isEmpty) return;

        setState(() {
          if (_winners.length == 1) {
            _topIndex = 0;
            _bottomIndex = 0;
          } else {
            _topIndex = (_topIndex + 2) % _winners.length;
            _bottomIndex = (_topIndex + 1) % _winners.length;
          }

          _visible = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  IconData _gameIcon(String game) {
    switch (game) {
      case 'Ludo':
        return Icons.grid_4x4_rounded;
      case 'Number Game':
        return Icons.casino_rounded;
      case 'Scratch & Win':
        return Icons.style_rounded;
      case 'Lottery':
        return Icons.confirmation_number_rounded;
      case 'Super Loto':
        return Icons.auto_awesome_rounded;
      case 'Andar Bahar':
        return Icons.layers_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  Widget _buildWinnerTile(
    Map<String, dynamic> w, {
    required bool fromLeft,
  }) {
    final name = (w['name'] ?? 'Player') as String;
    final city = (w['city'] ?? '') as String;
    final amount = w['amount'] ?? 0;
    final game = (w['game'] ?? '') as String;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      offset: _visible
          ? Offset.zero
          : Offset(fromLeft ? -1.5 : 1.5, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: _visible ? 1.0 : 0.0,
        child: Align(
          alignment:
              fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2DFF8F).withOpacity(0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD166), Color(0xFFFFA726)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _gameIcon(game),
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 11, height: 1.3),
                      children: [
                        TextSpan(
                          text: name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: city.isNotEmpty ? ' from $city won ' : ' won ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                        TextSpan(
                          text: '₹$amount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2DFF8F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_winners.isEmpty) {
      return const SizedBox(height: 8);
    }

    final topWinner = _winners[_topIndex];
    final bottomWinner = _winners[_bottomIndex];

return SizedBox(
  height: 96,
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _buildWinnerTile(
        topWinner,
        fromLeft: true,
      ),
      const SizedBox(height: 4),
      _buildWinnerTile(
        bottomWinner,
        fromLeft: false,
      ),
    ],
  ),
);
  }
}