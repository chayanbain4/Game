// lib/screens/number/number_game_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

import '../../services/user_session.dart';
import '../../config/api_config.dart';
import '../../widgets/engagement/floating_winner_toast.dart';
import '../../widgets/engagement/game_jackpot_banner.dart';
import '../../widgets/engagement/live_chat_overlay.dart';
import '../../widgets/engagement/small_reward_popup.dart';
import '../../widgets/engagement/loss_recovery_popup.dart';

class NumberGameScreen extends StatefulWidget {
  const NumberGameScreen({super.key});

  @override
  State<NumberGameScreen> createState() => _NumberGameScreenState();
}

class _NumberGameScreenState extends State<NumberGameScreen>
    with TickerProviderStateMixin {
  static const Color _bgTableCenter = Color(0xFF0F5132);
  static const Color _bgTableEdge = Color(0xFF062314);
  static const Color _surface = Color(0xFF112A1D);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _goldDark = Color(0xFFB8860B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _textLight = Color(0xFFF0F4FF);

  final AudioPlayer _popPlayer1 = AudioPlayer();
  final AudioPlayer _popPlayer2 = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _usePlayer1 = true;

  int? _selectedNumber;
  int _betCount = 1;
  static const int _betCost = 3;

  int? _result;
  bool _isPlaying = false;
  bool _isSpinning = false;
  bool _isGameOver = false;

  int _spinDisplay = -1;

  int _sessionWins = 0;
  bool _justWon = false;
  int? _lastWinAmount;

  Map<String, dynamic>? _pendingSmallReward;
  Map<String, dynamic>? _pendingLossRecovery;

  final math.Random _random = math.Random();
  int _statsTotalPlayers = 0;
  int _statsTotalWinners = 0;
  int _statsTotalLosers = 0;

  bool _showWinnersBar = false;
  List<Map<String, dynamic>> _recentWinners = [];

  final List<String> _fakeNames = [
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
    'Kavita'
  ];

  Timer? _spinTimer;
  Timer? _fakeWinnerTimer;

  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  late AnimationController _resultCtrl;
  late Animation<Offset> _resultSlide;
  late Animation<double> _resultFade;

  late AnimationController _counterCtrl;
  late Animation<int> _counterAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _sessionWins = UserSession.instance.wins;

    _popPlayer1.setPlayerMode(PlayerMode.lowLatency);
    _popPlayer2.setPlayerMode(PlayerMode.lowLatency);
    _voicePlayer.setPlayerMode(PlayerMode.lowLatency);

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _counterAnim = IntTween(begin: 0, end: 0).animate(_counterCtrl);

    _pageCtrl.forward();
    _startFakeWinnerToasts();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _resultCtrl.dispose();
    _counterCtrl.dispose();
    _spinTimer?.cancel();
    _fakeWinnerTimer?.cancel();
    _popPlayer1.dispose();
    _popPlayer2.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  int get _totalBetAmount => _betCount * _betCost;
  int get _totalWinAmount => _totalBetAmount * 2;

  void _playVoice(String fileName) async {
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource('audio/$fileName'));
    } catch (_) {}
  }

  void _playPopSound() async {
    try {
      final player = _usePlayer1 ? _popPlayer1 : _popPlayer2;
      _usePlayer1 = !_usePlayer1;
      await player.stop();
      await player.play(AssetSource('audio/pop.wav'));
    } catch (_) {}
  }

  void _startFakeWinnerToasts() {
    _fakeWinnerTimer = Timer.periodic(
      Duration(seconds: _random.nextInt(8) + 6),
      (timer) {
        if (!mounted || _isSpinning) return;
      },
    );
  }

  int _maxAffordableBetCount() {
    return (UserSession.instance.balance / _betCost).floor();
  }

  void _chooseNumber(int num) {
    if (_isPlaying || _isSpinning || _isGameOver) return;

    HapticFeedback.lightImpact();

    setState(() {
      if (_selectedNumber == null) {
        _selectedNumber = num;
        _betCount = 1;
        _playVoice('number-select.mp3');
        return;
      }

      if (_selectedNumber != num) {
        _selectedNumber = num;
        _betCount = 1;
        _playVoice('number-select.mp3');
        return;
      }

      final bool hasFreeSpins = UserSession.instance.freeSpins > 0;
      final int maxAffordable = _maxAffordableBetCount();

      if (!hasFreeSpins && _betCount >= maxAffordable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance to add more bets')),
        );
        return;
      }

      _betCount++;
    });
  }

  void _decreaseSelectedNumberBet(int num) {
    if (_isPlaying || _isSpinning || _isGameOver) return;
    if (_selectedNumber != num) return;

    HapticFeedback.selectionClick();

    setState(() {
      if (_betCount > 1) {
        _betCount--;
      } else {
        _selectedNumber = null;
        _betCount = 1;
      }
    });
  }

