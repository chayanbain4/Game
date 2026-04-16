import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  static const int _totalPages = 3;
  static const int _autoScrollSeconds = 4;

  late AnimationController _entryController;
  late AnimationController _iconPulseController;
  late Animation<double> _entryFade;
  late Animation<double> _entrySlide;
  late Animation<double> _iconPulse;

  static const Color _primary = Color(0xFF3D7A74);
  static const Color _bgDark = Color(0xFF1C2B2A);

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      tag: 'Game 01 • Ludo',
      title: 'Play Ludo With\nFriends & Family',
      boldWord: 'Play Ludo',
      description:
          'Roll the dice and race your tokens to victory!\nChallenge friends in real-time multiplayer Ludo.',
      accentColor: Color(0xFF3D7A74),
      bgAccent: Color(0xFFB8D8D8),
      pageType: _PageType.ludo,
    ),
    _OnboardPage(
      tag: 'Game 02 • Number',
      title: 'Choose Your\nLucky Number',
      boldWord: 'Choose',
      description:
          'Pick your winning number and place your bet.\nFast rounds, instant results, big rewards.',
      accentColor: Color(0xFFE8534A),
      bgAccent: Color(0xFFEAC4B8),
      pageType: _PageType.number,
    ),
    _OnboardPage(
      tag: 'Game 03 • Lottery',
      title: 'Win Big With\nLottery Jackpots',
      boldWord: 'Win Big',
      description:
          'Buy tickets, scratch cards and win massive jackpots.\nYour fortune is just one ticket away!',
      accentColor: Color(0xFF7B5EA7),
      bgAccent: Color(0xFFD4C5F0),
      pageType: _PageType.lottery,
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _entrySlide = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
    );

    _iconPulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _iconPulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(
      Duration(seconds: _autoScrollSeconds),
      (_) {
        final next = (_currentPage + 1) % _totalPages;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _stopAutoScroll() => _autoScrollTimer?.cancel();

  @override
  void dispose() {
    _stopAutoScroll();
    _entryController.dispose();
    _iconPulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _entryController.reset();
    _entryController.forward();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _stopAutoScroll();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
      _startAutoScroll();
    } else {
      _stopAutoScroll();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Stack(
        children: [
          // Animated background blobs
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: CustomPaint(
              key: ValueKey(_currentPage),
              painter: _BlobPainter(
                accentColor: _pages[_currentPage].bgAccent,
                pageIndex: _currentPage,
              ),
              size: Size.infinite,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── PageView ─────────────────────────────────────
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification) _stopAutoScroll();
                      if (n is ScrollEndNotification) {
                        Future.delayed(
                            const Duration(seconds: 2), _startAutoScroll);
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _totalPages,
                      itemBuilder: (_, i) => _buildPage(i),
                    ),
                  ),
                ),

                // ── Bottom controls ───────────────────────────────
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final page = _pages[index];

    return AnimatedBuilder(
      animation: _entryController,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon illustration
              FadeTransition(
                opacity: _entryFade,
                child: Transform.translate(
                  offset: Offset(0, -28 * (1 - _entrySlide.value)),
                  child: ScaleTransition(
                    scale: _iconPulse,
                    child: _buildIconIllustration(page),
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // Tag pill
              FadeTransition(
                opacity: _entryFade,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - _entrySlide.value)),
                  child: _buildTagPill(page),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              FadeTransition(
                opacity: _entryFade,
                child: Transform.translate(
                  offset: Offset(0, 22 * (1 - _entrySlide.value)),
                  child: _buildTitle(page),
                ),
              ),

              const SizedBox(height: 16),

              // Description
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entryController,
                  curve:
                      const Interval(0.3, 1.0, curve: Curves.easeOut),
                ),
                child: Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF0F1F1E).withOpacity(0.5),
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconIllustration(_OnboardPage page) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: page.bgAccent.withOpacity(0.15),
          ),
        ),
        // Mid ring
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: page.bgAccent.withOpacity(0.25),
          ),
        ),
        // Dark inner circle
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _bgDark,
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withOpacity(0.38),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _buildPageIcon(page),
          ),
        ),
        // Floating dots
        ..._floatingDots(page),
      ],
    );
  }

  Widget _buildPageIcon(_OnboardPage page) {
    switch (page.pageType) {
      case _PageType.ludo:
        return _LudoIcon(color: page.bgAccent);
      case _PageType.number:
        return _NumberIcon(color: page.bgAccent);
      case _PageType.lottery:
        return _LotteryIcon(color: page.bgAccent);
    }
  }

  List<Widget> _floatingDots(_OnboardPage page) {
    const positions = [
      Offset(78, -72),
      Offset(-82, -52),
      Offset(70, 68),
      Offset(-68, 70),
    ];
    const sizes = [11.0, 7.0, 9.0, 6.0];

    return List.generate(positions.length, (i) {
      return Positioned(
        left: 105 + positions[i].dx,
        top: 105 + positions[i].dy,
        child: Container(
          width: sizes[i],
          height: sizes[i],
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i.isEven
                ? page.accentColor.withOpacity(0.75)
                : page.bgAccent.withOpacity(0.65),
          ),
        ),
      );
    });
  }

  Widget _buildTagPill(_OnboardPage page) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: page.accentColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: page.accentColor.withOpacity(0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: page.accentColor),
          ),
          const SizedBox(width: 8),
          Text(
            page.tag,
            style: TextStyle(
              fontSize: 12,
              color: page.accentColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(_OnboardPage page) {
    final parts = page.title.split(page.boldWord);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 28,
          color: Color(0xFF0F1F1E),
          height: 1.25,
          letterSpacing: -0.5,
          fontWeight: FontWeight.w400,
        ),
        children: [
          TextSpan(
            text: page.boldWord,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: parts.isNotEmpty ? parts.last : ''),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Page indicators
          Row(
            children: List.generate(_totalPages, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 6),
                height: 8,
                width: active ? 28 : 8,
                decoration: BoxDecoration(
                  color: active
                      ? _pages[_currentPage].accentColor
                      : _pages[_currentPage].accentColor.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Get Started button
          GestureDetector(
            onTap: _next,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              height: 54,
              width: isLast ? 160 : 54,
              decoration: BoxDecoration(
                color: _pages[_currentPage].accentColor,
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color:
                        _pages[_currentPage].accentColor.withOpacity(0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: isLast
                  ? const Center(
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Icon Widgets ────────────────────────────────────────────────────

/// Ludo board icon — 2×2 colored quadrants with a center circle
class _LudoIcon extends StatelessWidget {
  final Color color;
  const _LudoIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(painter: _LudoPainter(color: color)),
    );
  }
}

class _LudoPainter extends CustomPainter {
  final Color color;
  _LudoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = 6.0;

    final colors = [
      color,
      Colors.white.withOpacity(0.55),
      Colors.white.withOpacity(0.55),
      color,
    ];

    final rects = [
      Rect.fromLTWH(0, 0, w / 2 - 2, h / 2 - 2),
      Rect.fromLTWH(w / 2 + 2, 0, w / 2 - 2, h / 2 - 2),
      Rect.fromLTWH(0, h / 2 + 2, w / 2 - 2, h / 2 - 2),
      Rect.fromLTWH(w / 2 + 2, h / 2 + 2, w / 2 - 2, h / 2 - 2),
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[i], Radius.circular(r)),
        Paint()..color = colors[i],
      );
    }

    // Center circle
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      9,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      6,
      Paint()..color = color.withOpacity(0.8),
    );

    // Token dots
    final dotPaint = Paint()..color = color;
    final whiteDot = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(Offset(w * 0.25, h * 0.25), 4, whiteDot);
    canvas.drawCircle(Offset(w * 0.75, h * 0.75), 4, whiteDot);
    canvas.drawCircle(Offset(w * 0.25, h * 0.75), 4, dotPaint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.25), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Number choosing icon — stylized number wheel / dial
class _NumberIcon extends StatelessWidget {
  final Color color;
  const _NumberIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(painter: _NumberPainter(color: color)),
    );
  }
}

class _NumberPainter extends CustomPainter {
  final Color color;
  _NumberPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 6 number slots around the ring
    final nums = ['1', '2', '3', '4', '5', '6'];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * 3.14159 / 180;
      final x = cx + (r - 8) * cos(angle);
      final y = cy + (r - 8) * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: nums[i],
          style: TextStyle(
            color: i == 0 ? Colors.white : color.withOpacity(0.6),
            fontSize: i == 0 ? 13 : 10,
            fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (i == 0) {
        canvas.drawCircle(Offset(x, y), 10, Paint()..color = color);
      }

      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = color);
    canvas.drawCircle(
        Offset(cx, cy), 2, Paint()..color = Colors.white.withOpacity(0.8));
  }

  double cos(double r) => (r == 0)
      ? 1
      : (r == 3.14159 / 2)
          ? 0
          : _cos(r);
  double sin(double r) => _sin(r);

  double _cos(double x) {
    double result = 1, term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sin(double x) {
    double result = x, term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Lottery icon — ticket with star
class _LotteryIcon extends StatelessWidget {
  final Color color;
  const _LotteryIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 50,
      child: CustomPaint(painter: _LotteryPainter(color: color)),
    );
  }
}

class _LotteryPainter extends CustomPainter {
  final Color color;
  _LotteryPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ticket body
    final ticketPaint = Paint()..color = color.withOpacity(0.85);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 4, w, h - 4),
      const Radius.circular(10),
    );
    canvas.drawRRect(rrect, ticketPaint);

    // Tear line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (double x = 4; x < w * 0.4; x += 6) {
      canvas.drawLine(Offset(x, h / 2 + 2), Offset(x + 3, h / 2 + 2), linePaint);
    }

    // Star shape
    final starCx = w * 0.72;
    final starCy = h * 0.55;
    _drawStar(canvas, starCx, starCy, 12, 6, Colors.white.withOpacity(0.95));

    // Small circles left side
    canvas.drawCircle(
        Offset(w * 0.2, h * 0.42), 5, Paint()..color = Colors.white.withOpacity(0.7));
    canvas.drawCircle(
        Offset(w * 0.2, h * 0.68), 3, Paint()..color = Colors.white.withOpacity(0.5));

    // Top corner ribbon
    final ribbonPath = Path()
      ..moveTo(w - 18, 0)
      ..lineTo(w, 0)
      ..lineTo(w, 20)
      ..close();
    canvas.drawPath(ribbonPath, Paint()..color = Colors.white.withOpacity(0.25));
  }

  void _drawStar(Canvas canvas, double cx, double cy, double outerR,
      double innerR, Color color) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * 36 - 90) * 3.14159 / 180;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * _cos(angle);
      final y = cy + r * _sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  double _cos(double x) {
    double result = 1, term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sin(double x) {
    double result = x, term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Background Painter ─────────────────────────────────────────────────────
class _BlobPainter extends CustomPainter {
  final Color accentColor;
  final int pageIndex;

  _BlobPainter({required this.accentColor, required this.pageIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFF7F9F8),
    );

    canvas.drawCircle(
      Offset(w * 1.1, -h * 0.04),
      w * 0.68,
      Paint()
        ..color = accentColor.withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 65),
    );

    canvas.drawCircle(
      Offset(-w * 0.15, h * 0.88),
      w * 0.55,
      Paint()
        ..color = accentColor.withOpacity(0.11)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );

    final smallOffsets = [
      Offset(w * 0.85, h * 0.44),
      Offset(w * 0.1, h * 0.34),
      Offset(w * 0.5, h * 0.84),
    ];
    canvas.drawCircle(
      smallOffsets[pageIndex % 3],
      w * 0.18,
      Paint()
        ..color = accentColor.withOpacity(0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.accentColor != accentColor || old.pageIndex != pageIndex;
}

// ── Data model ─────────────────────────────────────────────────────────────
enum _PageType { ludo, number, lottery }

class _OnboardPage {
  final String tag;
  final String title;
  final String boldWord;
  final String description;
  final Color accentColor;
  final Color bgAccent;
  final _PageType pageType;

  const _OnboardPage({
    required this.tag,
    required this.title,
    required this.boldWord,
    required this.description,
    required this.accentColor,
    required this.bgAccent,
    required this.pageType,
  });
}