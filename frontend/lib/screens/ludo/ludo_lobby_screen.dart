// lib/screens/ludo/ludo_lobby_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/socket/socket_service.dart';
import '../../providers/ludo/game_provider.dart';
import '../../services/user_session.dart';
import 'ludo_board_screen.dart';

class LudoLobbyScreen extends StatefulWidget {
  const LudoLobbyScreen({super.key});

  @override
  State<LudoLobbyScreen> createState() => _LudoLobbyScreenState();
}

class _LudoLobbyScreenState extends State<LudoLobbyScreen>
    with TickerProviderStateMixin {

  _Phase  _phase    = _Phase.idle;
  String  _roomCode = '';
  String? _errorMsg;

  // ── 15s matchmaking countdown ──────────────────────────────────────────────
  int    _searchCountdown = 15;
  Timer? _searchTimer;

  late final String _userId;
  late final String _displayName;
  late final String _initial;

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _spinCtrl;
  late AnimationController _dotCtrl;

  late Animation<double> _entryFade;
  late Animation<double> _entrySlide;
  late Animation<double> _pulse;
  late Animation<double> _spin;
  late Animation<double> _dot;

  static const _bg      = Color(0xFF07071A);
  static const _surface = Color(0xFF0F0F2A);
  static const _border  = Color(0xFF1E1E45);
  static const _primary = Color(0xFF3D7A74);
  static const _teal    = Color(0xFF7ECDC7);
  static const _accent  = Color(0xFFE8534A);
  static const _red     = Color(0xFFFF4444);
  static const _blue    = Color(0xFF3DA9FF);
  static const _green   = Color(0xFF2DFF8F);
  static const _yellow  = Color(0xFFFFD93D);

  @override
  void initState() {
    super.initState();

final sessionEmail = UserSession.instance.email;
if (sessionEmail == null || sessionEmail.trim().isEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session missing. Please login again.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
  });

  _userId = '';
  _displayName = 'Guest';
  _initial = '?';
  return;
}

_userId = sessionEmail.trim();
_displayName = UserSession.instance.name?.trim().isNotEmpty == true
    ? UserSession.instance.name!.trim()
    : _userId;