Future<void> _playGame() async {
  if (_selectedNumber == null || _isPlaying || _isSpinning || _isGameOver) {
    return;
  }

  final bool hasFreeSpins = UserSession.instance.freeSpins > 0;
  final int requestedBetCount = _betCount;

  _playVoice('lets-begin.mp3');

  setState(() {
    _isPlaying = true;
    _result = null;
    _showWinnersBar = false;
    _recentWinners.clear();
  });

  HapticFeedback.mediumImpact();

  try {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/number/play'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': UserSession.instance.email,
            'number': _selectedNumber,
            'betCount': requestedBetCount,
            'useFreeSpins': hasFreeSpins,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (!mounted) return;

    if (response.statusCode != 200) {
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
      return;
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true || body['data'] == null) {
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message'] ?? 'Something went wrong.')),
      );
      return;
    }

    final data = body['data'];

    final int winNumber = data['result'] ?? 0;
    final bool isWin = data['isWin'] == true;
    final int finalBalance = (data['newBalance'] ?? UserSession.instance.balance) as int;
    final int finalFreeSpins = (data['freeSpins'] ?? UserSession.instance.freeSpins) as int;
    final int finalWinAmt = (data['winAmount'] ?? 0) as int;

    Map<String, dynamic>? smallReward;
    Map<String, dynamic>? lossRecovery;

    if (data['smallReward'] != null) {
      smallReward = Map<String, dynamic>.from(data['smallReward']);
    }
    if (data['lossRecovery'] != null) {
      lossRecovery = Map<String, dynamic>.from(data['lossRecovery']);
    }

    UserSession.instance.setBalance(finalBalance);
    UserSession.instance.setFreeSpins(finalFreeSpins);

    if (smallReward != null) _pendingSmallReward = smallReward;
    if (lossRecovery != null) _pendingLossRecovery = lossRecovery;

    final int fakePlayers = 150 + _random.nextInt(400);
    final int fakeWinners = (fakePlayers * 0.1).toInt() + _random.nextInt(10);
    final int fakeLosers = fakePlayers - fakeWinners;

    setState(() {
      _isPlaying = false;
      _lastWinAmount = finalWinAmt;
      _statsTotalPlayers = fakePlayers;
      _statsTotalWinners = fakeWinners;
      _statsTotalLosers = fakeLosers;
    });

    _startSpinAnimation(winNumber, isWin);
  } on TimeoutException {
    if (mounted) {
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
  }
}

  void _showSmallReward(Map<String, dynamic> reward) {
    SmallRewardPopup.show(context, reward);
  }

  void _showLossRecovery(Map<String, dynamic> recovery) {
    LossRecoveryPopup.show(context, recovery);
  }

  void _startSpinAnimation(int targetNumber, bool isWin) {
    setState(() => _isSpinning = true);

    int tick = 0;

    _spinTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      tick++;
      setState(() => _spinDisplay = _random.nextInt(10));
      HapticFeedback.selectionClick();
      _playPopSound();

      if (tick >= 10) {
        timer.cancel();
        _onSpinComplete(targetNumber, isWin);
      }
    });
  }

  void _onSpinComplete(int winNumber, bool isWin) async {
    if (isWin) {
      _sessionWins++;
      await UserSession.instance.setWins(_sessionWins);
      HapticFeedback.heavyImpact();
    }

    List<Map<String, dynamic>> newWinners = [];
    final int displayCount = math.min(15, _statsTotalWinners);

    if (isWin) {
      newWinners.add({
        'name': UserSession.instance.name ?? 'You',
        'amount': _lastWinAmount ?? _betCost,
        'isMe': true,
      });
    }

    for (int i = 0; i < displayCount; i++) {
      final baseName = _fakeNames[_random.nextInt(_fakeNames.length)];
      final fakeBets = _random.nextInt(5) + 1;
      final randomWin = fakeBets * _betCost * 2;
      newWinners.add({
        'name': '${baseName}${_random.nextInt(99)}',
        'amount': randomWin,
        'isMe': false,
      });
    }

    setState(() {
      _result = winNumber;
      _justWon = isWin;
      _isSpinning = false;
      _spinDisplay = -1;
      _isGameOver = true;
      _recentWinners = newWinners;
      _showWinnersBar = true;
    });

    _resultCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (_pendingSmallReward != null) {
      _showSmallReward(_pendingSmallReward!);
      _pendingSmallReward = null;
    }
    if (_pendingLossRecovery != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _showLossRecovery(_pendingLossRecovery!);
      _pendingLossRecovery = null;
    }
    if (isWin) {
      final win = _lastWinAmount ?? 0;
      _counterAnim = IntTween(begin: 0, end: win).animate(
        CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOut),
      );
      _counterCtrl.forward(from: 0);
    }
  }

  void _resetGame() {
    _resultCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _isGameOver = false;
        _result = null;
        _selectedNumber = null;
        _betCount = 1;
      });
    });
  }

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
                        _buildRecentWinnersBar(),
                        GameJackpotBanner(),
                        const SizedBox(height: 12),
                        _buildStatusHeader(),
                        const SizedBox(height: 24),
                        _buildNumberGrid(),
                        const SizedBox(height: 24),
                        _buildHotColdIndicators(),
                        const Spacer(),
                        _buildPlayButton(),
                        const SizedBox(height: 80),
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
                child: SizedBox(
                  height: 220,
                  child: const LiveChatOverlay(),
                ),
              ),
              if (_isGameOver) _buildModernResultPanel(),
              const FloatingWinnerToast(),
            ],
          ),
        ),
      ),
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
              'Number Game',
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

  Widget _buildRecentWinnersBar() {
    if (!_showWinnersBar || _recentWinners.isEmpty) {
      return const SizedBox(height: 42, child: Center());
    }

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentWinners.length,
        itemBuilder: (context, i) {
          final winner = _recentWinners[i];
          final isMe = winner['isMe'] == true;
          final name = winner['name'].toString();
          final amt = winner['amount'];
          final bgColor =
              isMe ? Colors.green.withOpacity(0.3) : Colors.black.withOpacity(0.3);
          final borderColor =
              isMe ? Colors.greenAccent.withOpacity(0.5) : _gold.withOpacity(0.15);
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
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: avatarTextCol,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSpinning)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'SHUFFLING...',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            )
          else
            Text(
              _isGameOver
                  ? 'ROUND OVER'
                  : _selectedNumber == null
                      ? 'SELECT YOUR NUMBER'
                      : 'NUMBER $_selectedNumber  •  $_betCount BET${_betCount > 1 ? "S" : ""}  •  ₹$_totalBetAmount',
              style: const TextStyle(
                color: _gold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHotColdIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
            _statIndicator('HOT 🔥', '4, 8', Colors.orangeAccent),
            Container(width: 1, height: 24, color: Colors.white12),
            _statIndicator('COLD ❄️', '2, 9', Colors.cyanAccent),
            Container(width: 1, height: 24, color: Colors.white12),
            _statIndicator('LAST 🎯', '${_result ?? "?"}', _gold),
          ],
        ),
      ),
    );
  }

  Widget _statIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: IgnorePointer(
        ignoring: _isPlaying || _isSpinning || _isGameOver,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: (_isGameOver && !_justWon) ? 0.6 : 1.0,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 10,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (_, i) => _CasinoGridTile(
              number: i,
              selected: _isSpinning ? false : _selectedNumber == i,
              winner: _result == i,
              isSpinHighlight: _isSpinning && _spinDisplay == i,
              betCount: (_selectedNumber == i && !_isGameOver) ? _betCount : 0,
              onTap: () => _chooseNumber(i),
              onLongPress: () => _decreaseSelectedNumberBet(i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    final canPlay =
        _selectedNumber != null && !_isPlaying && !_isSpinning && !_isGameOver;
    final hasFreeSpins = UserSession.instance.freeSpins > 0;
    final totalBet = hasFreeSpins ? 0 : _totalBetAmount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: canPlay ? _playGame : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canPlay ? [_gold, _goldDark] : [_surface, _surface],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canPlay
                ? [
                    BoxShadow(
                      color: _gold.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ]
                : null,
            border: Border.all(
              color: canPlay ? _gold : Colors.white.withOpacity(0.1),
              width: canPlay ? 0 : 1,
            ),
          ),
          child: Center(
            child: _isPlaying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PLAY NOW',
                        style: TextStyle(
                          color: canPlay
                              ? Colors.black
                              : Colors.white.withOpacity(0.3),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (canPlay) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasFreeSpins ? 'FREE' : '₹$totalBet',
                            style: TextStyle(
                              color: hasFreeSpins
                                  ? Colors.green.shade800
                                  : Colors.black87,
                              fontSize: 13,
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

  Widget _buildModernResultPanel() {
    final isWin = _justWon;
    final totalDeducted = _betCount * _betCost;

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
                                  'Winning number was $_result',
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
                              'YOUR BET',
                              '${_selectedNumber ?? "--"}  ×${_betCount}',
                              isWin ? _gold : const Color(0xFFA0B5A8),
                            ),
                            _statDivider(),
                            _statChip(
                              'RESULT',
                              _result?.toString() ?? '--',
                              const Color(0xFF4ADE80),
                            ),
                            _statDivider(),
                            if (isWin)
                              AnimatedBuilder(
                                animation: _counterAnim,
                                builder: (_, __) => _statChip(
                                  'WINNINGS',
                                  '+₹${_counterAnim.value}',
                                  Colors.greenAccent,
                                ),
                              )
                            else
                              _statChip('LOST', '-₹$totalDeducted', _red),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_statsTotalPlayers > 0) _buildPlayersBar(),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _resetGame,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isWin
                                  ? [_gold, _goldDark]
                                  : [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF2563EB)
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
                              'Play Again',
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.1));

  Widget _buildPlayersBar() {
    final winPct =
        _statsTotalPlayers > 0 ? _statsTotalWinners / _statsTotalPlayers : 0.0;
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

class _CasinoGridTile extends StatefulWidget {
  final int number;
  final bool selected;
  final bool winner;
  final bool isSpinHighlight;
  final int betCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CasinoGridTile({
    required this.number,
    required this.selected,
    required this.winner,
    this.isSpinHighlight = false,
    this.betCount = 0,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_CasinoGridTile> createState() => _CasinoGridTileState();
}

class _CasinoGridTileState extends State<_CasinoGridTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;
    final isWinner = widget.winner;
    final isHighlight = widget.isSpinHighlight;

    Color borderColor;
    Color bgColor;
    Color textColor;

    if (isWinner) {
      borderColor = Colors.greenAccent;
      bgColor = Colors.green.withOpacity(0.35);
      textColor = Colors.greenAccent;
    } else if (isHighlight) {
      borderColor = const Color(0xFFFFD700);
      bgColor = const Color(0xFFFFD700).withOpacity(0.4);
      textColor = Colors.white;
    } else if (isSelected) {
      borderColor = const Color(0xFFFFD700);
      bgColor = const Color(0xFFFFD700).withOpacity(0.15);
      textColor = const Color(0xFFFFD700);
    } else {
      borderColor = Colors.white.withOpacity(0.15);
      bgColor = Colors.black.withOpacity(0.3);
      textColor = Colors.white70;
    }

    final hasGlow = isWinner || isHighlight || isSelected;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: hasGlow ? 2.5 : 1),
            boxShadow: hasGlow
                ? [
                    BoxShadow(
                      color: borderColor.withOpacity(0.5),
                      blurRadius: 12,
                    )
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '${widget.number}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isSelected && !isWinner && !isHighlight && widget.betCount <= 1)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFFFD700),
                    size: 14,
                  ),
                ),
              if (isSelected && !isWinner && !isHighlight && widget.betCount > 1)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${widget.betCount}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
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