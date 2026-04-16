// lib/screens/andarbahar/andarbahar_game_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../services/user_session.dart';
import '../../services/andarbahar_service.dart';
import '../../models/andarbahar/andarbahar_game_model.dart';
import '../../widgets/engagement/floating_winner_toast.dart';
import '../../widgets/engagement/small_reward_popup.dart';
import '../../widgets/engagement/loss_recovery_popup.dart';
import '../../widgets/engagement/game_jackpot_banner.dart';
import '../../widgets/engagement/live_chat_overlay.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  GAME FLOW (NEW):
//
//  IDLE       → User sees Dealer Man + "START GAME" button
//  SHUFFLING  → Dealer shuffles (3.5 s), API call fires in parallel
//  JOKER_SHOW → Dealer throws Joker card → box revealed (wait 1.5 s)
//  PICK       → User picks ANDAR or BAHAR  (no timer – wait forever)
//  DEALING    → Dealer deals alternating cards to Andar/Bahar piles
//  RESULT     → Win/loss panel slides up
// ══════════════════════════════════════════════════════════════════════════════

enum _Phase { idle, shuffling, jokerShow, pick, dealing, result }

class AndarBaharGameScreen extends StatefulWidget {
  const AndarBaharGameScreen({super.key});

  @override
  State<AndarBaharGameScreen> createState() => _AndarBaharGameScreenState();
}

