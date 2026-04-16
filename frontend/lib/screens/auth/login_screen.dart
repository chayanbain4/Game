import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../../services/user_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;

  late AnimationController _entryController;
  late AnimationController _switchController;

  late Animation<double> _headerSlide;
  late Animation<double> _formFade;
  late Animation<double> _switchFade;

    // final String baseUrl = "http://10.0.2.2:4000";
  final String baseUrl = const bool.fromEnvironment('dart.vm.product')
    ? "https://game.iwebgenics.com"
    : "http://10.0.2.2:4017";

  static const Color _primary = Color(0xFF3D7A74);
  static const Color _accent = Color(0xFFE8534A);
  static const Color _bgDark = Color(0xFF1C2B2A);
  static const Color _surface = Color(0xFFF7F9F8);
  static const Color _textDark = Color(0xFF0F1F1E);
  static const Color _textMid = Color(0xFF6B8280);
  static const Color _border = Color(0xFFDEE8E7);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _headerSlide = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );

    _formFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _switchFade = CurvedAnimation(
      parent: _switchController,
      curve: Curves.easeInOut,
    );

    _entryController.forward();
    _switchController.value = 1.0;
  }

  @override
  void dispose() {
    _entryController.dispose();
    _switchController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleMode() async {
    await _switchController.reverse();
    setState(() => _isLogin = !_isLogin);
    _switchController.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final url =
          _isLogin ? "$baseUrl/auth/login" : "$baseUrl/auth/register";
      final body = _isLogin
          ? {
              "email": _emailController.text.trim(),
              "password": _passwordController.text.trim(),
            }
          : {
              "name": _nameController.text.trim(),
              "number": _phoneController.text.trim(),
              "email": _emailController.text.trim(),
              "password": _passwordController.text.trim(),
            };

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (_isLogin) {
          // ── Save real user data into session ──────────────────
          await UserSession.instance.setUser(
            name: data['user']?['name'] ??
                data['name'] ??
                _emailController.text.trim().split('@').first,
            email: data['user']?['email'] ??
                data['email'] ??
                _emailController.text.trim(),
            phone: data['user']?['number'] ??
                data['user']?['phone'] ??
                data['phone'] ??
                '',
            token: data['token'] ?? data['accessToken'] ?? '',
          );
          _showSnack(data['message'] ?? 'Welcome back!', success: true);
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushNamed(context, '/otp-verification', arguments: {
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'name': _nameController.text.trim(),
          });
        }
      } else {
        _showSnack(data['message'] ?? 'Something went wrong');
      }
    } catch (e) {
      if (mounted) _showSnack('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: success ? _primary : _accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              // ── HEADER ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _headerSlide,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, -40 * (1 - _headerSlide.value)),
                  child: Opacity(
                    opacity: _headerSlide.value,
                    child: _buildHeader(),
                  ),
                ),
              ),

              // ── FORM SHEET ───────────────────────────────────────
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
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36)),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(28, 36, 28, 40),
                        child: FadeTransition(
                          opacity: _switchFade,
                          child: Form(
                            key: _formKey,
                            child: _buildForm(),
                          ),
                        ),
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
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill tag
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7ECDC7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLogin ? 'Welcome back' : 'New here',
                    style: const TextStyle(
                      color: Color(0xFFB0D4D2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _isLogin ? 'Login to\nyour account' : 'Create your\naccount',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _isLogin
                  ? 'Enter your credentials to continue'
                  : 'Fill in the details to get started',
              style: const TextStyle(
                color: Color(0xFF8BBBB8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isLogin ? 'Sign in' : 'Register',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _textDark,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isLogin
              ? 'Hello, welcome back to your account'
              : 'Join us today and get started',
          style: const TextStyle(fontSize: 13, color: _textMid),
        ),

        const SizedBox(height: 28),

        if (!_isLogin) ...[
          _buildField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                (!_isLogin && (v == null || v.trim().isEmpty))
                    ? 'Please enter your name'
                    : null,
          ),
          const SizedBox(height: 16),
        ],

        _buildField(
          controller: _emailController,
          label: 'Email address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter your email';
            if (!v.contains('@')) return 'Please enter a valid email';
            return null;
          },
        ),

        const SizedBox(height: 16),

        if (!_isLogin) ...[
          _buildPhoneField(),
          const SizedBox(height: 16),
        ],

        _buildField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _textMid,
              size: 20,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your password';
            if (v.length < 6) return 'At least 6 characters required';
            return null;
          },
        ),

        if (_isLogin) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
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
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      key: ValueKey(_isLogin ? 'login' : 'register'),
                      _isLogin ? 'Login' : 'Request OTP',
                      style: const TextStyle(
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

        Row(
          children: [
            Expanded(
                child: Divider(
                    color: _textMid.withOpacity(0.2), thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('or',
                  style: TextStyle(
                      color: _textMid.withOpacity(0.6), fontSize: 13)),
            ),
            Expanded(
                child: Divider(
                    color: _textMid.withOpacity(0.2), thickness: 1)),
          ],
        ),

        const SizedBox(height: 24),

        Center(
          child: GestureDetector(
            onTap: _toggleMode,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14,
                    color: _textMid,
                    fontWeight: FontWeight.w400),
                children: [
                  TextSpan(
                    text: _isLogin
                        ? 'No registered yet?  '
                        : 'Already have an account?  ',
                  ),
                  TextSpan(
                    text: _isLogin ? 'Create an account' : 'Login',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(
          color: _textDark, fontSize: 15, fontWeight: FontWeight.w500),
      cursorColor: _primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMid, fontSize: 14),
        floatingLabelStyle: const TextStyle(
            color: _primary, fontSize: 13, fontWeight: FontWeight.w600),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, color: _textMid, size: 20),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border, width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent, width: 2)),
        errorStyle: const TextStyle(fontSize: 12, color: _accent),
      ),
      validator: validator,
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(
          color: _textDark, fontSize: 15, fontWeight: FontWeight.w500),
      cursorColor: _primary,
      decoration: InputDecoration(
        labelText: 'Phone number',
        labelStyle: const TextStyle(color: _textMid, fontSize: 14),
        floatingLabelStyle: const TextStyle(
            color: _primary, fontSize: 13, fontWeight: FontWeight.w600),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇮🇳', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Container(width: 1, height: 20, color: _border),
              const SizedBox(width: 8),
              const Text('+91',
                  style: TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border, width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent, width: 2)),
      ),
      validator: (v) =>
          (!_isLogin && (v == null || v.trim().isEmpty))
              ? 'Please enter your phone number'
              : null,
    );
  }
}

// ── Background Painter ─────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base gradient
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1C2B2A),
          Color(0xFF243432),
          Color(0xFF1A2928),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    // Glow top-right
    canvas.drawCircle(
      Offset(w * 1.05, h * 0.04),
      w * 0.75,
      Paint()
        ..color = const Color(0xFF3D7A74).withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );

    // Glow top-left
    canvas.drawCircle(
      Offset(-w * 0.1, h * 0.22),
      w * 0.45,
      Paint()
        ..color = const Color(0xFF5A9E97).withOpacity(0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );

    // Dot grid
    final dot = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..style = PaintingStyle.fill;
    const sp = 28.0;
    for (double x = sp / 2; x < w; x += sp) {
      for (double y = sp / 2; y < h * 0.56; y += sp) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }

    // Decorative thin arc
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