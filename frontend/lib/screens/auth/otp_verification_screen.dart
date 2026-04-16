import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../services/user_session.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({Key? key}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  // ── Single controller + focus — the fix for physical keyboard lag ──
  // Instead of 6 TextFields (each causing setState + focus conflicts),
  // we use ONE hidden TextField. The 6 boxes are just display widgets
  // that read from this single controller. No setState on every keystroke.
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isLoading = false;
  String? _email;
  String? _phone;
  String? _name;

  // Resend countdown
  int _secondsLeft = 60;
  bool _canResend = false;
  late AnimationController _timerController;

  late AnimationController _entryController;
  late Animation<double> _headerSlide;
  late Animation<double> _formFade;

  // Box shake animation for wrong OTP
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://game.iwebgenics.com'
        : 'http://10.0.2.2:4017',
  );

  static const Color _primary  = Color(0xFF3D7A74);
  static const Color _accent   = Color(0xFFE8534A);
  static const Color _bgDark   = Color(0xFF1C2B2A);
  static const Color _surface  = Color(0xFFF7F9F8);
  static const Color _textDark = Color(0xFF0F1F1E);
  static const Color _textMid  = Color(0xFF6B8280);
  static const Color _border   = Color(0xFFDEE8E7);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerSlide = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );
    _formFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    _entryController.forward();

    // Shake animation for wrong OTP
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Countdown timer
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        final remaining = (60 * (1 - _timerController.value)).ceil();
        if (mounted) {
          setState(() {
            _secondsLeft = remaining;
            _canResend = _timerController.isCompleted;
          });
        }
      });
    _timerController.forward();

    // Listen to OTP input — triggers rebuild only for the 6 display boxes
    _otpController.addListener(_onOtpChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _email = args['email'];
          _phone = args['phone'];
          _name  = args['name'];
        });
      }
    });
  }

  void _onOtpChanged() {
    // Only rebuild the digit boxes — NOT the whole screen
    // The listener is attached to the controller, setState here is safe
    // because it's called once per actual text change (not per IME event)
    setState(() {});
  }

  @override
  void dispose() {
    _entryController.dispose();
    _timerController.dispose();
    _shakeController.dispose();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  String get _otpCode => _otpController.text;

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: success ? _primary : _accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCode;
    if (otp.length != 6) {
      _showSnack('Please enter the complete 6-digit OTP');
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email, 'otp': otp}),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await UserSession.instance.setUser(
          name:  data['user']?['name']   ?? _name  ?? _email?.split('@').first ?? '',
          email: data['user']?['email']  ?? _email ?? '',
          phone: data['user']?['number'] ?? data['user']?['phone'] ?? _phone ?? '',
          token: data['token']           ?? data['accessToken'] ?? '',
        );
        _showSnack(data['message'] ?? 'Verification successful', success: true);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        _shakeController.forward(from: 0);
        _otpController.clear();
        _showSnack(data['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      if (mounted) _showSnack('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _email == null) return;

    setState(() {
      _isLoading   = true;
      _canResend   = false;
      _secondsLeft = 60;
    });

    _otpController.clear();
    _timerController.reset();
    _timerController.forward();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email}),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      _showSnack(
        response.statusCode == 200
            ? (data['message'] ?? 'OTP resent successfully')
            : (data['message'] ?? 'Failed to resend OTP'),
        success: response.statusCode == 200,
      );
    } catch (e) {
      if (mounted) _showSnack('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),
          Column(
            children: [
              // ── HEADER ────────────────────────────────────────────
              AnimatedBuilder(
                animation: _headerSlide,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, -40 * (1 - _headerSlide.value)),
                  child: Opacity(
                      opacity: _headerSlide.value, child: _buildHeader()),
                ),
              ),

              // ── FORM SHEET ────────────────────────────────────────
              Expanded(
                child: AnimatedBuilder(
                  animation: _formFade,
                  builder: (_, child) => Opacity(
                    opacity: _formFade.value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - _formFade.value)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(36)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(36)),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                        child: _buildBody(),
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

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 32, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08), width: 1),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7ECDC7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Almost there',
                    style: TextStyle(
                      color: Color(0xFFB0D4D2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Verify your\nidentity',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Enter the 6-digit code we sent you',
              style: TextStyle(color: Color(0xFF8BBBB8), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OTP Verification',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _textDark,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'We sent a verification code to your email.',
          style: TextStyle(fontSize: 13, color: _textMid),
        ),

        const SizedBox(height: 20),

        // Phone pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_android_rounded,
                  color: _primary, size: 18),
              const SizedBox(width: 10),
              Text(
                _phone ?? '+91 XXXXXXXXXX',
                style: const TextStyle(
                  fontSize: 15,
                  color: _textDark,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: _accent),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        const Text(
          'Verification code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textMid,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 14),

        // ── OTP display boxes + hidden input ──────────────────────
        // The Stack puts a single invisible TextField behind the 6 boxes.
        // Tapping any box focuses the hidden field → keyboard appears.
        // No setState on every keystroke, no focus conflicts, no lag.
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: Stack(
            children: [
              // Hidden TextField — the actual input
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  // Disable all IME features that cause double-fire on physical keyboard
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  style: const TextStyle(fontSize: 1, color: Colors.transparent),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),

              // 6 visual digit boxes — rebuilt by listener only when text changes
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  final shake = math.sin(_shakeAnim.value * math.pi * 5) * 8;
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _buildDigitBox(i)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Timer / resend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!_canResend) ...[
              const Icon(Icons.timer_outlined, size: 14, color: _textMid),
              const SizedBox(width: 4),
              Text(
                '${_secondsLeft}s',
                style: const TextStyle(
                  fontSize: 13,
                  color: _textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else
              GestureDetector(
                onTap: _isLoading ? null : _resendOtp,
                child: const Text(
                  'Resend code',
                  style: TextStyle(
                    fontSize: 13,
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 36),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withOpacity(0.5),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      key: ValueKey('submit'),
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Resend hint
        Center(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: _textMid),
              children: [
                const TextSpan(text: "Didn't receive code?  "),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: (_canResend && !_isLoading) ? _resendOtp : null,
                    child: Text(
                      'Resend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _canResend ? _accent : _textMid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Single digit display box ──────────────────────────────────
  // This is a pure display widget — no TextFields, no focus, no setState.
  // It just reads one character from the single _otpController.
  Widget _buildDigitBox(int index) {
    final digits = _otpController.text;
    final hasDigit = index < digits.length;
    final digit = hasDigit ? digits[index] : '';
    final isCurrent = index == digits.length && _otpFocusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 46, height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? _primary
              : hasDigit
                  ? _primary.withOpacity(0.45)
                  : _border,
          width: isCurrent ? 2.0 : 1.2,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _primary.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: hasDigit
            ? Text(
                digit,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              )
            : isCurrent
                // Blinking cursor in the active empty box
                ? _BlinkingCursor(color: _primary)
                : const SizedBox.shrink(),
      ),
    );
  }
}

// ── Blinking cursor widget ────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value,
        child: Container(
          width: 2,
          height: 24,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

// ── Background Painter ────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C2B2A),
            Color(0xFF243432),
            Color(0xFF1A2928),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    canvas.drawCircle(
      Offset(w * 1.05, h * 0.04),
      w * 0.75,
      Paint()
        ..color = const Color(0xFF3D7A74).withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );

    canvas.drawCircle(
      Offset(-w * 0.1, h * 0.22),
      w * 0.45,
      Paint()
        ..color = const Color(0xFF5A9E97).withOpacity(0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );

    final dot = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..style = PaintingStyle.fill;
    const sp = 28.0;
    for (double x = sp / 2; x < w; x += sp) {
      for (double y = sp / 2; y < h * 0.56; y += sp) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }

    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.12, h * 0.06),
          width: w * 0.65,
          height: w * 0.65),
      0,
      math.pi * 1.3,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}