class _AndarBaharGameScreenState extends State<AndarBaharGameScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────────────
  static const Color _bgTableCenter = Color(0xFF0F5132);
  static const Color _bgTableEdge   = Color(0xFF062314);
  static const Color _surface       = Color(0xFF112A1D);
  static const Color _andar         = Color(0xFF3B82F6);
  static const Color _bahar         = Color(0xFFEF4444);
  static const Color _gold          = Color(0xFFFFD700);
  static const Color _goldDark      = Color(0xFFB8860B);
  static const Color _textLight     = Color(0xFFF0F4FF);
  static const Color _textMid       = Color(0xFFA0B5A8);

  final _service = AndarBaharService();

  // Audio
  final AudioPlayer _shufflePlayer = AudioPlayer();
  final AudioPlayer _cardPlayer1   = AudioPlayer();
  final AudioPlayer _cardPlayer2   = AudioPlayer();
  bool _usePlayer1 = true;

  // ── Phase ────────────────────────────────────────────────────────
  _Phase _phase = _Phase.idle;

  // ── Game State ──────────────────────────────────────────────────
  String?              _playerChoice;
  AndarBaharGameModel? _currentGame;

  int    _revealedAndar     = 0;
  int    _revealedBahar     = 0;
  String _activeDealingSide = '';
  CardModel? _flyingCard;
  Alignment  _flyingCardAlign   = const Alignment(0, -0.8);
  bool   _suspense      = false;
  bool   _jokerRevealed = false; // true only AFTER dealer throw animation lands

  Map<String, dynamic>? _pendingReward;
  Map<String, dynamic>? _pendingRecovery;
  int?   _lastWinAmount;
  String _winType        = 'normal';
  int    _statsTotalPlayers = 0;
  int    _statsTotalWinners = 0;
  int    _statsTotalLosers  = 0;

  // ── Dealer ──────────────────────────────────────────────────────
  bool   _dealerCardVisible = false;
  Offset _dealerCardOffset  = Offset.zero;
  double _dealerCardOpacity = 0.0;
  String _dealerCardSuit    = '♠';
  String _dealerCardValue   = 'A';

  Timer? _faceSwapTimer;

  // Mock deck for shuffle animation
  final List<Map<String, String>> _mockDeck = [
    {'v': 'A',  's': '♠'}, {'v': 'K',  's': '♥'}, {'v': 'Q',  's': '♦'},
    {'v': 'J',  's': '♣'}, {'v': '10', 's': '♠'}, {'v': '9',  's': '♥'},
    {'v': '8',  's': '♦'}, {'v': '7',  's': '♣'}, {'v': '6',  's': '♠'},
    {'v': '5',  's': '♥'}, {'v': '4',  's': '♦'}, {'v': '3',  's': '♣'},
    {'v': '2',  's': '♠'}, {'v': 'A',  's': '♥'}, {'v': 'K',  's': '♦'},
    {'v': 'Q',  's': '♣'}, {'v': 'J',  's': '♠'}, {'v': '10', 's': '♥'},
    {'v': '9',  's': '♦'}, {'v': '8',  's': '♣'}, {'v': '7',  's': '♠'},
    {'v': '6',  's': '♥'}, {'v': '5',  's': '♦'}, {'v': '4',  's': '♣'},
  ];

  // ── Animation Controllers ───────────────────────────────────────
  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  late AnimationController _pulseCtrl;
  late Animation<double>   _shuffleAnim;

  late AnimationController _throwArmCtrl;
  late Animation<double>   _throwArmAngle;

  late AnimationController _dealerBobCtrl;
  late Animation<double>   _dealerBob;

  // Joker reveal pulse
  late AnimationController _jokerPulseCtrl;
  late Animation<double>   _jokerPulse;

  // Result panel slide-up
  late AnimationController _resultCtrl;
  late Animation<Offset>   _resultSlide;
  late Animation<double>   _resultFade;

  // Win amount counter
  late AnimationController _counterCtrl;
  late Animation<int>      _counterAnim;

  // Pick buttons pop-in
  late AnimationController _pickCtrl;
  late Animation<double>   _pickScale;

  // Dealer arm shuffle loop (rapid back-and-forth during shuffle phase)
  late AnimationController _shuffleArmCtrl;
  late Animation<double>   _shuffleArmAngle;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pageCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat(reverse: true);
    _shuffleAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutCubic);

    _throwArmCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _throwArmAngle = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -0.55).chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: -0.55, end: 0.65).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.65, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
    ]).animate(_throwArmCtrl);

    _dealerBobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _dealerBob = Tween<double>(begin: 0.0, end: -4.0)
        .animate(CurvedAnimation(parent: _dealerBobCtrl, curve: Curves.easeInOut));

    _jokerPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _jokerPulse = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _jokerPulseCtrl, curve: Curves.easeInOut));

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _resultSlide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _counterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _counterAnim = IntTween(begin: 0, end: 0).animate(_counterCtrl);

    _pickCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pickScale = CurvedAnimation(parent: _pickCtrl, curve: Curves.elasticOut);

    // Rapid arm shuffle: sweeps left-right repeatedly during shuffle phase
    _shuffleArmCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..repeat(reverse: true);
    _shuffleArmAngle = Tween<double>(begin: -0.5, end: 0.5)
        .animate(CurvedAnimation(parent: _shuffleArmCtrl, curve: Curves.easeInOutSine));

    _shufflePlayer.setSource(AssetSource('audio/shuffle.mp3'));
    _cardPlayer1.setSource(AssetSource('audio/card.mp3'));
    _cardPlayer1.setPlayerMode(PlayerMode.lowLatency);
    _cardPlayer2.setSource(AssetSource('audio/card.mp3'));
    _cardPlayer2.setPlayerMode(PlayerMode.lowLatency);

    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _faceSwapTimer?.cancel();
    _shufflePlayer.dispose();
    _cardPlayer1.dispose();
    _cardPlayer2.dispose();
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    _throwArmCtrl.dispose();
    _dealerBobCtrl.dispose();
    _jokerPulseCtrl.dispose();
    _resultCtrl.dispose();
    _counterCtrl.dispose();
    _pickCtrl.dispose();
    _shuffleArmCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  //  AUDIO
  // ════════════════════════════════════════════════════════════════
  void _playCardSound() async {
    try {
      final player = _usePlayer1 ? _cardPlayer1 : _cardPlayer2;
      _usePlayer1 = !_usePlayer1;
      await player.stop();
      await player.play(AssetSource('audio/card.mp3'));
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════
  //  DEALER THROW ANIMATION
  // ════════════════════════════════════════════════════════════════
  void _triggerDealerThrow(String suit, String value) {
    if (!mounted) return;
    setState(() {
      _dealerCardSuit    = suit;
      _dealerCardValue   = value;
      _dealerCardVisible = true;
      _dealerCardOffset  = Offset.zero;
      _dealerCardOpacity = 1.0;
    });
    _throwArmCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _dealerCardOffset  = const Offset(0, 80);
        _dealerCardOpacity = 0.0;
      });
    });
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _dealerCardVisible = false;
        _dealerCardOffset  = Offset.zero;
        _dealerCardOpacity = 1.0;
      });
    });
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 1: START GAME  →  SHUFFLE + API CALL
  // ════════════════════════════════════════════════════════════════
  Future<void> _startGame() async {
    if (_phase != _Phase.idle) return;

    final userId   = UserSession.instance.email ?? '';
    final username = UserSession.instance.name  ?? 'Player';
    if (userId.isEmpty) return;

    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    if (!hasFreeSpins && UserSession.instance.balance < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. Need ₹4, have ₹${UserSession.instance.balance}')),
      );
      return;
    }

    setState(() {
      _phase         = _Phase.shuffling;
      _currentGame   = null;
      _playerChoice  = null;
      _revealedAndar = 0;
      _revealedBahar = 0;
      _jokerRevealed = false;
    });
    _resultCtrl.reverse();
    _pickCtrl.reset();

    HapticFeedback.heavyImpact();
    try { await _shufflePlayer.play(AssetSource('audio/shuffle.mp3')); } catch (_) {}

    // Animate deck shuffling
    _faceSwapTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (mounted) setState(() => _mockDeck.shuffle());
    });

    // Fire API and wait minimum 3.5 s for dramatic effect
    dynamic response;
    await Future.wait([
      _service.play(userId, username, 'ANDAR', useFreeSpins: hasFreeSpins)
          .then((r) => response = r),
      Future.delayed(const Duration(milliseconds: 3500)),
    ]);

    if (!mounted) return;
    _shufflePlayer.stop();
    _faceSwapTimer?.cancel();

    if (response == null) {
      setState(() => _phase = _Phase.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to play. Try again.')),
      );
      return;
    }

    // Update balances
    if (response.newBalance != null) UserSession.instance.setBalance(response.newBalance!);
    if (response.freeSpins   != null) UserSession.instance.setFreeSpins(response.freeSpins!);
    if (response.newWinCount != null) UserSession.instance.setWins(response.newWinCount!);

    setState(() {
      _currentGame       = response.game;
      _lastWinAmount     = response.winAmount;
      _winType           = response.winType;
      _statsTotalPlayers = response.totalPlayers;
      _statsTotalWinners = response.totalWinners;
      _statsTotalLosers  = response.totalLosers;
      _phase             = _Phase.jokerShow;
    });
    if (response.reward   != null) _pendingReward   = response.reward;
    if (response.recovery != null) _pendingRecovery = response.recovery;

    // ── Step 2: Reveal Joker ──────────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    HapticFeedback.lightImpact();
    _playCardSound();
    _triggerDealerThrow(response.game.jokerCard.suit, response.game.jokerCard.value);

    // Wait for card to fly from dealer hand to the box (~350ms), THEN reveal it
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    setState(() => _jokerRevealed = true);
    HapticFeedback.mediumImpact();

    // Wait so user sees joker, then show pick buttons
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    setState(() => _phase = _Phase.pick);
    _pickCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 2: USER PICKS ANDAR / BAHAR  →  START DEALING
  // ════════════════════════════════════════════════════════════════
  void _selectAndDeal(String choice) {
    if (_phase != _Phase.pick) return;
    setState(() {
      _playerChoice = choice;
      _phase        = _Phase.dealing;
      _activeDealingSide = '';
    });
    HapticFeedback.heavyImpact();
    _startDealAnimation();
  }

  // ════════════════════════════════════════════════════════════════
  //  DEAL ANIMATION
  // ════════════════════════════════════════════════════════════════
  void _startDealAnimation() async {
    final game       = _currentGame!;
    final totalAndar = game.andarCards.length;
    final totalBahar = game.baharCards.length;
    int  andarIdx    = 0;
    int  baharIdx    = 0;
    bool dealToAndar = true;

    while (mounted && _phase == _Phase.dealing) {
      if (dealToAndar && andarIdx < totalAndar) {
        setState(() => _activeDealingSide = 'ANDAR');
        _playCardSound();
        final c = game.andarCards[andarIdx];
        _triggerDealerThrow(c.suit, c.value);
        setState(() { _flyingCard = c; _flyingCardAlign = const Alignment(-0.6, -0.25); });
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted || _phase != _Phase.dealing) return;
        setState(() => _flyingCardAlign = const Alignment(-0.5, 0.15));
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted || _phase != _Phase.dealing) return;
        andarIdx++;
        setState(() { _flyingCard = null; _revealedAndar = andarIdx; });
        HapticFeedback.selectionClick();
        if (andarIdx == totalAndar && game.winningSide == 'ANDAR') {
          setState(() => _suspense = true);
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 1500));
          if (!mounted || _phase != _Phase.dealing) return;
          setState(() => _suspense = false);
          _onDealComplete();
          return;
        }
        dealToAndar = false;
        await Future.delayed(const Duration(milliseconds: 100));
      } else if (!dealToAndar && baharIdx < totalBahar) {
        setState(() => _activeDealingSide = 'BAHAR');
        _playCardSound();
        final c = game.baharCards[baharIdx];
        _triggerDealerThrow(c.suit, c.value);
        setState(() { _flyingCard = c; _flyingCardAlign = const Alignment(0.6, -0.25); });
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted || _phase != _Phase.dealing) return;
        setState(() => _flyingCardAlign = const Alignment(0.5, 0.15));
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted || _phase != _Phase.dealing) return;
        baharIdx++;
        setState(() { _flyingCard = null; _revealedBahar = baharIdx; });
        HapticFeedback.selectionClick();
        if (baharIdx == totalBahar && game.winningSide == 'BAHAR') {
          setState(() => _suspense = true);
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 1500));
          if (!mounted || _phase != _Phase.dealing) return;
          setState(() => _suspense = false);
          _onDealComplete();
          return;
        }
        dealToAndar = true;
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        _onDealComplete();
        return;
      }
    }
  }

  void _onDealComplete() {
    if (!mounted) return;
    setState(() {
      _phase             = _Phase.result;
      _activeDealingSide = '';
      _flyingCard        = null;
    });

    _resultCtrl.forward(from: 0);

    final game = _currentGame!;
    if (game.isWin) {
      final win = _lastWinAmount ?? 0;
      _counterAnim = IntTween(begin: 0, end: win)
          .animate(CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOut));
      _counterCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    if (_pendingReward != null && mounted) {
      final reward = _pendingReward!; _pendingReward = null;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) SmallRewardPopup.show(context, reward);
      });
    }
    if (_pendingRecovery != null && mounted) {
      final recovery = _pendingRecovery!; _pendingRecovery = null;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) LossRecoveryPopup.show(context, recovery);
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  RESET TO IDLE
  // ════════════════════════════════════════════════════════════════
  void _newGame() {
    _resultCtrl.reverse();
    _counterCtrl.reset();
    _pickCtrl.reset();
    setState(() {
      _phase             = _Phase.idle;
      _currentGame       = null;
      _playerChoice      = null;
      _revealedAndar     = 0;
      _revealedBahar     = 0;
      _activeDealingSide = '';
      _suspense          = false;
      _jokerRevealed     = false;
    });
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [_bgTableCenter, _bgTableEdge],
              radius: 1.2,
              center: Alignment.center,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _FeltTexturePainter())),

              SlideTransition(
                position: _pageSlide,
                child: FadeTransition(
                  opacity: _pageFade,
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        GameJackpotBanner(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                            child: Column(
                              children: [
                                // ── DEALER MAN always visible ──
                                _buildDealerSection(),

                                const SizedBox(height: 20),

                                // ── Joker label + card (visible after shuffle ends) ──
                                // During jokerShow: shows "?" box until dealer throws, then card face
                                // During pick/dealing/result: always shows the card
                                if (_phase != _Phase.idle &&
                                    _phase != _Phase.shuffling)
                                  _buildJokerDisplay(),

                                const SizedBox(height: 20),

                                // ── Andar / Bahar table (only while dealing or result) ──
                                if (_phase == _Phase.dealing ||
                                    _phase == _Phase.result)
                                  _buildPlayersAndTable(),

                                const SizedBox(height: 20),

                                // ── Bottom action area ──
                                _buildBottomAction(),

                                if (_suspense) _buildSuspenseIndicator(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Flying card
              if (_flyingCard != null)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutQuad,
                  alignment: _flyingCardAlign,
                  child: Transform.rotate(
                    angle: _activeDealingSide == 'ANDAR' ? -0.1 : 0.1,
                    child: _buildRealisticPlayingCard(_flyingCard!, size: 60),
                  ),
                ),

              // Live chat overlay
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuad,
                left: 12,
                right: 12,
                bottom: bottomInset > 0 ? bottomInset + 8 : 16,
                height: 220,
                child: const LiveChatOverlay(),
              ),

              // Result panel
              if (_phase == _Phase.result && _currentGame != null)
                _buildModernResultPanel(),

              const FloatingWinnerToast(),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DEALER SECTION  (always shown)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDealerSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_throwArmCtrl, _dealerBobCtrl, _shuffleArmCtrl]),
      builder: (context, child) {
        // During shuffle → use the rapid sweep angle; otherwise use the throw angle
        final armAngle = _phase == _Phase.shuffling
            ? _shuffleArmAngle.value
            : _throwArmAngle.value;

        return Center(
          child: Transform.translate(
            offset: Offset(0, _dealerBob.value),
            child: SizedBox(
              width: 150,
              height: 175,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CustomPaint(
                    size: const Size(150, 175),
                    painter: _DealerManPainter(
                      armAngle: armAngle,
                      // Right arm mirrors left during shuffle (opposite direction)
                      rightArmAngle: _phase == _Phase.shuffling
                          ? -_shuffleArmAngle.value
                          : 0.0,
                      isShuffling: _phase == _Phase.shuffling,
                      shuffleProgress: _shuffleArmCtrl.value,
                    ),
                  ),
                  if (_dealerCardVisible)
                    AnimatedOpacity(
                      opacity: _dealerCardOpacity,
                      duration: const Duration(milliseconds: 220),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(
                            30 + _dealerCardOffset.dx,
                            18 + _dealerCardOffset.dy, 0),
                        child: Transform.rotate(
                          angle: -0.35,
                          child: _buildMockPlayingCard(
                              _dealerCardValue, _dealerCardSuit, size: 40),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  JOKER DISPLAY (shown after shuffling ends)
  // ════════════════════════════════════════════════════════════════
  Widget _buildJokerDisplay() {
    final game = _currentGame;
    return Column(
      children: [
        const Text(
          'MAIN CARD',
          style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _jokerPulse,
          builder: (_, child) => Transform.scale(
            scale: (_jokerRevealed && _phase == _Phase.jokerShow)
                ? _jokerPulse.value
                : 1.0,
            child: child,
          ),
          child: _jokerRevealed && game != null
              // Card is revealed — show the actual card face
              ? _buildMockPlayingCard(
                  game.jokerCard.value, game.jokerCard.suit,
                  size: 100, isMatch: true)
              // Not yet revealed — show mystery placeholder so the box is ready
              : Container(
                  width: 72, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _gold.withOpacity(0.4), width: 2),
                  ),
                  child: const Center(
                    child: Text('?',
                        style: TextStyle(fontSize: 36, color: _gold)),
                  ),
                ),
        ),
        if (_jokerRevealed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _phase == _Phase.jokerShow
                  ? '✨  Joker revealed!'
                  : _phase == _Phase.pick
                      ? 'Now pick your side ↓'
                      : '',
              style: TextStyle(
                  color: _phase == _Phase.pick
                      ? _gold
                      : Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BOTTOM ACTION AREA  (changes per phase)
  // ════════════════════════════════════════════════════════════════
  Widget _buildBottomAction() {
    switch (_phase) {
      // ── IDLE: big START button ───────────────────────────────────
      case _Phase.idle:
        return _buildStartButton();

      // ── SHUFFLING: spinner + label ───────────────────────────────
      case _Phase.shuffling:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withOpacity(0.3)),
          ),
          child: const Column(
            children: [
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                    color: _gold, strokeWidth: 2.5),
              ),
              SizedBox(height: 12),
              Text('Shuffling the deck...',
                  style: TextStyle(
                      color: _gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
        );

      // ── JOKER SHOW: waiting (dealer is throwing) ─────────────────
      case _Phase.jokerShow:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withOpacity(0.2)),
          ),
          child: const Center(
            child: Text('👁  Revealing main card...',
                style: TextStyle(
                    color: _textMid,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        );

      // ── PICK: Andar / Bahar choice buttons ───────────────────────
      case _Phase.pick:
        return ScaleTransition(
          scale: _pickScale,
          child: Column(
            children: [
              const Text(
                'Choose Your Side',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'serif',
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: _buildPickButton(
                          'ANDAR', _andar, Icons.arrow_back_rounded)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildPickButton(
                          'BAHAR', _bahar, Icons.arrow_forward_rounded)),
                ],
              ),
            ],
          ),
        );

      // ── DEALING: show who they picked + live progress ────────────
      case _Phase.dealing:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: (_playerChoice == 'ANDAR' ? _andar : _bahar)
                    .withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: _gold, strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(
                'Dealing cards... You bet on $_playerChoice',
                style: TextStyle(
                    color: _playerChoice == 'ANDAR' ? _andar : _bahar,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

      // ── RESULT: nothing here – panel slides up from bottom ───────
      case _Phase.result:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStartButton() {
    final hasFree = UserSession.instance.freeSpins > 0;
    return GestureDetector(
      onTap: _startGame,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_gold, _goldDark]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: _gold.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🃏  START GAME',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2)),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasFree ? 'FREE' : '₹4',
                style: TextStyle(
                    color: hasFree
                        ? Colors.green.shade800
                        : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickButton(String side, Color color, IconData icon) {
    return GestureDetector(
      onTap: () => _selectAndDeal(side),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.25), color.withOpacity(0.12)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(side,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PLAYERS + TABLE
  // ════════════════════════════════════════════════════════════════
  Widget _buildPlayersAndTable() {
    final game = _currentGame;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(children: [
            _buildPlayerAvatar('ANDAR', _andar, _activeDealingSide == 'ANDAR'),
            const SizedBox(height: 16),
            _buildCardSpread(
                game?.andarCards ?? [], _revealedAndar,
                game?.winningSide == 'ANDAR'),
          ]),
        ),
        Container(
          width: 2, height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Colors.transparent, _gold.withOpacity(0.3), Colors.transparent
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(children: [
            _buildPlayerAvatar('BAHAR', _bahar, _activeDealingSide == 'BAHAR'),
            const SizedBox(height: 16),
            _buildCardSpread(
                game?.baharCards ?? [], _revealedBahar,
                game?.winningSide == 'BAHAR'),
          ]),
        ),
      ],
    );
  }

  Widget _buildPlayerAvatar(String name, Color color, bool isActive) {
    final lottieUrl = name == 'ANDAR'
        ? 'https://lottie.host/81a967f4-8a43-4e67-80be-7c87c062c9cc/mUf8Mmb31i.json'
        : 'https://lottie.host/cd12c1c6-3023-41bb-ad68-07bcad30c90c/L3Y8qV2D1e.json';

    // Highlight the user's chosen side
    final isChosen = _playerChoice == name;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      transform: Matrix4.translationValues(0, isActive ? -10 : 0, 0),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive
                ? color
                : isChosen
                    ? color.withOpacity(0.5)
                    : Colors.transparent,
            width: 2),
        boxShadow:
            isActive ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15)] : [],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _surface,
                  border: Border.all(color: color.withOpacity(0.6), width: 2),
                ),
                child: ClipOval(
                  child: Lottie.network(lottieUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.person, color: color, size: 36)),
                ),
              ),
              if (isChosen)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.star,
                      color: Colors.white, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              style: TextStyle(
                  color: isActive ? Colors.white : _textMid,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCardSpread(
      List<CardModel> cards, int revealed, bool isWinningSide) {
    if (cards.isEmpty) {
      return Container(
        height: 80, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const Text('Awaiting Cards',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
      );
    }
    return Wrap(
      spacing: -20.0, runSpacing: 8.0, alignment: WrapAlignment.center,
      children: List.generate(cards.length, (i) {
        if (i >= revealed) return SizedBox(width: 60 * 0.72, height: 60);
        final isMatchCard = i == cards.length - 1 && isWinningSide;
        return Transform.rotate(
          angle: isMatchCard ? 0.05 : 0.0,
          child: _buildRealisticPlayingCard(cards[i],
              size: 60, isMatch: isMatchCard),
        );
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  RESULT PANEL
  // ════════════════════════════════════════════════════════════════
  Widget _buildModernResultPanel() {
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isWin
                    ? [const Color(0xFF0A2A1A), const Color(0xFF051510)]
                    : [const Color(0xFF200A0A), const Color(0xFF100404)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isWin ? _gold.withOpacity(0.8) : _bahar.withOpacity(0.5),
                  width: 2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: isWin ? _gold.withOpacity(0.22) : _bahar.withOpacity(0.18),
                  blurRadius: 40, spreadRadius: 4, offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 62, height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                (isWin ? _gold : _bahar).withOpacity(0.28),
                                Colors.transparent,
                              ]),
                              border: Border.all(
                                  color: isWin ? _gold : _bahar, width: 2),
                            ),
                            child: Center(
                              child: Text(isWin ? '🏆' : '😔',
                                  style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isWin ? 'YOU WON!' : 'BETTER LUCK',
                                  style: TextStyle(
                                    color: isWin ? _gold : _bahar,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${game.winningSide} matched the Joker',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statChip('YOUR BET', game.playerChoice,
                                game.playerChoice == game.winningSide
                                    ? _gold
                                    : _textMid),
                            _statDivider(),
                            _statChip('RESULT', game.winningSide,
                                game.winningSide == 'ANDAR' ? _andar : _bahar),
                            _statDivider(),
                            if (isWin)
                              AnimatedBuilder(
                                animation: _counterAnim,
                                builder: (_, __) => _statChip(
                                    'WINNINGS',
                                    '₹${_counterAnim.value}',
                                    Colors.greenAccent),
                              )
                            else
                              _statChip('DEDUCTED', '-₹4', _bahar),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_statsTotalPlayers > 0) _buildPlayersBar(),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _newGame,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isWin
                                  ? [_gold, _goldDark]
                                  : [_andar, const Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (isWin ? _gold : _andar).withOpacity(0.38),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isWin ? '🎰  Play Again' : '🃏  Try Again',
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

  // ════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: _textLight, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Andar Bahar',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _textLight,
                    fontSize: 20,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '₹${UserSession.instance.balance}',
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════
  Widget _statChip(String label, String value, Color valueColor) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 9,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      );

  Widget _statDivider() => Container(
      width: 1, height: 28, color: Colors.white.withOpacity(0.1));

  Widget _buildPlayersBar() {
    final winPct = _statsTotalPlayers > 0
        ? _statsTotalWinners / _statsTotalPlayers
        : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$_statsTotalWinners won',
                style: TextStyle(
                    color: Colors.greenAccent.withOpacity(0.8),
                    fontSize: 11)),
            Text('$_statsTotalPlayers players',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 11)),
            Text('$_statsTotalLosers lost',
                style: TextStyle(
                    color: _bahar.withOpacity(0.8), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(
                flex: (winPct * 100).round().clamp(1, 99),
                child: Container(
                    height: 6, color: Colors.greenAccent.withOpacity(0.65)),
              ),
              Expanded(
                flex: (100 - (winPct * 100).round()).clamp(1, 99),
                child:
                    Container(height: 6, color: _bahar.withOpacity(0.55)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuspenseIndicator() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.6)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _gold)),
          SizedBox(width: 12),
          Text('Revealing Match...',
              style: TextStyle(
                  color: _gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildRealisticPlayingCard(CardModel card,
          {double size = 50, bool isMatch = false}) =>
      _buildMockPlayingCard(card.value, card.suit,
          size: size, isMatch: isMatch);

  Widget _buildMockPlayingCard(String value, String suit,
      {double size = 50, bool isMatch = false}) {
    final isRed = suit == '♥' ||
        suit == '♦' ||
        suit.toLowerCase().contains('heart') ||
        suit.toLowerCase().contains('diamond');
    final color =
        isRed ? const Color(0xFFD32F2F) : const Color(0xFF1E1E1E);
    String s = suit;
    if (s.toLowerCase().contains('heart'))   s = '♥';
    if (s.toLowerCase().contains('diamond')) s = '♦';
    if (s.toLowerCase().contains('spade'))   s = '♠';
    if (s.toLowerCase().contains('club'))    s = '♣';
    return Container(
      width: size * 0.72, height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isMatch ? _gold : Colors.grey.shade400,
            width: isMatch ? 3 : 1),
        boxShadow: [
          if (isMatch)
            BoxShadow(
                color: _gold.withOpacity(0.8),
                blurRadius: 15,
                spreadRadius: 2),
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(2, 2)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          top: 2, left: 4,
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.bold,
                    height: 1)),
            Text(s,
                style: TextStyle(
                    color: color, fontSize: size * 0.18, height: 1)),
          ])),
        Center(
            child: Text(s,
                style: TextStyle(
                    color: color.withOpacity(0.15),
                    fontSize: size * 0.5))),
        Positioned(
          bottom: 2, right: 4,
          child: RotatedBox(
            quarterTurns: 2,
            child: Column(children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.bold,
                      height: 1)),
              Text(s,
                  style: TextStyle(
                      color: color,
                      fontSize: size * 0.18,
                      height: 1)),
            ]),
          )),
      ]),
    );
  }

  Widget _buildCardBack({double size = 50}) {
    return Container(
      width: size * 0.72, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(1, 1))
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(
              color: Colors.white.withOpacity(0.5), width: 1),
          image: const DecorationImage(
            image: NetworkImage(
                'https://www.transparenttextures.com/patterns/argyle.png'),
            repeat: ImageRepeat.repeat,
            opacity: 0.3,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FELT TEXTURE PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _FeltTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.014)
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 14) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_FeltTexturePainter o) => false;
}

// ════════════════════════════════════════════════════════════════════════════
//  DEALER MAN PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _DealerManPainter extends CustomPainter {
  final double armAngle;
  final double rightArmAngle;   // mirrored during shuffle
  final bool   isShuffling;
  final double shuffleProgress; // 0..1, drives card fan/riffle
  const _DealerManPainter({
    required this.armAngle,
    this.rightArmAngle = 0.0,
    this.isShuffling = false,
    this.shuffleProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final cx = w * 0.50;

    final skin    = Paint()..color = const Color(0xFFF1C27D);
    final skinDk  = Paint()..color = const Color(0xFFD4956A);
    final suit_   = Paint()..color = const Color(0xFF1B2A44);
    final suitDk  = Paint()..color = const Color(0xFF0F1E32);
    final shirt   = Paint()..color = const Color(0xFFF8F8F8);
    final tie     = Paint()..color = const Color(0xFFB71C1C);
    final trouser = Paint()..color = const Color(0xFF0D1929);
    final shoe_   = Paint()..color = const Color(0xFF120C04);
    final hair    = Paint()..color = const Color(0xFF1A0E05);
    final white_  = Paint()..color = Colors.white;
    final gold_   = Paint()..color = const Color(0xFFB8860B);

    final headR  = w * 0.125;
    final headCy = h * 0.115;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.988), width: w * 0.52, height: h * 0.025),
      Paint()
        ..color = Colors.black.withOpacity(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawCircle(Offset(cx, headCy - headR * 0.06), headR * 1.10, hair);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - headR * 1.03, headCy + headR * 0.18),
            width: headR * 0.34, height: headR * 0.55), skinDk);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + headR * 1.03, headCy + headR * 0.18),
            width: headR * 0.34, height: headR * 0.55), skinDk);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - headR * 1.01, headCy + headR * 0.18),
            width: headR * 0.28, height: headR * 0.48), skin);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + headR * 1.01, headCy + headR * 0.18),
            width: headR * 0.28, height: headR * 0.48), skin);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, headCy), width: headR * 2.02, height: headR * 2.18),
      skin,
    );

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, headCy + headR * 0.95),
          width: headR * 1.75, height: headR * 0.58),
      Paint()
        ..shader = RadialGradient(
                colors: [skinDk.color.withOpacity(0.45), Colors.transparent])
            .createShader(Rect.fromCenter(
                center: Offset(cx, headCy + headR * 0.95),
                width: headR * 1.75, height: headR * 0.58)),
    );

    final hairPath = Path()
      ..moveTo(cx - headR * 0.98, headCy - headR * 0.52)
      ..quadraticBezierTo(cx - headR * 0.38, headCy - headR * 1.28,
          cx, headCy - headR * 1.14)
      ..quadraticBezierTo(cx + headR * 0.38, headCy - headR * 1.28,
          cx + headR * 0.98, headCy - headR * 0.52)
      ..close();
    canvas.drawPath(hairPath, hair);

    canvas.drawLine(
      Offset(cx - headR * 0.16, headCy - headR * 0.92),
      Offset(cx - headR * 0.10, headCy - headR * 0.30),
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke,
    );

    final browPaint = Paint()
      ..color = const Color(0xFF3B1F0A)
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(cx - headR * 0.64, headCy - headR * 0.36),
        Offset(cx - headR * 0.14, headCy - headR * 0.44), browPaint);
    canvas.drawLine(
        Offset(cx + headR * 0.14, headCy - headR * 0.44),
        Offset(cx + headR * 0.64, headCy - headR * 0.36), browPaint);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - headR * 0.38, headCy - headR * 0.11),
            width: headR * 0.44, height: headR * 0.33), white_);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + headR * 0.38, headCy - headR * 0.11),
            width: headR * 0.44, height: headR * 0.33), white_);

    canvas.drawCircle(Offset(cx - headR * 0.38, headCy - headR * 0.11),
        headR * 0.135, Paint()..color = const Color(0xFF3D2410));
    canvas.drawCircle(Offset(cx + headR * 0.38, headCy - headR * 0.11),
        headR * 0.135, Paint()..color = const Color(0xFF3D2410));
    canvas.drawCircle(Offset(cx - headR * 0.38, headCy - headR * 0.11),
        headR * 0.075, Paint()..color = const Color(0xFF0A0A0A));
    canvas.drawCircle(Offset(cx + headR * 0.38, headCy - headR * 0.11),
        headR * 0.075, Paint()..color = const Color(0xFF0A0A0A));
    canvas.drawCircle(
        Offset(cx - headR * 0.33, headCy - headR * 0.17), headR * 0.042, white_);
    canvas.drawCircle(
        Offset(cx + headR * 0.43, headCy - headR * 0.17), headR * 0.042, white_);

    final nosePaint = Paint()
      ..color = skinDk.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx - headR * 0.14, headCy + headR * 0.34),
          width: headR * 0.28, height: headR * 0.22),
      math.pi, math.pi * 0.7, false, nosePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx + headR * 0.14, headCy + headR * 0.34),
          width: headR * 0.28, height: headR * 0.22),
      math.pi * 1.3, math.pi * 0.7, false, nosePaint,
    );

    final mouthPath = Path()
      ..moveTo(cx - headR * 0.27, headCy + headR * 0.62)
      ..quadraticBezierTo(
          cx, headCy + headR * 0.76, cx + headR * 0.27, headCy + headR * 0.62);
    canvas.drawPath(mouthPath,
        Paint()
          ..color = const Color(0xFF8B3A1A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);

    canvas.drawLine(
      Offset(cx - headR * 0.16, headCy + headR * 0.62),
      Offset(cx + headR * 0.16, headCy + headR * 0.62),
      Paint()
        ..color = const Color(0xFF7A2A10).withOpacity(0.5)
        ..strokeWidth = 1.0,
    );

    final neckTop = headCy + headR * 0.92;
    final neckBot = headCy + headR * 1.50;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, (neckTop + neckBot) / 2),
            width: headR * 0.70, height: neckBot - neckTop),
        const Radius.circular(5),
      ),
      skin,
    );

    final torsoTop = neckBot;
    final torsoBot = h * 0.61;
    final torsoW   = w * 0.42;

    final jacketPath = Path()
      ..moveTo(cx - torsoW * 0.48, torsoTop)
      ..lineTo(cx - torsoW * 0.60, torsoBot)
      ..lineTo(cx + torsoW * 0.60, torsoBot)
      ..lineTo(cx + torsoW * 0.48, torsoTop)
      ..close();
    canvas.drawPath(jacketPath, suit_);

    canvas.drawPath(jacketPath,
        Paint()
          ..shader = LinearGradient(
                  colors: [suitDk.color.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.centerLeft, end: Alignment.center)
              .createShader(Rect.fromLTWH(
                  cx - torsoW * 0.6, torsoTop, torsoW * 0.5, torsoBot - torsoTop)));

    canvas.drawPath(
        Path()
          ..moveTo(cx - headR * 0.25, torsoTop)
          ..lineTo(cx - headR * 0.13, torsoTop + headR * 1.28)
          ..lineTo(cx + headR * 0.13, torsoTop + headR * 1.28)
          ..lineTo(cx + headR * 0.25, torsoTop)
          ..close(), shirt);

    canvas.drawPath(
        Path()
          ..moveTo(cx - headR * 0.07, torsoTop + headR * 0.08)
          ..lineTo(cx + headR * 0.07, torsoTop + headR * 0.08)
          ..lineTo(cx + headR * 0.14, torsoTop + headR * 0.98)
          ..lineTo(cx,                torsoTop + headR * 1.24)
          ..lineTo(cx - headR * 0.14, torsoTop + headR * 0.98)
          ..close(), tie);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, torsoTop + headR * 0.12),
          width: headR * 0.22, height: headR * 0.15),
      Paint()..color = const Color(0xFF8B0000),
    );
    canvas.drawLine(
      Offset(cx, torsoTop + headR * 0.18),
      Offset(cx - headR * 0.04, torsoTop + headR * 0.82),
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 1.2,
    );

    final lapelPaint = Paint()..color = suitDk.color;
    canvas.drawPath(
        Path()
          ..moveTo(cx - headR * 0.25, torsoTop)
          ..lineTo(cx - torsoW * 0.48, torsoTop + headR * 0.98)
          ..lineTo(cx - headR * 0.06, torsoTop + headR * 1.28)
          ..close(), lapelPaint);
    canvas.drawPath(
        Path()
          ..moveTo(cx + headR * 0.25, torsoTop)
          ..lineTo(cx + torsoW * 0.48, torsoTop + headR * 0.98)
          ..lineTo(cx + headR * 0.06, torsoTop + headR * 1.28)
          ..close(), lapelPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - torsoW * 0.40, torsoTop + headR * 0.62,
            headR * 0.56, headR * 0.44),
        const Radius.circular(2),
      ), shirt,
    );

    for (int i = 0; i < 3; i++) {
      final by = torsoTop + headR * 1.48 + i * headR * 0.44;
      canvas.drawCircle(Offset(cx, by), headR * 0.068, gold_);
      canvas.drawCircle(Offset(cx, by), headR * 0.038,
          Paint()..color = const Color(0xFF6B4A00));
    }

    // Throwing arm (left)
    final shoulderL = Offset(cx - torsoW * 0.54, torsoTop + headR * 0.26);
    canvas.save();
    canvas.translate(shoulderL.dx, shoulderL.dy);
    canvas.rotate(armAngle);

    canvas.drawPath(
        Path()
          ..moveTo(-headR * 0.25, 0)
          ..quadraticBezierTo(-headR * 0.50, headR * 0.68, -headR * 0.23, headR * 1.30)
          ..lineTo(headR * 0.23, headR * 1.30)
          ..quadraticBezierTo(headR * 0.12, headR * 0.60, headR * 0.25, 0)
          ..close(), suit_);

    canvas.drawLine(Offset(0, 0), Offset(-headR * 0.04, headR * 1.32),
        Paint()
          ..color = suitDk.color
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke);

    canvas.drawPath(
        Path()
          ..moveTo(-headR * 0.20, headR * 1.24)
          ..quadraticBezierTo(-headR * 0.32, headR * 1.98, -headR * 0.04, headR * 2.42)
          ..lineTo(headR * 0.25, headR * 2.26)
          ..quadraticBezierTo(headR * 0.16, headR * 1.82, headR * 0.20, headR * 1.24)
          ..close(), skin);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, headR * 1.32),
            width: headR * 0.54, height: headR * 0.24),
        const Radius.circular(3),
      ), shirt,
    );
    canvas.drawCircle(Offset(headR * 0.14, headR * 1.32), headR * 0.04, gold_);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, headR * 2.48),
            width: headR * 0.60, height: headR * 0.48), skin);

    for (int f = 0; f < 4; f++) {
      final fx = -headR * 0.23 + f * headR * 0.155;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(fx, headR * 2.60),
              width: headR * 0.13, height: headR * 0.30),
          const Radius.circular(5),
        ), skin,
      );
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(-headR * 0.33, headR * 2.38),
            width: headR * 0.24, height: headR * 0.34), skin);

    final kn = Paint()
      ..color = skinDk.color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int f = 0; f < 3; f++) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(-headR * 0.15 + f * headR * 0.155, headR * 2.46),
            width: headR * 0.14, height: headR * 0.10),
        0, math.pi, false, kn,
      );
    }

    // ── LEFT HAND: fan of cards ────────────────────────────────────
    if (isShuffling) {
      final cardW  = headR * 0.48;
      final cardH  = headR * 0.68;
      final cardPt = Paint()..color = const Color(0xFFB71C1C);
      final cardBd = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final cardBg = Paint()..color = Colors.white;

      const fanCards = 5;
      for (int i = 0; i < fanCards; i++) {
        final t     = i / (fanCards - 1);
        final angle = -0.30 + t * 0.60;
        final cx2   = -headR * 0.04 + t * headR * 0.08;
        final cy2   = headR * 2.28;
        canvas.save();
        canvas.translate(cx2, cy2);
        canvas.rotate(angle);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
          const Radius.circular(3)), cardBg);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cardW * 0.75, height: cardH * 0.75),
          const Radius.circular(2)), cardPt);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
          const Radius.circular(3)), cardBd);
        canvas.restore();
      }
    }
    // ── END LEFT HAND CARDS ───────────────────────────────────────

    canvas.restore(); // end left arm transform

    // Resting / shuffling arm (right) — now animated during shuffle
    final shoulderR = Offset(cx + torsoW * 0.54, torsoTop + headR * 0.26);

    canvas.save();
    canvas.translate(shoulderR.dx, shoulderR.dy);
    canvas.rotate(rightArmAngle); // mirrors left arm during shuffle

    // Upper arm sleeve
    canvas.drawPath(
        Path()
          ..moveTo(-headR * 0.25, 0)
          ..quadraticBezierTo(headR * 0.40, headR * 0.70, headR * 0.20, headR * 1.30)
          ..lineTo(headR * 0.54, headR * 1.30)
          ..quadraticBezierTo(headR * 0.64, headR * 0.60, headR * 0.25, 0)
          ..close(), suit_);

    // Forearm skin
    canvas.drawPath(
        Path()
          ..moveTo(headR * 0.20, headR * 1.24)
          ..quadraticBezierTo(headR * 0.24, headR * 2.02, headR * 0.06, headR * 2.44)
          ..lineTo(headR * 0.40, headR * 2.30)
          ..quadraticBezierTo(headR * 0.50, headR * 1.90, headR * 0.54, headR * 1.24)
          ..close(), skin);

    // Cuff
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(headR * 0.37, headR * 1.34),
            width: headR * 0.52, height: headR * 0.24),
        const Radius.circular(3)), shirt);

    // Hand
    canvas.drawOval(
        Rect.fromCenter(center: Offset(headR * 0.22, headR * 2.50),
            width: headR * 0.56, height: headR * 0.46), skin);

    // ── RIGHT HAND: fan of cards (mirror of left) ─────────────────
    if (isShuffling) {
      final cardW  = headR * 0.48;
      final cardH  = headR * 0.68;
      final cardPt = Paint()..color = const Color(0xFFB71C1C);
      final cardBd = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final cardBg = Paint()..color = Colors.white;

      const fanCards = 5;
      for (int i = 0; i < fanCards; i++) {
        final t     = i / (fanCards - 1);
        // Mirror fan: right hand fans opposite direction
        final angle = 0.30 - t * 0.60;
        final cx2   = headR * 0.18 + t * headR * 0.08;
        final cy2   = headR * 2.28;
        canvas.save();
        canvas.translate(cx2, cy2);
        canvas.rotate(angle);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
          const Radius.circular(3)), cardBg);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cardW * 0.75, height: cardH * 0.75),
          const Radius.circular(2)), cardPt);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
          const Radius.circular(3)), cardBd);
        canvas.restore();
      }
    }
    // ── END RIGHT HAND CARDS ──────────────────────────────────────

    canvas.restore(); // end right arm transform

    // ── RIFFLE CARD IN WORLD SPACE ────────────────────────────────
    // Travels between both hands. Left hand is at roughly (cx - torsoW*0.54, torsoBot - headR*0.5)
    // Right hand is at roughly (cx + torsoW*0.54, torsoBot - headR*0.5)
    // shuffleProgress oscillates 0→1→0 — card goes left→right→left
    if (isShuffling) {
      final cardW   = headR * 0.46;
      final cardH   = headR * 0.64;
      final cardPt  = Paint()..color = const Color(0xFFB71C1C);
      final cardBd  = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final cardBg  = Paint()..color = Colors.white;

      // Anchor points for both hands in world space
      final leftHandX  = cx - torsoW * 0.46;
      final rightHandX = cx + torsoW * 0.46 + headR * 0.22;
      final handY      = torsoBot - headR * 0.40;

      final t          = shuffleProgress;           // 0..1
      final riffleX    = leftHandX + t * (rightHandX - leftHandX);
      // arc: peaks upward in the middle
      final riffleY    = handY - math.sin(t * math.pi) * headR * 1.1;
      final riffleRot  = -0.5 + t * 1.0;           // tilts as it travels

      canvas.save();
      canvas.translate(riffleX, riffleY);
      canvas.rotate(riffleRot);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
        const Radius.circular(3)), cardBg);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: cardW * 0.72, height: cardH * 0.72),
        const Radius.circular(2)), cardPt);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
        const Radius.circular(3)), cardBd);
      canvas.restore();
    }
    // ── END RIFFLE CARD ───────────────────────────────────────────

    // Belt
    canvas.drawRect(
      Rect.fromLTWH(cx - torsoW * 0.60, torsoBot - headR * 0.19,
          torsoW * 1.20, headR * 0.26),
      Paint()..color = const Color(0xFF080808),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, torsoBot - headR * 0.06),
            width: headR * 0.56, height: headR * 0.22),
        const Radius.circular(2),
      ), gold_,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, torsoBot - headR * 0.06),
            width: headR * 0.30, height: headR * 0.11),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFF5A3A00),
    );

    // Trousers
    canvas.drawPath(
        Path()
          ..moveTo(cx - torsoW * 0.60, torsoBot)
          ..lineTo(cx - torsoW * 0.40, h * 0.928)
          ..lineTo(cx - torsoW * 0.04, h * 0.928)
          ..lineTo(cx - torsoW * 0.04, torsoBot)
          ..close(), trouser);
    canvas.drawPath(
        Path()
          ..moveTo(cx + torsoW * 0.60, torsoBot)
          ..lineTo(cx + torsoW * 0.40, h * 0.928)
          ..lineTo(cx + torsoW * 0.04, h * 0.928)
          ..lineTo(cx + torsoW * 0.04, torsoBot)
          ..close(), trouser);

    final crease = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - torsoW * 0.32, torsoBot + 4),
        Offset(cx - torsoW * 0.22, h * 0.924), crease);
    canvas.drawLine(Offset(cx + torsoW * 0.32, torsoBot + 4),
        Offset(cx + torsoW * 0.22, h * 0.924), crease);

    // Shoes
    canvas.drawPath(
        Path()
          ..moveTo(cx - torsoW * 0.42, h * 0.928)
          ..lineTo(cx - torsoW * 0.54, h * 0.962)
          ..quadraticBezierTo(cx - torsoW * 0.57, h * 0.980,
              cx - torsoW * 0.46, h * 0.982)
          ..lineTo(cx - torsoW * 0.02, h * 0.982)
          ..lineTo(cx - torsoW * 0.02, h * 0.928)
          ..close(), shoe_);
    canvas.drawPath(
        Path()
          ..moveTo(cx + torsoW * 0.42, h * 0.928)
          ..lineTo(cx + torsoW * 0.54, h * 0.962)
          ..quadraticBezierTo(cx + torsoW * 0.57, h * 0.980,
              cx + torsoW * 0.46, h * 0.982)
          ..lineTo(cx + torsoW * 0.02, h * 0.982)
          ..lineTo(cx + torsoW * 0.02, h * 0.928)
          ..close(), shoe_);

    final shine = Paint()
      ..color = Colors.white.withOpacity(0.11)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - torsoW * 0.52, h * 0.966),
        Offset(cx - torsoW * 0.10, h * 0.966), shine);
    canvas.drawLine(Offset(cx + torsoW * 0.52, h * 0.966),
        Offset(cx + torsoW * 0.10, h * 0.966), shine);
  }

  @override
  bool shouldRepaint(_DealerManPainter old) =>
      old.armAngle != armAngle ||
      old.rightArmAngle != rightArmAngle ||
      old.isShuffling != isShuffling ||
      old.shuffleProgress != shuffleProgress;
}