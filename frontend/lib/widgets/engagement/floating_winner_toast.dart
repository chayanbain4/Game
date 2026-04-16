// lib/widgets/engagement/floating_winner_toast.dart
//
// Drop this widget in any game screen's Stack — it watches GameProvider
// and auto-shows an animated toast when the current user wins.
// Also exposes FloatingWinnerToast.showManual(context, amount, label)
// for non-Ludo games (scratch, andar bahar, etc.) that don't use Provider.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ludo/game_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Public widget — add to Stack in any screen
// ─────────────────────────────────────────────────────────────────
class FloatingWinnerToast extends StatefulWidget {
  /// userId is required so Ludo mode knows if THIS player won.
  /// Leave null for manual (non-Ludo) mode.
  final String? userId;

  const FloatingWinnerToast({super.key, this.userId});

  // ── Manual trigger for non-Ludo games ──────────────────────
  /// Call this from scratch/andarbahar/lottery screens after a win.
  /// [amount]  – e.g. 25  (number)
  /// [label]   – e.g. "Scratch Card"
  static void showManual(
    BuildContext context, {
    required int amount,
    String label = 'Game',
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        amount: amount,
        label: label,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<FloatingWinnerToast> createState() => _FloatingWinnerToastState();
}

class _FloatingWinnerToastState extends State<FloatingWinnerToast> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    // Only active in Ludo mode (userId provided)
    if (widget.userId == null) return const SizedBox.shrink();

    return Consumer<GameProvider>(
      builder: (ctx, p, _) {
        // Trigger once when this user wins
        // Trigger for BOTH normal win AND opponent-left win
        if (!_shown &&
            p.gameOver &&
            p.winner == widget.userId &&
            p.winAmount > 0) {
          _shown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            FloatingWinnerToast.showManual(
              ctx,
              amount: p.winAmount,
              label: 'Ludo',
            );
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Internal overlay widget — handles animation + auto-dismiss
// ─────────────────────────────────────────────────────────────────
class _ToastOverlay extends StatefulWidget {
  final int amount;
  final String label;
  final VoidCallback onDone;

  const _ToastOverlay({
    required this.amount,
    required this.label,
    required this.onDone,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _pulseCtrl;

  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  final _rng = Random();
  final List<_Confetti> _confetti = [];

  static const _green  = Color(0xFF2DFF8F);
  static const _gold   = Color(0xFFFFD93D);
  static const _bg     = Color(0xFF0F1C1B);
  static const _border = Color(0xFF00D2A0);

  @override
  void initState() {
    super.initState();

    // ── Slide in from top ──────────────────────────────────
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.elasticOut));
    _fadeAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    // ── Pulse on the amount text ───────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ── Confetti particles ─────────────────────────────────
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    for (int i = 0; i < 22; i++) {
      _confetti.add(_Confetti.random(_rng));
    }
    _confettiCtrl.forward();

    // ── Start entry + schedule exit ────────────────────────
    _slideCtrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _slideCtrl.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _confettiCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Confetti ──────────────────────────────────
              AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => SizedBox(
                  width: sw - 40,
                  height: 90,
                  child: Stack(
                    children: _confetti.map((c) {
                      final t = _confettiCtrl.value;
                      final dx = c.startX * (sw - 40) +
                          sin(t * c.freq * pi) * c.spread;
                      final dy = t * c.speed * 100 - 20;
                      final opacity = (1.0 - t).clamp(0.0, 1.0);
                      return Positioned(
                        left: dx,
                        top: dy,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.rotate(
                            angle: t * c.rotation,
                            child: Container(
                              width: c.size,
                              height: c.size * 0.55,
                              decoration: BoxDecoration(
                                color: c.color,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Toast card ────────────────────────────────
              GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withOpacity(0.30),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Trophy icon
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _gold.withOpacity(0.35), width: 1.5),
                        ),
                        child: const Center(
                          child: Text('🏆',
                              style: TextStyle(fontSize: 26)),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Text column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You Won — ${widget.label}!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, __) => Transform.scale(
                                scale: _pulseAnim.value,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '+₹${widget.amount} added!',
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dismiss hint
                      Text(
                        'tap to close',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.20),
                          fontSize: 10,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Confetti particle data class
// ─────────────────────────────────────────────────────────────────
class _Confetti {
  final double startX;
  final double speed;
  final double spread;
  final double freq;
  final double rotation;
  final double size;
  final Color color;

  const _Confetti({
    required this.startX,
    required this.speed,
    required this.spread,
    required this.freq,
    required this.rotation,
    required this.size,
    required this.color,
  });

  static const _colors = [
    Color(0xFF2DFF8F),
    Color(0xFFFFD93D),
    Color(0xFF3DA9FF),
    Color(0xFFFF4444),
    Color(0xFFFF9F43),
    Color(0xFFB983FF),
  ];

  factory _Confetti.random(Random rng) => _Confetti(
        startX:   rng.nextDouble(),
        speed:    0.6 + rng.nextDouble() * 0.8,
        spread:   20 + rng.nextDouble() * 40,
        freq:     1 + rng.nextDouble() * 3,
        rotation: (rng.nextDouble() - 0.5) * 8,
        size:     5 + rng.nextDouble() * 6,
        color:    _colors[rng.nextInt(_colors.length)],
      );
}