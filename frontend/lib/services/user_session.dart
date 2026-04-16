// lib/services/user_session.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  // In-memory cache
  String? name;
  String? email;
  String? phone;
  String? token;
  int     wins = 0;
  int     balance = 0;
  int     freeSpins = 0;
  bool    welcomeBonusClaimed = false;

  // Reactive notifiers
  final ValueNotifier<int> winsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> freeSpinsNotifier = ValueNotifier<int>(0);

  static const _kName  = 'session_name';
  static const _kEmail = 'session_email';
  static const _kPhone = 'session_phone';
  static const _kToken = 'session_token';
  static const _kWins  = 'session_wins';
  static const _kBalance = 'session_balance';
  static const _kFreeSpins = 'session_free_spins';
  static const _kBonusClaimed = 'session_bonus_claimed';

  /// First letter of name for avatar.
  String get initial =>
      (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';

  /// True when logged in.
  bool get isLoggedIn => email != null && email!.isNotEmpty;

  // ── Save on login ─────────────────────────────────────────
  Future<void> setUser({
    required String name,
    required String email,
    String? phone,
    String? token,
    int wins = 0,
  }) async {
    this.name  = name;
    this.email = email;
    this.phone = phone;
    this.token = token;
    this.wins  = wins;
    this.balance = 0;
    this.freeSpins = 0;
    this.welcomeBonusClaimed = false;
    winsNotifier.value = wins;
    balanceNotifier.value = 0;
    freeSpinsNotifier.value = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName,  name);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kPhone, phone ?? '');
    await prefs.setString(_kToken, token ?? '');
    await prefs.setInt   (_kWins,  wins);
    await prefs.setInt   (_kBalance, 0);
    await prefs.setInt   (_kFreeSpins, 0);
    await prefs.setBool  (_kBonusClaimed, false);
  }

  // ── Update balance ────────────────────────────────────────
  Future<void> setBalance(int newBalance) async {
    balance = newBalance;
    balanceNotifier.value = newBalance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBalance, newBalance);
  }

  // ── Update free spins ─────────────────────────────────────
  Future<void> setFreeSpins(int count) async {
    freeSpins = count;
    freeSpinsNotifier.value = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFreeSpins, count);
  }

  // ── Mark welcome bonus claimed ────────────────────────────
  Future<void> setBonusClaimed(bool claimed) async {
    welcomeBonusClaimed = claimed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBonusClaimed, claimed);
  }

  // ── Update wins only (called after each game result) ──────
  Future<void> setWins(int newWins) async {
    wins = newWins;
    winsNotifier.value = newWins; // notifies ValueListenableBuilder widgets immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWins, newWins);
  }

  // ── Restore session on app launch ─────────────────────────
  Future<bool> tryRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_kEmail);
    if (savedEmail == null || savedEmail.isEmpty) return false;

    name  = prefs.getString(_kName)  ?? '';
    email = savedEmail;
    phone = prefs.getString(_kPhone) ?? '';
    token = prefs.getString(_kToken) ?? '';
    wins  = prefs.getInt   (_kWins)  ?? 0;
    balance = prefs.getInt  (_kBalance) ?? 0;
    freeSpins = prefs.getInt (_kFreeSpins) ?? 0;
    welcomeBonusClaimed = prefs.getBool(_kBonusClaimed) ?? false;
    winsNotifier.value = wins;
    balanceNotifier.value = balance;
    freeSpinsNotifier.value = freeSpins;
    return true;
  }

  // ── Clear on logout ───────────────────────────────────────
  Future<void> clear() async {
    name  = null;
    email = null;
    phone = null;
    token = null;
    wins  = 0;
    balance = 0;
    freeSpins = 0;
    welcomeBonusClaimed = false;
    winsNotifier.value = 0;
    balanceNotifier.value = 0;
    freeSpinsNotifier.value = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPhone);
    await prefs.remove(_kToken);
    await prefs.remove(_kWins);
    await prefs.remove(_kBalance);
    await prefs.remove(_kFreeSpins);
    await prefs.remove(_kBonusClaimed);
  }
}