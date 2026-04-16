// lib/screens/roulette/roulette_game_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../services/user_session.dart';
import '../../services/roulette_service.dart';
import '../../models/roulette/roulette_game_model.dart';
import '../../widgets/engagement/floating_winner_toast.dart';
import '../../widgets/engagement/small_reward_popup.dart';
import '../../widgets/engagement/loss_recovery_popup.dart';
import '../../widgets/engagement/live_chat_overlay.dart';

// ── Number colour helpers ─────────────────────────────────────────
const _kRedNums = {1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36};

Color _numColor(int n) {
  if (n == 0) return const Color(0xFF22C55E);
  return _kRedNums.contains(n) ? const Color(0xFFEF4444) : const Color(0xFF1C1C1C);
}

// ═══════════════════════════════════════════════════════════════
class RouletteGameScreen extends StatefulWidget {
  const RouletteGameScreen({super.key});

  @override
  State<RouletteGameScreen> createState() => _RouletteGameScreenState();
}

class _RouletteGameScreenState extends State<RouletteGameScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ────────────────────────────────────────────
  static const Color _bgDark  = Color(0xFF041A10);
  static const Color _bgMid   = Color(0xFF0B2E1A);
  static const Color _gold    = Color(0xFFFFD700);
  static const Color _goldDim = Color(0xFFB8860B);
  static const Color _red     = Color(0xFFEF4444);
  static const Color _textLight = Color(0xFFF0F4FF);
  static const Color _textMid   = Color(0xFFA0B5A8);

  final _service = RouletteService();

  // ── Game state ───────────────────────────────────────────────
  bool _isSpinning = false;
  bool _isFetching = false;
  bool _isGameOver = false;
  static RouletteGameModel? _currentGame;

  final List<RouletteBet> _selectedBets = [];
  int _chipAmount = 10;

  // Ball cell: which number on the board the ball is currently over
  int? _ballCell;

  int?   _landedNum;
  String _winType        = 'normal';
  int    _popularNum     = 7;
  int    _popularPercent = 0;
  static int _statsTotalPlayers = 0;
  static int _statsTotalWinners = 0;
  static int _statsTotalLosers  = 0;

  // ── Dynamic History State ─────────────────────────────────────
  final List<int> _history = [];
  int _spinsSinceLastZero = 0;

  Map<String, dynamic>? _pendingReward;
  Map<String, dynamic>? _pendingRecovery;

  // ── Audio ─────────────────────────────────────────────────────
  final _sfxBegin    = AudioPlayer();
  final _sfxRoulette = AudioPlayer();

  // ── Animation controllers ────────────────────────────────────
  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  late AnimationController _resultCtrl;
  late Animation<Offset>   _resultSlide;
  late Animation<double>   _resultFade;

  late AnimationController _counterCtrl;
  late Animation<int>      _counterAnim;

  late AnimationController _pulseCtrl;

  // Used to cancel ball animation if screen disposes mid-spin
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Initialize Random Fake History on First Load
    final rand = math.Random();
    bool zeroFound = false;
    for (int i = 0; i < 5; i++) {
      int n = rand.nextInt(37); // Random between 0 and 36
      _history.add(n);
      if (n == 0 && !zeroFound) {
        _spinsSinceLastZero = i;
        zeroFound = true;
      }
    }
    if (!zeroFound) {
      _spinsSinceLastZero = rand.nextInt(15) + 5; // Random number if 0 not in history
    }

    _pageCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pageFade  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _resultCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultSlide = Tween<Offset>(
            begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
    _resultFade  = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _counterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _counterAnim =
        IntTween(begin: 0, end: 0).animate(_counterCtrl);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _disposed = true;
    _pageCtrl.dispose();
    _resultCtrl.dispose();
    _counterCtrl.dispose();
    _pulseCtrl.dispose();
    _sfxBegin.dispose();
    _sfxRoulette.dispose();
    super.dispose();
  }

  // ── Bet helpers ──────────────────────────────────────────────
  void _toggleBet(String betType, dynamic betValue) {
    if (_isSpinning || _isFetching || _isGameOver) return;
    setState(() {
      final i = _selectedBets.indexWhere(
          (b) => b.betType == betType &&
                 b.betValue.toString() == betValue.toString());
      if (i >= 0) {
        _selectedBets.removeAt(i);
      } else {
        _selectedBets.add(RouletteBet(
            betType: betType, betValue: betValue, amount: _chipAmount));
      }
    });
  }

  bool _isBetOn(String t, dynamic v) => _selectedBets
      .any((b) => b.betType == t && b.betValue.toString() == v.toString());

  int _betAmt(String t, dynamic v) {
    final match = _selectedBets.where(
        (b) => b.betType == t && b.betValue.toString() == v.toString());
    return match.isEmpty ? 0 : match.first.amount;
  }

  int get _totalBet => _selectedBets.fold(0, (s, b) => s + b.amount);

  // ── Spin ─────────────────────────────────────────────────────
  Future<void> _spin() async {
    if (_isSpinning || _isFetching || _selectedBets.isEmpty) {
      if (_selectedBets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Place at least one bet first!')));
      }
      return;
    }

    final userId   = UserSession.instance.email ?? '';
    final username = UserSession.instance.name  ?? 'Player';
    if (userId.isEmpty) return;

    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    if (!hasFreeSpins && UserSession.instance.balance < _totalBet) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insufficient balance. Need ₹$_totalBet')));
      return;
    }

    // ── Step 1: fetch result ────────────────────────────────────
    setState(() {
      _isFetching  = true;
      _isGameOver  = false;
      _currentGame = null;
      _landedNum   = null;
      _ballCell    = null;
    });
    _resultCtrl.reverse();
    HapticFeedback.heavyImpact();

    _sfxBegin.play(AssetSource('audio/lets-begin.mp3'));

    final response = await _service.play(
      userId, username, List.from(_selectedBets),
      useFreeSpins: hasFreeSpins,
    );

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted || _disposed) return;

    if (response == null) {
      setState(() => _isFetching = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to spin. Try again.')));
      return;
    }

    final spinNum = response.spinResult as int;

    // ── Step 2: Show Full Screen Circular Roulette Wheel Overlay ──────────────
    setState(() {
      _isFetching = false;
      _isSpinning = true;
      _landedNum  = spinNum; // Pass target to wheel
    });

    await _sfxRoulette.setReleaseMode(ReleaseMode.loop);
    _sfxRoulette.play(AssetSource('audio/roulette.mp3'));

    // Wait for the exact duration of the Wheel Overlay animation (5.5 seconds)
    await Future.delayed(const Duration(milliseconds: 5500));    
    if (!mounted || _disposed) return;

    await _sfxRoulette.stop();

    // ── Step 3: apply result and hide wheel ────────────────────────────────────
    if (response.newBalance  != null) UserSession.instance.setBalance(response.newBalance!);
    if (response.freeSpins   != null) UserSession.instance.setFreeSpins(response.freeSpins!);
    if (response.newWinCount != null) UserSession.instance.setWins(response.newWinCount!);

    setState(() {
      _currentGame       = response.game;
      _ballCell          = spinNum; // Keep indicator on board
      _winType           = response.winType;
      _popularNum        = response.popularNumber ?? 7;
      _popularPercent    = response.popularPercent;
      _statsTotalPlayers = response.totalPlayers;
      _statsTotalWinners = response.totalWinners;
      _statsTotalLosers  = response.totalLosers;
      _isSpinning        = false; // Hides the spinning wheel popup
      _isGameOver        = true;

      // UPDATE DYNAMIC HISTORY
      _history.insert(0, spinNum);
      if (_history.length > 5) {
        _history.removeLast(); 
      }
      
      if (spinNum == 0) {
        _spinsSinceLastZero = 0;
      } else {
        _spinsSinceLastZero++;
      }
    });

    _resultCtrl.forward(from: 0);

    if (response.game.isWin) {
      final win = response.totalWin as int;
      _counterAnim = IntTween(begin: 0, end: win)
          .animate(CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOut));
      _counterCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    if (response.reward   != null) _pendingReward   = response.reward;
    if (response.recovery != null) _pendingRecovery = response.recovery;

    if (_pendingReward != null && mounted) {
      final r = _pendingReward!; _pendingReward = null;
      Future.delayed(const Duration(milliseconds: 800),
          () { if (mounted) SmallRewardPopup.show(context, r); });
    }
    if (_pendingRecovery != null && mounted) {
      final r = _pendingRecovery!; _pendingRecovery = null;
      Future.delayed(const Duration(milliseconds: 1400),
          () { if (mounted) LossRecoveryPopup.show(context, r); });
    }
  }

  void _newGame() {
    _resultCtrl.reverse();
    _counterCtrl.reset();
    _sfxRoulette.stop();
    _sfxBegin.stop();
    setState(() {
      _currentGame = null;
      _selectedBets.clear();
      _landedNum   = null;
      _ballCell    = null;
      _isGameOver  = false;
      _isFetching  = false;
      _isSpinning  = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _bgDark,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Main scroll content ──────────────────────────────
            SlideTransition(
              position: _pageSlide,
              child: FadeTransition(
                opacity: _pageFade,
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              // --- 1. DYNAMIC HISTORY & LAST 0 STATS ---
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('History: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                        ..._history.map((num) {
                                          Color dotColor;
                                          if (num == 0) dotColor = const Color(0xFF22C55E);
                                          else if (_kRedNums.contains(num)) dotColor = const Color(0xFFEF4444);
                                          else dotColor = Colors.white70; // For black numbers
                                          return HistoryDot(number: num, color: dotColor);
                                        }).toList(),
                                      ],
                                    ),
                                    Text('Last 0: $_spinsSinceLastZero spins ago', 
                                      style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // ── Board ──────────────────────────
                              _buildBoardSection(),

                              if (_landedNum != null && _isGameOver) ...[
                                const SizedBox(height: 12),
                                _buildLandedDisplay(),
                              ],

                              const SizedBox(height: 14),
                              _buildChipSelector(),

                              if (_selectedBets.isNotEmpty && !_isGameOver) ...[
                                const SizedBox(height: 10),
                                _buildBetsSummary(),
                              ],

                              if (!_isGameOver) ...[
                                const SizedBox(height: 14),
                                _buildSpinButton(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Live chat overlay ────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              left: 12, right: 12,
              bottom: bottomInset > 0 ? bottomInset + 8 : 16,
              height: 220,
              child: const LiveChatOverlay(),
            ),

            // ── Result panel ─────────────────────────────────────
            if (_isGameOver && _currentGame != null) _buildResultPanel(),

            // ── Casino Wheel Overlay ─────────────────────────────
            if (_isSpinning && _landedNum != null)
              Positioned.fill(
                child: RouletteWheelOverlay(targetNumber: _landedNum!),
              ),

            // --- RANDOM FAKE WINNER NOTIFICATION ---
            const Positioned(
              top: 60.0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: FakeRandomWinnerBanner(), 
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(children: [
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
        const Text('🎡  Roulette',
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
      ]),
    );
  }

  Widget _buildBoardSection() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFB8860B).withOpacity(0.6), width: 1.5),
      ),
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 22, child: _numCell(0)),
                Expanded(child: _buildNumberRows()),
                SizedBox(width: 30, child: _buildColumnBets()),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(flex: 1, child: _buildDozenRow()),
          const SizedBox(height: 2),
          Expanded(flex: 1, child: _buildEvenMoneyRow()),

          if (_isFetching)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _gold.withOpacity(0.8)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Placing bet...',
                    style: TextStyle(
                        color: _gold.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 3 rows of numbers ─────────────────────────────────────────
  static const _row1 = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36];
  static const _row2 = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35];
  static const _row3 = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34];

  Widget _buildNumberRows() {
    return Column(children: [
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: _row1.map((n) => Expanded(child: _numCell(n))).toList())),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: _row2.map((n) => Expanded(child: _numCell(n))).toList())),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: _row3.map((n) => Expanded(child: _numCell(n))).toList())),
    ]);
  }

  Widget _buildColumnBets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _specialCell('column', 'col3', '2-1', const Color(0xFF34D399))),
        Expanded(child: _specialCell('column', 'col2', '2-1', const Color(0xFF34D399))),
        Expanded(child: _specialCell('column', 'col1', '2-1', const Color(0xFF34D399))),
      ]
    );
  }

  Widget _buildDozenRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _specialCell('dozen', '1st', '1st 12', const Color(0xFFFBBF24))),
        Expanded(child: _specialCell('dozen', '2nd', '2nd 12', const Color(0xFFFBBF24))),
        Expanded(child: _specialCell('dozen', '3rd', '3rd 12', const Color(0xFFFBBF24))),
      ]
    );
  }

  Widget _buildEvenMoneyRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _specialCell('half',   'low',   '1-18',  const Color(0xFF60A5FA))),
        Expanded(child: _specialCell('parity', 'even',  'Even',  const Color(0xFF60A5FA))),
        Expanded(child: _colorCircleCell('red')),
        Expanded(child: _colorCircleCell('black')),
        Expanded(child: _specialCell('parity', 'odd',   'Odd',   const Color(0xFF60A5FA))),
        Expanded(child: _specialCell('half',   'high',  '19-36', const Color(0xFF60A5FA))),
      ]
    );
  }

  // ── Individual cell builders ──────────────────────────────────
  Widget _numCell(int n) {
    final isBall     = _ballCell == n;
    final isSelected = _isBetOn('number', n);
    final betAmt     = _betAmt('number', n);
    
    // Only highlight landed cell AFTER animation finishes (_isGameOver)
    final isLanded   = _landedNum == n && _isGameOver;

    Color bg;
    if (n == 0)              bg = const Color(0xFF16a34a);
    else if (_kRedNums.contains(n)) bg = const Color(0xFF8B1010);
    else                     bg = const Color(0xFF191919);

    return GestureDetector(
      onTap: () => _toggleBet('number', n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(1),
        height: 34,
        decoration: BoxDecoration(
          color: isLanded
              ? _gold.withOpacity(0.85)
              : isSelected
                  ? bg
                  : bg.withOpacity(0.65),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isBall
                ? Colors.white
                : isLanded
                    ? _gold
                    : isSelected
                        ? _gold.withOpacity(0.7)
                        : Colors.white.withOpacity(0.12),
            width: isBall || isLanded ? 2.0 : isSelected ? 1.2 : 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$n',
              style: TextStyle(
                color: isLanded ? Colors.black : Colors.white,
                fontSize: n == 0 ? 10 : 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isBall && _isGameOver)
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        blurRadius: 6),
                  ],
                ),
              ),
            if (isSelected && !(isBall && _isGameOver))
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '₹$betAmt',
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 5,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _specialCell(
      String type, String val, String label, Color accent) {
    final isSelected = _isBetOn(type, val);
    final betAmt     = _betAmt(type, val);
    return GestureDetector(
      onTap: () => _toggleBet(type, val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withOpacity(0.18)
              : accent.withOpacity(0.04),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected
                ? accent.withOpacity(0.8)
                : accent.withOpacity(0.22),
            width: isSelected ? 1.2 : 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : accent.withOpacity(0.55),
                fontSize: 8,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (isSelected)
              Positioned(
                bottom: 1, right: 2,
                child: Text(
                  '₹$betAmt',
                  style: TextStyle(
                      color: accent, fontSize: 6, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _colorCircleCell(String colorName) {
    final isSelected = _isBetOn('color', colorName);
    final betAmt     = _betAmt('color', colorName);
    final circleBg   = colorName == 'red'
        ? const Color(0xFFc03030)
        : const Color(0xFF555555);
    final borderClr  = colorName == 'red'
        ? const Color(0xFFEF4444)
        : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () => _toggleBet('color', colorName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? circleBg.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected
                ? borderClr.withOpacity(0.8)
                : borderClr.withOpacity(0.25),
            width: isSelected ? 1.2 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                  color: circleBg, shape: BoxShape.circle),
            ),
            if (isSelected)
              Text(
                '₹$betAmt',
                style: TextStyle(
                    color: borderClr,
                    fontSize: 6,
                    fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  // ── Landed display ───────────────────────────────────────────
  Widget _buildLandedDisplay() {
    final num   = _landedNum!;
    final color = _numColor(num);
    final label = num == 0
        ? 'GREEN'
        : _kRedNums.contains(num) ? 'RED' : 'BLACK';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final glow = 0.5 + _pulseCtrl.value * 0.5;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: color.withOpacity(0.45 * glow), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text('$num',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
              Text(
                num == 0
                    ? 'Zero — special'
                    : '${num % 2 == 0 ? 'Even' : 'Odd'}  •  ${num <= 18 ? '1–18' : '19–36'}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 11),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // ── Chip selector ─────────────────────────────────────────────
  Widget _buildChipSelector() {
    final chips = [5, 10, 25, 50, 100];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Chip Size',
          style: TextStyle(
              color: Colors.white.withOpacity(0.50),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Row(
        children: chips.map((c) {
          final sel = c == _chipAmount;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _chipAmount = c),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(
                          colors: [_gold, _goldDim])
                      : null,
                  color: sel ? null : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? _gold : Colors.white.withOpacity(0.12),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text('₹$c',
                      style: TextStyle(
                          color: sel ? Colors.black : _textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ── Bets summary bar ─────────────────────────────────────────
  Widget _buildBetsSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.18)),
      ),
      child: Row(children: [
        Text('${_selectedBets.length} bet${_selectedBets.length > 1 ? 's' : ''}',
            style: TextStyle(
                color: _textLight.withOpacity(0.55), fontSize: 12)),
        const Spacer(),
        Text('Total: ',
            style: TextStyle(
                color: _textLight.withOpacity(0.50), fontSize: 12)),
        Text('₹$_totalBet',
            style: const TextStyle(
                color: _gold, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _selectedBets.clear()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withOpacity(0.30)),
            ),
            child: Text('Clear',
                style: TextStyle(
                    color: _red.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ── Spin button ──────────────────────────────────────────────
  Widget _buildSpinButton() {
    final busy    = _isSpinning || _isFetching;
    final canSpin = _selectedBets.isNotEmpty && !busy;
    return GestureDetector(
      onTap: canSpin ? _spin : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: canSpin
              ? const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
              : null,
          color: canSpin ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          boxShadow: canSpin
              ? [
                  const BoxShadow(
                      color: Color(0x55FFD700),
                      blurRadius: 20,
                      offset: Offset(0, 6))
                ]
              : [],
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(
                  canSpin
                      ? '🎡  SPIN  •  ₹$_totalBet'
                      : '  Select a bet first',
                  style: TextStyle(
                    color: canSpin ? Colors.black : _textMid,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  RESULT PANEL  (slides up from bottom)
  // ═════════════════════════════════════════════════════════════
  Widget _buildResultPanel() {
    final game  = _currentGame!;
    final isWin = game.isWin;

    return SlideTransition(
      position: _resultSlide,
      child: FadeTransition(
        opacity: _resultFade,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isWin
                  ? const Color(0xFF071F12)
                  : const Color(0xFF1A0707),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isWin
                      ? _gold.withOpacity(0.75)
                      : _red.withOpacity(0.50),
                  width: 2,
                ),
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isWin ? _gold : _red, width: 2),
                      ),
                      child: Center(
                          child: Text(isWin ? '🏆' : '😔',
                              style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              isWin ? 'YOU WON!' : 'BETTER LUCK',
                              style: TextStyle(
                                  color: isWin ? _gold : _red,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Ball landed on ${game.spinResult}'
                              ' • ${game.resultColor.toUpperCase()}',
                              style: TextStyle(
                                  color:
                                      Colors.white.withOpacity(0.50),
                                  fontSize: 12),
                            ),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: [
                        _statChip('NUMBER', '${game.spinResult}',
                            _numColor(game.spinResult)),
                        _statDiv(),
                        _statChip('COLOR',
                            game.resultColor.toUpperCase(),
                            _numColor(game.spinResult)),
                        _statDiv(),
                        if (isWin)
                          AnimatedBuilder(
                            animation: _counterAnim,
                            builder: (_, __) => _statChip(
                                'YOU WIN',
                                '+₹${_counterAnim.value}',
                                Colors.greenAccent),
                          )
                        else
                          _statChip(
                              'DEDUCTED', '-₹$_totalBet', _red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (game.bets.isNotEmpty) _buildBetBreakdown(game),

                  if (_statsTotalPlayers > 0) ...[
                    const SizedBox(height: 10),
                    _buildPlayersBar(),
                  ],
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _newGame,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isWin
                              ? [_gold, _goldDim]
                              : [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF2563EB),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          isWin ? '🎰  Spin Again' : '🎡  Try Again',
                          style: TextStyle(
                            color: isWin ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBetBreakdown(RouletteGameModel game) {
    return Column(
      children: game.bets.map((b) {
        final clr =
            b.won ? Colors.greenAccent : _red.withOpacity(0.70);
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Text(
              '${b.betType.toUpperCase()}  ${b.betValue}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.60), fontSize: 12),
            ),
            const Spacer(),
            if (b.won)
              Text('${b.payout}× → +₹${b.winAmount}',
                  style: TextStyle(
                      color: clr,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))
            else
              Text('-₹${b.amount}',
                  style: TextStyle(color: clr, fontSize: 12)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _statChip(String label, String value, Color vc) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 9,
                  letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: vc,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      );

  Widget _statDiv() =>
      Container(width: 1, height: 26, color: Colors.white.withOpacity(0.10));

  Widget _buildPlayersBar() {
    final winPct = _statsTotalPlayers > 0
        ? _statsTotalWinners / _statsTotalPlayers
        : 0.0;
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$_statsTotalWinners won',
              style: TextStyle(
                  color: Colors.greenAccent.withOpacity(0.75),
                  fontSize: 11)),
          Text('$_statsTotalPlayers players',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.30), fontSize: 11)),
          Text('$_statsTotalLosers lost',
              style: TextStyle(
                  color: _red.withOpacity(0.75), fontSize: 11)),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(children: [
          Expanded(
            flex: (winPct * 100).round().clamp(1, 99),
            child: Container(
                height: 5,
                color: Colors.greenAccent.withOpacity(0.60)),
          ),
          Expanded(
            flex: (100 - (winPct * 100).round()).clamp(1, 99),
            child: Container(height: 5, color: _red.withOpacity(0.50)),
          ),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  CASINO WHEEL OVERLAY WIDGET
// ═══════════════════════════════════════════════════════════════
class RouletteWheelOverlay extends StatefulWidget {
  final int targetNumber;
  const RouletteWheelOverlay({super.key, required this.targetNumber});

  @override
  State<RouletteWheelOverlay> createState() => _RouletteWheelOverlayState();
}

class _RouletteWheelOverlayState extends State<RouletteWheelOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ballRotAnim;
  late Animation<double> _fadeAnim;

  // Standard European Roulette Sequence
  final List<int> _wheelNums = [
    0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 
    5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
  ];

  @override
  void initState() {
    super.initState();
    // 5.5 Seconds total animation time
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 5500));
    
    // Fade in over the first 10% of the animation
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.1))
    );

    // Calculate exact stopping angle
    final targetIdx = _wheelNums.indexOf(widget.targetNumber);
    final targetAngle = targetIdx * (2 * math.pi / 37);
    
    // 8 full spins + exact target angle
    final totalRotation = (math.pi * 2 * 8) + targetAngle; 

    // The ball spins fast and decelerates realistically
    _ballRotAnim = Tween<double>(begin: 0, end: totalRotation).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCirc) 
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      // Block touches from interacting with the board below
      child: GestureDetector(
        onTap: () {}, // consume taps
        child: Container(
          color: Colors.black.withOpacity(0.85),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glowing shadow behind wheel
              Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.15), blurRadius: 60, spreadRadius: 10)
                  ]
                ),
              ),
              
              // The Custom Painted Wheel
              SizedBox(
                width: 300, height: 300,
                child: CustomPaint(painter: _WheelPainter(nums: _wheelNums)),
              ),
              
              // Center metallic hub
             // Center metallic hub
              Container(
                width: 45, height: 45,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(colors: [Color(0xFFB8860B), Color(0xFF4A3605)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.8), width: 2),
                  boxShadow: [
                    // Fixed BoxShadow
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)
                  ]
                ),
              ),
              
              // Rotating Ball
              AnimatedBuilder(
                animation: _ballRotAnim,
                builder: (_, __) {
                  return Transform.rotate(
                    angle: _ballRotAnim.value,
                    child: Container(
                      width: 245, height: 245, // Ball track size (orbits inside the numbers)
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10), 
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 8, spreadRadius: 2)
                          ]
                        ),
                      ),
                    ),
                  );
                }
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<int> nums;
  _WheelPainter({required this.nums});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final sweepAngle = 2 * math.pi / 37;

    final redPaint = Paint()..color = const Color(0xFF8B1010)..style = PaintingStyle.fill;
    final blackPaint = Paint()..color = const Color(0xFF151515)..style = PaintingStyle.fill;
    final greenPaint = Paint()..color = const Color(0xFF16A34A)..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = const Color(0xFFFFD700).withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1;

    // Outer Rim
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF222222)..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFD700).withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 4);

    for (int i = 0; i < 37; i++) {
      final n = nums[i];
      // Offset by -pi/2 so 0 index starts at the very top center
      final startAngle = -math.pi / 2 + (i * sweepAngle) - (sweepAngle / 2);

      Paint p = blackPaint;
      if (n == 0) p = greenPaint;
      else if (_kRedNums.contains(n)) p = redPaint;

      // Draw Colored Slice
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 4), startAngle, sweepAngle, true, p);
      
      // Draw Divider Line
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 4), startAngle, sweepAngle, true, borderPaint);

      // Draw Number Text
      final textPainter = TextPainter(
        text: TextSpan(text: '$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      canvas.save();
      final textAngle = startAngle + (sweepAngle / 2);
      
      // Move canvas origin to wheel center
      canvas.translate(center.dx, center.dy);
      // Rotate canvas to the current slice's angle
      canvas.rotate(textAngle);
      // Move out to the edge of the wheel
      canvas.translate(radius - 22, 0); 
      // Rotate text 90 degrees so it faces inward (standard casino style)
      canvas.rotate(math.pi / 2); 
      
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
    
    // Inner Ring boundary
    canvas.drawCircle(center, radius - 40, Paint()..color = const Color(0xFFFFD700).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
//  ADDITIONAL WIDGETS
// ═══════════════════════════════════════════════════════════════

class HistoryDot extends StatelessWidget {
  final int number;
  final Color color;
  
  const HistoryDot({super.key, required this.number, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class FakeRandomWinnerBanner extends StatefulWidget {
  const FakeRandomWinnerBanner({super.key});

  @override
  State<FakeRandomWinnerBanner> createState() => _FakeRandomWinnerBannerState();
}

class _FakeRandomWinnerBannerState extends State<FakeRandomWinnerBanner> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  Timer? _timer;

  String _winnerName = "";
  int _winAmount = 0;
  
  final List<String> _names = ["Rahul", "Amit", "Priya", "Sneha", "Vikram", "Raj", "Kiran", "Neha"];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(begin: const Offset(0, -3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));

    _startFakeNotifications();
  }

  void _startFakeNotifications() {
    _timer = Timer.periodic(const Duration(seconds: 12), (timer) async {
      if (!mounted) return;
      
      setState(() {
        _winnerName = _names[math.Random().nextInt(_names.length)];
        _winAmount = (math.Random().nextInt(100) + 10) * 10; // e.g. 150, 500, 1000
      });
      
      _animCtrl.forward();
      await Future.delayed(const Duration(seconds: 4)); // Show for 4 seconds
      if (mounted) _animCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 10),
            Text(
              "$_winnerName won ₹$_winAmount!",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}