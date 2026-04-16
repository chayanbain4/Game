import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Rotating fake leaderboard that shows 10 winners with names and amounts
/// that change every ~3 minutes. No name ever repeats within a single list.
class LeaderboardCard extends StatefulWidget {
  const LeaderboardCard({super.key});

  @override
  State<LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends State<LeaderboardCard> {
  static const _names = [
    'Aarav', 'Vivaan', 'Aditya', 'Vihaan', 'Arjun',
    'Sai', 'Reyansh', 'Ayaan', 'Krishna', 'Ishaan',
    'Ananya', 'Diya', 'Myra', 'Sara', 'Aadhya',
    'Isha', 'Kiara', 'Riya', 'Priya', 'Neha',
    'Rohan', 'Amit', 'Vikram', 'Karan', 'Harsh',
    'Sneha', 'Pooja', 'Tanvi', 'Manish', 'Deepak',
    'Rahul', 'Mohit', 'Gaurav', 'Ankur', 'Tushar',
    'Megha', 'Kavita', 'Sonal', 'Payal', 'Nisha',
    'Yash', 'Kunal', 'Nikhil', 'Rajesh', 'Suresh',
    'Divya', 'Swati', 'Ritika', 'Shubham', 'Varun',
  ];

  static const _cities = [
    'Mumbai', 'Delhi', 'Pune', 'Jaipur', 'Lucknow',
    'Chennai', 'Kolkata', 'Hyderabad', 'Bangalore', 'Ahmedabad',
    'Surat', 'Nagpur', 'Indore', 'Bhopal', 'Patna',
  ];

  static const _amounts = [
    20, 40, 50, 100, 150, 200, 250, 300, 400, 500,
    750, 1000, 1500, 2000, 2500, 3000, 5000,
  ];

  List<Map<String, dynamic>> _leaders = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generate();
    // Rotate names every 3 minutes
    _timer = Timer.periodic(const Duration(minutes: 3), (_) => _generate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generate() {
    // Use time-based seed so it changes every 3 minutes
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final slot = epoch ~/ (3 * 60 * 1000); // changes every 3 min
    final rng = Random(slot);

    // Pick 10 unique names
    final shuffled = List<int>.generate(_names.length, (i) => i);
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }

    final list = <Map<String, dynamic>>[];
    for (int i = 0; i < 10; i++) {
      final nameIdx = shuffled[i];
      final city = _cities[rng.nextInt(_cities.length)];
      final amount = _amounts[rng.nextInt(_amounts.length)];
      list.add({
        'name': _names[nameIdx],
        'city': city,
        'total': amount,
      });
    }
    // Sort descending by amount for leaderboard feel
    list.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    if (mounted) setState(() => _leaders = list);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1332), Color(0xFF261B47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6C47FF).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C47FF).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Top Winners Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF2DFF8F),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ...List.generate(
            _leaders.length,
            (i) => _buildRow(i, _leaders[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index, Map<String, dynamic> entry) {
    final name = entry['name'] as String;
    final city = entry['city'] as String;
    final total = entry['total'] as int;
    final rank = index + 1;

    final Color rankColor;
    final String rankIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD166);
        rankIcon = '🥇';
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0);
        rankIcon = '🥈';
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32);
        rankIcon = '🥉';
        break;
      default:
        rankColor = Colors.white.withOpacity(0.35);
        rankIcon = '';
    }

    // Mask name: "Rahul" → "Ra***"
    final masked = name.length > 2
        ? '${name.substring(0, 2)}${'*' * (name.length - 2).clamp(1, 4)}'
        : name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: rank <= 3
              ? rankColor.withOpacity(0.06)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 28,
              child: rankIcon.isNotEmpty
                  ? Text(rankIcon, style: const TextStyle(fontSize: 16))
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 8),

            // Avatar circle
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name + city
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    masked,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    city,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2DFF8F).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₹$total',
                style: const TextStyle(
                  color: Color(0xFF2DFF8F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
