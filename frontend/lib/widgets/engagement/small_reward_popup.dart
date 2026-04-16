import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_session.dart';

/// A celebratory popup that slides in when user earns a small frequent reward.
/// Call `SmallRewardPopup.show(context, rewardData)` from any game screen.
class SmallRewardPopup {
  static Future<void> show(BuildContext context, Map<String, dynamic> reward) async {
    if (!context.mounted) return;

    final type    = reward['type'] as String? ?? 'cash';
    final label   = reward['label'] as String? ?? '';
    final message = reward['message'] as String? ?? 'You earned a reward!';
    final amount  = (reward['amount'] as num?)?.toInt() ?? 0;
    final newBal  = (reward['newBalance'] as num?)?.toInt();

    // Update balance locally
    if (newBal != null) {
      await UserSession.instance.setBalance(newBal);
    }
    // Update free spins if ticket reward
    if (type == 'ticket') {
      final spins = (reward['freeSpins'] as num?)?.toInt();
      if (spins != null) {
        UserSession.instance.setFreeSpins(spins);
      } else {
        // Increment locally if server didn't return count
        UserSession.instance.setFreeSpins(UserSession.instance.freeSpins + 1);
      }
    }

    HapticFeedback.heavyImpact();

    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SmallReward',
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: _RewardDialog(
              type: type,
              label: label,
              message: message,
              amount: amount,
              onCollect: () {
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class _RewardDialog extends StatelessWidget {
  final String type;
  final String label;
  final String message;
  final int amount;
  final VoidCallback onCollect;

  const _RewardDialog({
    required this.type,
    required this.label,
    required this.message,
    required this.amount,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = type == 'cash';
    final icon = isCash ? '💰' : '🎟️';
    final accentColor = isCash
        ? const Color(0xFF00D2A0)
        : const Color(0xFFA29BFE);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF1A3040)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withAlpha(80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(40),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reward icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withAlpha(50)),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                '🎁  Bonus Reward!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(170),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Big label
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),

              Text(
                isCash ? 'added to your account' : 'use it on your next game!',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),

              // Collect button
              GestureDetector(
                onTap: onCollect,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withAlpha(200)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Collect  🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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
