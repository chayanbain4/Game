// lib/screens/scratch/scratch_game_screen.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_session.dart';
import '../../services/scratch_service.dart';
import '../../models/scratch/scratch_result_model.dart';
import '../../widgets/engagement/floating_winner_toast.dart';
import '../../widgets/engagement/small_reward_popup.dart';
import '../../widgets/engagement/loss_recovery_popup.dart';
import '../../widgets/engagement/game_jackpot_banner.dart';
import '../../widgets/engagement/live_chat_overlay.dart';

class ScratchGameScreen extends StatefulWidget {
  const ScratchGameScreen({super.key});

  @override
  State<ScratchGameScreen> createState() => _ScratchGameScreenState();
}

class _ScratchGameScreenState extends State<ScratchGameScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ────────────────────────────────────────────────────────
  static const Color _bgCenter = Color(0xFF0F5132);
  static const Color _bgEdge = Color(0xFF062314);
  static const Color _surface = Color(0xFF112A1D);
  static const Color _card = Color(0xFF0D2118);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _goldDark = Color(0xFFB8860B);
  static const Color _accent = Color(0xFFFF9F43);
  static const Color _green = Color(0xFF2DFF8F);
  static const Color _red = Color(0xFFEF4444);
  static const Color _textLight = Color(0xFFF0F4FF);
  static const Color _textMid = Color(0xFF7FA8A4);

  // ── Symbol config ────────────────────────────────────────────────────────
  static const Map<String, List<dynamic>> _symbols = {
    'cherry': ['🍒', Color(0xFFE8534A)],
    'lemon': ['🍋', Color(0xFFFFD166)],
    'orange': ['🍊', Color(0xFFFF9F43)],
    'bell': ['🔔', Color(0xFFFFD166)],
    'star': ['⭐', Color(0xFFFFD700)],
    'diamond': ['💎', Color(0xFF4ECDC4)],
  };

  final _random = Random();

  // ── Audio ────────────────────────────────────────────────────────────────
  final AudioPlayer _scratchPlayer1 = AudioPlayer();
  final AudioPlayer _scratchPlayer2 = AudioPlayer();
  final AudioPlayer _scratchPlayer3 = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  int _scratchPoolIdx = 0;

  final _fakeNames = [
    'Rahul',
    'Priya',
    'Amit',
    'Neha',
    'Vikas',
    'Karan',
    'Sneha',
    'Ravi',
    'Pooja',
    'Sunil',
    'Anita',
    'Deepak',
    'Roshni',
    'Sanjay',
    'Kavita',
  ];

  bool _showWinnersBar = false;
  List<Map<String, dynamic>> _recentWinners = [];

  // ── Live fake activity ───────────────────────────────────────────────────
  int _liveCount = 0;
  String _activityMsg = '';
  bool _showActivity = false;

  // ── Game state ───────────────────────────────────────────────────────────
  final _scratchService = ScratchService();
  Timer? _activityTimer;
  bool _isPlaying = false;
  static bool _isRevealing = false;
  static ScratchResultModel? _currentResult;
  static List<bool> _revealed = List.filled(9, false);

  int _selectedMultiplier = 1;

  Map<String, dynamic>? _pendingReward;
  Map<String, dynamic>? _pendingRecovery;
  int? _lastWinAmount;

  static int _statsTotalPlayers = 0;
  static int _statsTotalWinners = 0;
  static int _statsTotalLosers = 0;

  // prevent repeated sound spam while dragging
  int? _lastDraggedCellIndex;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  late AnimationController _resultCtrl;
  late Animation<Offset> _resultSlide;
  late Animation<double> _resultFade;

  late AnimationController _shimmerCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic),
    );

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic),
    );
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _scratchPlayer1.setPlayerMode(PlayerMode.lowLatency);
    _scratchPlayer2.setPlayerMode(PlayerMode.lowLatency);
    _scratchPlayer3.setPlayerMode(PlayerMode.lowLatency);
    _voicePlayer.setPlayerMode(PlayerMode.lowLatency);

    _pageCtrl.forward();
    _liveCount = 180 + _random.nextInt(320);
    _startActivityTicker();
  }

  void _playScratchSound() async {
    try {
      final players = [_scratchPlayer1, _scratchPlayer2, _scratchPlayer3];
      final p = players[_scratchPoolIdx % 3];
      _scratchPoolIdx++;
      await p.stop();
      await p.play(AssetSource('audio/scratch.mp3'));
    } catch (_) {}
  }

  void _playVoice(String file) async {
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource('audio/$file'));
    } catch (_) {}
  }

  void _startActivityTicker() {
    _activityTimer = Timer.periodic(
      Duration(seconds: 9 + _random.nextInt(6)),
      (_) {
        if (!mounted || _isPlaying || _isRevealing) return;
        final name = _fakeNames[_random.nextInt(_fakeNames.length)];
        final possibleAmounts = [10, 20, 25, 40, 50];
        final amount = possibleAmounts[_random.nextInt(possibleAmounts.length)];
        final delta = _random.nextBool() ? 1 : -1;

        setState(() {
          _liveCount =
              (_liveCount + delta * (_random.nextInt(5) + 1)).clamp(150, 600);
          _activityMsg = '$name just won ₹$amount 🎉';
          _showActivity = true;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showActivity = false);
        });
      },
    );
  }

  @override
  void dispose() {
    if (_isRevealing && _currentResult != null) {
      _revealed = List.filled(9, true);
      _isRevealing = false;
    }
    _pageCtrl.dispose();
    _resultCtrl.dispose();
    _activityTimer?.cancel();
    _scratchPlayer1.dispose();
    _scratchPlayer2.dispose();
    _scratchPlayer3.dispose();
    _voicePlayer.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Play logic ───────────────────────────────────────────────────────────
  Future<void> _playScratch() async {
    if (_isPlaying || _isRevealing) return;

    final userId = UserSession.instance.email ?? '';
    final username = UserSession.instance.name ?? 'Player';
    if (userId.isEmpty) return;

    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    final cost = 5 * _selectedMultiplier;

    if (!hasFreeSpins && UserSession.instance.balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Need ₹$cost, have ₹${UserSession.instance.balance}',
          ),
        ),
      );
      return;
    }

    _playVoice('lets-begin.mp3');

    setState(() {
      _isPlaying = true;
      _currentResult = null;
      _revealed = List.filled(9, false);
      _isRevealing = false;
      _showWinnersBar = false;
      _recentWinners.clear();
      _resultCtrl.reset();
      _lastDraggedCellIndex = null;
    });

    final response = await _scratchService.play(
      userId,
      username,
      useFreeSpins: hasFreeSpins,
      multiplier: _selectedMultiplier,
    );

    if (!mounted) return;

    if (response == null) {
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get scratch card. Try again.')),
      );
      return;
    }

    if (response.newBalance != null) {
      UserSession.instance.setBalance(response.newBalance!);
    }
    if (response.freeSpins != null) {
      UserSession.instance.setFreeSpins(response.freeSpins!);
    }
    if (response.newWinCount != null) {
      UserSession.instance.setWins(response.newWinCount!);
    }

    setState(() {
      _currentResult = response.result;
      _isPlaying = false;
      _isRevealing = true;
      _lastWinAmount = response.winAmount ?? 0;
      _statsTotalPlayers = response.totalPlayers;
      _statsTotalWinners = response.totalWinners;
      _statsTotalLosers = response.totalLosers;
    });

    if (response.reward != null) _pendingReward = response.reward;
    if (response.recovery != null) _pendingRecovery = response.recovery;
  }

  void _revealCell(int index) {
    if (!_isRevealing || _currentResult == null || _revealed[index]) return;

    HapticFeedback.selectionClick();
    _playScratchSound();

    setState(() {
      _revealed[index] = true;
    });

    if (_revealed.every((r) => r)) {
      _onAllRevealed();
    }
  }

  void _handleScratchAtPosition(Offset localPosition, Size size) {
    if (!_isRevealing || _currentResult == null) return;

    const crossAxisSpacing = 10.0;
    const mainAxisSpacing = 10.0;
    const count = 3;

    final cellWidth = (size.width - (crossAxisSpacing * (count - 1))) / count;
    final cellHeight = (size.height - (mainAxisSpacing * (count - 1))) / count;

    final dx = localPosition.dx;
    final dy = localPosition.dy;

    if (dx < 0 || dy < 0 || dx > size.width || dy > size.height) return;

    final col = dx ~/ (cellWidth + crossAxisSpacing);
    final row = dy ~/ (cellHeight + mainAxisSpacing);

    if (col < 0 || col >= 3 || row < 0 || row >= 3) return;

    final localXInBlock = dx - (col * (cellWidth + crossAxisSpacing));
    final localYInBlock = dy - (row * (cellHeight + mainAxisSpacing));

    if (localXInBlock > cellWidth || localYInBlock > cellHeight) return;

    final index = row * 3 + col;

    if (_lastDraggedCellIndex == index) return;
    _lastDraggedCellIndex = index;

    _revealCell(index);
  }

  void _onAllRevealed() {
    _isRevealing = false;
    _lastDraggedCellIndex = null;
    if (!mounted) return;

    final List<Map<String, dynamic>> winners = [];
    final fakeCount = 5 + _random.nextInt(7);
    final possibleAmounts = [10, 20, 25, 40, 50];

    for (int i = 0; i < fakeCount; i++) {
      winners.add({
        'name':
            '${_fakeNames[_random.nextInt(_fakeNames.length)]}${_random.nextInt(99)}',
        'amount': possibleAmounts[_random.nextInt(possibleAmounts.length)],
        'isMe': false,
      });
    }

    if (_currentResult!.isWin) {
      HapticFeedback.heavyImpact();
      winners.insert(0, {
        'name': UserSession.instance.name ?? 'You',
        'amount': _lastWinAmount ?? 0,
        'isMe': true,
      });
    }

    setState(() {
      _showWinnersBar = true;
      _recentWinners = winners;
    });

    _resultCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_pendingReward != null) {
        SmallRewardPopup.show(context, _pendingReward!);
        _pendingReward = null;
      }
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (_pendingRecovery != null) {
        LossRecoveryPopup.show(context, _pendingRecovery!);
        _pendingRecovery = null;
      }
    });
  }

  void _resetGame() {
    _resultCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _currentResult = null;
        _revealed = List.filled(9, false);
        _lastDraggedCellIndex = null;
      });
    });
  }

  bool get _isDone =>
      _currentResult != null && _revealed.every((r) => r) && !_isRevealing;

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
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                            child: Column(
                              children: [
                                _buildStatusHeader(),
                                const SizedBox(height: 14),
                                _buildMultiplierSelector(),
                                const SizedBox(height: 18),
                                _buildScratchCard(),
                                const SizedBox(height: 20),
                                _buildPlayButton(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutQuad,
                left: 12,
                right: 12,
                bottom: bottomInset > 0 ? bottomInset + 8 : 16,
                height: 220,
                child: const LiveChatOverlay(),
              ),
              if (_isDone) _buildResultPanel(),
              const FloatingWinnerToast(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplierSelector() {
    final multipliers = [1, 2, 5, 10];
    final canChange = !_isPlaying && !_isRevealing && _currentResult == null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: multipliers.map((m) {
        final isSelected = _selectedMultiplier == m;
        return GestureDetector(
          onTap: canChange ? () => setState(() => _selectedMultiplier = m) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? _gold : Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _goldDark : Colors.white.withOpacity(0.15),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: _gold.withOpacity(0.4), blurRadius: 8)]
                  : [],
            ),
            child: Text(
              '${m}x',
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: _textLight,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Scratch & Win',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textLight,
                fontSize: 20,
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnersBar() {
    if (!_showWinnersBar || _recentWinners.isEmpty) {
      return const SizedBox(height: 42);
    }

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentWinners.length,
        itemBuilder: (_, i) {
          final w = _recentWinners[i];
          final isMe = w['isMe'] == true;
          final name = w['name'].toString();
          final amt = w['amount'];

          return Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.green.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMe
                    ? Colors.greenAccent.withOpacity(0.5)
                    : _gold.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isMe
                      ? Colors.greenAccent
                      : Colors.primaries[i % Colors.primaries.length].shade700,
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: isMe ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isMe ? 'You' : name,
                  style: TextStyle(
                    color: isMe ? Colors.greenAccent : Colors.white70,
                    fontSize: 12,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '+₹$amt',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader() {
    String label;
    if (_isPlaying) {
      label = 'GETTING CARD...';
    } else if (_isRevealing) {
      label = 'SCRATCH MANUALLY';
    } else if (_isDone) {
      label = 'ROUND OVER';
    } else {
      label = 'SELECT BET & GET CARD';
    }

    return Text(
      label,
      style: const TextStyle(
        color: _gold,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildScratchCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            _gold.withOpacity(0.7),
            _goldDark.withOpacity(0.3),
            _gold.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🃏', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_gold, Color(0xFFFFF176), _gold],
                  ).createShader(b),
                  child: const Text(
                    'SCRATCH CARD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('🃏', style: TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isRevealing
                  ? 'Drag or tap on boxes to scratch'
                  : 'Match 3 symbols to win!',
              style: TextStyle(
                color: _textMid,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            AspectRatio(
              aspectRatio: 1.05,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridSize =
                      Size(constraints.maxWidth, constraints.maxHeight);

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: _isRevealing
                        ? (details) => _handleScratchAtPosition(
                              details.localPosition,
                              gridSize,
                            )
                        : null,
                    onPanStart: _isRevealing
                        ? (details) => _handleScratchAtPosition(
                              details.localPosition,
                              gridSize,
                            )
                        : null,
                    onPanUpdate: _isRevealing
                        ? (details) => _handleScratchAtPosition(
                              details.localPosition,
                              gridSize,
                            )
                        : null,
                    onPanEnd: (_) => _lastDraggedCellIndex = null,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 9,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.05,
                      ),
                      itemBuilder: (_, i) => _buildCell(i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    return _ScratchCell(
      key: ValueKey('cell_$index'),
      index: index,
      hasResult: _currentResult != null,
      isRevealed: _revealed[index],
      isMatch: _isMatchingSymbol(index),
      isWin: _currentResult?.isWin == true,
      symbol: _currentResult != null ? _currentResult!.cells[index] : '',
      symbols: _symbols,
      shimmerCtrl: _shimmerCtrl,
      onTap: () => _revealCell(index),
    );
  }

  bool _isMatchingSymbol(int index) {
    if (_currentResult == null || !_currentResult!.isWin) return false;
    return _currentResult!.cells[index] == _currentResult!.symbol;
  }

  Widget _buildPlayButton() {
    final canTap = !_isPlaying && !_isRevealing;
    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    final label = _isDone ? 'New Card' : 'Get Scratch Card';
    final currentCost = 5 * _selectedMultiplier;

    return ScaleTransition(
      scale: (!_isPlaying && !_isRevealing && _currentResult == null)
          ? _pulse
          : const AlwaysStoppedAnimation(1.0),
      child: GestureDetector(
        onTap: canTap ? (_isDone ? _resetGame : _playScratch) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canTap ? [_gold, _goldDark] : [_surface, _surface],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canTap
                ? [
                    BoxShadow(
                      color: _gold.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
            border: Border.all(
              color: canTap ? _gold : Colors.white.withOpacity(0.08),
              width: canTap ? 0 : 1,
            ),
          ),
          child: Center(
            child: _isPlaying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      strokeWidth: 2.0,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🎰  $label',
                        style: TextStyle(
                          color: canTap ? Colors.black : Colors.white30,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (canTap) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasFreeSpins ? 'FREE' : '₹$currentCost',
                            style: TextStyle(
                              color: hasFreeSpins
                                  ? Colors.green.shade800
                                  : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final isWin = _currentResult!.isWin;
    final winAmt = _lastWinAmount ?? 0;
    final totalDeducted = 5 * _selectedMultiplier;

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isWin
                      ? _gold.withOpacity(0.8)
                      : _red.withOpacity(0.5),
                  width: 2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: isWin
                      ? _gold.withOpacity(0.22)
                      : _red.withOpacity(0.18),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
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
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isWin ? _gold : _red).withOpacity(0.28),
                                  Colors.transparent
                                ],
                              ),
                              border: Border.all(
                                color: isWin ? _gold : _red,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isWin ? '🏆' : '😔',
                                style: const TextStyle(fontSize: 28),
                              ),
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
                                    color: isWin ? _gold : _red,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isWin
                                      ? '${_currentResult!.matchCount}× ${(_symbols[_currentResult!.symbol]?[0] as String?) ?? ''} matched!'
                                      : 'No match this round',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statChip(
                              'CARD COST',
                              '-₹$totalDeducted',
                              _red.withOpacity(0.8),
                            ),
                            _statDivider(),
                            _statChip(
                              'SYMBOL',
                              isWin
                                  ? ((_symbols[_currentResult!.symbol]?[0]
                                              as String?) ??
                                          '?')
                                  : '—',
                              const Color(0xFF4ADE80),
                            ),
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
                      if (_statsTotalPlayers > 0) _buildPlayersBar(),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () {
                          _resultCtrl.reverse().then((_) {
                            if (!mounted) return;
                            setState(() {
                              _currentResult = null;
                              _revealed = List.filled(9, false);
                              _lastDraggedCellIndex = null;
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isWin
                                  ? [_gold, _goldDark]
                                  : const [
                                      Color(0xFF3B82F6),
                                      Color(0xFF2563EB)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (isWin ? _gold : const Color(0xFF3B82F6))
                                    .withOpacity(0.38),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '🎰  New Card',
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

  Widget _statChip(String label, String value, Color valueColor) => Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
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
            Text(
              '$_statsTotalWinners won',
              style: TextStyle(
                color: Colors.greenAccent.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
            Text(
              '$_statsTotalPlayers players',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
              ),
            ),
            Text(
              '$_statsTotalLosers lost',
              style: TextStyle(
                color: _red.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
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
                  color: Colors.greenAccent.withOpacity(0.65),
                ),
              ),
              Expanded(
                flex: (100 - (winPct * 100).round()).clamp(1, 99),
                child: Container(
                  height: 6,
                  color: _red.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScratchCell extends StatefulWidget {
  final int index;
  final bool hasResult;
  final bool isRevealed;
  final bool isMatch;
  final bool isWin;
  final String symbol;
  final Map<String, List<dynamic>> symbols;
  final AnimationController shimmerCtrl;
  final VoidCallback onTap;

  const _ScratchCell({
    required Key key,
    required this.index,
    required this.hasResult,
    required this.isRevealed,
    required this.isMatch,
    required this.isWin,
    required this.symbol,
    required this.symbols,
    required this.shimmerCtrl,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_ScratchCell> createState() => _ScratchCellState();
}

class _ScratchCellState extends State<_ScratchCell>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFFFD700);
  static const Color _accent = Color(0xFFFF9F43);

  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  bool _prevRevealed = false;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeOutCubic),
    );
    if (widget.isRevealed) {
      _flipCtrl.value = 1.0;
      _prevRevealed = true;
    }
  }

  @override
  void didUpdateWidget(_ScratchCell old) {
    super.didUpdateWidget(old);
    if (!_prevRevealed && widget.isRevealed) {
      _prevRevealed = true;
      _flipCtrl.forward(from: 0);
    }
    if (_prevRevealed && !widget.isRevealed) {
      _prevRevealed = false;
      _flipCtrl.reset();
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMatch = widget.isMatch && widget.isWin;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (_, __) {
          final t = _flipAnim.value;
          final showFront = t > 0.5;
          final angle = showFront ? (1.0 - t) * pi : t * pi;

          final scaleYCurved = showFront
              ? Curves.elasticOut.transform(((t - 0.5) * 2).clamp(0.0, 1.0))
              : 1.0;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(showFront ? 0 : angle)
              ..scale(1.0, showFront ? scaleYCurved : 1.0, 1.0),
            child: showFront ? _buildFront(isMatch) : _buildBack(),
          );
        },
      ),
    );
  }

  Widget _buildBack() {
    final hasResult = widget.hasResult;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: hasResult
            ? _accent.withOpacity(0.1)
            : Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasResult
              ? _accent.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
          width: 1.2,
        ),
      ),
      child: Center(
        child: hasResult
            ? AnimatedBuilder(
                animation: widget.shimmerCtrl,
                builder: (_, __) => Icon(
                  Icons.auto_awesome_rounded,
                  color: _accent.withOpacity(
                    0.3 + 0.3 * sin(widget.shimmerCtrl.value * 2 * pi),
                  ),
                  size: 30,
                ),
              )
            : Icon(
                Icons.casino_rounded,
                color: Colors.white.withOpacity(0.1),
                size: 26,
              ),
      ),
    );
  }

  Widget _buildFront(bool isMatch) {
    final emoji = (widget.symbols[widget.symbol]?[0] as String?) ?? '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isMatch
            ? _gold.withOpacity(0.18)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMatch ? _gold : Colors.white.withOpacity(0.08),
          width: isMatch ? 2.0 : 1.0,
        ),
        boxShadow: isMatch
            ? [
                BoxShadow(
                  color: _gold.withOpacity(0.45),
                  blurRadius: 20,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Center(
        child: isMatch
            ? _GlowingSymbol(emoji: emoji)
            : Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

class _GlowingSymbol extends StatefulWidget {
  final String emoji;
  const _GlowingSymbol({required this.emoji});

  @override
  State<_GlowingSymbol> createState() => _GlowingSymbolState();
}

class _GlowingSymbolState extends State<_GlowingSymbol>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounce = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounce,
      child: Text(widget.emoji, style: const TextStyle(fontSize: 34)),
    );
  }
}

class _FeltPainter extends CustomPainter {
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
  bool shouldRepaint(_FeltPainter oldDelegate) => false;
}