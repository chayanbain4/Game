// lib/screens/home_screen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/user_session.dart';

import '../widgets/ludo/ludo_card.dart';
import '../widgets/number/number_card.dart';
import '../widgets/scratch/scratch_card.dart';
import '../widgets/lottery/lottery_card.dart';
import '../widgets/superloto/superloto_card.dart';
import '../widgets/andarbahar/andarbahar_card.dart';
import '../widgets/engagement/jackpot_banner.dart';
import '../widgets/engagement/welcome_bonus_popup.dart';
import '../widgets/engagement/draw_countdown.dart';
import '../widgets/engagement/floating_winner_popup.dart';
import '../widgets/engagement/daily_reward_popup.dart';
import '../widgets/engagement/leaderboard_card.dart';
import '../widgets/engagement/lucky_numbers_card.dart';
import '../widgets/engagement/floating_winner_toast.dart';
import '../widgets/roulette/roulette_card.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Entry animation
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slide;

  // Card pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Live count animation
  late AnimationController _liveCountCtrl;
  late Animation<double> _liveCountScale;

  // Shimmer / glow loop
  late AnimationController _glowCtrl;

  // Neon flicker for header
  late AnimationController _flickerCtrl;
  late Animation<double> _flickerAnim;

  // Live online users count
  int _liveOnlineUsers = 1000 + Random().nextInt(4001);
  Timer? _liveUsersTimer;
  bool _isOpeningDailyReward = false;

  // Stats
  int  _wins              = 0;
  bool _winsLoading       = true;
  int  _gamesSinceReward  = 0;
  int  _rewardThreshold   = 3;
  int  _dailyStreak       = 0;
  bool _dailyRewardClaimed = false;

  // Recent winners from server
  List<Map<String, dynamic>> _recentWinners = [];
  int _winnerIndex = 0;
  Timer? _winnerRotateTimer;

  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://game.iwebgenics.com'
        : 'http://10.0.2.2:4017',
  );

  // ── Design tokens ─────────────────────────────────────────────
  static const Color _bgDeep    = Color(0xFF080C14);
  static const Color _bgCard    = Color(0xFF0F1623);
  static const Color _bgPanel   = Color(0xFF131C2E);
  static const Color _gold      = Color(0xFFFFD166);
  static const Color _neonGreen = Color(0xFF00FFB2);
  static const Color _neonBlue  = Color(0xFF00BFFF);
  static const Color _accent    = Color(0xFFFF6B35);
  static const Color _purple    = Color(0xFF9B5DE5);
  static const Color _redHot    = Color(0xFFFF3B5C);
  static const Color _textWhite = Color(0xFFF0F6FF);
  static const Color _textDim   = Color(0xFF6B7FA8);
  static const Color _borderGlow = Color(0xFF1E3A5F);

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5  && hour < 12) return 'Good Morning 🌤️';
    if (hour >= 12 && hour < 17) return 'Good Afternoon ☀️';
    if (hour >= 17 && hour < 21) return 'Good Evening 🌇';
    return 'Good Night 🌙';
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Entry animation
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _slide = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic));
    _ctrl.forward();

    // Pulse animation for game cards
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Live count scale
    _liveCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _liveCountScale = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _liveCountCtrl, curve: Curves.easeInOut),
    );

    // Glow shimmer loop
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Neon flicker
    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);
    _flickerAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _flickerCtrl, curve: Curves.linear),
    );

    _wins = UserSession.instance.wins;
    _fetchStats();
    _fetchRecentWinners();
    _startLiveUsersCounter();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        WelcomeBonusPopup.showIfNeeded(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fresh = UserSession.instance.wins;
    if (fresh != _wins) setState(() => _wins = fresh);
  }

  Future<void> _fetchStats() async {
    final token = UserSession.instance.token;
    if (token == null || token.isEmpty) {
      setState(() => _winsLoading = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/auth/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final serverWins    = (data['wins']                 as num?)?.toInt() ?? 0;
          final serverBalance = (data['balance']              as num?)?.toInt() ?? 0;
          final bonusClaimed  = data['welcomeBonusClaimed']  == true;
          final gamesReward   = (data['gamesSinceLastReward'] as num?)?.toInt() ?? 0;
          final threshold     = (data['rewardThreshold']      as num?)?.toInt() ?? 3;
          final streak        = (data['dailyRewardStreak']    as num?)?.toInt() ?? 0;
          final claimed       = data['dailyRewardClaimedToday'] == true;
          final freeSpins     = (data['freeSpins']            as num?)?.toInt() ?? 0;

          await UserSession.instance.setWins(serverWins);
          await UserSession.instance.setBalance(serverBalance);
          await UserSession.instance.setBonusClaimed(bonusClaimed);
          await UserSession.instance.setFreeSpins(freeSpins);

          if (mounted) {
            setState(() {
              _wins               = serverWins;
              _winsLoading        = false;
              _gamesSinceReward   = gamesReward;
              _rewardThreshold    = threshold;
              _dailyStreak        = streak;
              _dailyRewardClaimed = claimed;
            });
          }
        }
      } else {
        if (mounted) setState(() => _winsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _winsLoading = false);
    }
  }

  Future<void> _fetchRecentWinners() async {
    final token = UserSession.instance.token;
    if (token == null || token.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/engagement/recent-winners'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final list = (data['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ?? [];
          if (list.isNotEmpty && mounted) {
            setState(() => _recentWinners = list);
            _startWinnerRotation();
          }
        }
      }
    } catch (_) {}
  }

  void _startWinnerRotation() {
    _winnerRotateTimer?.cancel();
    _winnerRotateTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _recentWinners.isEmpty) return;
      setState(() {
        _winnerIndex = (_winnerIndex + 1) % _recentWinners.length;
      });
    });
  }

  void _startLiveUsersCounter() {
    _liveUsersTimer?.cancel();
    _liveUsersTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        final change = Random().nextInt(121) - 60;
        _liveOnlineUsers = (_liveOnlineUsers + change).clamp(1000, 5000);
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    _liveCountCtrl.dispose();
    _glowCtrl.dispose();
    _flickerCtrl.dispose();
    _winnerRotateTimer?.cancel();
    _liveUsersTimer?.cancel();
    super.dispose();
  }

  Future<void> _openDailyRewardPopup() async {
    if (_isOpeningDailyReward || !mounted) return;
    setState(() => _isOpeningDailyReward = true);
    try {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      await DailyRewardPopup.show(context);
    } catch (e) {
      debugPrint('Daily reward popup open error: $e');
    } finally {
      if (mounted) setState(() => _isOpeningDailyReward = false);
    }
  }

  void _showProfilePopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            child: _ProfilePopup(
              name:    UserSession.instance.name    ?? '',
              email:   UserSession.instance.email   ?? '',
              phone:   UserSession.instance.phone   ?? '',
              wins:    UserSession.instance.wins,
              initial: UserSession.instance.initial,
              onLogout: () async {
                await UserSession.instance.clear();
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          // Deep background pattern
          Positioned.fill(child: _buildBackgroundPattern()),

          Column(
            children: [
              // Header
              AnimatedBuilder(
                animation: _slide,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, -40 * (1 - _slide.value)),
                  child: Opacity(opacity: _fade.value, child: _buildHeader()),
                ),
              ),

              // Body
              Expanded(
                child: RefreshIndicator(
                  color: _neonGreen,
                  backgroundColor: _bgCard,
                  onRefresh: () async {
                    await _fetchStats();
                    await _fetchRecentWinners();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    child: AnimatedBuilder(
                      animation: _slide,
                      builder: (_, child) => Opacity(
                        opacity: _fade.value,
                        child: Transform.translate(
                          offset: Offset(0, 28 * (1 - _slide.value)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const JackpotBanner(),
                          const SizedBox(height: 12),
                          const DrawCountdown(),
                          const SizedBox(height: 12),
                          const LuckyNumbersCard(),
                          const SizedBox(height: 14),

                       if (_recentWinners.isNotEmpty) ...[
  _buildWinnerTicker(),
  const SizedBox(height: 14),
],

_buildSectionLabel('🎮  Choose Your Game'),
const SizedBox(height: 12),

                          Column(
                            children: [
                              const FloatingWinnerPopup(),
                              const SizedBox(height: 6),
                              GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.92,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                               children: [
  _buildPulsingCard(const RouletteCard(),   delayMs: 0),
  _buildPulsingCard(const AndarBaharCard(), delayMs: 150),
  _buildPulsingCard(const LudoCard(),       delayMs: 300),
  _buildPulsingCard(const NumberCard(),     delayMs: 450),
  _buildPulsingCard(const ScratchCard(),    delayMs: 600),
  _buildPulsingCard(const LotteryCard(),    delayMs: 750),
  _buildPulsingCard(const SuperLotoCard(),  delayMs: 900),
],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Subtle tiled background ───────────────────────────────────
  Widget _buildBackgroundPattern() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _BgPatternPainter(_glowCtrl.value),
        );
      },
    );
  }

  // ── Pulsing game card wrapper ─────────────────────────────────
  Widget _buildPulsingCard(Widget card, {required int delayMs}) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final offset = (delayMs / 1400.0) % 1.0;
        final t      = (_pulseCtrl.value + offset) % 1.0;
        final scale  = 0.97 + 0.04 * sin(t * pi);
        return Transform.scale(
          scale: scale,
          child: _buildCardGlowWrapper(child!),
        );
      },
      child: card,
    );
  }

  // Neon border glow around each card
  Widget _buildCardGlowWrapper(Widget child) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        final glow = 0.3 + _glowCtrl.value * 0.7;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _neonGreen.withOpacity(0.08 * glow),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  // ── Winner ticker ─────────────────────────────────────────────
  Widget _buildWinnerTicker() {
    final winner = _recentWinners[_winnerIndex];
    final name   = winner['name']    as String? ?? 'Player';
    final city   = winner['city']    as String? ?? '';
    final game   = winner['game']    as String? ?? 'Game';
    final amount = winner['amount']  as int?    ?? 0;
    final ago    = winner['timeAgo'] as String? ?? '';

    final text = '🎉 $name${city.isNotEmpty ? ' from $city' : ''}'
        ' won ₹$amount on $game${ago.isNotEmpty ? '  •  $ago' : ''}';

    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        final glow = 0.4 + _glowCtrl.value * 0.6;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _neonGreen.withOpacity(0.10),
                _neonBlue.withOpacity(0.05),
                _neonGreen.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _neonGreen.withOpacity(0.35 * glow),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _neonGreen.withOpacity(0.12 * glow),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // LIVE badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FFB2), Color(0xFF00D4A0)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: _neonGreen.withOpacity(0.5 * glow),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF080C14),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Trophy icon
              Icon(Icons.emoji_events_rounded,
                  color: _gold.withOpacity(0.9), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.6),
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    text,
                    key: ValueKey<int>(_winnerIndex),
                    style: const TextStyle(
                      color: _textWhite,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, child) {
        final glow = 0.3 + _glowCtrl.value * 0.7;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF080F1E),
                Color(0xFF0C1526),
                Color(0xFF091120),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: _neonGreen.withOpacity(0.15 * glow),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: _neonBlue.withOpacity(0.08 * glow),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Live user count with blinking dot
                        AnimatedBuilder(
                          animation: _liveCountCtrl,
                          builder: (context, child) {
                            final blinkOpacity = 0.45 + (_liveCountCtrl.value * 0.55);
                            return Transform.scale(
                              scale: _liveCountScale.value,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Pulsing dot with halo
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Opacity(
                                          opacity: blinkOpacity * 0.4,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: _neonGreen.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        Opacity(
                                          opacity: blinkOpacity,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _neonGreen,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _neonGreen.withOpacity(blinkOpacity),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Opacity(
                                      opacity: 0.75 + (_liveCountCtrl.value * 0.25),
                                      child: Text(
                                        '$_liveOnlineUsers players online',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _neonGreen.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 5),
                        // Main headline with neon glow
                        AnimatedBuilder(
                          animation: _glowCtrl,
                          builder: (_, __) {
                            final g = 0.5 + _glowCtrl.value * 0.5;
                            return ShaderMask(
                              shaderCallback: (rect) => const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFD4F5FF),
                                  Color(0xFFFFFFFF),
                                ],
                              ).createShader(rect),
                              child: Text(
                                "Let's Play & Win",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: _neonBlue.withOpacity(0.4 * g),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      // Daily reward
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: _isOpeningDailyReward ? null : _openDailyRewardPopup,
                          child: _headerIconBtn(
                            glowColor: _gold,
                            child: SizedBox.expand(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: _isOpeningDailyReward
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(_gold),
                                            ),
                                          )
                                        : const Text('🎁',
                                            style: TextStyle(fontSize: 20)),
                                  ),
                                  if (!_dailyRewardClaimed && !_isOpeningDailyReward)
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: _redHot,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _redHot.withOpacity(0.7),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/history'),
                        child: _headerIconBtn(
                          glowColor: _neonBlue,
                          child: const Icon(Icons.history_rounded,
                              color: Color(0xFF7EC8E3), size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showLeaderboard(context),
                        child: _headerIconBtn(
                          glowColor: _gold,
                          child: const Text('🏆',
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Avatar with glow ring
                      AnimatedBuilder(
                        animation: _glowCtrl,
                        builder: (_, __) {
                          final g = 0.4 + _glowCtrl.value * 0.6;
                          return GestureDetector(
                            onTap: () => _showProfilePopup(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3D7A74), Color(0xFF1F5450)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _neonGreen.withOpacity(0.4 * g),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _neonGreen.withOpacity(0.25 * g),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  UserSession.instance.initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Stats row — three glowing chips
              Row(
                children: [
                  _winsStatChip(),
                  const SizedBox(width: 8),
                  _balanceStatChip(),
                  const SizedBox(width: 8),
                  _streakStatChip(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Icon button with glow ─────────────────────────────────────
  Widget _headerIconBtn({required Widget child, required Color glowColor}) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        final g = 0.3 + _glowCtrl.value * 0.7;
        return Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1828),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: glowColor.withOpacity(0.22 * g),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.12 * g),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  // ── Stat chips ────────────────────────────────────────────────
  Widget _winsStatChip() {
    return Expanded(
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) {
          final g = 0.35 + _glowCtrl.value * 0.65;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _gold.withOpacity(0.08),
                  const Color(0xFF0D1828),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _gold.withOpacity(0.22 * g),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _gold.withOpacity(0.08 * g),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _gold.withOpacity(0.35),
                        _gold.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _winsLoading
                        ? Container(
                            width: 30,
                            height: 13,
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : ValueListenableBuilder<int>(
                            valueListenable: UserSession.instance.winsNotifier,
                            builder: (_, wins, __) => Text(
                              '$wins',
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                    Text(
                      'Wins',
                      style: TextStyle(
                        color: _textDim.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceStatChip() {
    return Expanded(
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) {
          final g = 0.35 + _glowCtrl.value * 0.65;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _neonGreen.withOpacity(0.08),
                  const Color(0xFF0D1828),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _neonGreen.withOpacity(0.22 * g),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonGreen.withOpacity(0.08 * g),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _neonGreen.withOpacity(0.30),
                        _neonGreen.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('💰', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: UserSession.instance.balanceNotifier,
                      builder: (_, bal, __) => Text(
                        '₹$bal',
                        style: const TextStyle(
                          color: _neonGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'Balance',
                      style: TextStyle(
                        color: _textDim.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _streakStatChip() {
    return Expanded(
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) {
          final g = 0.35 + _glowCtrl.value * 0.65;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accent.withOpacity(0.10),
                  const Color(0xFF0D1828),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accent.withOpacity(0.25 * g),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.10 * g),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _accent.withOpacity(0.40),
                        _accent.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_dailyStreak}d',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Streak',
                      style: TextStyle(
                        color: _textDim.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        final g = 0.4 + _glowCtrl.value * 0.6;
        return Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_neonGreen, _neonBlue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: _neonGreen.withOpacity(0.7 * g),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textWhite,
                letterSpacing: 0.1,
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Leaderboard sheet ─────────────────────────────────────────
  void _showLeaderboard(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D1525), Color(0xFF0A101E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: _neonGreen.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FFB2), Color(0xFF00BFFF)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const LeaderboardCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background pattern painter ────────────────────────────────────
class _BgPatternPainter extends CustomPainter {
  final double animValue;
  _BgPatternPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF1A2540).withOpacity(0.5)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Glowing orbs
    final orbPaint = Paint()..style = PaintingStyle.fill;

    // Top-right teal orb
    orbPaint.shader = RadialGradient(
      colors: [
        const Color(0xFF00FFB2).withOpacity(0.07 + animValue * 0.05),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.85, size.height * 0.08),
      radius: 160,
    ));
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.08), 160, orbPaint);

    // Bottom-left blue orb
    orbPaint.shader = RadialGradient(
      colors: [
        const Color(0xFF0066FF).withOpacity(0.06 + animValue * 0.04),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.1, size.height * 0.75),
      radius: 180,
    ));
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.75), 180, orbPaint);

    // Mid-right orange orb
    orbPaint.shader = RadialGradient(
      colors: [
        const Color(0xFFFF6B35).withOpacity(0.04 + animValue * 0.03),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.9, size.height * 0.5),
      radius: 120,
    ));
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.5), 120, orbPaint);
  }

  @override
  bool shouldRepaint(_BgPatternPainter old) => old.animValue != animValue;
}

// ── Profile Popup ─────────────────────────────────────────────────
class _ProfilePopup extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final int    wins;
  final String initial;
  final VoidCallback onLogout;

  const _ProfilePopup({
    required this.name,
    required this.email,
    required this.phone,
    required this.wins,
    required this.initial,
    required this.onLogout,
  });

  static const Color _bgDeep   = Color(0xFF080C14);
  static const Color _bgCard   = Color(0xFF0F1623);
  static const Color _neonGreen = Color(0xFF00FFB2);
  static const Color _gold     = Color(0xFFFFD166);
  static const Color _redHot   = Color(0xFFFF3B5C);
  static const Color _textWhite = Color(0xFFF0F6FF);
  static const Color _textDim  = Color(0xFF6B7FA8);
  static const Color _border   = Color(0xFF1A2540);
  static const Color _accent   = Color(0xFF3D7A74);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _neonGreen.withOpacity(0.20),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 50,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: _neonGreen.withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header band
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A1628), Color(0xFF0D1E35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    border: Border(
                      bottom: BorderSide(
                        color: _neonGreen.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar with neon ring
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3D7A74), Color(0xFF1F5450)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _neonGreen.withOpacity(0.5),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _neonGreen.withOpacity(0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: _textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Wins badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _gold.withOpacity(0.15),
                              _gold.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _gold.withOpacity(0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withOpacity(0.20),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: ValueListenableBuilder<int>(
                          valueListenable: UserSession.instance.winsNotifier,
                          builder: (_, latestWins, __) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏆',
                                  style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                '$latestWins Wins',
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info rows
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      _infoRow(
                        emoji: '👤',
                        label: 'Full Name',
                        value: name.isNotEmpty ? name : '—',
                      ),
                      _divider(),
                      _infoRow(
                        emoji: '✉️',
                        label: 'Email',
                        value: email.isNotEmpty ? email : '—',
                      ),
                      _divider(),
                      _infoRow(
                        emoji: '📱',
                        label: 'Phone',
                        value: phone.isNotEmpty ? phone : '—',
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1525),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _border,
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  color: _textDim,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: onLogout,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF3B5C), Color(0xFFCC2244)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _redHot.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.logout_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
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

  Widget _infoRow({
    required String emoji,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1525),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textDim,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _textWhite,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 1,
        color: _border.withOpacity(0.6),
      );
}