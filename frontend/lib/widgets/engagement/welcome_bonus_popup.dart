import 'package:flutter/material.dart';
import '../../services/engagement_service.dart';
import '../../services/user_session.dart';

class WelcomeBonusPopup {
  static Future<void> showIfNeeded(BuildContext context) async {
    // Already claimed locally — skip API call
    if (UserSession.instance.welcomeBonusClaimed) return;

    final service = EngagementService();
    final status = await service.getWelcomeBonusStatus();
    if (status == null) return;

    final claimed = status['claimed'] == true;
    if (claimed) {
      // Mark locally so we don't check again
      await UserSession.instance.setBonusClaimed(true);
      final bal = (status['balance'] as num?)?.toInt() ?? 0;
      await UserSession.instance.setBalance(bal);
      return;
    }

    if (!context.mounted) return;

    final amount = status['displayAmount'] ?? '₹100';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'WelcomeBonus',
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: _WelcomeBonusDialog(
              displayAmount: amount,
              onClaim: () async {
                final result = await service.claimWelcomeBonus();
                if (result != null) {
                  final newBalance =
                      (result['balance'] as num?)?.toInt() ?? 0;
                  await UserSession.instance.setBalance(newBalance);
                  await UserSession.instance.setBonusClaimed(true);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeBonusDialog extends StatefulWidget {
  final String displayAmount;
  final Future<void> Function() onClaim;

  const _WelcomeBonusDialog({
    required this.displayAmount,
    required this.onClaim,
  });

  @override
  State<_WelcomeBonusDialog> createState() => _WelcomeBonusDialogState();
}

class _WelcomeBonusDialogState extends State<_WelcomeBonusDialog> {
  bool _claiming = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B0E3A), Color(0xFF2D1A5E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD166).withAlpha(80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD166).withAlpha(40),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gift icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFFFD166),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🎉 Welcome Bonus!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ve received ${widget.displayAmount} as a signup bonus!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start playing now — it\'s on us!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              // Big amount display
              Text(
                widget.displayAmount,
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              // Claim button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _claiming
                      ? null
                      : () async {
                          setState(() => _claiming = true);
                          await widget.onClaim();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: const Color(0xFF1B0E3A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _claiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF1B0E3A),
                          ),
                        )
                      : const Text(
                          'Claim Bonus',
                          style: TextStyle(
                            fontSize: 16,
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
