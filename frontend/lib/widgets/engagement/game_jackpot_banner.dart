// lib/widgets/engagement/game_jackpot_banner.dart
import 'dart:math';
import 'package:flutter/material.dart';

class GameJackpotBanner extends StatefulWidget {
  GameJackpotBanner({super.key});

  @override
  State<GameJackpotBanner> createState() => _GameJackpotBannerState();
}

class _GameJackpotBannerState extends State<GameJackpotBanner>
    with SingleTickerProviderStateMixin {
  final _rand = Random();

  // Jackpot amount — resets to 100 when it hits 2999
  int _amount = 0;

  // Fake winner names cycling
  static const List<String> _names = [
    'Rahul', 'Priya', 'Amit', 'Sneha', 'Vikram',
    'Pooja', 'Arjun', 'Neha', 'Ravi', 'Kavya',
    'Suresh', 'Anita', 'Deepak', 'Meena', 'Kiran',
  ];
  static const List<String> _cities = [
    'Mumbai', 'Delhi', 'Pune', 'Hyderabad', 'Chennai',
    'Bangalore', 'Kolkata', 'Ahmedabad', 'Jaipur', 'Lucknow',
  ];
  static const List<String> _games = [
    'Jackpot',
  ];

  String _winnerName = '';
  String _winnerCity = '';
  String _winnerGame = '';
  int _winnerAmount = 0;
  bool _showWinner = false;

  // Visibility: banner hides and reappears randomly
  bool _visible = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // For number slide animation
  int _prevAmount = 0;

  @override
  void initState() {
    super.initState();

    // Start between 100 and 800
    _amount = 100 + _rand.nextInt(700);
    _prevAmount = _amount;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _scheduleIncrement();
    _scheduleWinnerFlash();
    _scheduleVisibilityToggle();
  }

  void _scheduleIncrement() {
    // Random delay 2–6 seconds
    final delay = 2000 + _rand.nextInt(4000);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;

      // Random jump: anywhere from 7 to 47
      final jump = 7 + _rand.nextInt(41);
      int next = _amount + jump;

      if (next >= 2999) {
        // Reset back to 100–300
        next = 100 + _rand.nextInt(200);
      }

      setState(() {
        _prevAmount = _amount;
        _amount = next;
      });

      _scheduleIncrement();
    });
  }

  void _scheduleWinnerFlash() {
    // Show a winner popup every 8–18 seconds
    final delay = 8000 + _rand.nextInt(10000);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;

      final name = _names[_rand.nextInt(_names.length)];
      final city = _cities[_rand.nextInt(_cities.length)];
      final game = _games[_rand.nextInt(_games.length)];
      // Winner amount between 50 and 500
      final amt = (5 + _rand.nextInt(46)) * 10;

      setState(() {
        _winnerName = name;
        _winnerCity = city;
        _winnerGame = game;
        _winnerAmount = amt;
        _showWinner = true;
      });

      // Hide winner after 3.5 seconds
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _showWinner = false);
      });

      _scheduleWinnerFlash();
    });
  }

  void _scheduleVisibilityToggle() {
    // Randomly hide the banner for a few seconds, then bring it back
    final showDelay = 15000 + _rand.nextInt(20000); // visible for 15–35s
    Future.delayed(Duration(milliseconds: showDelay), () {
      if (!mounted) return;
      setState(() => _visible = false);

      // Hidden for 4–8 seconds
      final hideDelay = 4000 + _rand.nextInt(4000);
      Future.delayed(Duration(milliseconds: hideDelay), () {
        if (!mounted) return;
        setState(() => _visible = true);
        _scheduleVisibilityToggle();
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return '\u20B9$t,${r.toString().padLeft(3, '0')}';
    }
    return '\u20B9$n';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: _visible
          ? _buildBanner()
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBanner() {
    return AnimatedBuilder(
      animation: _pulse,
      key: const ValueKey('banner'),
      builder: (_, __) {
        final g = _pulse.value;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B0E3A), Color(0xFF2E1760)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFD166).withOpacity(g * 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD166).withOpacity(g * 0.18),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // ── Main jackpot row ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      // Trophy
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD166).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: const Color(0xFFFFD166).withOpacity(g * 0.4),
                          ),
                        ),
                        child: const Center(
                          child: Text('\ud83c\udfc6', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Label + animated amount
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'JACKPOT PRIZE',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD166).withOpacity(0.80),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _liveBadge(g),
                              ],
                            ),
                            const SizedBox(height: 2),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              transitionBuilder: (child, anim) => SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.8),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                                child: FadeTransition(opacity: anim, child: child),
                              ),
                              child: Text(
                                _fmt(_amount),
                                key: ValueKey(_amount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // No winner pill
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                         
                          Text(
                            'Could be you!',
                            style: TextStyle(
                              color: const Color(0xFFFFD166).withOpacity(0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Winner flash strip ────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _showWinner
                      ? _buildWinnerStrip()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWinnerStrip() {
    return Container(
      key: const ValueKey('winner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2DFF8F).withOpacity(0.07),
        border: Border(
          top: BorderSide(color: const Color(0xFF2DFF8F).withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF2DFF8F).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('\ud83c\udfc6', style: TextStyle(fontSize: 11))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11),
                children: [
                  TextSpan(
                    text: '$_winnerName ',
                    style: const TextStyle(
                      color: Color(0xFF2DFF8F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: 'from $_winnerCity won ',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  TextSpan(
                    text: '\u20B9$_winnerAmount',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' · $_winnerGame',
                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveBadge(double pulse) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF2DFF8F).withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2DFF8F).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2DFF8F).withOpacity(pulse),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Color(0xFF2DFF8F),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}