import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/user_session.dart';

/// Fetches 3 lucky numbers from the backend per user per day.
/// If a user plays these numbers in Lottery/Super Loto and wins,
/// they get a 50% Lucky Bonus on their prize.
class LuckyNumbersCard extends StatefulWidget {
  const LuckyNumbersCard({super.key});

  @override
  State<LuckyNumbersCard> createState() => _LuckyNumbersCardState();
}

class _LuckyNumbersCardState extends State<LuckyNumbersCard> {
static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4000',
);

  List<int> _lucky = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final token = UserSession.instance.token;
    if (token == null || token.isEmpty) {
      // Fallback: local generation so card isn't empty
      _fallback();
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/engagement/lucky-numbers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['numbers'] != null) {
          setState(() {
            _lucky = List<int>.from(data['numbers']);
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    _fallback();
  }

  void _fallback() {
    // Same algorithm as backend so they stay in sync
    final now = DateTime.now();
    final userId = UserSession.instance.email ?? 'guest';
    int seed = now.year * 10000 + now.month * 100 + now.day;
    for (int i = 0; i < userId.length; i++) {
      seed = (seed * 31 + userId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final numbers = <int>{};
    while (numbers.length < 3) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      numbers.add((seed % 49) + 1);
    }
    if (mounted) {
      setState(() {
        _lucky = numbers.toList()..sort();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2B1E), Color(0xFF1A3028)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2DFF8F).withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DFF8F).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Text('🍀', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Lucky Numbers Today',
                      style: TextStyle(
                        color: Color(0xFFF0F7F6),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use in Lottery / Super Loto for +50% bonus! 🎰',
                      style: TextStyle(
                        color: const Color(0xFF2DFF8F).withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Number bubbles row
          if (_loading)
            const SizedBox(
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2DFF8F),
                  ),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _lucky
                  .map(
                    (n) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2DFF8F), Color(0xFF00D2A0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF2DFF8F).withOpacity(0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              color: Color(0xFF0A1A12),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
