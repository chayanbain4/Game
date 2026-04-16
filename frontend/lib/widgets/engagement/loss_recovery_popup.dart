import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supportive popup shown after consecutive losses, awarding a free ticket.
/// Call `LossRecoveryPopup.show(context, recoveryData)` from any game screen.
class LossRecoveryPopup {
  static Future<void> show(
      BuildContext context, Map<String, dynamic> recovery) async {
    if (!context.mounted) return;

    final message =
        (recovery['message'] as String?) ?? 'Here is a free ticket!';

    HapticFeedback.mediumImpact();

    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LossRecovery',
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: _RecoveryDialog(
              message: message,
              onClaim: () {
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class _RecoveryDialog extends StatelessWidget {
  final String message;
  final VoidCallback onClaim;

  const _RecoveryDialog({required this.message, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFA726);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 290,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0E2E), Color(0xFF2B1650)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withAlpha(80), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(40),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withAlpha(60)),
                ),
                child: const Center(
                  child: Text('🎟️', style: TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Don\'t Give Up!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'Free ticket added to your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withAlpha(200),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Claim button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Keep Playing! 🎮',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
