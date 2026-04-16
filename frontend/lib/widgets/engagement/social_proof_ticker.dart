import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/engagement_service.dart';

/// Social proof ticker — auto-scrolling winner notifications.
/// "Rahul from Mumbai won ₹5000" builds trust and motivates new players.
class SocialProofTicker extends StatefulWidget {
  const SocialProofTicker({super.key});

  @override
  State<SocialProofTicker> createState() => _SocialProofTickerState();
}

class _SocialProofTickerState extends State<SocialProofTicker> {
  List<Map<String, dynamic>> _winners = [];
  int _current = 0;
  Timer? _rotateTimer;
  Timer? _refreshTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _loadWinners();
    // Refresh winner list every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadWinners();
    });
  }

  Future<void> _loadWinners() async {
    final winners = await EngagementService().getRecentWinners();
    if (!mounted || winners.isEmpty) return;
    setState(() => _winners = winners);
    _startRotation();
  }

  void _startRotation() {
    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _winners.isEmpty) return;
      // Fade out → switch → fade in
      setState(() => _visible = false);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _current = (_current + 1) % _winners.length;
          _visible = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    if (_winners.isEmpty) return const SizedBox.shrink();

    final w = _winners[_current];
    final name = w['name'] ?? 'Player';
    final city = w['city'] ?? '';
    final amount = w['amount'] ?? 0;
    final game = w['game'] ?? '';
    final timeAgo = w['timeAgo'] ?? '';

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EFEE), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Trophy avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD166), Color(0xFFFFA726)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_gameIcon(game), color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),

            // Winner details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12.5, height: 1.3),
                      children: [
                        TextSpan(
                          text: name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F1F1E),
                          ),
                        ),
                        TextSpan(
                          text: ' from $city',
                          style: const TextStyle(color: Color(0xFF6B8280)),
                        ),
                        const TextSpan(
                          text: ' won ',
                          style: TextStyle(color: Color(0xFF6B8280)),
                        ),
                        TextSpan(
                          text: '₹$amount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        '$timeAgo • $game',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
