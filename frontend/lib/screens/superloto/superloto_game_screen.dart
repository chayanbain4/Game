// lib/screens/superloto/superloto_game_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/user_session.dart';
import '../../services/superloto_service.dart';
import '../../models/superloto/superloto_draw_model.dart';
import '../../models/superloto/superloto_ticket_model.dart';
import '../../widgets/engagement/floating_winner_toast.dart';
import '../../widgets/engagement/small_reward_popup.dart';
import '../../widgets/engagement/loss_recovery_popup.dart';
import '../../widgets/engagement/game_jackpot_banner.dart';
import '../../widgets/engagement/live_chat_overlay.dart';

class SuperLotoGameScreen extends StatefulWidget {
  const SuperLotoGameScreen({super.key});

  @override
  State<SuperLotoGameScreen> createState() => _SuperLotoGameScreenState();
}

class _SuperLotoGameScreenState extends State<SuperLotoGameScreen>
    with TickerProviderStateMixin {

  // ── Casino design tokens ──────────────────────────────────────
  static const Color _bgCenter  = Color(0xFF0B3D2E);
  static const Color _bgEdge    = Color(0xFF051C14);
  static const Color _surface   = Color(0xFF0F2D20);
  static const Color _card      = Color(0xFF0A2118);
  static const Color _gold      = Color(0xFFFFD700);
  static const Color _goldDark  = Color(0xFFB8860B);
  static const Color _green     = Color(0xFF2DFF8F);
  static const Color _red       = Color(0xFFEF4444);
  static const Color _textLight = Color(0xFFF0F4FF);
  static const Color _textMid   = Color(0xFF7FA8A4);

  static const int _totalNumbers     = 49;
  static const int _pickCount        = 6;
  static const int _closingThreshold = 20;
  static const int _baseTicketFee    = 12;
  static const List<int> _multipliers = [1, 2, 5, 10];

  final _service = SuperLotoService();
  final _random  = Random();

  // ── Audio ─────────────────────────────────────────────────────
  late AudioPlayer _audioPlayer;

  // ── Fake activity ─────────────────────────────────────────────
  final _fakeNames = [
    'Rahul', 'Priya', 'Amit', 'Neha', 'Vikas', 'Karan',
    'Sneha', 'Ravi', 'Pooja', 'Sunil', 'Anita', 'Deepak',
    'Roshni', 'Sanjay', 'Kavita', 'Arjun', 'Meera', 'Rohan',
  ];
  int    _liveCount    = 0;
  String _activityMsg  = '';
  bool   _showActivity = false;
  bool   _showWinnersBar = false;
  List<Map<String, dynamic>> _recentWinners = [];

  // ── Draw state ────────────────────────────────────────────────
  static SuperLotoDrawModel? _currentDraw;
  static List<SuperLotoTicketModel> _myTickets           = [];
  static List<SuperLotoTicketModel> _previousDrawTickets = [];
  static final Set<int> _selectedNumbers                 = {};
  static int _previousDrawNumber                         = 0;
  int _selectedMultiplier = 1;

  bool _isIdle          = true;
  bool _loading         = true;
  bool _buying          = false;
  bool _ticketBought    = false;
  // Only show result/shuffle if user bought a ticket in THIS session
  bool _playedThisSession = false;

  static SuperLotoTicketModel? _resultTicket;
  static SuperLotoTicketModel? _winTicket;
  static int _lastCheckedDraw = 0;

  static int _revealedBallCount = 6;
  Timer? _ballRevealTimer;
  static int _lastRevealedDraw = 0;

  Timer? _countdownTimer;
  Timer? _syncTimer;
  Timer? _activityTimer;
  static int _secondsLeft = 0;

  // ── Shuffle animation state ───────────────────────────────────
  bool _isShuffling       = false;
  List<int> _shuffleNumbers = [7, 14, 21, 28, 35, 42];
  Timer? _shuffleTimer;
  // pending ticket waiting for shuffle to finish
  SuperLotoTicketModel? _pendingResultTicket;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  late AnimationController _resultCtrl;
  late Animation<Offset>   _resultSlide;
  late Animation<double>   _resultFade;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  late AnimationController _shimmerCtrl;

  // ── Shuffle ball bounce animation ─────────────────────────────
  late AnimationController _shuffleBounceCtrl;
  late Animation<double>   _shuffleBounce;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Audio player init ────────────────────────────────────────
    _audioPlayer = AudioPlayer();

    _pageCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pageFade  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _resultSlide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    // ── Shuffle bounce animation (loop) ──────────────────────────
    _shuffleBounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..repeat(reverse: true);
    _shuffleBounce = Tween<double>(begin: 0.88, end: 1.12)
        .animate(CurvedAnimation(parent: _shuffleBounceCtrl, curve: Curves.easeInOut));

    _liveCount = 180 + _random.nextInt(320);
    _pageCtrl.forward();
    _startActivityTicker();
    _loadData();
    _startCountdown();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => _syncState());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _resultCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _shuffleBounceCtrl.dispose();
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
    _activityTimer?.cancel();
    _ballRevealTimer?.cancel();
    _shuffleTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  int get _currentFee => _baseTicketFee * _selectedMultiplier;
  int get _previewWin => 24 * _selectedMultiplier;
  bool get _hasResult => _resultTicket != null;

  // ── Audio helpers ─────────────────────────────────────────────
  Future<void> _playAudio(String fileName) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('[SuperLoto] audio error: $e');
    }
  }

  // ── Fake activity ticker ──────────────────────────────────────
  void _startActivityTicker() {
    _activityTimer = Timer.periodic(Duration(seconds: 8 + _random.nextInt(7)), (_) {
      if (!mounted) return;
      final name    = _fakeNames[_random.nextInt(_fakeNames.length)];
      final amounts = [24, 48, 120, 240];
      final amount  = amounts[_random.nextInt(amounts.length)];
      final delta   = _random.nextBool() ? 1 : -1;
      setState(() {
        _liveCount    = (_liveCount + delta * (_random.nextInt(5) + 1)).clamp(150, 600);
        _activityMsg  = '$name just won ₹$amount 🎉';
        _showActivity = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showActivity = false);
      });
    });
  }

  // ── Ball reveal (after shuffle completes) ─────────────────────
  void _triggerBallReveal(int drawNumber) {
    if (_lastRevealedDraw == drawNumber) return;
    _lastRevealedDraw  = drawNumber;
    _revealedBallCount = 0;
    _ballRevealTimer?.cancel();
    _ballRevealTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _revealedBallCount++);
      HapticFeedback.selectionClick();
      if (_revealedBallCount >= 6) t.cancel();
    });
  }

  // ── Shuffle animation (5.5 sec) then reveal result ────────────
  void _startShuffleAnimation({required VoidCallback onComplete}) {
    if (_isShuffling) return;

    setState(() {
      _isShuffling    = true;
      _shuffleNumbers = List.generate(6, (_) => _random.nextInt(49) + 1);
    });

    // Play scratch once at start for atmosphere
    _playAudio('scratch.mp3');

    _shuffleTimer?.cancel();

    // 350ms per tick — slow enough to hear pop.wav on each number change
    // 5500ms total ÷ 350ms = ~15 ticks
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 350), (t) {
      if (!mounted) { t.cancel(); return; }

      setState(() {
        _shuffleNumbers = List.generate(6, (_) => _random.nextInt(49) + 1);
      });

      // Play pop sound on each number change
      _audioPlayer.stop().then((_) {
        _audioPlayer.play(AssetSource('audio/pop.wav'));
      });

      HapticFeedback.selectionClick();
    });

    // After 5.5 seconds — stop shuffle and show result
    Timer(const Duration(milliseconds: 5500), () {
      _shuffleTimer?.cancel();
      if (!mounted) return;
      setState(() => _isShuffling = false);
      HapticFeedback.heavyImpact();
      onComplete();
    });
  }

  String _formatTime(int s) {
    final m = s ~/ 60, sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ── Countdown ─────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isIdle) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _syncState();
        // Only poll for result if the user actually bought a ticket THIS session
        if (_playedThisSession) _checkForResult();
      }
    });
  }

  // ── Sync ──────────────────────────────────────────────────────
  Future<void> _syncState() async {
    final userId = UserSession.instance.email ?? '';
    final status = await _service.getStatus();
    if (!mounted) return;

    if (status == null || !(status['isDrawActive'] as bool? ?? false)) {
      if (!_isIdle && _previousDrawNumber > 0 && _myTickets.isNotEmpty) {
        final updated = await _service.getUserTickets(userId, _previousDrawNumber);
        if (mounted && updated.isNotEmpty) {
          setState(() { _previousDrawTickets = updated; _myTickets = []; });
        }
      }
      if (mounted) {
        setState(() { _isIdle = true; _currentDraw = null; _secondsLeft = 0; });
      }
      // Only check for result if user played this session
      if (_playedThisSession) _checkForResult();
      return;
    }

    final draw = await _service.getCurrentDraw();
    if (!mounted || draw == null) return;

    if (_previousDrawNumber > 0 && draw.drawNumber != _previousDrawNumber) {
      final oldTickets = await _service.getUserTickets(userId, _previousDrawNumber);
      if (mounted && oldTickets.isNotEmpty) setState(() => _previousDrawTickets = oldTickets);
      _previousDrawNumber = draw.drawNumber;
    } else if (_previousDrawNumber == 0) {
      _previousDrawNumber = draw.drawNumber;
    }

    final tickets = await _service.getUserTickets(userId, draw.drawNumber);
    if (mounted) {
      setState(() {
        _isIdle       = false;
        _currentDraw  = draw;
        _myTickets    = tickets;
        _secondsLeft  = draw.remainingTime ?? 0;
        if (tickets.isNotEmpty) _ticketBought = true;
      });
    }
  }

  Future<void> _loadData() async {
    final userId = UserSession.instance.email ?? '';

    // ── Silently mark last known draw so old results never auto-appear ──
    await _silentlyInitLastCheckedDraw(userId);

    final status = await _service.getStatus();
    if (!mounted) return;

    if (status == null || !(status['isDrawActive'] as bool? ?? false)) {
      setState(() { _isIdle = true; _loading = false; });
      // Do NOT call _checkForResult here — user hasn't played yet
      return;
    }

    final draw = await _service.getCurrentDraw();
    if (!mounted) return;

    if (draw != null) {
      final tickets = await _service.getUserTickets(userId, draw.drawNumber);
      if (!mounted) return;
      _previousDrawNumber = draw.drawNumber;
      setState(() {
        _isIdle       = false;
        _currentDraw  = draw;
        _myTickets    = tickets;
        _loading      = false;
        _secondsLeft  = draw.remainingTime ?? 120;
        _ticketBought = tickets.isNotEmpty;
      });
    } else {
      setState(() { _isIdle = true; _loading = false; });
    }
    // Do NOT call _checkForResult here on first load
  }

  // ── Silently record the latest draw number on first open ─────
  // This prevents results from PREVIOUS sessions showing on load.
  Future<void> _silentlyInitLastCheckedDraw(String userId) async {
    if (_lastCheckedDraw > 0) return; // already initialised this session
    if (userId.isEmpty) return;
    try {
      final history = await _service.getUserHistory(userId, limit: 5);
      if (history.isNotEmpty) {
        final maxDraw = history.map((t) => t.drawNumber).reduce((a, b) => a > b ? a : b);
        _lastCheckedDraw = maxDraw; // mark as seen — won't re-show
      }
    } catch (_) {}
  }

  // ── Check for draw result — triggers shuffle first ────────────
  Future<void> _checkForResult() async {
    final userId = UserSession.instance.email ?? '';
    if (userId.isEmpty) return;

    final history = await _service.getUserHistory(userId, limit: 10);
    if (!mounted) return;

    for (final ticket in history) {
      if (ticket.drawNumber > _lastCheckedDraw) {
        _lastCheckedDraw = ticket.drawNumber;
        _buildResultWinnersBar(ticket);

        // ── Start shuffle first, THEN show result panel ───────────
        _startShuffleAnimation(onComplete: () {
          if (!mounted) return;
          setState(() {
            _resultTicket = ticket;
            _ticketBought = false;
          });
          _resultCtrl.forward(from: 0);

          if (ticket.isWin) {
            setState(() => _winTicket = ticket);
            // Add prize to current balance locally — same pattern as lottery
            // newBalance was already set after ticket purchase (fee deducted)
            // so: current balance + winAmount = correct final balance
            if (ticket.winAmount > 0) {
              UserSession.instance.setBalance(
                  UserSession.instance.balance + ticket.winAmount);
            }
            UserSession.instance.setWins(UserSession.instance.wins + 1);
          }
        });
        break;
      }
    }

    if (history.isNotEmpty) {
      final maxDraw = history.map((t) => t.drawNumber).reduce((a, b) => a > b ? a : b);
      if (maxDraw > _lastCheckedDraw) _lastCheckedDraw = maxDraw;
    }
  }

  void _buildResultWinnersBar(SuperLotoTicketModel myTicket) {
    final winners   = <Map<String, dynamic>>[];
    final fakeCount = 4 + _random.nextInt(6);
    final amounts   = [24, 48, 120, 240];
    for (int i = 0; i < fakeCount; i++) {
      winners.add({
        'name':   '${_fakeNames[_random.nextInt(_fakeNames.length)]}${_random.nextInt(99)}',
        'amount': amounts[_random.nextInt(amounts.length)],
        'isMe':   false,
      });
    }
    if (myTicket.isWin) {
      winners.insert(0, {
        'name':   UserSession.instance.name ?? 'You',
        'amount': myTicket.winAmount,
        'isMe':   true,
      });
    }
    setState(() { _recentWinners = winners; _showWinnersBar = true; });
  }

  // ── Number picker ─────────────────────────────────────────────
  void _toggleNumber(int num) {
    if (_buying || _ticketBought) return;
    setState(() {
      if (_selectedNumbers.contains(num)) {
        _selectedNumbers.remove(num);
      } else if (_selectedNumbers.length < _pickCount) {
        _selectedNumbers.add(num);
      }
    });
  }

  void _clearSelection() {
    if (_ticketBought) return;
    setState(() => _selectedNumbers.clear());
  }

  // ── Buy ticket ────────────────────────────────────────────────
  Future<void> _buyTicket() async {
    if (_buying || _ticketBought) return;
    if (_selectedNumbers.length != _pickCount) return;
    if (!_isIdle && _secondsLeft < _closingThreshold) {
      _showSnack('Draw is closing — wait for result'); return;
    }
    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    if (!hasFreeSpins && UserSession.instance.balance < _currentFee) {
      _showSnack('Insufficient balance. Need ₹$_currentFee'); return;
    }

    // ── Play lets-begin audio ─────────────────────────────────────
    _playAudio('lets-begin.mp3');

    setState(() => _buying = true);

    final response = await _service.buyTicket(
      UserSession.instance.email ?? '',
      UserSession.instance.name  ?? 'Player',
      _selectedNumbers.toList()..sort(),
      useFreeSpins: hasFreeSpins,
      multiplier:   _selectedMultiplier,
    );

    if (!mounted) return;
    if (response != null) {
      _handlePurchaseResponse(response);
      setState(() {
        _myTickets.add(response.ticket);
        _selectedNumbers.clear();
        _buying             = false;
        _ticketBought       = true;
        _playedThisSession  = true; // unlock result checking for this session
      });
      _showSnack('🎫 Ticket locked! Waiting for draw... (${_selectedMultiplier}x)');
    } else {
      setState(() => _buying = false);
      _showSnack('Purchase failed. Try again.');
    }
  }

  // ── Quick pick ────────────────────────────────────────────────
  Future<void> _quickPick() async {
    if (_buying || _ticketBought) return;
    if (!_isIdle && _secondsLeft < _closingThreshold) {
      _showSnack('Draw is closing — wait for result'); return;
    }
    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    if (!hasFreeSpins && UserSession.instance.balance < _currentFee) {
      _showSnack('Insufficient balance. Need ₹$_currentFee'); return;
    }

    // ── Play lets-begin audio ─────────────────────────────────────
    _playAudio('lets-begin.mp3');

    setState(() => _buying = true);

    final response = await _service.quickPick(
      UserSession.instance.email ?? '',
      UserSession.instance.name  ?? 'Player',
      useFreeSpins: hasFreeSpins,
      multiplier:   _selectedMultiplier,
    );

    if (!mounted) return;
    if (response != null) {
      _handlePurchaseResponse(response);
      setState(() {
        _myTickets.add(response.ticket);
        _buying             = false;
        _ticketBought       = true;
        _playedThisSession  = true; // unlock result checking for this session
      });
      _showSnack('🎲 Quick Pick locked! Waiting for draw... (${_selectedMultiplier}x)');
    } else {
      setState(() => _buying = false);
      _showSnack('Purchase failed. Try again.');
    }
  }

  void _handlePurchaseResponse(SuperLotoBuyResponse response) {
    if (response.newBalance != null) UserSession.instance.setBalance(response.newBalance!);
    if (response.freeSpins  != null) UserSession.instance.setFreeSpins(response.freeSpins!);
    if (response.drawNumber != null) {
      setState(() {
        _isIdle      = false;
        _secondsLeft = response.remainingTime ?? 120;
        if (_previousDrawNumber != response.drawNumber) _previousDrawNumber = response.drawNumber!;
      });
    }
    HapticFeedback.mediumImpact();
    if (response.reward   != null) SmallRewardPopup.show(context, response.reward!);
    if (response.recovery != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) LossRecoveryPopup.show(context, response.recovery!);
      });
    }
    _syncState();
  }

  void _dismissResult() {
    _resultCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _resultTicket   = null;
        _winTicket      = null;
        _showWinnersBar = false;
        _recentWinners.clear();
      });
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _bgEdge,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [_bgCenter, _bgEdge],
              radius: 1.3,
              center: Alignment.center,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _FeltPainter())),

              SlideTransition(
                position: _pageSlide,
                child: FadeTransition(
                  opacity: _pageFade,
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        _buildWinnersBar(),
                        GameJackpotBanner(),
                        const SizedBox(height: 4),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator(color: _gold))
                              : SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
                                  child: Column(
                                    children: [
                                      _buildStatusHeader(),
                                      const SizedBox(height: 12),
                                      _isIdle && !_ticketBought
                                          ? _buildIdleBanner()
                                          : _buildDrawInfo(),
                                      const SizedBox(height: 14),
                                      _buildMultiplierSelector(),
                                      const SizedBox(height: 14),
                                      _buildNumberPicker(),
                                      const SizedBox(height: 14),
                                      _buildActionButtons(),
                                      const SizedBox(height: 20),
                                      _buildMyTickets(),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Live chat
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuad,
                left: 12, right: 12,
                bottom: bottomInset > 0 ? bottomInset + 8 : 16,
                height: 220,
                child: const LiveChatOverlay(),
              ),

              // ── Shuffle overlay — appears while numbers are being drawn ──
              if (_isShuffling) _buildShuffleOverlay(),

              // Result bottom sheet
              if (_hasResult) _buildResultPanel(),

              const FloatingWinnerToast(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: _textLight, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Super Loto',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _textLight, fontSize: 20,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('💰', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              ValueListenableBuilder<int>(
                valueListenable: UserSession.instance.balanceNotifier,
                builder: (_, bal, __) => Text('₹$bal',
                    style: const TextStyle(
                        color: _gold, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Winners bar ───────────────────────────────────────────────
  Widget _buildWinnersBar() {
    if (!_showWinnersBar || _recentWinners.isEmpty) {
      if (!_showActivity) return const SizedBox(height: 36);
      return SizedBox(
        height: 36,
        child: Center(
          child: AnimatedOpacity(
            opacity: _showActivity ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔴', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 6),
                Text('$_liveCount live  •  $_activityMsg',
                    style: const TextStyle(
                        color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentWinners.length,
        itemBuilder: (_, i) {
          final w    = _recentWinners[i];
          final isMe = w['isMe'] == true;
          final name = w['name'].toString();
          final amt  = w['amount'];
          return Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isMe ? Colors.green.withOpacity(0.3) : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isMe ? Colors.greenAccent.withOpacity(0.5) : _gold.withOpacity(0.15)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isMe
                    ? Colors.greenAccent
                    : Colors.primaries[i % Colors.primaries.length].shade700,
                child: Text(name[0].toUpperCase(),
                    style: TextStyle(
                        color: isMe ? Colors.black : Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 6),
              Text(isMe ? 'You' : name,
                  style: TextStyle(
                      color: isMe ? Colors.greenAccent : Colors.white70,
                      fontSize: 12,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.normal)),
              const SizedBox(width: 4),
              Text('+₹$amt',
                  style: const TextStyle(
                      color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          );
        },
      ),
    );
  }

  // ── Status header ─────────────────────────────────────────────
  Widget _buildStatusHeader() {
    String label;
    if (_isShuffling)       label = 'DRAWING WINNING NUMBERS...';
    else if (_buying)       label = 'LOCKING IN TICKET...';
    else if (_ticketBought) label = 'TICKET LOCKED — DRAW IN PROGRESS';
    else if (_isIdle)       label = 'PICK NUMBERS & START DRAW';
    else                    label = 'DRAW OPEN — BUY YOUR TICKET';
    return Text(label,
        style: const TextStyle(
            color: _gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8));
  }

  // ── Idle banner ───────────────────────────────────────────────
  Widget _buildIdleBanner() {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.35), width: 1.5),
          boxShadow: [BoxShadow(color: _gold.withOpacity(0.12), blurRadius: 20)],
        ),
        child: Column(children: [
          const Text('🏆', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text('No Draw Running',
              style: TextStyle(color: _textLight, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Pick your numbers below and buy a ticket\nto start the 2-minute draw window!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMid, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withOpacity(0.25)),
            ),
            child: const Text('⏱  First ticket starts the draw',
                style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // ── Draw info ─────────────────────────────────────────────────
  Widget _buildDrawInfo() {
    final draw        = _currentDraw;
    final bool isClosing = !_isIdle && draw != null && draw.isOpen && _secondsLeft < _closingThreshold;
    final statusColor = isClosing ? _gold : (!_isIdle && draw?.isOpen == true ? _green : _red);
    final statusText  = _ticketBought && !_isIdle
        ? 'WAITING'
        : (isClosing ? 'CLOSING' : (!_isIdle && draw?.isOpen == true ? 'OPEN' : 'DRAWING'));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: _gold.withOpacity(0.08), blurRadius: 20)],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🏆', style: TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text('Draw #${draw?.drawNumber ?? _previousDrawNumber}',
                  style: const TextStyle(
                      color: _textLight, fontSize: 18, fontWeight: FontWeight.w800)),
              if (_ticketBought) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.lock_rounded, color: _green, size: 12),
                  const SizedBox(width: 4),
                  const Text('Your ticket is locked in',
                      style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ],
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(_formatTime(_secondsLeft),
                  style: const TextStyle(
                      color: _gold, fontSize: 26, fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ],
        ),
        if (draw != null && draw.isDrawn && draw.winningNumbers.isNotEmpty) ...[
          Builder(builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _triggerBallReveal(draw.drawNumber));
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 14),
          Divider(color: _gold.withOpacity(0.2), height: 1),
          const SizedBox(height: 14),
          Text(_revealedBallCount < 6 ? 'REVEALING NUMBERS...' : 'WINNING NUMBERS',
              style: TextStyle(
                  color: _revealedBallCount < 6 ? _gold : _textMid,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8,
              children: draw.winningNumbers
                  .take(_revealedBallCount)
                  .map((n) => _buildBall(n, isWinning: true))
                  .toList()),
        ],
      ]),
    );
  }

  // ── Multiplier selector ───────────────────────────────────────
  Widget _buildMultiplierSelector() {
    final canChange = !_buying && !_ticketBought;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🎯  Bet Multiplier',
                style: TextStyle(color: _textLight, fontSize: 13, fontWeight: FontWeight.w700)),
            Text('Pay ₹$_currentFee  →  Win ₹$_previewWin+',
                style: TextStyle(
                    color: _selectedMultiplier > 1 ? _gold : _textMid,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _multipliers.map((m) {
            final isSelected = _selectedMultiplier == m;
            final Color chipColor = m == 1
                ? _gold : m == 2
                    ? const Color(0xFF00C9A7) : m == 5
                        ? const Color(0xFF845EF7) : const Color(0xFFFF6B6B);
            return Expanded(
              child: GestureDetector(
                onTap: canChange ? () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMultiplier = m);
                } : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? chipColor.withOpacity(0.22) : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected ? chipColor : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1),
                    boxShadow: isSelected
                        ? [BoxShadow(color: chipColor.withOpacity(0.35), blurRadius: 12)]
                        : null,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${m}x',
                        style: TextStyle(
                            color: isSelected ? chipColor : Colors.white38,
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('₹${_baseTicketFee * m}',
                        style: TextStyle(
                            color: isSelected ? chipColor.withOpacity(0.8) : Colors.white24,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Number picker ─────────────────────────────────────────────
  Widget _buildNumberPicker() {
    final bool locked        = _ticketBought || _buying;
    final bool drawIsClosing = !_isIdle && _secondsLeft < _closingThreshold;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: locked ? _green.withOpacity(0.2) : _gold.withOpacity(0.15)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pick $_pickCount numbers (1–$_totalNumbers)',
                style: const TextStyle(color: _textLight, fontSize: 13, fontWeight: FontWeight.w600)),
            if (locked)
              Row(children: [
                const Icon(Icons.lock_rounded, color: _green, size: 13),
                const SizedBox(width: 4),
                const Text('Locked',
                    style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
              ])
            else
              Text('${_selectedNumbers.length}/$_pickCount',
                  style: TextStyle(
                      color: _selectedNumbers.length == _pickCount ? _green : _textMid,
                      fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        if (drawIsClosing && !locked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('⚠️ Draw closing — wait for result',
                style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 5, runSpacing: 5,
          children: List.generate(_totalNumbers, (i) {
            final num        = i + 1;
            final isSelected = _selectedNumbers.contains(num);
            final isLocked   = locked && isSelected;
            return GestureDetector(
              onTap: (locked || drawIsClosing) ? null : () => _toggleNumber(num),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isLocked
                      ? _green.withOpacity(0.18)
                      : isSelected
                          ? _gold.withOpacity(0.85)
                          : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isLocked
                          ? _green.withOpacity(0.6)
                          : isSelected ? _gold : Colors.white.withOpacity(0.08),
                      width: isSelected ? 2 : 1),
                  boxShadow: isSelected
                      ? [BoxShadow(color: _gold.withOpacity(0.4), blurRadius: 8)]
                      : null,
                ),
                child: Center(
                  child: Text('$num',
                      style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white38,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400)),
                ),
              ),
            );
          }),
        ),
        if (_selectedNumbers.isNotEmpty && !locked) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _clearSelection,
            child: Text('Clear selection',
                style: TextStyle(color: _red.withOpacity(0.7), fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  // ── Action buttons ────────────────────────────────────────────
  Widget _buildActionButtons() {
    final bool drawIsClosing = !_isIdle && _secondsLeft < _closingThreshold;
    final bool canAct    = !drawIsClosing && !_buying && !_ticketBought;
    final bool canBuy    = canAct && _selectedNumbers.length == _pickCount;
    final bool canQuick  = canAct;
    final bool hasFreeSpins = UserSession.instance.freeSpins > 0;
    final String priceLabel = hasFreeSpins ? 'FREE' : '₹$_currentFee';

    if (_ticketBought) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withOpacity(0.35)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(color: _green, strokeWidth: 2)),
          const SizedBox(width: 12),
          const Text('Waiting for draw result...',
              style: TextStyle(color: _green, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: canBuy ? _buyTicket : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: canBuy ? [_gold, _goldDark] : [Colors.black26, Colors.black26]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: canBuy
                  ? [BoxShadow(color: _gold.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 5))]
                  : null,
            ),
            child: Center(
              child: _buying
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_isIdle ? '🎫  Buy & Start' : '🎫  Buy Ticket',
                          style: TextStyle(
                              color: canBuy ? Colors.black : Colors.white24,
                              fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(priceLabel,
                          style: TextStyle(
                              color: canBuy
                                  ? (hasFreeSpins ? Colors.green.shade800 : Colors.black54)
                                  : Colors.white12,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GestureDetector(
          onTap: canQuick ? _quickPick : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: canQuick
                      ? [const Color(0xFF00C9A7), const Color(0xFF009B7D)]
                      : [Colors.black26, Colors.black26]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: canQuick
                  ? [BoxShadow(
                      color: const Color(0xFF00C9A7).withOpacity(0.4),
                      blurRadius: 16, offset: const Offset(0, 5))]
                  : null,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_isIdle ? '🎲  Quick & Start' : '🎲  Quick Pick',
                    style: TextStyle(
                        color: canQuick ? Colors.black : Colors.white24,
                        fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(priceLabel,
                    style: TextStyle(
                        color: canQuick
                            ? (hasFreeSpins ? Colors.green.shade900 : Colors.black54)
                            : Colors.white12,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Ball ──────────────────────────────────────────────────────
  Widget _buildBall(int number, {bool isWinning = false, bool isMatched = false}) {
    final Color c = isMatched ? _green : (isWinning ? _gold : const Color(0xFFE2A847));
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: c,
          boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Center(
        child: Text('$number',
            style: TextStyle(
                color: isWinning || isMatched ? Colors.black : Colors.white,
                fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
  }

  // ── Shuffle overlay ───────────────────────────────────────────
  /// Full-screen overlay that shows 5–6 seconds of rapidly changing yellow
  /// balls while scratch.mp3 plays, simulating the draw machine.
  Widget _buildShuffleOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.88),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Header ──────────────────────────────────────────
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFF8A0), Color(0xFFFFD700)],
              ).createShader(bounds),
              child: const Text(
                '🎰  DRAWING NUMBERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),

            const SizedBox(height: 6),
            Text(
              'The machine is picking your fate...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  letterSpacing: 0.5),
            ),

            const SizedBox(height: 40),

            // ── 6 Bouncing shuffle balls ─────────────────────────
            AnimatedBuilder(
              animation: _shuffleBounceCtrl,
              builder: (_, __) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: List.generate(6, (i) {
                    // Each ball has a slightly offset bounce phase
                    final offsetPhase = (i / 6.0);
                    final t = (_shuffleBounceCtrl.value + offsetPhase) % 1.0;
                    // Sine wave for independent bounce
                    final bounce = 1.0 + 0.14 * sin(t * pi * 2);
                    return Transform.scale(
                      scale: bounce,
                      child: _buildShuffleBall(_shuffleNumbers[i]),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: 40),

            // ── Animated dots indicator ──────────────────────────
            AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = (_shimmerCtrl.value + i * 0.33) % 1.0;
                    final opacity = (sin(phase * pi * 2) * 0.5 + 0.5).clamp(0.2, 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold.withOpacity(opacity),
                      ),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: 20),

            Text(
              'Results reveal shortly',
              style: TextStyle(
                  color: _gold.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  /// Single shuffle ball — large gold, glowing, rapid number change
  Widget _buildShuffleBall(int number) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFF176), Color(0xFFFFD700), Color(0xFFB8860B)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.65),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Color(0xFF3A2800),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  // ── My tickets ────────────────────────────────────────────────
  Widget _buildMyTickets() {
    if (_myTickets.isEmpty && _previousDrawTickets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_previousDrawTickets.isNotEmpty) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Last Draw #${_previousDrawTickets.first.drawNumber}',
                style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w700)),
            GestureDetector(
                onTap: () => setState(() => _previousDrawTickets = []),
                child: Text('Dismiss', style: TextStyle(color: _textMid, fontSize: 12))),
          ],
        ),
        const SizedBox(height: 10),
        ..._previousDrawTickets.map((t) => _buildTicketTile(t)),
        const SizedBox(height: 18),
      ],
      if (_myTickets.isNotEmpty) ...[
        Text('My Tickets — Draw #${_currentDraw?.drawNumber ?? _previousDrawNumber}',
            style: const TextStyle(color: _textLight, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._myTickets.map((t) => _buildTicketTile(t)),
      ],
    ]);
  }

  Widget _buildTicketTile(SuperLotoTicketModel ticket) {
    Color  statusColor;
    String statusText;
    if (ticket.isPending)    { statusColor = _gold;             statusText = 'Pending'; }
    else if (ticket.isWin)  { statusColor = Colors.greenAccent; statusText = ticket.tierLabel ?? 'Win!'; }
    else                     { statusColor = _red;              statusText = 'No Match'; }
    final int mult = ticket.multiplier > 1 ? ticket.multiplier : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: ticket.isWin ? Colors.greenAccent.withOpacity(0.3) : Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(ticket.isQuickPick ? '🎲' : '🎫', style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(ticket.isQuickPick ? 'Quick Pick' : 'My Pick',
                  style: const TextStyle(
                      color: _textLight, fontSize: 12, fontWeight: FontWeight.w600)),
              if (mult > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _gold.withOpacity(0.35))),
                  child: Text('${mult}x',
                      style: const TextStyle(
                          color: _gold, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(statusText,
                  style: TextStyle(
                      color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 5,
            children: ticket.numbers.map((n) {
              final isMatched = ticket.matchedNumbers.contains(n);
              return _buildBall(n, isMatched: isMatched);
            }).toList()),
        if (!ticket.isPending && ticket.matchCount > 0) ...[
          const SizedBox(height: 5),
          Text('${ticket.matchCount} matched',
              style: const TextStyle(color: _green, fontSize: 11)),
        ],
        if (ticket.isWin && ticket.winAmount > 0) ...[
          const SizedBox(height: 3),
          Text('+₹${ticket.winAmount} won',
              style: const TextStyle(
                  color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // ── Result panel slides up from bottom ────────────────────────
  Widget _buildResultPanel() {
    final ticket = _resultTicket!;
    final isWin  = ticket.isWin;
    final winAmt = ticket.winAmount;

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
                    color: isWin ? _gold.withOpacity(0.8) : _red.withOpacity(0.5),
                    width: 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: isWin ? _gold.withOpacity(0.22) : _red.withOpacity(0.18),
                  blurRadius: 40, spreadRadius: 4, offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          (isWin ? _gold : _red).withOpacity(0.25),
                          Colors.transparent
                        ]),
                        border: Border.all(color: isWin ? _gold : _red, width: 2),
                      ),
                      child: Center(
                          child: Text(isWin ? '🏆' : '😔',
                              style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isWin ? 'YOU WON!' : 'BETTER LUCK',
                            style: TextStyle(
                                color: isWin ? _gold : _red,
                                fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text(
                          isWin ? '${ticket.matchCount} numbers matched!' : 'No match this round',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
                        if (ticket.tierLabel != null && isWin)
                          Text(ticket.tierLabel!,
                              style: TextStyle(
                                  color: _gold.withOpacity(0.8),
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Stats strip
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statChip('MULTIPLIER', '${ticket.multiplier}x', _gold),
                        _statDivider(),
                        _statChip('MATCHED', '${ticket.matchCount}/6', _green),
                        _statDivider(),
                        _statChip(
                          isWin ? 'WINNINGS' : 'RESULT',
                          isWin ? '+₹$winAmt' : 'No Win',
                          isWin ? Colors.greenAccent : _textMid,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Balls
                  Wrap(spacing: 6, runSpacing: 6,
                      children: ticket.numbers.map((n) {
                        final isMatched = ticket.matchedNumbers.contains(n);
                        return _buildBall(n, isMatched: isMatched);
                      }).toList()),

                  const SizedBox(height: 20),

                  // CTA
                  GestureDetector(
                    onTap: _dismissResult,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isWin
                              ? [_gold, _goldDark]
                              : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isWin ? _gold : const Color(0xFF3B82F6)).withOpacity(0.38),
                            blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isWin ? '🏆  Play Again' : '🎲  Try Again',
                          style: TextStyle(
                              color: isWin ? Colors.black : Colors.white,
                              fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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

  Widget _statChip(String label, String value, Color valueColor) => Column(children: [
    Text(label,
        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9, letterSpacing: 1.4)),
    const SizedBox(height: 4),
    Text(value,
        style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
  ]);

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.1));
}

// ── Felt texture ──────────────────────────────────────────────
class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.012)..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 14) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_FeltPainter o) => false;
}