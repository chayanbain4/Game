import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/daily_reward_service.dart';
import '../../services/user_session.dart';

class DailyRewardPopup {
  static Future<void> show(BuildContext context) async {
    final status = await DailyRewardService().getStatus();
    if (status == null) return;

    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DailyReward',
      barrierColor: Colors.black.withAlpha(180),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: _DailyRewardDialog(status: status),
          ),
        );
      },
    );
  }
}

class _DailyRewardDialog extends StatefulWidget {
  final DailyRewardStatus status;
  const _DailyRewardDialog({required this.status});

  @override
  State<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<_DailyRewardDialog>
    with SingleTickerProviderStateMixin {
  static const Color _bg      = Color(0xFF0F1C1B);
  static const Color _surface = Color(0xFF182423);
  static const Color _gold    = Color(0xFFFFD166);
  static const Color _green   = Color(0xFF2DFF8F);
  static const Color _accent  = Color(0xFFFF9F43);
  static const Color _primary = Color(0xFF3D7A74);
  static const Color _text    = Color(0xFFF0F7F6);
  static const Color _textMid = Color(0xFF7FA8A4);

  bool _claimed = false;
  bool _claiming = false;
  DailyRewardClaimResult? _result;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _claimed = widget.status.claimedToday;
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounce = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _claimReward() async {
    if (_claiming || _claimed) return;
    setState(() => _claiming = true);

    final result = await DailyRewardService().claim();

    if (!mounted) return;

    if (result != null && result.success) {
      HapticFeedback.heavyImpact();
      _bounceCtrl.forward(from: 0);

      if (result.newBalance != null) {
        UserSession.instance.setBalance(result.newBalance!);
      }
      if (result.freeSpins != null) {
        UserSession.instance.setFreeSpins(result.freeSpins!);
      }

      setState(() {
        _claimed = true;
        _claiming = false;
        _result = result;
      });
    } else {
      setState(() {
        _claiming = false;
        if (result?.alreadyClaimed == true) _claimed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.status.rewardTable;
    final streak = _result?.streak ?? widget.status.streak;

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _gold.withAlpha(60), width: 1.5),
          boxShadow: [
            BoxShadow(color: _gold.withAlpha(25), blurRadius: 40),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    const Text(
                      'Daily Rewards',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  streak > 0
                      ? '$streak day streak! Keep it going!'
                      : 'Start your streak today!',
                  style: const TextStyle(color: _textMid, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // 7-day grid
                _buildDayGrid(table, streak),

                const SizedBox(height: 20),

                // Claim button or claimed badge
                if (_claimed)
                  _buildClaimedBadge()
                else
                  _buildClaimButton(),

                const SizedBox(height: 12),

                // Close
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: _textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _buildDayGrid(List<DailyRewardDay> table, int streak) {
    // Current day in cycle (0-based)
    final currentCycleDay = _claimed
        ? ((streak - 1) % table.length)
        : (streak % table.length);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(table.length, (i) {
        final reward = table[i];
        final bool isCompleted = _claimed ? i <= currentCycleDay : i < currentCycleDay;
        final bool isCurrent = i == currentCycleDay;
        final bool isLocked = !isCompleted && !isCurrent;

        return _buildDayCard(reward, i + 1, isCompleted, isCurrent, isLocked);
      }),
    );
  }

  Widget _buildDayCard(
      DailyRewardDay reward, int dayNum, bool completed, bool current, bool locked) {
    Color borderColor;
    Color bgColor;
    Color textColor;
    Widget icon;

    if (completed) {
      borderColor = _green.withAlpha(100);
      bgColor = _green.withAlpha(20);
      textColor = _green;
      icon = const Icon(Icons.check_circle_rounded, color: _green, size: 22);
    } else if (current) {
      borderColor = _gold.withAlpha(150);
      bgColor = _gold.withAlpha(25);
      textColor = _gold;
      icon = _rewardIcon(reward);
    } else {
      borderColor = Colors.white.withAlpha(15);
      bgColor = _surface;
      textColor = _textMid.withAlpha(120);
      icon = Icon(Icons.lock_outline_rounded, color: _textMid.withAlpha(80), size: 18);
    }

    final card = Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: current ? 2 : 1),
        boxShadow: current
            ? [BoxShadow(color: _gold.withAlpha(30), blurRadius: 12)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Day $dayNum',
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          icon,
          const SizedBox(height: 4),
          Text(
            reward.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (current && !_claimed) {
      return ScaleTransition(scale: _bounce, child: card);
    }
    return card;
  }

  Widget _rewardIcon(DailyRewardDay reward) {
    if (reward.type == 'ticket') {
      return const Text('🎫', style: TextStyle(fontSize: 22));
    }
    if (reward.day == 7) {
      return const Text('💰', style: TextStyle(fontSize: 22));
    }
    return const Text('💎', style: TextStyle(fontSize: 22));
  }

  Widget _buildClaimButton() {
    return GestureDetector(
      onTap: _claimReward,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD166), Color(0xFFFF9F43)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accent.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _claiming
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  '🎁  Claim Today\'s Reward',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildClaimedBadge() {
    final rewardLabel = _result?.reward?.label ?? widget.status.todayReward.label;
    final amount = _result?.reward?.amount ?? widget.status.todayReward.amount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _green.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            '✅  Claimed: $rewardLabel',
            style: const TextStyle(
              color: _green,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (amount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '+₹$amount added to your balance!',
              style: TextStyle(
                color: _green.withAlpha(180),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Come back tomorrow for more!',
            style: TextStyle(color: _textMid, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
