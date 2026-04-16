// lib/screens/lottery/lottery_game_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_session.dart';
import '../../services/lottery_service.dart';
import '../../models/lottery/lottery_draw_model.dart';
import '../../models/lottery/lottery_ticket_model.dart';
import '../../widgets/engagement/floating_winner_toast.dart';
import '../../widgets/engagement/small_reward_popup.dart';
import '../../widgets/engagement/loss_recovery_popup.dart';
import '../../widgets/engagement/game_result_stats.dart';
import '../../widgets/engagement/game_jackpot_banner.dart';
import '../../widgets/engagement/live_chat_overlay.dart';

class LotteryGameScreen extends StatefulWidget {
  const LotteryGameScreen({super.key});

  @override
  State<LotteryGameScreen> createState() => _LotteryGameScreenState();
}

class _LotteryGameScreenState extends State<LotteryGameScreen>
    with TickerProviderStateMixin {
  // ── Design tokens (casino felt theme) ────────────────────────────────────
  static const Color _bgTableCenter = Color(0xFF0F5132);
  static const Color _bgTableEdge   = Color(0xFF062314);
  static const Color _surface       = Color(0xFF112A1D);
  static const Color _card          = Color(0xFF0D2118);
  static const Color _gold          = Color(0xFFFFD700);
  static const Color _goldDark      = Color(0xFFB8860B);
  static const Color _green         = Color(0xFF00D2A0);
  static const Color _red           = Color(0xFFEF4444);
  static const Color _blue          = Color(0xFF6C9AEF);
  static const Color _accent        = Color(0xFFA29BFE);
  static const Color _textLight     = Color(0xFFF0F4FF);
  static const Color _textMid       = Color(0xFF7B9A8A);

  static const int _totalNumbers = 21; // 0–20
  static const int _pickCount    = 3;

  final _lotteryService = LotteryService();
  final Random _random   = Random();

  // ── State (static to survive navigation) ─────────────────────────────────
  static LotteryDrawModel?      _currentDraw;
  static List<LotteryTicketModel> _myTickets           = [];
  static List<LotteryTicketModel> _previousDrawTickets = [];
  static final Set<int>           _selectedNumbers      = {};
  static int                      _previousDrawNumber   = 0;
  static String                   _lastDrawWinType      = 'normal';

  bool _loading = _currentDraw == null;
  bool _buying  = false;

  // Multiplier State
  int _selectedMultiplier = 1;

  // User-Triggered Sequence State
  bool _isDrawSequenceRunning = false;
  int _secondsLeft = 0;

  // Win celebration
  static LotteryTicketModel? _winTicket;
  static int                 _lastCheckedDraw = 0;

  // Post-round result panel
  bool _showResultPanel = false;
  bool _justWon         = false;
  int? _lastWinAmount;

  // Shuffle Animation State
  bool _isShuffling = false;
  int? _shuffleHighlight;
  Timer? _shuffleTimer;
  Timer? _countdownTimer;

  // Recent winners bar (social proof)
  bool                       _showWinnersBar = false;
  List<Map<String, dynamic>> _recentWinners  = [];
  final List<String> _fakeNames = [
    'Rahul','Priya','Amit','Neha','Vikas','Karan','Sneha','Ravi',
    'Pooja','Sunil','Anita','Deepak','Roshni','Sanjay','Kavita',
  ];

  // Fake social stats
  int _statsTotalPlayers = 0;
  int _statsTotalWinners = 0;
  int _statsTotalLosers  = 0;

  // Ball reveal animation
  static int _revealedBallCount = 3;
  Timer? _ballRevealTimer;
  static int _lastRevealedDraw = 0;

  // Sync
  Timer? _syncTimer;

  // ── Audio ─────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();  // scratch / lets-begin
  final AudioPlayer _tickPlayer  = AudioPlayer();  // per-number tick during shuffle

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> _playTick() async {
    try {
      await _tickPlayer.stop();
      await _tickPlayer.play(AssetSource('audio/pop.wav'));
    } catch (_) {}
  }

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  late AnimationController _resultCtrl;
  late Animation<Offset>   _resultSlide;
  late Animation<double>   _resultFade;

  late AnimationController _counterCtrl;
  late Animation<int>      _counterAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _resultSlide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _counterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _counterAnim = IntTween(begin: 0, end: 0).animate(_counterCtrl);

    _pageCtrl.forward();
    _loadData();
    
    // Background sync to keep draw number updated, but NOT controlling the UI countdown anymore
    _syncTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _syncTime());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _resultCtrl.dispose();
    _counterCtrl.dispose();
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
    _ballRevealTimer?.cancel();
    _shuffleTimer?.cancel();
    _audioPlayer.dispose();
    _tickPlayer.dispose();
    super.dispose();
  }

  // ── LOCAL DRAW SEQUENCE (30s + 6s Shuffle) ───────────────────────────────
  void _runDrawSequence() {
    setState(() {
      _isDrawSequenceRunning = true;
      _secondsLeft = 30; // 30 seconds local countdown
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _startShuffleAnimation(); // Start the 6s shuffle once 30s is over
      }
    });
  }

  // ── Shuffle Animation (decelerating speed + sound per number) ────────────
  void _startShuffleAnimation() {
    if (_isShuffling) return;
    _playSound('audio/scratch.mp3'); // overall shuffle ambience
    setState(() => _isShuffling = true);

    // 25 ticks: delay ramps from 60ms → 420ms (ease-out feel)
    const int    totalTicks = 25;
    const double startMs    = 60.0;
    const double endMs      = 420.0;
    int tick = 0;

    void scheduleNext() {
      if (!mounted || !_isShuffling) return;

      if (tick >= totalTicks) {
        // Shuffle complete
        setState(() {
          _isShuffling          = false;
          _shuffleHighlight     = null;
          _isDrawSequenceRunning = false;
        });
        _checkForWins();
        return;
      }

      // Linear ease-out: each tick is slower than the last
      final double progress = tick / totalTicks;
      final int    delayMs  = (startMs + (endMs - startMs) * progress).round();

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted || !_isShuffling) return;
        setState(() => _shuffleHighlight = _random.nextInt(_totalNumbers));
        _playTick(); // 🔊 pop.wav on each number highlight
        tick++;
        scheduleNext();
      });
    }

    scheduleNext();
  }

  // ── Ball reveal ───────────────────────────────────────────────
  void _triggerBallReveal(int drawNumber) {
    if (_lastRevealedDraw == drawNumber) return;
    _lastRevealedDraw = drawNumber;
    _revealedBallCount = 0;
    _ballRevealTimer?.cancel();
    _ballRevealTimer =
        Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _revealedBallCount++);
      HapticFeedback.selectionClick();
      if (_revealedBallCount >= 3) timer.cancel();
    });
  }

  // ── Sync ──────────────────────────────────────────────────────
  Future<void> _syncTime() async {
    final userId = UserSession.instance.email ?? '';
    final draw   = await _lotteryService.getCurrentDraw();
    if (!mounted) return;

    if (draw != null) {
      if (_previousDrawNumber > 0 && draw.drawNumber != _previousDrawNumber) {
        if (_currentDraw != null && _currentDraw!.isDrawn) {
          _lastDrawWinType = _currentDraw!.winType;
        }
        final oldTickets =
            await _lotteryService.getUserTickets(userId, _previousDrawNumber);
        if (mounted && oldTickets.isNotEmpty) {
          setState(() => _previousDrawTickets = oldTickets);
        }
        _previousDrawNumber = draw.drawNumber;
      }

      final tickets =
          await _lotteryService.getUserTickets(userId, draw.drawNumber);
      if (mounted) {
        setState(() {
          _currentDraw = draw;
          _myTickets   = tickets;
        });
      }
    }
  }

  // ── Load data ─────────────────────────────────────────────────
  Future<void> _loadData() async {
    final userId = UserSession.instance.email ?? '';
    final draw   = await _lotteryService.getCurrentDraw();
    if (!mounted) return;

    if (draw != null) {
      final tickets =
          await _lotteryService.getUserTickets(userId, draw.drawNumber);
      if (!mounted) return;

      if (_previousDrawNumber > 0 && draw.drawNumber != _previousDrawNumber) {
        final oldTickets =
            await _lotteryService.getUserTickets(userId, _previousDrawNumber);
        if (mounted && oldTickets.isNotEmpty) {
          setState(() => _previousDrawTickets = oldTickets);
        }
      }

      _previousDrawNumber = draw.drawNumber;
      setState(() {
        _currentDraw = draw;
        _myTickets   = tickets;
        _loading     = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  // ── Check wins (Unified Bottom Popup) ────────────────────────
  Future<void> _checkForWins() async {
    final userId = UserSession.instance.email ?? '';
    if (userId.isEmpty) return;

    // Fetch latest history to see results of the just-finished sequence
    final history = await _lotteryService.getUserHistory(userId, limit: 10);
    if (!mounted) return;

    for (final ticket in history) {
      if (ticket.isPending) continue;
      if (ticket.drawNumber <= _lastCheckedDraw) continue;

      _lastCheckedDraw = ticket.drawNumber;

      if (ticket.isWin) {
        setState(() => _winTicket = ticket);
        _triggerResultPanel(true, ticket.winAmount);
        HapticFeedback.heavyImpact();
      } else {
        _triggerResultPanel(false, 0);
      }

      // ── Always re-fetch authoritative balance from server ──────
      // NEVER do local arithmetic (balance + winAmount) — the server
      // already credited the prize in executeDraw. Local math causes
      // double-counting when the fee deduction isn't yet reflected locally.
      _refreshBalance(userId);
      break;
    }
  }

  // ── Fetch authoritative balance from server ───────────────────
  // Called after every draw result — guarantees the display matches
  // the exact server value with no local arithmetic double-counting.
  Future<void> _refreshBalance(String email) async {
    try {
      final token = UserSession.instance.token ?? '';
      if (token.isEmpty) return;
      final res = await _lotteryService.fetchUserStats(token);
      if (!mounted || res == null) return;
      final balance   = (res['balance']   as num?)?.toInt();
      final wins      = (res['wins']      as num?)?.toInt();
      final freeSpins = (res['freeSpins'] as num?)?.toInt();
      if (balance   != null) UserSession.instance.setBalance(balance);
      if (wins      != null) UserSession.instance.setWins(wins);
      if (freeSpins != null) UserSession.instance.setFreeSpins(freeSpins);
    } catch (_) {}
  }

  // ── Toggle number ─────────────────────────────────────────────
  void _toggleNumber(int num) {
    if (_buying || _isDrawSequenceRunning || _isShuffling) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedNumbers.contains(num)) {
        _selectedNumbers.remove(num);
      } else if (_selectedNumbers.length < _pickCount) {
        _selectedNumbers.add(num);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedNumbers.clear());

  // ── Buy ticket ───────────────────────────────────
  Future<void> _buyTicket() async {
    if (_buying || _currentDraw == null || _isDrawSequenceRunning) return;
    if (_selectedNumbers.length != _pickCount) return;

    _playSound('audio/lets-begin.mp3'); // 🔊 play on buy tap

    final fee          = (2 * _selectedNumbers.length) * _selectedMultiplier;
    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    
    if (!hasFreeSpins && UserSession.instance.balance < fee) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Insufficient balance. Need ₹$fee, have ₹${UserSession.instance.balance}')));
      return;
    }

    final userId   = UserSession.instance.email ?? '';
    final username = UserSession.instance.name ?? 'Player';

    setState(() => _buying = true);

    final response = await _lotteryService.buyTicket(
      userId, username,
      _selectedNumbers.toList()..sort(),
      _currentDraw!.drawNumber,
      useFreeSpins: hasFreeSpins,
      multiplier: _selectedMultiplier, 
    );

    if (!mounted) return;

    if (response != null) {
      if (response.newBalance != null)
        UserSession.instance.setBalance(response.newBalance!);
      if (response.freeSpins != null)
        UserSession.instance.setFreeSpins(response.freeSpins!);

      HapticFeedback.mediumImpact();
      setState(() {
        _myTickets.add(response.ticket);
        _selectedNumbers.clear();
        _buying = false;
      });
      
      // Start Local Countdown & Shuffle Sequence
      _runDrawSequence();

      if (response.reward != null)
        SmallRewardPopup.show(context, response.reward!);
      if (response.recovery != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) LossRecoveryPopup.show(context, response.recovery!);
        });
      }
    } else {
      setState(() => _buying = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draw closed. Wait for next draw.')));
    }
  }

  // ── Quick pick ───────────────────────────────────
  Future<void> _quickPick() async {
    if (_buying || _currentDraw == null || _isDrawSequenceRunning) return;

    _playSound('audio/lets-begin.mp3'); // 🔊 play on quick pick tap

    final fee          = (2 * _pickCount) * _selectedMultiplier;
    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    
    if (!hasFreeSpins && UserSession.instance.balance < fee) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Insufficient balance. Need ₹$fee, have ₹${UserSession.instance.balance}')));
      return;
    }

    final userId   = UserSession.instance.email ?? '';
    final username = UserSession.instance.name ?? 'Player';

    setState(() => _buying = true);

    final response = await _lotteryService.quickPick(
        userId, username, _currentDraw!.drawNumber,
        useFreeSpins: hasFreeSpins,
        multiplier: _selectedMultiplier); 

    if (!mounted) return;

    if (response != null) {
      if (response.newBalance != null)
        UserSession.instance.setBalance(response.newBalance!);
      if (response.freeSpins != null)
        UserSession.instance.setFreeSpins(response.freeSpins!);

      HapticFeedback.mediumImpact();
      setState(() {
        _myTickets.add(response.ticket);
        _buying = false;
      });
      
      // Start Local Countdown & Shuffle Sequence
      _runDrawSequence();

      if (response.reward != null)
        SmallRewardPopup.show(context, response.reward!);
      if (response.recovery != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) LossRecoveryPopup.show(context, response.recovery!);
        });
      }
    } else {
      setState(() => _buying = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draw closed. Wait for next draw.')));
    }
  }

  // ── Result panel trigger ────────────────────────────────────────────
  void _triggerResultPanel(bool isWin, int winAmt) {
    final fakePlayers = 150 + _random.nextInt(400);
    final fakeWinners = (fakePlayers * 0.12).toInt() + _random.nextInt(8);
    final fakeLosers  = fakePlayers - fakeWinners;

    List<Map<String, dynamic>> winners = [];
    if (isWin) {
      winners.add({
        'name':   UserSession.instance.name ?? 'You',
        'amount': winAmt,
        'isMe':   true,
      });
    }
    final displayCount = min(14, fakeWinners);
    for (int i = 0; i < displayCount; i++) {
      final base      = _fakeNames[_random.nextInt(_fakeNames.length)];
      final randomAmt = (_random.nextInt(6) + 1) * 6;
      winners.add({
        'name':   '$base${_random.nextInt(99)}',
        'amount': randomAmt,
        'isMe':   false,
      });
    }

    setState(() {
      _justWon            = isWin;
      _lastWinAmount      = winAmt;
      _statsTotalPlayers  = fakePlayers;
      _statsTotalWinners  = fakeWinners;
      _statsTotalLosers   = fakeLosers;
      _recentWinners      = winners;
      _showWinnersBar     = true;
      _showResultPanel    = true;
    });

    _resultCtrl.forward(from: 0);

    if (isWin) {
      _counterAnim = IntTween(begin: 0, end: winAmt)
          .animate(CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOut));
      _counterCtrl.forward(from: 0);
    }
  }

  void _dismissResultPanel() {
    _resultCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _showResultPanel = false);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
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
              // Felt texture
              Positioned.fill(child: CustomPaint(painter: _FeltTexturePainter())),

              // Main content
              SlideTransition(
                position: _pageSlide,
                child: FadeTransition(
                  opacity: _pageFade,
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        _buildRecentWinnersBar(),
                        GameJackpotBanner(),
                        const SizedBox(height: 6),
                        _buildCountdownStrip(), 
                        Expanded(
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: _gold))
                              : SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 16, 180),
                                  child: Column(
                                    children: [
                                      _buildHotColdStrip(),
                                      const SizedBox(height: 14),
                                      _buildNumberPicker(),
                                      const SizedBox(height: 16),
                                      _buildMultiplierSelector(), 
                                      const SizedBox(height: 8),
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

              // Live chat overlay (bottom)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuad,
                left: 12, right: 12,
                bottom: bottomInset > 0 ? bottomInset + 8 : 16,
                height: 220,
                child: const LiveChatOverlay(),
              ),

              const FloatingWinnerToast(),

              // Result panel (slides up from the very bottom of the screen)
              if (_showResultPanel)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildResultPanel(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: _textLight, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Lottery',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _textLight,
                  fontSize: 20,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2),
            ),
          ),
          // Balance chip
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
                Text('₹${UserSession.instance.balance}',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Winners scroll bar ────────────────────────────────────────────────────
  Widget _buildRecentWinnersBar() {
    if (!_showWinnersBar || _recentWinners.isEmpty) {
      return const SizedBox(height: 42);
    }
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentWinners.length,
        itemBuilder: (context, i) {
          final w           = _recentWinners[i];
          final isMe        = w['isMe'] == true;
          final name        = w['name'].toString();
          final amt         = w['amount'];
          final bgColor     = isMe
              ? Colors.green.withOpacity(0.3)
              : Colors.black.withOpacity(0.3);
          final borderColor = isMe
              ? Colors.greenAccent.withOpacity(0.5)
              : _gold.withOpacity(0.15);
          final avatarColor = isMe
              ? Colors.greenAccent
              : Colors.primaries[i % Colors.primaries.length].shade700;
          final avatarTextCol = isMe ? Colors.black : Colors.white;

          return Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: avatarColor,
                  child: Text(name[0].toUpperCase(),
                      style: TextStyle(
                          color: avatarTextCol,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                Text(isMe ? 'You' : name,
                    style: TextStyle(
                        color: isMe ? Colors.greenAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isMe ? FontWeight.w700 : FontWeight.normal)),
                const SizedBox(width: 4),
                Text('+₹$amt',
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Countdown strip ───────────────────────────────────────────────────────
  Widget _buildCountdownStrip() {
    final draw = _currentDraw;

    Color statusColor;
    String statusText;
    String statusIcon;
    
    if (_isShuffling) {
      statusColor = _gold; statusText = 'DRAWING'; statusIcon = '🎲';
    } else if (_isDrawSequenceRunning) {
      statusColor = _gold; statusText = 'CLOSING'; statusIcon = '⏳';
    } else {
      statusColor = _green; statusText = 'READY';  statusIcon = '🟢';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: statusColor.withOpacity(0.1),
                blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            Text(statusIcon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text('Draw #${draw?.drawNumber ?? '--'}',
                style: const TextStyle(
                    color: _textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ),
            const Spacer(),
            Text(
              _isShuffling 
                  ? '...' 
                  : (_isDrawSequenceRunning ? '${max(0, _secondsLeft)}s' : '--'),
              style: TextStyle(
                  color: _secondsLeft < 10 && _isDrawSequenceRunning ? _red : _gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hot / Cold / Last strip ───────────────────────────────────────────────
  Widget _buildHotColdStrip() {
    final draw         = _currentDraw;
    final lastResult   = (draw != null && draw.isDrawn && draw.winningNumbers.isNotEmpty)
        ? draw.winningNumbers.join(', ')
        : '?';
    final seed  = draw?.drawNumber ?? 0;
    final hot1  = seed % 21;
    final hot2  = (seed + 7) % 21;
    final cold1 = (seed + 13) % 21;
    final cold2 = (seed + 19) % 21;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statIndicator('HOT 🔥', '$hot1, $hot2', Colors.orangeAccent),
            Container(width: 1, height: 24, color: Colors.white12),
            _statIndicator('COLD ❄️', '$cold1, $cold2', Colors.cyanAccent),
            Container(width: 1, height: 24, color: Colors.white12),
            _statIndicator('LAST 🎯', lastResult, _gold),
          ],
        ),
      ),
    );
  }

  Widget _statIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ── Number picker grid ────────────────────────────────────────────────────
  Widget _buildNumberPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pick $_pickCount Numbers  (0 – ${_totalNumbers - 1})',
                style: const TextStyle(
                    color: _textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedNumbers.length == _pickCount
                      ? _green.withOpacity(0.2)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _selectedNumbers.length == _pickCount
                          ? _green.withOpacity(0.5)
                          : Colors.transparent),
                ),
                child: Text(
                  '${_selectedNumbers.length}/$_pickCount',
                  style: TextStyle(
                      color: _selectedNumbers.length == _pickCount
                          ? _green
                          : _textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IgnorePointer(
            ignoring: _buying || _isDrawSequenceRunning || _isShuffling,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: (_isDrawSequenceRunning || _isShuffling) ? 0.6 : 1.0,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_totalNumbers, (i) {
                  // Either selected manually OR highlighted dynamically by shuffle
                  final isSelected = _selectedNumbers.contains(i) || (i == _shuffleHighlight);
                  return _LotteryNumberTile(
                    number: i,
                    selected: isSelected,
                    onTap: () => _toggleNumber(i),
                  );
                }),
              ),
            ),
          ),
          if (_selectedNumbers.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _clearSelection,
              child: Text('Clear selection',
                  style: TextStyle(color: _red.withOpacity(0.8), fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bet Multiplier Selector ───────────────────────────────────────────────
  Widget _buildMultiplierSelector() {
    final options = [1, 2, 5, 10];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Bet Multiplier:', 
            style: TextStyle(color: _textLight, fontSize: 13, fontWeight: FontWeight.bold)),
          Row(
            children: options.map((m) {
              final isSelected = _selectedMultiplier == m;
              return GestureDetector(
                onTap: () {
                  if (_buying || _isDrawSequenceRunning) return;
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMultiplier = m);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _gold.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                    border: Border.all(color: isSelected ? _gold : Colors.white12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${m}x', 
                    style: TextStyle(
                      color: isSelected ? _gold : Colors.white54, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 13
                    )
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    final canBuy   = _selectedNumbers.length == _pickCount && !_buying && !_isDrawSequenceRunning;
    final canQuick = !_buying && !_isDrawSequenceRunning;

    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    final priceLabel   = hasFreeSpins ? 'FREE' : '₹${(2 * _pickCount) * _selectedMultiplier}';
    final priceColor   = hasFreeSpins ? Colors.greenAccent : Colors.black87;

    return Row(
      children: [
        // Buy Ticket
        Expanded(
          child: GestureDetector(
            onTap: canBuy ? _buyTicket : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: canBuy
                        ? [_gold, _goldDark]
                        : [_surface, _surface]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: canBuy
                    ? [
                        BoxShadow(
                            color: _gold.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ]
                    : null,
                border: Border.all(
                    color: canBuy ? _gold : Colors.white.withOpacity(0.1),
                    width: canBuy ? 0 : 1),
              ),
              child: _buying
                  ? const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.black87, strokeWidth: 2.5)))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎫  BUY TICKET',
                            style: TextStyle(
                                color: canBuy
                                    ? Colors.black
                                    : Colors.white.withOpacity(0.3),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(priceLabel,
                            style: TextStyle(
                                color: canBuy ? priceColor : Colors.white24,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Quick Pick
        Expanded(
          child: GestureDetector(
            onTap: canQuick ? _quickPick : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: canQuick
                        ? [_blue, const Color(0xFF4A6FD4)]
                        : [_surface, _surface]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: canQuick
                    ? [
                        BoxShadow(
                            color: _blue.withOpacity(0.35),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ]
                    : null,
                border: Border.all(
                    color: canQuick ? _blue : Colors.white.withOpacity(0.1),
                    width: canQuick ? 0 : 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎲  QUICK PICK',
                      style: TextStyle(
                          color: canQuick
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(priceLabel,
                      style: TextStyle(
                          color: canQuick ? priceColor : Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── My tickets ────────────────────────────────────────────────────────────
  Widget _buildMyTickets() {
    final hasCurrent  = _myTickets.isNotEmpty;
    if (!hasCurrent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCurrent) ...[
          Text('My Tickets — Draw #${_currentDraw?.drawNumber ?? ''}',
              style: const TextStyle(
                  color: _textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ..._myTickets.map((t) => _buildTicketTile(t)),
        ],
      ],
    );
  }

  Widget _buildTicketTile(LotteryTicketModel ticket) {
    Color  statusColor;
    String statusText;
    if (ticket.isPending) {
      statusColor = _accent;  statusText = 'Pending';
    } else if (ticket.isWin) {
      statusColor = _gold;    statusText = '🎉 ${ticket.tierLabel ?? "Win!"}';
    } else {
      statusColor = _red;
      statusText  = ticket.matchCount > 0
          ? '${ticket.matchCount} matched — not enough'
          : 'No Match';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ticket.isWin
              ? _gold.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(ticket.isQuickPick ? '🎲' : '🎫',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(ticket.isQuickPick ? 'Quick Pick' : 'My Pick',
                    style: const TextStyle(
                        color: _textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                children: ticket.numbers.take(_pickCount).map<Widget>((n) {
                  final isMatched = ticket.matchedNumbers.contains(n);
                  return _buildBall(n, isMatched: isMatched);
                }).toList(),
              ),
              if (ticket.multiplier > 1) 
                Text('${ticket.multiplier}x Bet', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          if (!ticket.isPending && ticket.matchCount > 0) ...[
            const SizedBox(height: 6),
            Text('${ticket.matchCount} matched',
                style: TextStyle(
                    color: ticket.isWin ? _gold : _green, fontSize: 12)),
          ],
          if (ticket.isWin && ticket.winAmount > 0) ...[
            const SizedBox(height: 4),
            Text('+₹${ticket.winAmount}',
                style: const TextStyle(
                    color: Color(0xFF2DFF8F),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  // ── Lottery ball widget ───────────────────────────────────────────────────
  Widget _buildBall(int number,
      {bool isWinning = false, bool isMatched = false}) {
    Color ballColor;
    if (isMatched)       ballColor = _green;
    else if (isWinning)  ballColor = _gold;
    else                 ballColor = const Color(0xFF6C5CE7);

    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ballColor,
        boxShadow: [
          BoxShadow(
              color: ballColor.withOpacity(0.45),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text('$number',
            style: TextStyle(
                color: (isWinning || isMatched) ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ── Result panel (Fixed Bottom Position for WINS and LOSSES) ──────────────
  Widget _buildResultPanel() {
    final isWin = _justWon;
    final draw  = _currentDraw;

    return SlideTransition(
      position: _resultSlide,
      child: FadeTransition(
        opacity: _resultFade,
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
                top: BorderSide(
                    color: isWin
                        ? _gold.withOpacity(0.8)
                        : _red.withOpacity(0.5),
                    width: 2)),
            boxShadow: [
              BoxShadow(
                  color: isWin
                      ? _gold.withOpacity(0.22)
                      : _red.withOpacity(0.18),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, -8)),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      children: [
                        Container(
                          width: 62, height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              (isWin ? _gold : _red).withOpacity(0.28),
                              Colors.transparent
                            ]),
                            border: Border.all(
                                color: isWin ? _gold : _red, width: 2),
                          ),
                          child: Center(
                              child: Text(isWin ? '🏆' : '😔',
                                  style: const TextStyle(fontSize: 28))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                isWin
                                    ? (_winTicket?.tierLabel ?? 'Winner!')
                                    : 'No match this round',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Winning balls
                    if (draw != null &&
                        draw.winningNumbers.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.07)),
                        ),
                        child: Column(
                          children: [
                            Text('WINNING NUMBERS',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 10,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: draw.winningNumbers
                                  .map<Widget>((n) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        child: _buildBall(n,
                                            isWinning: true),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Stats chip row
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
                          _statChip('DRAW',
                              '#${draw?.drawNumber ?? '--'}', _gold),
                          _statDivider(),
                          _statChip(
                              'MATCHED',
                              '${_winTicket?.matchCount ?? 0}',
                              _green),
                          _statDivider(),
                          if (isWin)
                            AnimatedBuilder(
                              animation: _counterAnim,
                              builder: (_, __) => _statChip('WINNINGS',
                                  '₹${_counterAnim.value}',
                                  Colors.greenAccent),
                            )
                          else
                            _statChip('RESULT', 'No Win', _red),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Players bar
                    if (_statsTotalPlayers > 0) _buildPlayersBar(),
                    const SizedBox(height: 18),

                    // Play Again button
                    GestureDetector(
                      onTap: _dismissResultPanel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: isWin
                                  ? [_gold, _goldDark]
                                  : [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF2563EB),
                                    ]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: (isWin
                                        ? _gold
                                        : const Color(0xFF3B82F6))
                                    .withOpacity(0.38),
                                blurRadius: 16,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Center(
                          child: Text('Continue Playing',
                              style: TextStyle(
                                  color: isWin ? Colors.black : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
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
    );
  }

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
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
        ],
      );

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.1));

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
                    color: Colors.greenAccent.withOpacity(0.8), fontSize: 11)),
            Text('$_statsTotalPlayers players',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 11)),
            Text('$_statsTotalLosers lost',
                style: TextStyle(
                    color: _red.withOpacity(0.8), fontSize: 11)),
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
                      height: 6,
                      color: Colors.greenAccent.withOpacity(0.65))),
              Expanded(
                  flex: (100 - (winPct * 100).round()).clamp(1, 99),
                  child: Container(
                      height: 6, color: _red.withOpacity(0.55))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Felt texture painter ────────────────────────────────
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

// ── Lottery number tile with press animation ───────────────────────────────────
class _LotteryNumberTile extends StatefulWidget {
  final int          number;
  final bool         selected;
  final VoidCallback onTap;

  const _LotteryNumberTile({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LotteryNumberTile> createState() => _LotteryNumberTileState();
}

class _LotteryNumberTileState extends State<_LotteryNumberTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;

    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
                : null,
            color: isSelected ? null : Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFD700)
                  : Colors.white.withOpacity(0.12),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.45),
                        blurRadius: 12)
                  ]
                : [],
          ),
          child: Center(
            child: Text('${widget.number}',
                style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontSize: 14,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}