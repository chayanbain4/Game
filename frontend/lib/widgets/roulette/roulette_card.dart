// lib/widgets/roulette/roulette_card.dart
import 'dart:math';
import 'package:flutter/material.dart';

class RouletteCard extends StatefulWidget {
  const RouletteCard({super.key});

  @override
  State<RouletteCard> createState() => _RouletteCardState();
}

class _RouletteCardState extends State<RouletteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  final int _fakePlayers = 700 + Random().nextInt(1200);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _playerLabel {
    if (_fakePlayers >= 1000) {
      final k = (_fakePlayers / 1000).toStringAsFixed(1);
      return '${k}k playing';
    }
    return '$_fakePlayers playing';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => _ctrl.forward(),
      onTapUp:    (_) {
        _ctrl.reverse();
        Navigator.pushNamed(context, '/roulette');
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0A2E), Color(0xFF0D0618), Color(0xFF08030F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFB060FA).withOpacity(0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B5DE5).withOpacity(0.25),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Background glow orbs
                Positioned(
                  top: -20, right: -20,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFB060FA).withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -24, left: -12,
                  child: Container(
                    width: 75, height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF4D6D).withOpacity(0.05),
                    ),
                  ),
                ),

                // CASINO badge top-left
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9B1DFF), Color(0xFFE040FB)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9B1DFF).withOpacity(0.55),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎰', style: TextStyle(fontSize: 9)),
                        SizedBox(width: 3),
                        Text(
                          'CASINO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 34, 16, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Roulette wheel icon
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB060FA), Color(0xFF7B1FD4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB060FA).withOpacity(0.50),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🎡', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Roulette',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Multiplier badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _multiBadge('2x', const Color(0xFF4ADE80)),
                          const SizedBox(width: 4),
                          _multiBadge('5x', const Color(0xFFFFD700)),
                          const SizedBox(width: 4),
                          _multiBadge('19x', const Color(0xFFFF4D6D)),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Live player count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4ADE80).withOpacity(0.70),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _playerLabel,
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _multiBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.30), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}