// lib/screens/splash_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/update/app_entry_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _gradientCtrl;
  late AnimationController _meshCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _taglineCtrl;
  late AnimationController _dotsCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _exitCtrl;

  late Animation<double> _gradientAngle;
  late Animation<double> _meshFloat;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset>  _taglineSlide;
  late Animation<double>  _taglineFade;
  late Animation<double>  _dotsAnim;
  late Animation<double>  _shimmer;
  late Animation<double>  _exitFade;
  late Animation<double>  _ringScale;
  late Animation<double>  _ringFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _gradientCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _gradientAngle = Tween<double>(begin: 0, end: 2 * pi)
        .animate(CurvedAnimation(parent: _gradientCtrl, curve: Curves.linear));

    _meshCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _meshFloat = CurvedAnimation(parent: _meshCtrl, curve: Curves.easeInOut);

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.0, 0.50, curve: Curves.easeOut)));
    _ringScale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _ringFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut)));

    _taglineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));
    _taglineFade = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut);

    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _dotsAnim = CurvedAnimation(parent: _dotsCtrl, curve: Curves.linear);

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _shimmer = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _taglineCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Fade out splash first, then cross-fade into the next screen
    await _exitCtrl.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppEntryGate(),
        // Smooth fade-in of the next screen over 600ms
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _gradientCtrl.dispose();
    _meshCtrl.dispose();
    _logoCtrl.dispose();
    _taglineCtrl.dispose();
    _dotsCtrl.dispose();
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF05050F),
      body: AnimatedBuilder(
        animation: _exitCtrl,
        builder: (_, child) => Opacity(opacity: _exitFade.value, child: child),
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Animated gradient background ───────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_gradientAngle, _meshFloat]),
              builder: (_, __) => CustomPaint(
                painter: _GradientBgPainter(
                  angle:      _gradientAngle.value,
                  float:      _meshFloat.value,
                  screenSize: size,
                ),
              ),
            ),

            // ── Floating mesh texture ──────────────────────────────────────
            AnimatedBuilder(
              animation: _meshFloat,
              builder: (_, __) => CustomPaint(
                painter: _MeshBlobPainter(float: _meshFloat.value),
              ),
            ),

            // ── Center content ─────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Spinning gradient ring + 'i' icon ──────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoCtrl, _shimmerCtrl, _gradientAngle]),
                    builder: (_, __) => Opacity(
                      opacity: _logoFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          width: 110, height: 110,
                          child: Stack(alignment: Alignment.center, children: [

                            // Spinning outer ring
                            Transform.scale(
                              scale: _ringScale.value,
                              child: Opacity(
                                opacity: _ringFade.value.clamp(0.0, 1.0),
                                child: Transform.rotate(
                                  angle: _gradientAngle.value,
                                  child: Container(
                                    width: 110, height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: const [
                                          Color(0xFF6C63FF),
                                          Color(0xFF3DA9FF),
                                          Color(0xFF00D2A0),
                                          Color(0xFFFF6B9D),
                                          Color(0xFF6C63FF),
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF05050F),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Second slower ring (reverse spin)
                            Transform.scale(
                              scale: _ringScale.value * 0.88,
                              child: Opacity(
                                opacity: (_ringFade.value * 0.45).clamp(0.0, 1.0),
                                child: Transform.rotate(
                                  angle: -_gradientAngle.value * 0.6,
                                  child: Container(
                                    width: 96, height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Center glow circle
                            Container(
                              width: 76, height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF6C63FF).withOpacity(0.22),
                                    const Color(0xFF3DA9FF).withOpacity(0.10),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF).withOpacity(0.40),
                                    blurRadius: 32,
                                    spreadRadius: 6,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF3DA9FF).withOpacity(0.20),
                                    blurRadius: 52,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),

                            // 'i' letter with shimmer
                            ShaderMask(
                              shaderCallback: (r) => LinearGradient(
                                begin: Alignment(-1.5 + _shimmer.value * 3, 0),
                                end:   Alignment(-0.5 + _shimmer.value * 3, 0),
                                colors: const [
                                  Color(0xFF9B94FF),
                                  Colors.white,
                                  Color(0xFF5EC5FF),
                                  Color(0xFF9B94FF),
                                ],
                                stops: const [0.0, 0.35, 0.65, 1.0],
                              ).createShader(r),
                              child: const Text(
                                'i',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── iGame title with shimmer ────────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoCtrl, _shimmerCtrl]),
                    builder: (_, __) => Opacity(
                      opacity: _logoFade.value.clamp(0.0, 1.0),
                      child: ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment(-1.5 + _shimmer.value * 3.0, 0),
                          end:   Alignment(-0.5 + _shimmer.value * 3.0, 0),
                          colors: const [
                            Color(0xFFB8B0FF),
                            Colors.white,
                            Color(0xFF70D6FF),
                            Color(0xFFB8B0FF),
                          ],
                          stops: const [0.0, 0.40, 0.65, 1.0],
                        ).createShader(r),
                        child: const Text(
                          'iGame',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Tagline ────────────────────────────────────────────
                  SlideTransition(
                    position: _taglineSlide,
                    child: FadeTransition(
                      opacity: _taglineFade,
                      child: Text(
                        'Play Smart · Win Real',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 56),

                  // ── Pulsing loading dots ───────────────────────────────
                  FadeTransition(
                    opacity: _taglineFade,
                    child: AnimatedBuilder(
                      animation: _dotsAnim,
                      builder: (_, __) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final delay = i / 3.0;
                          final t = ((_dotsAnim.value - delay + 1.0) % 1.0);
                          final scaleV = (t < 0.5
                              ? 0.5 + t * 1.0
                              : 1.5 - (t - 0.5) * 1.0).clamp(0.4, 1.0);
                          final opacity = (t < 0.5
                              ? 0.3 + t * 1.2
                              : 0.9 - (t - 0.5) * 1.0).clamp(0.0, 0.9);

                          final colors = [
                            [const Color(0xFF6C63FF), const Color(0xFF9B94FF)],
                            [const Color(0xFF3DA9FF), const Color(0xFF70D6FF)],
                            [const Color(0xFF00D2A0), const Color(0xFF6DFFC2)],
                          ];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: Transform.scale(
                              scale: scaleV,
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: colors[i],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors[i][0].withOpacity(opacity * 0.7),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom gradient progress line ──────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: FadeTransition(
                opacity: _taglineFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_logoCtrl, _taglineCtrl]),
                      builder: (_, __) {
                        final p = (_logoCtrl.value * 0.55 +
                                _taglineCtrl.value * 0.45)
                            .clamp(0.0, 1.0);
                        return Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF6C63FF).withOpacity(p),
                                const Color(0xFF3DA9FF).withOpacity(p),
                                const Color(0xFF00D2A0).withOpacity(p * 0.7),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.25, 0.55, 0.78, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xFF05050F)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated gradient background painter ─────────────────────────────────────
class _GradientBgPainter extends CustomPainter {
  final double angle;
  final double float;
  final Size   screenSize;
  const _GradientBgPainter({
    required this.angle,
    required this.float,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, s.height),
        Paint()..color = const Color(0xFF05050F));

    void blob(Offset center, Color color, double radius, double opacity) {
      canvas.drawCircle(center, radius, Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)));
    }

    final shift = sin(angle) * 28;

    blob(Offset(s.width * 0.08 + shift, s.height * 0.12 - shift * 0.6),
        const Color(0xFF6C63FF), 310, 0.20);
    blob(Offset(s.width * 0.92 - shift * 0.4, s.height * 0.14 + shift * 0.3),
        const Color(0xFF3DA9FF), 270, 0.15);
    blob(Offset(s.width * 0.88 + shift * 0.2, s.height * 0.86 - shift * 0.3),
        const Color(0xFF00D2A0), 250, 0.13);
    blob(Offset(s.width * 0.10 - shift * 0.1, s.height * 0.88 + shift * 0.2),
        const Color(0xFF5046E5), 230, 0.15);
    blob(Offset(s.width * 0.50, s.height * 0.48 + float * 18),
        const Color(0xFF6C63FF), 190, 0.06);
  }

  @override
  bool shouldRepaint(_GradientBgPainter o) =>
      o.angle != angle || o.float != float;
}

// ── Mesh dot grid + scanlines ─────────────────────────────────────────────────
class _MeshBlobPainter extends CustomPainter {
  final double float;
  const _MeshBlobPainter({required this.float});

  @override
  void paint(Canvas canvas, Size s) {
    const spacing = 36.0;
    final ox = (float * spacing * 0.4) % spacing;
    final oy = (float * spacing * 0.25) % spacing;

    for (double x = -spacing + ox; x < s.width + spacing; x += spacing) {
      for (double y = -spacing + oy; y < s.height + spacing; y += spacing) {
        final dist    = sqrt(pow(x - s.width/2, 2) + pow(y - s.height/2, 2));
        final maxDist = sqrt(pow(s.width/2, 2) + pow(s.height/2, 2));
        final opacity = (1 - dist / maxDist) * 0.055;
        canvas.drawCircle(Offset(x, y), 1.2,
            Paint()..color = Colors.white.withOpacity(opacity.clamp(0.0, 0.07)));
      }
    }

    final linePaint = Paint()
      ..color       = Colors.white.withOpacity(0.016)
      ..strokeWidth = 0.5;
    for (double i = -s.height; i < s.width + s.height; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i + s.height, s.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(_MeshBlobPainter o) => o.float != float;
}