_initial = UserSession.instance.initial;

    _initAnimations();

    // Connect socket and attach listeners immediately — no delay.
    // A delay caused a race where game_started could fire before
    // listeners were registered.
    SocketService().connect(_userId);
    _attachListeners();
  }

  void _initAnimations() {
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();

    _entryFade  = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut));
    _entrySlide = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic));
    _pulse = Tween<double>(begin: 1.00, end: 1.04).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _spin  = Tween<double>(begin: 0.0, end: 2 * pi).animate(
        CurvedAnimation(parent: _spinCtrl, curve: Curves.linear));
    _dot   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _dotCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _detachListeners();
    _searchTimer?.cancel();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ── 15s countdown helpers ────────────────────────────────────────────────
  void _startCountdown() {
    _searchTimer?.cancel();
    _searchCountdown = 15;
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_searchCountdown > 0) {
        setState(() => _searchCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  void _stopCountdown() {
    _searchTimer?.cancel();
    _searchTimer = null;
  }

  // ── Socket ─────────────────────────────────────────────────

  void _attachListeners() {
    final s = SocketService().socket;

    // User A — placed in queue, server gives roomCode
    s.on('match_waiting', (data) {
      if (!mounted) return;
      // Keep countdown running — it shows the 15s bot wait timer to the user
      setState(() {
        _roomCode = (data['roomCode'] ?? '').toString();
        _phase    = _Phase.waiting;
        _errorMsg = null;
      });
    });

    // Both players matched — navigate to board
    // ─────────────────────────────────────────────────────────
    // BUG FIX: User B never receives match_waiting so _roomCode stays ''.
    // The roomCode is inside the game_started payload — ALWAYS read it
    // from there. Otherwise User B emits roll_dice to room '' and the
    // server ignores it → dice_result never comes → rolling stuck forever.
    // ─────────────────────────────────────────────────────────
    s.on('game_started', (data) {
      if (!mounted) return;

      // Prefer roomCode from game data (works for both User A and B)
      final roomCode = (data['roomCode'] ?? _roomCode).toString();

      if (roomCode.isEmpty) {
        setState(() {
          _phase    = _Phase.error;
          _errorMsg = 'Match started but room code is missing. Please try again.';
        });
        return;
      }

      _roomCode = roomCode;
      _stopCountdown();

      final provider = context.read<GameProvider>();
      provider.attachListeners(_userId);
      provider.initFromData(data, _userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LudoBoardScreen(
            roomCode: roomCode,
            userId:   _userId,
          ),
        ),
      );
    });

    s.on('match_error', (data) {
      if (!mounted) return;
      _stopCountdown();
      setState(() {
        _phase    = _Phase.error;
        _errorMsg = (data['message'] ?? 'Something went wrong. Please try again.').toString();
      });
    });

    s.on('match_cancelled', (_) {
      if (!mounted) return;
      if (_phase != _Phase.idle && _phase != _Phase.error) {
        setState(() => _phase = _Phase.idle);
      }
    });

    s.on('balance_update', (data) {
      if (!mounted) return;
      final newBalance = (data['newBalance'] as num?)?.toInt();
      if (newBalance != null) {
        UserSession.instance.setBalance(newBalance);
      }
      final freeSpins = (data['freeSpins'] as num?)?.toInt();
      if (freeSpins != null) {
        UserSession.instance.setFreeSpins(freeSpins);
      }
    });
  }

  void _detachListeners() {
    try {
      final s = SocketService().socket;
      s.off('match_waiting');
      s.off('game_started');
      s.off('match_error');
      s.off('match_cancelled');
      s.off('balance_update');
    } catch (_) {}
  }

  // ── Actions ────────────────────────────────────────────────

  void _startSearch() {
    if (_phase == _Phase.searching || _phase == _Phase.waiting) return;

    // Check balance before matchmaking (₹10 per game) — skip if user has free spins
    if (UserSession.instance.freeSpins <= 0 && UserSession.instance.balance < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. Need ₹10, have ₹${UserSession.instance.balance}')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _phase           = _Phase.searching;
      _errorMsg        = null;
      _searchCountdown = 15;
    });
    SocketService().socket.emit('find_match', {'userId': _userId});
    _startCountdown();
  }

  void _cancelSearch() {
    HapticFeedback.lightImpact();
    _stopCountdown();
    SocketService().socket.emit('cancel_match', {});
    setState(() {
      _phase           = _Phase.idle;
      _roomCode        = '';
      _searchCountdown = 15;
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),
          SafeArea(
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => Opacity(
                opacity: _entryFade.value,
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - _entrySlide.value)),
                  child: child,
                ),
              ),
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          _buildBoardGraphic(),
                          const SizedBox(height: 30),
                          _buildTitle(),
                          const SizedBox(height: 10),
                          _buildSubtitle(),
                          const SizedBox(height: 34),
                          _buildStatusCard(),
                          const SizedBox(height: 26),
                          _buildStartButton(),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                            child: (_phase == _Phase.searching ||
                                    _phase == _Phase.waiting)
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _buildCancelButton(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                            child: _errorMsg != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _buildErrorBanner(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 32),
                          _buildRulesRow(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          // ── Back button ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              if (_phase == _Phase.searching || _phase == _Phase.waiting) {
                _cancelSearch();
              }
              Navigator.pop(context);
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white54, size: 16),
            ),
          ),
          const Spacer(),

          // ── Balance chip — coin icon + amount ────────────────────────────
          ValueListenableBuilder<int>(
            valueListenable: UserSession.instance.balanceNotifier,
            builder: (_, balance, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD93D).withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFD93D).withOpacity(0.32),
                    width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Coin icon matching image-2 style
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFE566), Color(0xFFFFB300)],
                        center: Alignment(-0.3, -0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD93D).withOpacity(0.55),
                          blurRadius: 6, spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('₹',
                          style: TextStyle(
                              color: Color(0xFF7A4800),
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$balance',
                    style: const TextStyle(
                        color: Color(0xFFFFD93D),
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardGraphic() {
    return SizedBox(
      width: 200, height: 200,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _spinCtrl]),
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: 190, height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _primary.withOpacity(0.12), width: 1.5),
                ),
              ),
            ),
            Container(
              width: 164, height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: _primary.withOpacity(0.07), width: 1),
              ),
            ),
            Container(
              width: 126, height: 126,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: _surface,
                border: Border.all(color: _border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.30),
                    blurRadius: 30, spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(painter: _MiniBoardPainter()),
              ),
            ),
            for (int i = 0; i < 4; i++) _buildOrbitToken(i),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitToken(int i) {
    const colors = [_red, _blue, _green, _yellow];
    final angle  = _spin.value + (i * pi / 2);
    const r      = 80.0;
    return Transform.translate(
      offset: Offset(cos(angle) * r, sin(angle) * r),
      child: Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors[i],
          boxShadow: [
            BoxShadow(
                color: colors[i].withOpacity(0.75),
                blurRadius: 9, spreadRadius: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Ludo',
      style: TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Roll the dice. Race your tokens.\nBe the first to reach home.',
      textAlign: TextAlign.center,
      style: TextStyle(
          color: Colors.white.withOpacity(0.36),
          fontSize: 14, height: 1.6),
    );
  }

  Widget _buildStatusCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: (_phase == _Phase.searching || _phase == _Phase.waiting)
          ? _searchingCard()
          : _idleCard(),
    );
  }

  Widget _idleCard() {
    return Container(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.people_alt_rounded, color: _teal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('2 – 4 Players',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Tap Start — we\'ll find you an opponent instantly',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.36),
                      fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchingCard() {
    // Countdown colour: green(15-9) → yellow(8-5) → red(4-0)
    final Color countColor = _searchCountdown > 8
        ? _green
        : _searchCountdown > 4
            ? _yellow
            : const Color(0xFFFF4444);

    return AnimatedBuilder(
      key: const ValueKey('searching'),
      animation: _dotCtrl,
      builder: (_, __) {
        final dots = _dot.value < 0.33 ? '.' : _dot.value < 0.66 ? '..' : '...';

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _primary.withOpacity(0.28)),
          ),
          child: Column(
            children: [
              // ── Top row: spinner + text + BIG number ─────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Spinner
                  SizedBox(
                    width: 44, height: 44,
                    child: AnimatedBuilder(
                      animation: _spinCtrl,
                      builder: (_, __) => CustomPaint(
                          painter: _ArcSpinnerPainter(_spin.value, _teal)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Finding a match…',
                            style: TextStyle(
                                color: _teal,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('Searching for opponent$dots',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.34),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  // ── THE BIG COUNTDOWN: 15 → 14 → 13 … 0 ─────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.6),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut)),
                        child: child,
                      ),
                    ),
                    child: Text(
                      '${_searchCountdown}',
                      key: ValueKey(_searchCountdown),
                      style: TextStyle(
                          color: countColor,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Progress bar ───────────────────────────────────────────────
              LayoutBuilder(builder: (ctx, bc) {
                final frac = (_searchCountdown / 15.0).clamp(0.0, 1.0);
                return Stack(children: [
                  Container(
                    width: double.infinity, height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.linear,
                    width: bc.maxWidth * frac,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [countColor, countColor.withOpacity(0.45)],
                      ),
                      boxShadow: [
                        BoxShadow(color: countColor.withOpacity(0.50), blurRadius: 8),
                      ],
                    ),
                  ),
                ]);
              }),

              const SizedBox(height: 8),

              // ── Bottom label row ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchCountdown > 0
                        ? 'Looking for a real player…'
                        : 'Matching you now…',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.30),
                        fontSize: 11),
                  ),
                  Text(
                    '${_searchCountdown}s',
                    style: TextStyle(
                        color: countColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStartButton() {
    final active = _phase == _Phase.idle || _phase == _Phase.error;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Transform.scale(
        scale: active ? _pulse.value : 1.0,
        child: GestureDetector(
          onTap: active ? _startSearch : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFF4DA89F), Color(0xFF2C6E69)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active ? null : _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: active ? Colors.transparent : _border, width: 1.2),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _primary.withOpacity(0.45),
                        blurRadius: 22,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded,
                    color: active ? Colors.white : Colors.white24, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Start',
                  style: TextStyle(
                      color: active ? Colors.white : Colors.white24,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(active ? 0.2 : 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    UserSession.instance.freeSpins > 0 ? 'FREE' : '₹10',
                    style: TextStyle(
                      color: UserSession.instance.freeSpins > 0
                          ? const Color(0xFF2DFF8F)
                          : (active ? Colors.white : Colors.white24),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: _cancelSearch,
      child: Container(
        width: double.infinity, height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: Center(
          child: Text('Cancel',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.30),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF8888), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMsg!,
                style: const TextStyle(
                    color: Color(0xFFFF9090),
                    fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesRow() {
    return Row(
      children: [
        _ruleChip(Icons.casino_rounded,         'Roll dice'),
        const SizedBox(width: 8),
        _ruleChip(Icons.directions_run_rounded, 'Move tokens'),
        const SizedBox(width: 8),
        _ruleChip(Icons.home_rounded,           'Reach home'),
      ],
    );
  }

  Widget _ruleChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(icon, color: _teal, size: 18),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.40),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

String _fallbackId() => 
      'player_${DateTime.now().millisecondsSinceEpoch % 99999}';
}

// ── Phase enum ────────────────────────────────────────────────────
enum _Phase { idle, searching, waiting, error }

// ── Mini board painter ────────────────────────────────────────────
class _MiniBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final quads = [
      (Rect.fromLTWH(0,   0,   w/2, h/2), const Color(0x44FF4444)),
      (Rect.fromLTWH(w/2, 0,   w/2, h/2), const Color(0x443DA9FF)),
      (Rect.fromLTWH(0,   h/2, w/2, h/2), const Color(0x44FFD93D)),
      (Rect.fromLTWH(w/2, h/2, w/2, h/2), const Color(0x442DFF8F)),
    ];
    for (final (rect, color) in quads) {
      canvas.drawRect(rect, Paint()..color = color);
    }

    final arm = Paint()..color = Colors.white.withOpacity(0.07);
    canvas.drawRect(Rect.fromLTWH(w * 0.35, 0,        w * 0.30, h),        arm);
    canvas.drawRect(Rect.fromLTWH(0,        h * 0.35, w,        h * 0.30), arm);

    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h / 2), width: w * 0.26, height: h * 0.26),
      Paint()..color = Colors.white.withOpacity(0.14),
    );

    final dots = [
      (Offset(w * 0.25, h * 0.25), const Color(0xFFFF4444)),
      (Offset(w * 0.75, h * 0.25), const Color(0xFF3DA9FF)),
      (Offset(w * 0.25, h * 0.75), const Color(0xFFFFD93D)),
      (Offset(w * 0.75, h * 0.75), const Color(0xFF2DFF8F)),
    ];
    for (final (pos, color) in dots) {
      canvas.drawCircle(pos, 5, Paint()..color = color.withOpacity(0.75));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Arc spinner ───────────────────────────────────────────────────
class _ArcSpinnerPainter extends CustomPainter {
  final double angle;
  final Color  color;
  const _ArcSpinnerPainter(this.angle, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 4;

    canvas.drawCircle(c, r,
        Paint()
          ..color = color.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0);

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      angle, pi * 1.3, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcSpinnerPainter old) => old.angle != angle;
}

// ── Background glows ──────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    void glow(Offset o, Color c, double r) {
      canvas.drawCircle(o, r,
          Paint()
            ..shader = RadialGradient(
                    colors: [c.withOpacity(0.09), Colors.transparent])
                .createShader(Rect.fromCircle(center: o, radius: r)));
    }

    glow(Offset(s.width * 0.85, s.height * 0.08),  const Color(0xFF3D7A74), 240);
    glow(Offset(s.width * 0.10, s.height * 0.55),  const Color(0xFF3DA9FF), 180);
    glow(Offset(s.width * 0.75, s.height * 0.84),  const Color(0xFFFFD93D), 150);
  }

  @override
  bool shouldRepaint(_BgPainter _) => false;
}