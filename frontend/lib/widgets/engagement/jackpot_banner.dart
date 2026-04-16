import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/engagement_service.dart';

class JackpotBanner extends StatefulWidget {
  const JackpotBanner({super.key});

  @override
  State<JackpotBanner> createState() => _JackpotBannerState();
}

class _JackpotBannerState extends State<JackpotBanner> {
  final _service = EngagementService();
  List<JackpotModel> _jackpots = [];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadJackpots();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadJackpots() async {
    final data = await _service.getJackpots();
    if (mounted && data.isNotEmpty) {
      setState(() => _jackpots = data);
      _startRotation();
    }
  }

  void _startRotation() {
    if (_jackpots.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() => _currentIndex = (_currentIndex + 1) % _jackpots.length);
      }
    });
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'star':
        return Icons.star_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jackpots.isEmpty) return const SizedBox.shrink();

    final jp = _jackpots[_currentIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(jp.name),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B0E3A), Color(0xFF2D1A5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD166).withAlpha(60),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD166).withAlpha(25),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(jp.icon),
                color: const Color(0xFFFFD166),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Text + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jp.name,
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    jp.displayAmount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (jp.targetAmount > 0) ...[
                    const SizedBox(height: 6),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: jp.progress,
                          backgroundColor: Colors.white.withAlpha(30),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFD166),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          jp.displayAmount,
                          style: TextStyle(
                            color: const Color(0xFFFFD166).withAlpha(180),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          jp.targetDisplay,
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      jp.message,
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Dots indicator
            if (_jackpots.length > 1)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _jackpots.length,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentIndex
                          ? const Color(0xFFFFD166)
                          : Colors.white.withAlpha(50),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
