// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/ludo/game_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/number/number_game_screen.dart';
import 'screens/ludo/ludo_lobby_screen.dart';
import 'screens/scratch/scratch_game_screen.dart';
import 'screens/lottery/lottery_game_screen.dart';
import 'screens/superloto/superloto_game_screen.dart';
import 'screens/andarbahar/andarbahar_game_screen.dart';
import 'screens/history/game_history_screen.dart';
import 'screens/update/app_entry_gate.dart';
import 'screens/roulette/roulette_lobby_screen.dart';   // ← lobby (entry point)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: 'Multiplayer Games',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF3D7A74),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation:       0,
            centerTitle:     true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        builder: (context, child) => child!,

        home: const SplashScreen(),

        routes: {
          '/dashboard':        (context) => const DashboardScreen(),
          '/login':            (context) => const LoginScreen(),
          '/otp-verification': (context) => const OtpVerificationScreen(),
          '/home':             (context) => const HomeScreen(),
          '/number':           (context) => const NumberGameScreen(),
          '/ludo':             (context) => const LudoLobbyScreen(),
          '/scratch':          (context) => const ScratchGameScreen(),
          '/lottery':          (context) => const LotteryGameScreen(),
          '/superloto':        (context) => const SuperLotoGameScreen(),
          '/andarbahar':       (context) => const AndarBaharGameScreen(),
          '/history':          (context) => const GameHistoryScreen(),
          '/roulette':         (context) => const RouletteLobbyScreen(), // ← lobby first
        },
      ),
    );
  }
}