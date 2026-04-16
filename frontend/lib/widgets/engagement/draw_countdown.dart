import 'dart:async';
import 'package:flutter/material.dart';

/// Urgency widget — cycles through upcoming game draws with a live countdown.
/// Creates FOMO: "Next draw in 02:15 — join now!"
class DrawCountdown extends StatefulWidget {
  const DrawCountdown({super.key});

  @override
  State<DrawCountdown> createState() => _DrawCountdownState();
}

class _DrawCountdownState extends State<DrawCountdown>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  int _currentDraw = 0;

  // Each draw has a name, icon, and a random duration (2–10 min)
  static final List<_DrawInfo> _draws = [
    _DrawInfo('Lottery Draw', Icons.confirmation_number_rounded, const Color(0xFFE8534A)),
    _DrawInfo('Super Loto Draw', Icons.auto_awesome_rounded, const Color(0xFF9C27B0)),
    _DrawInfo('Number Game Round', Icons.casino_rounded, const Color(0xFFFF9800)),
  ];

  // Remaining seconds for each draw (randomized on init + recycle)
  late List<int> _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _draws
        .map((_) => 120 + (DateTime.now().microsecond % 480)) // 2–10 min
        .toList();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _remaining.length; i++) {
          _remaining[i]--;
          if (_remaining[i] <= 0) {
            // Recycle with a new random duration
            _remaining[i] = 120 + (DateTime.now().microsecond % 480);
          }
        }
      });
    });

    // Rotate displayed draw every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _currentDraw = (_currentDraw + 1) % _draws.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final draw = _draws[_currentDraw];
    final secs = _remaining[_currentDraw];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_currentDraw),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              draw.color.withOpacity(0.12),
              draw.color.withOpacity(0.04),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: draw.color.withOpacity(0.18), width: 1),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: draw.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(draw.icon, color: draw.color, size: 18),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draw.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: draw.color.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Starts soon — join now!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Countdown
            ScaleTransition(
              scale: _pulse,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: draw.color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: draw.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(secs),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawInfo {
  final String name;
  final IconData icon;
  final Color color;
  const _DrawInfo(this.name, this.icon, this.color);
}
