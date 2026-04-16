// lib/screens/roulette/roulette_lobby_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/user_session.dart';
import 'roulette_game_screen.dart';

// ── Helpers ───────────────────────────────────────────────────
const _kRedNums = {1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36};

Color _getHistoryColor(int n) {
  if (n == 0) return const Color(0xFF22C55E);
  if (_kRedNums.contains(n)) return const Color(0xFFEF4444);
  return const Color(0xFF1C1C1C);
}

// ═══════════════════════════════════════════════════════════════
class RouletteLobbyScreen extends StatefulWidget {
  const RouletteLobbyScreen({super.key});

  @override
  State<RouletteLobbyScreen> createState() => _RouletteLobbyScreenState();
}

class _RouletteLobbyScreenState extends State<RouletteLobbyScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _bg    = Color(0xFF041A10);
  static const _gold  = Color(0xFFFFD700);

  // Fake live casino data
  late List<_LiveTableData> _tables;
  Timer? _liveUpdateTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _initTables();
    _startLiveUpdates();

    // Trigger fade in
    Future.delayed(const Duration(milliseconds: 100), () => _fadeCtrl.forward());
  }

  void _initTables() {
    final rand = math.Random();
    _tables = [
      _LiveTableData(
        name: "Diamond Auto",
        players: 142,
        isSpinning: false,
        themeColor: const Color(0xFF8B5CF6), // Purple
        history: List.generate(4, (_) => rand.nextInt(37)),
      ),
      _LiveTableData(
        name: "Lightning",
        players: 328,
        isSpinning: true,
        themeColor: const Color(0xFFEF4444), // Red
        history: List.generate(4, (_) => rand.nextInt(37)),
      ),
      _LiveTableData(
        name: "European",
        players: 891,
        isSpinning: false,
        themeColor: const Color(0xFF10B981), // Green
        history: List.generate(4, (_) => rand.nextInt(37)),
      ),
      _LiveTableData(
        name: "Classic RNG",
        players: 412,
        isSpinning: true,
        themeColor: const Color(0xFF3B82F6), // Blue
        history: List.generate(4, (_) => rand.nextInt(37)),
      ),
    ];
  }

  void _startLiveUpdates() {
    _liveUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final rand = math.Random();
      setState(() {
        for (var table in _tables) {
          // Fluctuate players slightly
          table.players += rand.nextInt(15) - 7; 
          if (table.players < 10) table.players = 45; 
          
          // Randomly toggle spinning status and add history
          if (rand.nextDouble() > 0.6) {
            table.isSpinning = !table.isSpinning;
            if (!table.isSpinning) {
              table.history.insert(0, rand.nextInt(37));
              if (table.history.length > 4) table.history.removeLast();
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _liveUpdateTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    HapticFeedback.heavyImpact();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RouletteGameScreen()));
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Live Casino',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3)),
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: UserSession.instance.balanceNotifier,
            builder: (_, bal, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('💰', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text('₹$bal',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / CTA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2E1A), Color(0xFF041A10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _gold.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _gold.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🎰', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Premium Roulette', 
                            style: TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text('Ready to place your bets?', 
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: _gold.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Center(
                      child: Text('NEW GAME',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('LIVE TABLES',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
              const Spacer(),
              Text('Visual Only', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
          
          const SizedBox(height: 16),

          // 4 Tables Grid (Visualization Only)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tables.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85, // Makes the cards slightly taller than wide
            ),
            itemBuilder: (context, index) {
              return _ActiveGridTableCard(table: _tables[index]);
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Models & Active Grid Table Card Widget
// ═══════════════════════════════════════════════════════════════

class _LiveTableData {
  final String name;
  int players;
  bool isSpinning;
  final Color themeColor;
  final List<int> history;

  _LiveTableData({
    required this.name,
    required this.players,
    required this.isSpinning,
    required this.themeColor,
    required this.history,
  });
}

class _ActiveGridTableCard extends StatelessWidget {
  final _LiveTableData table;

  const _ActiveGridTableCard({required this.table});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF092013), // Deep casino green
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: table.isSpinning 
            ? table.themeColor.withOpacity(0.4) 
            : Colors.white.withOpacity(0.05),
          width: table.isSpinning ? 1.5 : 1.0,
        ),
        boxShadow: table.isSpinning ? [
          BoxShadow(
            color: table.themeColor.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ] : [],
      ),
      child: Column(
        children: [
          // Header: Name & Players
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: table.themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: table.themeColor.withOpacity(0.8), blurRadius: 4)]
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        table.name, 
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.person, size: 12, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 2),
                  Text('${table.players}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                ],
              )
            ],
          ),
          
          const Spacer(),

          // Central Visual Indicator (Virtual Wheel representation)
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer track
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 4),
                ),
              ),
              // Dynamic Core
              _PulsingCore(isSpinning: table.isSpinning, themeColor: table.themeColor),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Status Text
          Text(
            table.isSpinning ? 'SPINNING...' : 'BETS OPEN',
            style: TextStyle(
              color: table.isSpinning ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),

          const Spacer(),

          // History Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: table.history.map((num) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _HistoryDot(number: num),
              );
            }).toList(),
          )
        ],
      ),
    );
  }
}

// ── Mini Widgets ────────────────────────────────────────────────

class _PulsingCore extends StatefulWidget {
  final bool isSpinning;
  final Color themeColor;
  
  const _PulsingCore({required this.isSpinning, required this.themeColor});

  @override
  State<_PulsingCore> createState() => _PulsingCoreState();
}

class _PulsingCoreState extends State<_PulsingCore> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (widget.isSpinning) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning && !oldWidget.isSpinning) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isSpinning && oldWidget.isSpinning) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpinning) {
      // Static "Bets Open" state
      return Container(
        width: 35, height: 35,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.2), // Green
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
        ),
        child: const Center(child: Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981))),
      );
    }

    // "Spinning" animated state
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 35 + (_ctrl.value * 10), 
          height: 35 + (_ctrl.value * 10),
          decoration: BoxDecoration(
            color: widget.themeColor.withOpacity(0.3 + (_ctrl.value * 0.4)),
            shape: BoxShape.circle,
            border: Border.all(color: widget.themeColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withOpacity(0.5),
                blurRadius: 10 * _ctrl.value,
                spreadRadius: 2 * _ctrl.value,
              )
            ]
          ),
          child: const Center(
            child: Icon(Icons.sync, size: 20, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _HistoryDot extends StatelessWidget {
  final int number;
  const _HistoryDot({required this.number});

  @override
  Widget build(BuildContext context) {
    final bg = _getHistoryColor(number);

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}