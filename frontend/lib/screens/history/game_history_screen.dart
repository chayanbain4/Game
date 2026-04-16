import 'package:flutter/material.dart';
import '../../services/history_service.dart';
import '../../services/user_session.dart';

const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

String _formatDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

String _formatTime(DateTime dt) {
  final d = dt.toLocal();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const _bgDark = Color(0xFF0F1C1B);
  static const _cardBg = Color(0xFF1A2E2D);
  static const _accent = Color(0xFF3D7A74);

  late TabController _tabCtrl;
  GameHistoryData? _data;
  bool _loading = true;

  final _tabs = const [
    Tab(text: 'All'),
    Tab(text: 'Scratch'),
    Tab(text: 'A-B'),
    Tab(text: 'Lottery'),
    Tab(text: 'S-Loto'),
    Tab(text: 'Ludo'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _fetchHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final userId = UserSession.instance.email ?? '';
    if (userId.isEmpty) return;
    final data = await HistoryService().getFullHistory(userId);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Game History',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF6BA8A4),
          indicatorColor: const Color(0xFF2DFF8F),
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2DFF8F)))
          : _data == null
              ? _buildEmpty('Failed to load history')
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(_data!.all),
                    _buildList(_data!.scratch),
                    _buildList(_data!.andarbahar),
                    _buildList(_data!.lottery),
                    _buildList(_data!.superloto),
                    _buildList(_data!.ludo),
                  ],
                ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF3D5C5A), size: 56),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(color: Color(0xFF6BA8A4), fontSize: 14)),
        ],
      ),
    );
  }

  // Group entries by date and build list
  Widget _buildList(List<HistoryEntry> entries) {
    if (entries.isEmpty) return _buildEmpty('No history yet');

    // Group by date string
    final grouped = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      final key = _formatDate(e.createdAt);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final dateKeys = grouped.keys.toList();

    return RefreshIndicator(
      color: const Color(0xFF2DFF8F),
      backgroundColor: _cardBg,
      onRefresh: _fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: dateKeys.length,
        itemBuilder: (ctx, i) {
          final date = dateKeys[i];
          final items = grouped[date]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i > 0) const SizedBox(height: 16),
              // Date header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFFB0D4D2),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Entries for that date
              ...items.map((e) => _buildTile(e)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTile(HistoryEntry entry) {
    final time = _formatTime(entry.createdAt);
    final config = _gameConfig(entry.game);
    final resultColor = entry.isWin
        ? const Color(0xFF2DFF8F)
        : entry.isPending
            ? const Color(0xFFFFD166)
            : const Color(0xFFE8534A);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Game icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(config.icon, color: config.color, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Game name + details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(_subtitle(entry),
                    style: const TextStyle(
                        color: Color(0xFF6BA8A4), fontSize: 12)),
              ],
            ),
          ),

          // Result + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.result,
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(time,
                  style: const TextStyle(
                      color: Color(0xFF6BA8A4), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(HistoryEntry e) {
    switch (e.game) {
      case 'scratch':
        final symbol = e.raw['symbol'] ?? '';
        final match = e.raw['matchCount'] ?? 0;
        return symbol.isNotEmpty ? '$symbol × $match' : '$match matches';
      case 'andarbahar':
        final choice = e.raw['playerChoice'] ?? '';
        final side = e.raw['winningSide'] ?? '';
        return 'Picked $choice · Won $side';
      case 'lottery':
        final nums = (e.raw['numbers'] as List?)?.join(', ') ?? '';
        final matched = e.raw['matchCount'] ?? 0;
        return 'Numbers: $nums · $matched matched';
      case 'superloto':
        final nums = (e.raw['numbers'] as List?)?.join(', ') ?? '';
        final matched = e.raw['matchCount'] ?? 0;
        return 'Numbers: $nums · $matched matched';
      case 'ludo':
        final opponent = e.raw['opponent'] ?? '';
        return 'vs $opponent';
      default:
        return '';
    }
  }

  _GameIconConfig _gameConfig(String game) {
    switch (game) {
      case 'scratch':
        return _GameIconConfig(
            'Scratch & Win', Icons.auto_awesome, const Color(0xFFFF9F43));
      case 'andarbahar':
        return _GameIconConfig(
            'Andar Bahar', Icons.style_rounded, const Color(0xFF9B59B6));
      case 'lottery':
        return _GameIconConfig(
            'Lottery', Icons.confirmation_number_rounded, const Color(0xFF3498DB));
      case 'superloto':
        return _GameIconConfig(
            'Super Loto', Icons.stars_rounded, const Color(0xFFE74C3C));
      case 'ludo':
        return _GameIconConfig(
            'Ludo', Icons.casino_rounded, const Color(0xFF2ECC71));
      default:
        return _GameIconConfig(
            game, Icons.gamepad_rounded, const Color(0xFF7ECDC7));
    }
  }
}

class _GameIconConfig {
  final String label;
  final IconData icon;
  final Color color;
  const _GameIconConfig(this.label, this.icon, this.color);
}
