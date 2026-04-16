// lib/screens/ludo/ludo_board_screen.dart
//
// pubspec.yaml — add under dependencies:
//   audioplayers: ^6.1.0
//
// pubspec.yaml — add under flutter › assets:
//   - assets/audio/ludo.mp3          ← dice spin sound (short 0:01s)
//   - assets/audio/lets-begin.mp3    ← game start sound

import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/ludo/game_provider.dart';
import '../../services/user_session.dart';
import '../../core/socket/socket_service.dart';
import '../../widgets/engagement/floating_winner_toast.dart';

class LudoBoardScreen extends StatefulWidget {
  final String roomCode;
  final String userId;
  const LudoBoardScreen({
    super.key,
    required this.roomCode,
    required this.userId,
  });

  @override
  State<LudoBoardScreen> createState() => _LudoBoardScreenState();
}

class _LudoBoardScreenState extends State<LudoBoardScreen>
    with TickerProviderStateMixin {

  // ── Audio — two players so my roll and opp roll never cut each other ───────
  final AudioPlayer _sfxMe      = AudioPlayer();   // my dice spin
  final AudioPlayer _sfxOpp     = AudioPlayer();   // opponent dice spin
  final AudioPlayer _sfxStart   = AudioPlayer();   // lets-begin
  bool _startSoundPlayed        = false;

  // ── Step-by-step token animation ─────────────────────────────────────────
  // _animTokens  = what the board renders right now (moves 1 step at a time)
  // _committed   = last positions received from the server
  Map<String, List<int>> _animTokens = {
    'red':[0,0,0,0],'blue':[0,0,0,0],'green':[0,0,0,0],'yellow':[0,0,0,0],
  };
  Map<String, List<int>> _committed = {
    'red':[0,0,0,0],'blue':[0,0,0,0],'green':[0,0,0,0],'yellow':[0,0,0,0],
  };
  String? _movingColor;
  int     _movingIdx   = -1;

  // ── My dice (spinning circle animation) ──────────────────────────────────
  late AnimationController _mySpinCtrl;   // full 360° spin while rolling
  late AnimationController _dicePopCtrl;
  late Animation<double>   _mySpinAnim;
  late Animation<double>   _dicePopAnim;
  int  _myDiceValue   = 0;   // shown on dice face
  bool _isRolling      = false;
  int  _rollingForTurn = -1;
  int  _pendingDice    = 0;          // server result buffered while min-spin runs
  int  _rollStartMs    = 0;          // when the spin started (epoch ms)
  static const int _minSpinMs = 1000; // spin for at least 1 s (matches sound)
  bool _tokenMovePending = false;    // true while waiting for opp dice to finish
  final _rng           = Random();

  // ── Opponent dice ─────────────────────────────────────────────────────────
  late AnimationController _oppSpinCtrl;
  late Animation<double>   _oppSpinAnim;
  bool _oppIsRolling    = false;
  int  _oppDiceValue    = 0;
  int  _oppRollingTurn  = -1;
  // Track dice value changes to detect bot rolls independent of turn state
  int  _lastSeenDice    = 0;   // last p.dice value we processed
  bool _oppRollQueued   = false; // queued while my spin is still running

  // ── Token pulse (can-move glow) / bounce (landed) ─────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _bounceCtrl;
  late Animation<double>   _bounceAnim;
  String? _lastMovedKey;

  // ── Board constants ────────────────────────────────────────────────────────
  static const Map<String, int> _startCell = {
    'red':1,'blue':14,'green':27,'yellow':40,
  };

  static const List<List<int>> boardPath = [
    [6,1],[6,2],[6,3],[6,4],[6,5],
    [5,6],[4,6],[3,6],[2,6],[1,6],[0,6],[0,7],[0,8],
    [1,8],[2,8],[3,8],[4,8],[5,8],
    [6,9],[6,10],[6,11],[6,12],[6,13],[6,14],[7,14],[8,14],
    [8,13],[8,12],[8,11],[8,10],[8,9],
    [9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[14,7],[14,6],
    [13,6],[12,6],[11,6],[10,6],[9,6],
    [8,5],[8,4],[8,3],[8,2],[8,1],[8,0],[6,0],[7,0],
  ];  // [7,0] is now pos-52: token enters home col [7,1] as one step right

  static const Map<String, List<List<int>>> basePos = {
    'red':   [[1,1],[1,3],[3,1],[3,3]],
    'blue':  [[1,11],[1,13],[3,11],[3,13]],
    'green': [[11,11],[11,13],[13,11],[13,13]],
    'yellow':[[11,1],[11,3],[13,1],[13,3]],
  };

  static const Map<String, List<List<int>>> homeCols = {
    'red':   [[7,1],[7,2],[7,3],[7,4],[7,5]],
    'blue':  [[1,7],[2,7],[3,7],[4,7],[5,7]],
    'green': [[7,13],[7,12],[7,11],[7,10],[7,9]],
    'yellow':[[13,7],[12,7],[11,7],[10,7],[9,7]],
  };

  static const List<int> safeCells = [1, 9, 14, 22, 27, 35, 40, 48];

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFF07071A);

  static const Map<String,Color> cMap = {
    'red':    Color(0xFFFF4444),
    'blue':   Color(0xFF3DA9FF),
    'green':  Color(0xFF2DFF8F),
    'yellow': Color(0xFFFFD93D),
  };
  static const Map<String,Color> cLight = {
    'red':    Color(0xFFFF9999),
    'blue':   Color(0xFF99D6FF),
    'green':  Color(0xFF99FFCC),
    'yellow': Color(0xFFFFED99),
  };
  static const Map<String,Color> cDeep = {
    'red':    Color(0xFF3A0000),
    'blue':   Color(0xFF002040),
    'green':  Color(0xFF003A1A),
    'yellow': Color(0xFF3A2800),
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // My spinning dice
    _mySpinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _mySpinAnim = Tween<double>(begin: 0.0, end: 2 * pi)
        .animate(CurvedAnimation(parent: _mySpinCtrl, curve: Curves.linear));

    // Opponent spinning dice
    _oppSpinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _oppSpinAnim = Tween<double>(begin: 0.0, end: 2 * pi)
        .animate(CurvedAnimation(parent: _oppSpinCtrl, curve: Curves.linear));

    // Pop when dice lands
    _dicePopCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _dicePopAnim =
        CurvedAnimation(parent: _dicePopCtrl, curve: Curves.elasticOut);

    // Pulse for movable tokens
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.82, end: 1.18)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Bounce when token lands
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.82), weight: 36),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.0),  weight: 34),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  bool _listenerAdded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAdded) {
      _listenerAdded = true;
      context.read<GameProvider>().addListener(_onProviderChange);
    }
  }

  // ── Provider listener ──────────────────────────────────────────────────────
  void _onProviderChange() {
    if (!mounted) return;
    final p = context.read<GameProvider>();

    // ── Game just started ────────────────────────────────────────────────────
    if (p.gameStarted && !_startSoundPlayed) {
      _startSoundPlayed = true;
      _syncAnimTokens(p);
      _playSoundStart();
    }

    // ── Kill lingering opp animation when MY turn arrives ────────────────────
    if (p.myTurn && (_oppIsRolling || _oppRollingTurn != -1)) {
      _oppSpinCtrl.stop();
      if (mounted) setState(() { _oppIsRolling = false; _oppRollingTurn = -1; });
    }
    // Reset dice tracker when dice resets to 0 (new turn starting)
    if (p.dice == 0) _lastSeenDice = 0;

    // ── MY dice: buffer + enforce minimum 1s spin ────────────────────────────
    if (_isRolling && p.dice != 0 && _pendingDice == 0) {
      _pendingDice = p.dice;
      final elapsed   = DateTime.now().millisecondsSinceEpoch - _rollStartMs;
      final remaining = _minSpinMs - elapsed;
      if (remaining <= 0) {
        _finishRoll(_pendingDice);
      } else {
        Future.delayed(Duration(milliseconds: remaining), () {
          if (mounted && _isRolling) _finishRoll(_pendingDice);
        });
      }
    }

    // Force-stop only if server gave us nothing (disconnect edge case)
    if (_isRolling && !p.myTurn && _pendingDice == 0) _forceStopRoll();

    // ── OPPONENT dice detection ───────────────────────────────────────────────
    // KEY: detect by dice VALUE CHANGE, not by turn state.
    // When bot rolls non-6 (no tokens), the server instantly flips turn back
    // to me — so p.myTurn may already be true when this fires. We still need
    // to show the bot's animation. We detect it by noticing p.dice changed
    // to a new value that we haven't animated yet.
    final diceChanged = p.dice != 0 && p.dice != _lastSeenDice;
    if (diceChanged) {
      _lastSeenDice = p.dice;
      // Was this MY roll? Only if I started rolling (tracked by _rollStartMs)
      final isMyRoll = _isRolling || _pendingDice != 0;
      if (!isMyRoll) {
        // This is the opponent's dice — queue animation
        final theirDice = p.dice;
        final theirTurn = p.currentTurn;
        if (_isRolling || _pendingDice != 0) {
          // My spin still running — queue for after it finishes
          _oppRollQueued = true;
          _oppDiceValue  = theirDice;
          _oppRollingTurn = theirTurn;
        } else {
          // I'm completely idle — start immediately
          _startOppRoll(theirDice, theirTurn);
        }
      }
    }

    // ── Token step animation (deferred until all dice animations finish) ─────
    if (_oppIsRolling) {
      if (!_tokenMovePending) {
        _tokenMovePending = true;
        Future.delayed(const Duration(milliseconds: 1400), () {
          _tokenMovePending = false;
          if (mounted) _detectTokenMoves(context.read<GameProvider>());
        });
      }
    } else if (_isRolling || _pendingDice != 0) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _rollStartMs;
      final wait    = (_minSpinMs - elapsed).clamp(0, _minSpinMs) + 200;
      Future.delayed(Duration(milliseconds: wait), () {
        if (mounted) _detectTokenMoves(context.read<GameProvider>());
      });
    } else {
      _detectTokenMoves(p);
    }
  }

  void _syncAnimTokens(GameProvider p) {
    if (!mounted) return;
    setState(() {
      _animTokens = {
        for (final e in p.tokens.entries) e.key: List<int>.from(e.value)
      };
      _committed = {
        for (final e in p.tokens.entries) e.key: List<int>.from(e.value)
      };
    });
  }

  // Compare server state vs last committed; animate each changed token
  void _detectTokenMoves(GameProvider p) {
    bool any = false;
    for (final color in ['red','blue','green','yellow']) {
      final newList = p.tokens[color]!;
      final oldList = _committed[color]!;
      for (int i = 0; i < 4; i++) {
        if (newList[i] != oldList[i]) {
          any = true;
          final from = _animTokens[color]![i];
          final to   = newList[i];
          if (to == 0) {
            // Captured — teleport instantly back to base
            if (mounted) setState(() => _animTokens[color]![i] = 0);
          } else {
            _animateSteps(color, i, from, to);
          }
        }
      }
    }
    if (any) {
      _committed = {
        for (final e in p.tokens.entries) e.key: List<int>.from(e.value)
      };
    }
  }

  // Walk the token from fromPos → toPos, one logical cell per 160 ms
  Future<void> _animateSteps(String color, int idx, int from, int to) async {
    if (from == to) return;
    final path = _buildPath(color, from, to);
    if (!mounted) return;

    setState(() { _movingColor = color; _movingIdx = idx; });

    for (final pos in path) {
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() => _animTokens[color]![idx] = pos);
    }

    if (mounted) {
      setState(() {
        _lastMovedKey = '$color-$idx';
        _movingColor  = null;
        _movingIdx    = -1;
      });
      _bounceCtrl.forward(from: 0);
      HapticFeedback.selectionClick();
    }
  }

  // Compute every logical board position between from and to
  List<int> _buildPath(String color, int from, int to) {
    final list  = <int>[];
    final start = _startCell[color]!;
    int cur     = from;

    while (cur != to && list.length < 62) {
      if (cur == 0) {
        cur = start;
      } else if (cur > 52) {
        cur = cur + 1;
      } else {
        final done = (cur - start + 52) % 52;
        cur = (done == 51) ? 53 : (cur % 52) + 1;
      }
      if (cur > 57) break;
      list.add(cur);
    }
    return list;
  }

  void _startOppRoll(int finalDice, int turn) {
    _oppRollingTurn = turn;
    _oppSpinCtrl.repeat();
    _playSoundOpp();                 // opponent dice spin sound
    HapticFeedback.mediumImpact();
    setState(() { _oppIsRolling = true; _oppDiceValue = _rng.nextInt(6) + 1; });

    Future.delayed(const Duration(milliseconds: 1300), () {
      // Guard: if my turn already started, _onProviderChange already cleared this
      if (!mounted || !_oppIsRolling) return;
      _oppSpinCtrl.stop();
      setState(() {
        _oppIsRolling   = false;
        _oppDiceValue   = finalDice;
        _oppRollingTurn = -1;
      });
      _dicePopCtrl.forward(from: 0);
      HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    final p = context.read<GameProvider>();
    p..removeListener(_onProviderChange)..detachListeners();
    _mySpinCtrl.dispose();
    _oppSpinCtrl.dispose();
    _dicePopCtrl.dispose();
    _pulseCtrl.dispose();
    _bounceCtrl.dispose();
    _sfxMe.dispose();
    _sfxOpp.dispose();
    _sfxStart.dispose();
    super.dispose();
  }

  Future<void> _playSoundMe()    async { try { await _sfxMe.stop();    await _sfxMe.play(AssetSource('audio/ludo.mp3'));        } catch (_) {} }
  Future<void> _playSoundOpp()   async { try { await _sfxOpp.stop();   await _sfxOpp.play(AssetSource('audio/ludo.mp3'));       } catch (_) {} }
  Future<void> _playSoundStart() async { try { await _sfxStart.stop(); await _sfxStart.play(AssetSource('audio/lets-begin.mp3')); } catch (_) {} }

  // ── User actions ───────────────────────────────────────────────────────────
  Future<void> _confirmLeave() async {
    final p = context.read<GameProvider>();
    if (!p.gameStarted || p.gameOver) {
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Leave Game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('If you leave now, your opponent wins.',
            style: TextStyle(color: Colors.white54, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay',
                  style: TextStyle(color: Color(0xFF3DA9FF)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        SocketService().socket.emit('leave_game', {'roomCode': widget.roomCode});
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  void _rollDice() {
    final p = context.read<GameProvider>();
    if (!p.myTurn || p.diceRolled || _isRolling || _rollingForTurn != -1 ||
        _oppIsRolling || _oppRollQueued) return;
    HapticFeedback.mediumImpact();
    _playSoundMe();                         // my dice spin sound
    _rollingForTurn = p.currentTurn;
    _pendingDice    = 0;
    _rollStartMs    = DateTime.now().millisecondsSinceEpoch;
    _mySpinCtrl.repeat();                  // full 360° circle spin
    setState(() { _isRolling = true; _myDiceValue = _rng.nextInt(6) + 1; });
    p.rollDice(widget.roomCode);
    // Hard-stop fallback (server should respond well within 5 s)
    Future.delayed(const Duration(seconds: 5), () {
      if (_isRolling && mounted) {
        final lp = context.read<GameProvider>();
        _finishRoll(lp.dice != 0 ? lp.dice : (_pendingDice != 0 ? _pendingDice : _myDiceValue));
      }
    });
  }

  void _finishRoll(int value) {
    if (!mounted) return;
    _mySpinCtrl.stop();
    final savedDice  = _pendingDice;
    _pendingDice     = 0;
    // Show the real number with a pop animation
    setState(() {
      _isRolling      = false;
      _myDiceValue    = value;
      _rollingForTurn = -1;
    });
    _dicePopCtrl.forward(from: 0);
    HapticFeedback.heavyImpact();

    // 800ms after my number shows → play queued opponent animation.
    // _oppRollQueued is set in _onProviderChange the moment server sends bot dice.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (!_oppIsRolling) {
        if (_oppRollQueued) {
          // Use the queued dice/turn that was captured during my spin
          _oppRollQueued = false;
          _startOppRoll(_oppDiceValue, _oppRollingTurn);
        } else {
          // Fallback: check live provider in case we missed the capture
          final p = context.read<GameProvider>();
          if (!p.myTurn && p.diceRolled && p.dice != 0 &&
              p.currentTurn != _oppRollingTurn) {
            _startOppRoll(p.dice, p.currentTurn);
          }
        }
      }
    });
  }

  void _forceStopRoll() {
    if (!mounted || !_isRolling) return;
    _mySpinCtrl.stop();
    setState(() { _isRolling = false; _myDiceValue = 0; _rollingForTurn = -1; });
  }

  void _tapToken(int idx, String color) {
    final p = context.read<GameProvider>();
    if (!p.myTurn || !p.diceRolled || color != p.myColor) return;
    HapticFeedback.selectionClick();
    // Pre-snapshot so opponent-detector doesn't double-fire on my own move
    _committed = {
      for (final e in p.tokens.entries) e.key: List<int>.from(e.value)
    };
    p.moveToken(widget.roomCode, idx);
  }

  // Name resolution — never shows raw BOT_xxx strings
  String _displayName(GameProvider p, String id) {
    final prof = p.playerProfiles[id];
    if (prof?['name'] != null) return prof!['name'].toString();
    return id.contains('@') ? id.split('@').first : id;
  }

  // ── Board helpers ──────────────────────────────────────────────────────────
  int _pathIdx(int r, int c) {
    for (int i = 0; i < boardPath.length; i++) {
      if (boardPath[i][0] == r && boardPath[i][1] == c) return i;
    }
    return -1;
  }

  String? _homeColColor(int r, int c) {
    for (final e in homeCols.entries) {
      for (final pt in e.value) {
        if (pt[0] == r && pt[1] == c) return e.key;
      }
    }
    return null;
  }

  bool _isBaseSlot(String color, int r, int c) {
    for (final pt in basePos[color]!) {
      if (pt[0] == r && pt[1] == c) return true;
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, p, __) {
        final myC  = p.myColor;
        final chip = myC != null ? cMap[myC]! : Colors.white38;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            backgroundColor: _bg,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 17, color: Colors.white30),
                onPressed: _confirmLeave,
              ),
              title: Text(
                'ROOM  ${widget.roomCode}',
                style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3),
              ),
              actions: [
                if (myC != null)
                  Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: chip.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: chip.withOpacity(0.45), width: 1.2),
                    ),
                    child: Row(children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: chip)),
                      const SizedBox(width: 5),
                      Text(myC.toUpperCase(),
                          style: TextStyle(
                              color: chip,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.5)),
                    ]),
                  ),
              ],
            ),
            body: Stack(
              children: [
                Positioned.fill(
                    child: CustomPaint(painter: _AmbientPainter())),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      _buildPlayers(p),
                      const SizedBox(height: 8),
                      _buildStatus(p),
                      const SizedBox(height: 8),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        child: _buildBoard(p),
                      ),
                      const Spacer(),
                      _buildDiceRow(p),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                if (p.gameOver)
                  Positioned.fill(
                    child: p.opponentLeft
                        ? _buildOpponentLeft(p)
                        : _buildGameOver(p),
                  ),
                FloatingWinnerToast(userId: widget.userId),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Board grid ─────────────────────────────────────────────────────────────
  Widget _buildBoard(GameProvider p) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 28,
                spreadRadius: 4),
            BoxShadow(
                color: const Color(0xFF3DA9FF).withOpacity(0.07),
                blurRadius: 48,
                spreadRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 225,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
            itemBuilder: (_, i) => _cell(i ~/ 15, i % 15, p),
          ),
        ),
      ),
    );
  }

  Widget _cell(int r, int c, GameProvider p) {
    if (r < 6 && c < 6)   return _baseQuad('red',    r, c, p);
    if (r < 6 && c > 8)   return _baseQuad('blue',   r, c, p);
    if (r > 8 && c > 8)   return _baseQuad('green',  r, c, p);
    if (r > 8 && c < 6)   return _baseQuad('yellow', r, c, p);
    if (r >= 6 && r <= 8 && c >= 6 && c <= 8) return _centerCell(r, c, p);
    final hc = _homeColColor(r, c);
    if (hc != null) return _homeCell(hc, r, c, p);
    final pi = _pathIdx(r, c);
    if (pi >= 0) return _pathCell(pi + 1, r, c, p);
    return const ColoredBox(color: Color(0xFF08081E));
  }

  // ── Base quadrant ─────────────────────────────────────────────────────────
  Widget _baseQuad(String color, int row, int col, GameProvider p) {
    final base = cMap[color]!;
    final deep = cDeep[color]!;

    if (!_isBaseSlot(color, row, col)) {
      final align = color == 'red'
          ? const Alignment(-0.6, -0.6)
          : color == 'blue'
              ? const Alignment(0.6, -0.6)
              : color == 'green'
                  ? const Alignment(0.6, 0.6)
                  : const Alignment(-0.6, 0.6);
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: align,
            radius: 1.6,
            colors: [base.withOpacity(0.46), deep],
          ),
        ),
      );
    }

    // Token slot inside quadrant
    final bList = basePos[color]!;
    int tokIdx  = -1;
    for (int i = 0; i < bList.length; i++) {
      if (bList[i][0] == row && bList[i][1] == col) { tokIdx = i; break; }
    }
    if (tokIdx < 0) return ColoredBox(color: deep);

    final toks     = _animTokens[color]!;
    final inBase   = toks[tokIdx] == 0;
    final isMe     = color == p.myColor;
    final canEnter = isMe && p.myTurn && p.diceRolled && p.dice == 6 && inBase;

    return GestureDetector(
      onTap: canEnter ? () => _tapToken(tokIdx, color) : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [deep.withOpacity(0.25), deep.withOpacity(0.80)],
          ),
        ),
        child: Center(
          child: inBase
              ? _tokenWidget(color, tokIdx,
                  canMove: canEnter, p: p, size: 13.5)
              : Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: base.withOpacity(0.08),
                    border: Border.all(
                        color: base.withOpacity(0.18), width: 0.8),
                  ),
                ),
        ),
      ),
    );
  }

  // ── Path cell ─────────────────────────────────────────────────────────────
  Widget _pathCell(int pos, int row, int col, GameProvider p) {
    Color    bg   = const Color(0xFF0B0B1E);
    IconData? icon;
    Color?   iconCol;

    if (pos == 1)  { bg = cMap['red']!.withOpacity(0.75);    icon = Icons.east;  iconCol = Colors.white.withOpacity(0.7); }
    if (pos == 14) { bg = cMap['blue']!.withOpacity(0.75);   icon = Icons.south; iconCol = Colors.white.withOpacity(0.7); }
    if (pos == 27) { bg = cMap['green']!.withOpacity(0.75);  icon = Icons.west;  iconCol = Colors.white.withOpacity(0.7); }
    if (pos == 40) { bg = cMap['yellow']!.withOpacity(0.75); icon = Icons.north; iconCol = Colors.white.withOpacity(0.7); }

    final isSafe = safeCells.contains(pos) && icon == null;
    if (isSafe) bg = Colors.white.withOpacity(0.05);

    final here = <_Tok>[];
    _animTokens.forEach((c, ps) {
      for (int i = 0; i < ps.length; i++) {
        if (ps[i] == pos) here.add(_Tok(c, i, c == p.myColor));
      }
    });
    final myHere  = here.where((t) => t.isMe).toList();
    final canMove = p.myTurn && p.diceRolled;

    return GestureDetector(
      onTap: myHere.isNotEmpty && canMove
          ? () => _tapToken(myHere.first.i, myHere.first.c)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
              color: Colors.white.withOpacity(0.04), width: 0.5),
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (isSafe)
            Icon(Icons.star_rounded, size: 10,
                color: Colors.white.withOpacity(0.18)),
          if (icon != null && here.isEmpty)
            Icon(icon, size: 13, color: iconCol),
          if (here.length == 1)
            _tokenWidget(here[0].c, here[0].i,
                canMove: canMove && here[0].isMe, p: p,
                isMoving: _movingColor == here[0].c && _movingIdx == here[0].i,
                size: 12)
          else if (here.length > 1)
            _stackedTokens(here),
        ]),
      ),
    );
  }

  // ── Home column cell ──────────────────────────────────────────────────────
  Widget _homeCell(String color, int row, int col, GameProvider p) {
    final base = cMap[color]!;
    final hc   = homeCols[color]!;
    int step   = -1;
    for (int i = 0; i < hc.length; i++) {
      if (hc[i][0] == row && hc[i][1] == col) { step = i + 1; break; }
    }

    final toks = _animTokens[color]!;
    final here = <_Tok>[];
    for (int i = 0; i < toks.length; i++) {
      if (toks[i] == 52 + step) {  // pos 53-57; 57=won still renders in home col slot 5
        here.add(_Tok(color, i, color == p.myColor));
      }
    }
    final myHere  = here.where((t) => t.isMe).toList();
    final canMove = p.myTurn && p.diceRolled;
    final alpha   = 0.10 + (step / 5.0) * 0.30;

    return GestureDetector(
      onTap: myHere.isNotEmpty && canMove
          ? () => _tapToken(myHere.first.i, color)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: base.withOpacity(alpha),
          border: Border.all(
              color: base.withOpacity(0.12), width: 0.5),
        ),
        child: Center(
          child: here.isEmpty
              ? null
              : here.length == 1
                  ? _tokenWidget(here[0].c, here[0].i,
                      canMove: canMove && here[0].isMe, p: p,
                      isMoving:
                          _movingColor == here[0].c && _movingIdx == here[0].i,
                      size: 12)
                  : _stackedTokens(here),
        ),
      ),
    );
  }

  // ── Center cell ───────────────────────────────────────────────────────────
  Widget _centerCell(int row, int col, GameProvider p) {
    if (row == 7 && col == 7) {
      final winners = <_Tok>[];
      _animTokens.forEach((c, ps) {
        for (int i = 0; i < ps.length; i++) {
          if (ps[i] > 57) winners.add(_Tok(c, i, false));  // > 57: truly cleared; 57 now lives in homeCol slot 5
        }
      });
      return Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1A1A44), Color(0xFF08081E)],
          ),
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.emoji_events_rounded,
              size: 20, color: Colors.white.withOpacity(0.18)),
          if (winners.isNotEmpty) _stackedTokens(winners),
        ]),
      );
    }
    Color? bg;
    if (row == 7 && col == 6) bg = cMap['red'];
    if (row == 6 && col == 7) bg = cMap['blue'];
    if (row == 7 && col == 8) bg = cMap['green'];
    if (row == 8 && col == 7) bg = cMap['yellow'];
    return Container(
        color: bg?.withOpacity(0.56) ?? const Color(0xFF0A0A22));
  }

  // ── Token — modern flat ring design ─────────────────────────────────────
  Widget _tokenWidget(String c, int idx,
      {required bool canMove,
       required GameProvider p,
       bool isMoving = false,
       double size   = 13}) {
    final base   = cMap[c]!;
    final light  = cLight[c]!;
    final isLast = _lastMovedKey == '$c-$idx';

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _bounceCtrl]),
      builder: (_, __) {
        double scale = 1.0;
        if (canMove)            scale = _pulseAnim.value;
        if (isLast || isMoving) scale = _bounceAnim.value;

        final glowColor  = base.withOpacity(isMoving ? 0.95 : canMove ? 0.80 : 0.22);
        final glowBlur   = isMoving ? 18.0 : canMove ? 12.0 : 4.0;
        final glowSpread = isMoving ? 4.0  : canMove ? 2.0  : 0.0;

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _TokenPainter(
                color:     base,
                light:     light,
                canMove:   canMove,
                isMoving:  isMoving,
                glowColor: glowColor,
                glowBlur:  glowBlur,
                glowSpread:glowSpread,
              ),
            ),
          ),
        );
      },
    );
  }

  // Multiple tokens on same cell — small modern tokens
  Widget _stackedTokens(List<_Tok> tokens) {
    return Stack(alignment: Alignment.center, children: [
      for (int i = 0; i < tokens.length && i < 4; i++)
        Positioned(
          top:    i < 2 ? 1.0 : null,
          bottom: i >= 2 ? 1.0 : null,
          left:   i.isEven ? 1.0 : null,
          right:  i.isOdd ? 1.0 : null,
          child: SizedBox(
            width: 8, height: 8,
            child: CustomPaint(
              painter: _TokenPainter(
                color:      cMap[tokens[i].c]!,
                light:      cLight[tokens[i].c]!,
                canMove:    false,
                isMoving:   false,
                glowColor:  cMap[tokens[i].c]!.withOpacity(0.0),
                glowBlur:   0,
                glowSpread: 0,
              ),
            ),
          ),
        ),
    ]);
  }

  // ── Dice row (my dice + opponent dice side by side) ────────────────────────
  Widget _buildDiceRow(GameProvider p) {
    final isOppTurn = !p.myTurn && p.gameStarted && !p.gameOver;
    final canRoll   = p.myTurn &&
        !p.diceRolled &&
        !_isRolling &&
        !_oppIsRolling &&     // locked while bot dice animation plays
        !_oppRollQueued &&    // locked while bot roll is queued
        p.gameStarted &&
        _rollingForTurn == -1;

    // Resolve displayed values
    final myVal  = _isRolling
        ? _myDiceValue
        : (p.dice != 0 && p.myTurn ? p.dice : _myDiceValue);
    final oppVal = _oppDiceValue;

    final oppId = p.players.isNotEmpty
        ? p.players
            .firstWhere((pl) => pl['id'].toString() != widget.userId,
                orElse: () => {'id': '?'})['id']
            .toString()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── LEFT: My dice ──────────────────────────────────────────────
          _diceFaceWidget(
            value:    myVal,
            rolling:  _isRolling,
            canRoll:  canRoll,
            isActive: !isOppTurn,
            spinAnim: _mySpinAnim,
            onTap:    canRoll ? _rollDice : null,
            label:    'You',
          ),
          // ── RIGHT: Opponent dice ────────────────────────────────────────
          _diceFaceWidget(
            value:    oppVal,
            rolling:  _oppIsRolling,
            canRoll:  false,
            isActive: isOppTurn,
            spinAnim: _oppSpinAnim,
            onTap:    null,
            label:    _displayName(p, oppId),
          ),
        ],
      ),
    );
  }

  Widget _diceFaceWidget({
    required int                value,
    required bool               rolling,
    required bool               canRoll,
    required bool               isActive,
    required Animation<double>  spinAnim,
    required VoidCallback?      onTap,
    required String             label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: Listenable.merge([spinAnim, _dicePopAnim]),
          builder: (_, __) {
            final pop = (!rolling && value > 0)
                ? (0.86 + _dicePopAnim.value * 0.14)
                : 1.0;
            return Transform.scale(
              scale: pop,
              child: Transform.rotate(
                // Full circular spin while rolling; snap to 0 when done
                angle: rolling ? spinAnim.value : 0.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isActive || rolling
                          ? [const Color(0xFF1A1E42), const Color(0xFF0D1032)]
                          : [const Color(0xFF111228), const Color(0xFF080B1C)],
                    ),
                    border: Border.all(
                      color: rolling
                          ? const Color(0xFF9B59FF)
                          : canRoll
                              ? const Color(0xFF4D7FFF)
                              : isActive
                                  ? Colors.white.withOpacity(0.18)
                                  : Colors.white.withOpacity(0.06),
                      width: rolling || canRoll ? 2.0 : 1.0,
                    ),
                    boxShadow: (rolling || canRoll || isActive)
                        ? [
                            BoxShadow(
                              color: (rolling
                                      ? const Color(0xFF9B59FF)
                                      : canRoll
                                          ? const Color(0xFF4D7FFF)
                                          : Colors.white)
                                  .withOpacity(rolling ? 0.55 : 0.22),
                              blurRadius: rolling ? 32 : 16,
                              spreadRadius: rolling ? 4 : 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CustomPaint(
                      painter: _DiceDotsPainter(
                        value:   rolling ? 0 : value,
                        rolling: rolling,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isActive ? Colors.white60 : Colors.white24,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            letterSpacing: 0.4,
          ),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── Status bar ─────────────────────────────────────────────────────────────
  Widget _buildStatus(GameProvider p) {
    String msg; Color clr; IconData icon;

    if (!p.gameStarted) {
      msg = 'Waiting for game…';
      clr = const Color(0xFFFFD93D);
      icon = Icons.hourglass_top_rounded;
    } else if (p.gameOver) {
      msg = 'Game over!';
      clr = const Color(0xFFFFD93D);
      icon = Icons.emoji_events_rounded;
    } else if (p.myTurn) {
      if (_isRolling) {
        msg = 'Rolling…';
        clr = const Color(0xFF9B59FF);
        icon = Icons.autorenew_rounded;
      } else if (!p.diceRolled) {
        msg = 'Your turn — tap the dice!';
        clr = const Color(0xFF2DFF8F);
        icon = Icons.casino_rounded;
      } else {
        msg = 'Tap a token to move';
        clr = const Color(0xFF3DA9FF);
        icon = Icons.touch_app_rounded;
      }
    } else {
      final idx = p.currentTurn % (p.players.isEmpty ? 1 : p.players.length);
      final who = p.players.isNotEmpty
          ? _displayName(p, p.players[idx]['id'].toString())
          : '…';
      msg  = _oppIsRolling ? '$who is rolling…'
           : p.diceRolled  ? '$who is moving…'
           :                  'Waiting for $who';
      clr  = _oppIsRolling ? const Color(0xFF9B59FF) : Colors.white38;
      icon = _oppIsRolling ? Icons.autorenew_rounded : Icons.schedule_rounded;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: Container(
        key: ValueKey(msg),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: clr.withOpacity(0.09),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: clr.withOpacity(0.28), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: clr),
          const SizedBox(width: 7),
          Text(msg,
              style: TextStyle(
                  color: clr,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (p.gameStarted && !p.gameOver) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: p.timeLeft <= 5
                    ? Colors.red.withOpacity(0.18)
                    : clr.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${p.timeLeft}s',
                style: TextStyle(
                    color: p.timeLeft <= 5 ? Colors.redAccent : clr,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Players row ────────────────────────────────────────────────────────────
  Widget _buildPlayers(GameProvider p) {
    if (p.players.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      children: p.players.asMap().entries.map((e) {
        final active = e.key == p.currentTurn % p.players.length;
        final col    = cMap[e.value['color']] ?? Colors.white54;
        final name   = _displayName(p, e.value['id'].toString());

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? col.withOpacity(0.12)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? col.withOpacity(0.55)
                  : Colors.white.withOpacity(0.07),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: col)),
            const SizedBox(width: 5),
            Text(name,
                style: TextStyle(
                    color: active ? col : Colors.white38,
                    fontSize: 11,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.normal)),
            if (active) ...[
              const SizedBox(width: 5),
              SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: col)),
            ],
          ]),
        );
      }).toList(),
    );
  }

  Widget _winsChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD93D).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFFD93D).withOpacity(0.32), width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏆', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: UserSession.instance.winsNotifier,
          builder: (_, wins, __) => Text('$wins Total Wins',
              style: const TextStyle(
                  color: Color(0xFFFFD93D),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Game-over overlay ──────────────────────────────────────────────────────
  Widget _buildGameOver(GameProvider p) {
    final iWon       = p.winner == widget.userId;
    final wc         = p.players.firstWhere(
        (x) => x['id'] == p.winner,
        orElse: () => {'color': 'yellow'})['color'] as String;
    final g          = cMap[wc] ?? const Color(0xFFFFD93D);
    final winnerName = p.winner != null ? _displayName(p, p.winner!) : 'Unknown';

    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.withOpacity(0.08),
                border: Border.all(color: g.withOpacity(0.35), width: 2),
              ),
              child: Text(iWon ? '🏆' : '😢',
                  style: const TextStyle(fontSize: 60)),
            ),
            const SizedBox(height: 16),
            Text(
              iWon ? 'You Win!' : 'You Lose',
              style: TextStyle(
                  color: g,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            Text(
              iWon
                  ? 'Brilliant game!'
                  : '$winnerName wins this round.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 13),
            ),
            if (iWon && p.winAmount > 0) ...[
              const SizedBox(height: 12),
              Text('+₹${p.winAmount} added to balance!',
                  style: const TextStyle(
                      color: Color(0xFF2DFF8F),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 10),
            _winsChip(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                  backgroundColor: g,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: const Text('Back to Home',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Opponent-left overlay ──────────────────────────────────────────────────
  Widget _buildOpponentLeft(GameProvider p) {
    return Container(
      color: Colors.black.withOpacity(0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2DFF8F).withOpacity(0.07),
                  border: Border.all(
                      color: const Color(0xFF2DFF8F).withOpacity(0.32),
                      width: 2),
                ),
                child: const Text('🏃',
                    style: TextStyle(fontSize: 54)),
              ),
              const SizedBox(height: 22),
              const Text('Opponent Left',
                  style: TextStyle(
                      color: Color(0xFF2DFF8F),
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                p.opponentMessage ??
                    'Your opponent disconnected.\nYou win by default!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 13,
                    height: 1.6),
              ),
              if (p.winAmount > 0) ...[
                const SizedBox(height: 16),
                Text('+₹${p.winAmount} added to balance!',
                    style: const TextStyle(
                        color: Color(0xFF2DFF8F),
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ],
              const SizedBox(height: 12),
              _winsChip(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2DFF8F),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Back to Home',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DICE DOTS PAINTER — physical white dots on canvas (no emoji)
// ══════════════════════════════════════════════════════════════════════════════
class _DiceDotsPainter extends CustomPainter {
  final int  value;
  final bool rolling;
  const _DiceDotsPainter({required this.value, required this.rolling});

  @override
  void paint(Canvas canvas, Size s) {
    if (value == 0) {
      // Idle: faint centre dot
      canvas.drawCircle(
        Offset(s.width / 2, s.height / 2),
        s.width * 0.09,
        Paint()..color = Colors.white.withOpacity(rolling ? 0.14 : 0.08),
      );
      return;
    }

    final r   = s.width * 0.088;
    final pad = s.width * 0.22;
    final cx  = s.width  / 2;
    final cy  = s.height / 2;

    final tl = Offset(pad,           pad);
    final tr = Offset(s.width - pad, pad);
    final ml = Offset(pad,           cy);
    final mr = Offset(s.width - pad, cy);
    final bl = Offset(pad,           s.height - pad);
    final br = Offset(s.width - pad, s.height - pad);
    final cc = Offset(cx, cy);

    // Map faces → dot positions
    final dotMap = <int, List<Offset>>{
      1: [cc],
      2: [tr, bl],
      3: [tr, cc, bl],
      4: [tl, tr, bl, br],
      5: [tl, tr, cc, bl, br],
      6: [tl, ml, bl, tr, mr, br],
    };
    final dots = dotMap[value] ?? [];

    for (final pos in dots) {
      // Soft glow ring
      canvas.drawCircle(pos, r + 2.5,
          Paint()
            ..color = Colors.white.withOpacity(0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // Dot body with radial highlight
      canvas.drawCircle(pos, r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.38, -0.45),
              colors: [Colors.white, Colors.white.withOpacity(0.68)],
            ).createShader(Rect.fromCircle(center: pos, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_DiceDotsPainter o) =>
      o.value != value || o.rolling != rolling;
}

// ══════════════════════════════════════════════════════════════════════════════
// AMBIENT BACKGROUND GLOW PAINTER
// ══════════════════════════════════════════════════════════════════════════════
class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    void g(Offset o, Color c, double r) {
      canvas.drawCircle(
          o,
          r,
          Paint()
            ..shader = RadialGradient(
                    colors: [c.withOpacity(0.055), Colors.transparent])
                .createShader(Rect.fromCircle(center: o, radius: r)));
    }
    g(Offset(s.width * 0.10, s.height * 0.10), const Color(0xFFFF4444), 200);
    g(Offset(s.width * 0.90, s.height * 0.10), const Color(0xFF3DA9FF), 200);
    g(Offset(s.width * 0.90, s.height * 0.85), const Color(0xFF2DFF8F), 200);
    g(Offset(s.width * 0.10, s.height * 0.85), const Color(0xFFFFD93D), 200);
  }

  @override
  bool shouldRepaint(_AmbientPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════
class _Tok {
  final String c;
  final int    i;
  final bool   isMe;
  const _Tok(this.c, this.i, this.isMe);
}

// ══════════════════════════════════════════════════════════════════════════════
// TOKEN PAINTER — modern flat ring with glow
// ══════════════════════════════════════════════════════════════════════════════
class _TokenPainter extends CustomPainter {
  final Color  color;
  final Color  light;
  final bool   canMove;
  final bool   isMoving;
  final Color  glowColor;
  final double glowBlur;
  final double glowSpread;

  const _TokenPainter({
    required this.color,
    required this.light,
    required this.canMove,
    required this.isMoving,
    required this.glowColor,
    required this.glowBlur,
    required this.glowSpread,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width  / 2;
    final cy = s.height / 2;
    final r  = s.width  / 2;

    // ── Outer glow ──────────────────────────────────────────────────────────
    if (canMove || isMoving) {
      canvas.drawCircle(
        Offset(cx, cy), r + glowSpread,
        Paint()
          ..color      = glowColor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur),
      );
    }

    // ── Outer ring (thick colored border) ───────────────────────────────────
    final ringW = r * 0.32;
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..shader = RadialGradient(
          colors: [light, color, Color.lerp(color, Colors.black, 0.35)!],
          stops:  const [0.0, 0.6, 1.0],
          center: const Alignment(-0.3, -0.3),
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // ── Inner white fill ─────────────────────────────────────────────────────
    final innerR = r - ringW;
    canvas.drawCircle(
      Offset(cx, cy), innerR,
      Paint()
        ..color = canMove
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.82),
    );

    // ── Inner shadow ring (depth) ────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy), innerR,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = innerR * 0.18
        ..color       = color.withOpacity(0.22),
    );

    // ── Center dot (color accent) ────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy), innerR * 0.32,
      Paint()
        ..color = color.withOpacity(isMoving ? 1.0 : 0.75),
    );

    // ── Top-left shine (makes it feel 3-D) ──────────────────────────────────
    canvas.drawCircle(
      Offset(cx - r * 0.22, cy - r * 0.24), r * 0.14,
      Paint()..color = Colors.white.withOpacity(0.70),
    );
  }

  @override
  bool shouldRepaint(_TokenPainter o) =>
      o.color != color || o.canMove != canMove || o.isMoving != isMoving;
}